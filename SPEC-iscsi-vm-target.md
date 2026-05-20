# Spec: VM-based iSCSI target for kickstart-tests

## Problem

The `iscsi` and `iscsi-bind` tests have been tagged `knownfailure` since May 2018 because:

1. `prepare()` calls `targetcli` on the host/container, requiring `target_core_mod` and `iscsi_target_mod` kernel modules — unavailable in the container runner
2. `autopart` + `bootloader --timeout=1` on a non-iBFT iSCSI disk fails with "No usable boot drive"
3. SLIRP `hostfwd` data-plane doesn't forward iSCSI traffic reliably in containers

## Proposed solution

Replace the local `targetcli` approach with a VM-based iSCSI target using QEMU mcast socket networking. The test becomes fully self-contained — no kernel modules, no bridge networking, no special capabilities.

## Architecture

```
Container (kstest user, qemu:///session)
├── QEMU: iSCSI target VM (mcast 230.0.0.1:PORT)
│   ├── net0: mcast socket (addr=0x10, IP 10.10.10.1)
│   ├── net1: SLIRP user (addr=0x11, SSH port-forward)
│   └── targetcli listening on 10.10.10.1:3260
│
└── QEMU: test VM / anaconda (mcast 230.0.0.1:PORT)
    ├── eth0: mcast socket (addr=0x10, IP 10.10.10.2 via ip= boot arg)
    └── eth1: SLIRP user (framework NIC, DHCP, internet for packages)
```

Both VMs join the same mcast group with `localaddr=127.0.0.1`. No bridge, no tap, no `NET_ADMIN`.

## Framework integration

### Key conventions (verified against source)

- **`prepare()`** must echo ONLY the kickstart path — entire stdout is captured as a file path by `shell_launcher.py:123-125`. All helper output must go to logfile/stderr.
- **`additional_runner_args()`** output is split by `.split()` (any whitespace) at `shell_launcher.py:54` and appended to virt-install args at `virtual_controller.py:194`. Each `echo` line becomes one argv element. `$tmpdir` is available as a global shell variable (not a parameter).
- **`prepare_network()`** output gets `,model=virtio` appended blindly at `virtual_controller.py:155`. Return `"user"` for a SLIRP NIC; the mcast NIC is injected via `additional_runner_args()` instead.
- **`prepare_disks()`** override returns empty — no local virtio disk. The iSCSI disk is the sole installation target.
- **`validate()`** override needed — default `validate_RESULT()` uses `virt-copy-out` on local disk images, but the iSCSI backing store is inside the target VM.

### Data flow between functions

`prepare()` writes state files to `$tmpdir`:
- `iscsi-target-domain` — libvirt domain name (for cleanup)
- `iscsi-target-disk` — disk image path (for cleanup)
- `iscsi-mcast-port` — mcast port (for `additional_runner_args()`)
- `iscsi-ssh-port` — SSH forward port (for `validate()` and cleanup)

`additional_runner_args()` reads `$tmpdir/iscsi-mcast-port` and echoes `--qemu-commandline` args.

`validate()` reads `$tmpdir/iscsi-ssh-port` and SSHs into the target VM to extract RESULT.

`cleanup()` reads `$tmpdir/iscsi-target-domain` and `$tmpdir/iscsi-target-disk` to destroy the target VM.

## Changes to kickstart-tests

### 1. `containers/runner/Dockerfile` — add `sshpass`

Add `sshpass` to the `dnf -y install` list. Required for SSH into the target VM.

### 2. New function: `create_iscsi_target_vm()` in `functions.sh`

```bash
create_iscsi_target_vm() {
    local wwn=$1
    local initiator=$2
    local tmpdir=$3
    local logfile=$4

    # Deterministic ports from tmpdir name to avoid collisions
    local port_seed=$(echo "${tmpdir}" | cksum | awk '{print $1}')
    local mcast_port=$((10000 + port_seed % 20000))
    local ssh_port=$((30000 + (port_seed + 1) % 20000))
    local target_ip=10.10.10.1
    local disk_img=${tmpdir}/iscsi-target.qcow2
    local domain_name="iscsi-target-$(basename ${tmpdir})"

    # Write state files early so cleanup works on partial failure
    echo ${domain_name} > ${tmpdir}/iscsi-target-domain
    echo ${disk_img} > ${tmpdir}/iscsi-target-disk
    echo ${mcast_port} > ${tmpdir}/iscsi-mcast-port
    echo ${ssh_port} > ${tmpdir}/iscsi-ssh-port

    local cache_dir=${KSTEST_ISCSI_CACHE:-/var/tmp/kstest-iscsi-cache}
    local base_img="${cache_dir}/iscsi-target-base.qcow2"

    if [ ! -f "${base_img}" ]; then
        # First run: download and prepare the base image
        local image_url=${KSTEST_ISCSI_TARGET_IMAGE:-"https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"}

        mkdir -p "${cache_dir}"

        if [[ "${image_url}" == http* ]]; then
            echo "Downloading iSCSI target base image..." >&2
            curl -f -L --retry 3 -o "${cache_dir}/download.tmp" "${image_url}" &>> ${logfile}
            mv "${cache_dir}/download.tmp" "${cache_dir}/downloaded.qcow2"
        else
            cp "${image_url}" "${cache_dir}/downloaded.qcow2"
        fi

        # Prepare the image offline: set root password, install targetcli,
        # enable sshd, disable cloud-init
        virt-customize -a "${cache_dir}/downloaded.qcow2" \
            --root-password password:testcase \
            --install targetcli,NetworkManager \
            --run-command 'systemctl enable sshd target' \
            --run-command 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-kstest.conf' \
            --run-command 'systemctl disable cloud-init cloud-init-local cloud-config cloud-final' \
            --selinux-relabel \
            &>> ${logfile}

        # Atomic cache write
        mv "${cache_dir}/downloaded.qcow2" "${base_img}.tmp.$$"
        mv "${base_img}.tmp.$$" "${base_img}"
    fi

    # Create overlay from cached base (instant)
    qemu-img create -f qcow2 -b "${base_img}" -F qcow2 "${disk_img}" &>> ${logfile}

    # Boot the target VM
    virt-install \
        --name ${domain_name} \
        --ram 2048 --vcpus 1 \
        --disk path=${disk_img},bus=virtio \
        --import --graphics none --noautoconsole \
        --osinfo detect=on,require=off \
        --seclabel type=none \
        --network none \
        --qemu-commandline="-netdev" \
        "--qemu-commandline=socket,id=net0,mcast=230.0.0.1:${mcast_port},localaddr=127.0.0.1" \
        --qemu-commandline="-device" \
        "--qemu-commandline=virtio-net-pci,netdev=net0,addr=0x10" \
        --qemu-commandline="-netdev" \
        "--qemu-commandline=user,id=net1,hostfwd=tcp::${ssh_port}-:22" \
        --qemu-commandline="-device" \
        "--qemu-commandline=virtio-net-pci,netdev=net1,addr=0x11" \
        &>> ${logfile}

    # Wait for boot with retry loop (up to 120s)
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2"
    local ssh_cmd="sshpass -p testcase ssh ${ssh_opts} -p ${ssh_port} root@127.0.0.1"
    local ssh_ok=false
    for i in $(seq 1 120); do
        if ${ssh_cmd} 'echo ready' &>/dev/null; then
            ssh_ok=true
            break
        fi
        sleep 1
    done

    if ! ${ssh_ok}; then
        echo "ERROR: iSCSI target VM did not become reachable in 120s" >&2
        return 1
    fi

    # Configure iSCSI target (all output to logfile)
    ${ssh_cmd} << SSHEOF &>> ${logfile}
        set -e
        # Configure static IP on mcast NIC (addr=0x10)
        IFACE=\$(ls /sys/bus/pci/devices/0000:00:10.0/net/ 2>/dev/null | head -1)
        if [ -z "\$IFACE" ]; then
            IFACE=\$(ip -o link show | grep -v lo | head -1 | awk -F': ' '{print \$2}')
        fi
        nmcli connection add type ethernet con-name iscsi-net ifname \$IFACE \
            ipv4.method manual ipv4.addresses ${target_ip}/24 ipv6.method disabled
        nmcli connection up iscsi-net

        # Create sparse backing store (10G)
        dd if=/dev/zero of=/root/disk bs=1M count=1 seek=10240

        # Configure iSCSI target with explicit portal IP
        targetcli "/backstores/fileio create file_or_dev=/root/disk name=disk"
        targetcli "/iscsi create wwn=${wwn}"
        targetcli "/iscsi/${wwn}/tpg1/luns create /backstores/fileio/disk"
        targetcli "/iscsi/${wwn}/tpg1 set attribute authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1"
        # Replace default portal with explicit IP to avoid portal redirect issues
        targetcli "/iscsi/${wwn}/tpg1/portals delete 0.0.0.0 3260" 2>/dev/null || true
        targetcli "/iscsi/${wwn}/tpg1/portals delete ::0 3260" 2>/dev/null || true
        targetcli "/iscsi/${wwn}/tpg1/portals create ${target_ip} 3260"
        targetcli "/ saveconfig"

        # Open firewall (may not be installed — ignore errors)
        firewall-cmd --permanent --add-service=iscsi-target 2>/dev/null && \
            firewall-cmd --reload 2>/dev/null || true
SSHEOF

    if [ $? -ne 0 ]; then
        echo "ERROR: iSCSI target VM setup failed" >&2
        return 1
    fi

    # Verify target is listening
    ${ssh_cmd} 'ss -tlnp | grep -q 3260' &>> ${logfile} || {
        echo "ERROR: iSCSI target not listening on port 3260" >&2
        return 1
    }
}
```

### 3. New function: `remove_iscsi_target_vm()` in `functions.sh`

```bash
remove_iscsi_target_vm() {
    local domain_name=$1
    local disk_img=$2
    local logfile=$3

    if [ -n "${domain_name}" ]; then
        virsh destroy ${domain_name} &>> ${logfile} || true
        virsh undefine ${domain_name} &>> ${logfile} || true
    fi
    rm -f ${disk_img}
}
```

### 4. Modified `iscsi.sh`

```bash
# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE=${TESTTYPE:-"iscsi"}

. ${KSTESTDIR}/functions.sh

kernel_args() {
    # net.ifnames=0: ensure predictable ethN naming for ip= boot arg
    # ip=: static IP on eth0 (mcast NIC at PCI addr=0x10, enumerated first on q35)
    echo ${DEFAULT_BOOTOPTS} net.ifnames=0 \
        ip=10.10.10.2:::255.255.255.0::eth0:none
}

prepare_network() {
    # Return SLIRP NIC only — mcast NIC added via additional_runner_args
    echo "user"
}

prepare_disks() {
    # No local disk — iSCSI disk is the sole installation target
    echo ""
}

prepare() {
    local ks=$1
    local tmpdir=$2

    local test_id=$(basename ${tmpdir})
    local lc_test_id=${test_id,,}
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}
    local initiator=iqn.2009-02.com.example:${lc_test_id}
    local logfile=${tmpdir}/iscsi-target.log

    # Start and configure iSCSI target VM (output goes to logfile, not stdout)
    create_iscsi_target_vm ${wwn} ${initiator} ${tmpdir} ${logfile} || return 1

    # Substitute values in kickstart
    sed -i \
        -e "s#@KSTEST_ISCSI_IP@#10.10.10.1#g" \
        -e "s#@KSTEST_ISCSI_PORT@#3260#g" \
        -e "s#@KSTEST_ISCSI_TARGET@#${wwn}#g" \
        -e "s#@KSTEST_ISCSINAME@#${initiator}#g" \
        ${ks}

    # ONLY echo the kickstart path — framework treats stdout as file path
    echo ${ks}
}

additional_runner_args() {
    # Read mcast port saved by prepare()
    local mcast_port=$(cat ${tmpdir}/iscsi-mcast-port 2>/dev/null)
    if [ -n "${mcast_port}" ]; then
        echo "--qemu-commandline=-netdev"
        echo "--qemu-commandline=socket,id=iscsi0,mcast=230.0.0.1:${mcast_port},localaddr=127.0.0.1"
        echo "--qemu-commandline=-device"
        echo "--qemu-commandline=virtio-net-pci,netdev=iscsi0,addr=0x10"
    fi
    # Disable SELinux confinement for mcast socket access
    echo "--seclabel"
    echo "type=none"
    echo "--wait"
    echo "$(get_timeout)"
}

validate() {
    local disksdir=$1

    # Extract RESULT from iSCSI backing store inside the target VM
    local ssh_port=$(cat ${disksdir}/iscsi-ssh-port 2>/dev/null)
    if [ -z "${ssh_port}" ]; then
        echo "*** No SSH port file — cannot extract RESULT"
        return 1
    fi

    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
    local ssh_cmd="sshpass -p testcase ssh ${ssh_opts} -p ${ssh_port} root@127.0.0.1"
    local scp_cmd="sshpass -p testcase scp ${ssh_opts} -P ${ssh_port}"

    # Copy RESULT file from the installed system on the iSCSI disk
    # The backing store is at /root/disk — mount it and extract RESULT
    ${ssh_cmd} << 'SSHEOF' > ${disksdir}/RESULT 2>/dev/null
        # Find and mount the root partition from the iSCSI backing store
        LOOPDEV=$(losetup --find --show --partscan /root/disk 2>/dev/null)
        if [ -z "$LOOPDEV" ]; then
            echo "FAILED: could not loop-mount iSCSI backing store"
            exit 0
        fi
        # Try each partition for /root/RESULT
        for part in ${LOOPDEV}p*; do
            mount -o ro "$part" /mnt 2>/dev/null || continue
            if [ -f /mnt/root/RESULT ]; then
                cat /mnt/root/RESULT
                umount /mnt
                losetup -d "$LOOPDEV"
                exit 0
            fi
            umount /mnt 2>/dev/null
        done
        # Try LVM
        vgscan --mknodes 2>/dev/null
        vgchange -ay 2>/dev/null
        for lv in /dev/mapper/*-root /dev/mapper/*-*; do
            mount -o ro "$lv" /mnt 2>/dev/null || continue
            if [ -f /mnt/root/RESULT ]; then
                cat /mnt/root/RESULT
                umount /mnt
                losetup -d "$LOOPDEV" 2>/dev/null
                exit 0
            fi
            umount /mnt 2>/dev/null
        done
        losetup -d "$LOOPDEV" 2>/dev/null
        echo "FAILED: /root/RESULT not found on iSCSI disk"
SSHEOF

    # Also collect anaconda logs from the target VM's backing store
    local anaconda_dir=${disksdir}/anaconda
    mkdir -p ${anaconda_dir}
    ${ssh_cmd} << 'SSHEOF' > /dev/null 2>&1
        LOOPDEV=$(losetup --find --show --partscan /root/disk 2>/dev/null)
        for part in ${LOOPDEV}p*; do
            mount -o ro "$part" /mnt 2>/dev/null || continue
            if [ -d /mnt/var/log/anaconda ]; then
                tar -cf /tmp/anaconda-logs.tar -C /mnt/var/log/anaconda . 2>/dev/null
                umount /mnt
                losetup -d "$LOOPDEV" 2>/dev/null
                exit 0
            fi
            umount /mnt 2>/dev/null
        done
        # Try LVM
        vgscan --mknodes 2>/dev/null
        vgchange -ay 2>/dev/null
        for lv in /dev/mapper/*-root /dev/mapper/*-*; do
            mount -o ro "$lv" /mnt 2>/dev/null || continue
            if [ -d /mnt/var/log/anaconda ]; then
                tar -cf /tmp/anaconda-logs.tar -C /mnt/var/log/anaconda . 2>/dev/null
                umount /mnt
                losetup -d "$LOOPDEV" 2>/dev/null
                exit 0
            fi
            umount /mnt 2>/dev/null
        done
        losetup -d "$LOOPDEV" 2>/dev/null
SSHEOF
    ${scp_cmd} root@127.0.0.1:/tmp/anaconda-logs.tar ${anaconda_dir}/anaconda-logs.tar 2>/dev/null
    tar -xf ${anaconda_dir}/anaconda-logs.tar -C ${anaconda_dir} 2>/dev/null
    rm -f ${anaconda_dir}/anaconda-logs.tar

    validate_RESULT ${disksdir}
}

cleanup() {
    local tmpdir=$1
    local domain=$(cat ${tmpdir}/iscsi-target-domain 2>/dev/null)
    local disk=$(cat ${tmpdir}/iscsi-target-disk 2>/dev/null)
    local logfile=${tmpdir}/iscsi-target.log
    remove_iscsi_target_vm "${domain}" "${disk}" "${logfile}"
}
```

### 5. Modified `iscsi.ks.in`

```kickstart
%ksappend repos/default.ks

iscsiname @KSTEST_ISCSINAME@
iscsi --ipaddr @KSTEST_ISCSI_IP@ --port @KSTEST_ISCSI_PORT@ --target @KSTEST_ISCSI_TARGET@

bootloader --location=none
zerombr
clearpart --all
autopart --nohome

keyboard us
lang en
timezone America/New_York
rootpw qweqwe
shutdown

%packages
%end

%post --nochroot
SYSROOT=/mnt/sysroot

function check_iscsi_session_nochroot() {
    local transport="$1"
    local target="$2"
    iscsiadm -m session | egrep -q '^'${transport}':.*'${target}
    if [[ $? -ne 0 ]]; then
        echo "*** Failed check: ${target} session using ${transport} exists" >> $SYSROOT/root/RESULT
    fi
}

check_iscsi_session_nochroot tcp @KSTEST_ISCSI_TARGET@
%end

%post
if [[ ! -e /root/RESULT ]]; then
   echo SUCCESS > /root/RESULT
fi
%end
```

Key changes from original:
- `bootloader --location=none` — non-iBFT iSCSI can't be a boot device
- `autopart --nohome` — simpler layout for iSCSI disk

### 6. Modified `iscsi-bind.ks.in`

Same changes: `bootloader --location=none`, `autopart --nohome`. Keep `--iface=@KSTEST_NETDEV1@`.

### 7. Modified `iscsi-bind.sh`

```bash
# shellcheck disable=SC2034
TESTTYPE=${TESTTYPE:-"iscsi"}

. ${KSTESTDIR}/iscsi.sh

prepare() {
    local ks=$1
    local tmpdir=$2

    local test_id=$(basename ${tmpdir})
    local lc_test_id=${test_id,,}
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}
    local initiator=iqn.2009-02.com.example:${lc_test_id}
    local logfile=${tmpdir}/iscsi-target.log

    create_iscsi_target_vm ${wwn} ${initiator} ${tmpdir} ${logfile} || return 1

    # eth0 is the mcast NIC (PCI addr=0x10, iSCSI network)
    sed -i \
        -e "s#@KSTEST_ISCSI_IP@#10.10.10.1#g" \
        -e "s#@KSTEST_ISCSI_PORT@#3260#g" \
        -e "s#@KSTEST_ISCSI_TARGET@#${wwn}#g" \
        -e "s#@KSTEST_ISCSINAME@#${initiator}#g" \
        -e "s#@KSTEST_NETDEV1@#eth0#g" \
        ${ks}

    echo ${ks}
}
```

### 8. New `iscsi-ordering.ks.in` (INSTALLER-4044)

```kickstart
%ksappend repos/default.ks

# INSTALLER-4044 reproducer: ignoredisk BEFORE iscsi
# On unfixed builds, this fails with "Disk sda does not exist"
# On fixed builds (deferred device resolution), this works
ignoredisk --only-use=@KSTEST_ISCSI_DISK@

iscsiname @KSTEST_ISCSINAME@
iscsi --ipaddr @KSTEST_ISCSI_IP@ --port @KSTEST_ISCSI_PORT@ --target @KSTEST_ISCSI_TARGET@

bootloader --location=none
zerombr
clearpart --all
autopart --nohome

keyboard us
lang en
timezone America/New_York
rootpw qweqwe
shutdown

%packages
%end

%post --nochroot
SYSROOT=/mnt/sysroot

function check_iscsi_session_nochroot() {
    local transport="$1"
    local target="$2"
    iscsiadm -m session | egrep -q '^'${transport}':.*'${target}
    if [[ $? -ne 0 ]]; then
        echo "*** Failed check: ${target} session using ${transport} exists" >> $SYSROOT/root/RESULT
    fi
}

check_iscsi_session_nochroot tcp @KSTEST_ISCSI_TARGET@
%end

%post
if [[ ! -e /root/RESULT ]]; then
   echo SUCCESS > /root/RESULT
fi
%end
```

### 9. New `iscsi-ordering.sh`

```bash
# INSTALLER-4044: ignoredisk before iscsi ordering test
# Requires the anaconda fix that defers device resolution to process_kickstart()

# shellcheck disable=SC2034
TESTTYPE=${TESTTYPE:-"iscsi"}

. ${KSTESTDIR}/iscsi.sh

prepare() {
    local ks=$1
    local tmpdir=$2

    local test_id=$(basename ${tmpdir})
    local lc_test_id=${test_id,,}
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}
    local initiator=iqn.2009-02.com.example:${lc_test_id}
    local logfile=${tmpdir}/iscsi-target.log

    create_iscsi_target_vm ${wwn} ${initiator} ${tmpdir} ${logfile} || return 1

    # sda is the expected device name for the first SCSI disk from iSCSI
    sed -i \
        -e "s#@KSTEST_ISCSI_IP@#10.10.10.1#g" \
        -e "s#@KSTEST_ISCSI_PORT@#3260#g" \
        -e "s#@KSTEST_ISCSI_TARGET@#${wwn}#g" \
        -e "s#@KSTEST_ISCSINAME@#${initiator}#g" \
        -e "s#@KSTEST_ISCSI_DISK@#sda#g" \
        ${ks}

    echo ${ks}
}
```

## NIC ordering assumption (q35)

On q35 machine type (modern Fedora default):
- The `--qemu-commandline` mcast NIC at `addr=0x10` lands on PCI bus 0, slot 16
- The framework NIC (`--network user,model=virtio`) goes through libvirt onto a PCIe root port on bus 1+
- PCI bus 0 is enumerated before bus 1, so with `net.ifnames=0`: **eth0 = mcast, eth1 = SLIRP**

On i440fx (older/non-default): both NICs on bus 0, libvirt NIC gets ~slot 3 (lower), so ordering reverses. This spec assumes q35.

If NIC ordering is wrong on first test run, change `ip=...::eth0:none` to `ip=...::eth1:none` in `kernel_args()`.

## Caching strategy

- First run: download cloud image + `virt-customize` to install targetcli and set root password (~2-5 min)
- Cache at `$KSTEST_ISCSI_CACHE` (default `/var/tmp/kstest-iscsi-cache/iscsi-target-base.qcow2`) — the image has targetcli installed but NO iSCSI target configured
- Subsequent runs: qcow2 overlay from cached base (instant) + SSH to configure test-specific IQN/portal (~30s)
- Atomic cache writes: temp file + `mv` to prevent corruption from concurrent writes
- Cache invalidation: manual (`rm -rf $KSTEST_ISCSI_CACHE`). `KSTEST_ISCSI_CACHE` env var allows CI to use a shared persistent cache

## Dependencies

Required on the host/container:
- `sshpass` — for SSH into target VM (add to Dockerfile)
- `qemu-img`, `virt-install`, `virt-customize` — already present
- `guestfs-tools` — already present (provides `virt-customize`)
- `/dev/kvm` — already present
- No `targetcli`, no kernel modules, no `NET_ADMIN`, no bridge networking

## Review findings addressed

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| C1 | Critical | SSH stdout corrupts `prepare()` output | All `create_iscsi_target_vm` output → logfile (`&>> ${logfile}`) |
| C2 | Critical | Cloud image has no root password / cloud-init blocks | `virt-customize` sets password, installs targetcli, disables cloud-init |
| C3 | Critical | Can't extract RESULT from iSCSI disk inside target VM | Custom `validate()` SSHs into target VM, loop-mounts backing store, extracts RESULT |
| C4 | Critical | `--connect qemu:///system` fails as non-root in container | Removed — use framework default (qemu:///session) |
| H1 | High | NIC PCI ordering depends on machine type (q35 vs i440fx) | Document q35 assumption; verify empirically on first run |
| H2 | High | `iscsi-bind.ks.in` not modified with bootloader fix | Added to file list — same `bootloader --location=none` change |
| H3 | High | Cached base image has stale targetcli state | Cache BEFORE targetcli config — each overlay starts clean |
| H4 | High | SELinux may block mcast socket on test VM | `--seclabel type=none` in `additional_runner_args()` |
| H5 | High | `iscsi_disk_img` variable references non-existent local file | Do not set — custom `validate()` replaces the pattern |
| M1 | Medium | SSH retry loop has no ConnectTimeout | Add `-o ConnectTimeout=2` to SSH opts |
| M2 | Medium | Concurrent cache writes can corrupt base image | Atomic write: temp file + `mv` |
| M3 | Medium | `prepare_disks()` creates unwanted local disk | Override to return empty |
| M4 | Medium | Port range overlap between mcast and SSH | Separate ranges: mcast 10000-29999, SSH 30000-49999 |
| M5 | Medium | `sda` disk name assumed for iscsi-ordering test | Document assumption; stable across x86_64 |
| L1 | Low | `--osinfo name=fedora-rawhide` may not exist | Use `detect=on,require=off` |
| L2 | Low | `prepare_disks()` return value for empty | Override explicitly |
