#!/usr/bin/python3
#
# Detect the tests affected by a git change.

import argparse
import subprocess
import sys
import os


FRAGMENTS_DIR = "fragments"
KS_IN_SUFFIX = ".ks.in"
SH_SUFFIX = ".sh"


SELF_TESTS = [
    (
        # test get_tests_with_modified_libs part
        "5248cee4e3f55^",
        "5248cee4e3f55",
        "bindtomac-bond-vlan-httpks bindtomac-bond2-httpks bindtomac-bond2-pre bindtomac-bridge-2devs-httpks bindtomac-bridge-2devs-pre bindtomac-bridge-httpks bindtomac-bridge-no-bootopts-net bindtomac-bridged-bond-httpks bindtomac-ifname-httpks bindtomac-network-device-default-httpks bindtomac-network-device-mac bindtomac-network-device-mac-httpks bindtomac-network-device-mac-pre bindtomac-network-static-2-httpks bindtomac-network-static-to-dhcp-pre-single bindtomac-onboot-activate-httpks bindtomac-onboot-bootopts-pre bindtomac-team-httpks bindtomac-team-pre bond-ks-initramfs bond-vlan-httpks bond-vlan-pre bond2-httpks bond2-pre bridge-2devs bridge-2devs-httpks bridge-2devs-pre bridge-httpks bridge-no-bootopts-net bridged-bond-httpks bridged-bond-pre dns hostname hostname-bootopts ifname-httpks network-addr-gen-mode network-addr-gen-mode-dhcpall network-autoconnections-dhcpall-httpks network-autoconnections-httpks network-bootopts-bond-bootif network-bootopts-bond-dhcp-httpks network-bootopts-bond-ks-override network-bootopts-bootif-httpks network-bootopts-bridge-dhcp-httpks network-bootopts-noautodefault network-bootopts-static network-bootopts-static-legacy-httpks network-bootopts-static-mac network-bootopts-static-unspec-bootif network-bootopts-static-unspec-single network-bootopts-team-dhcp-httpks network-bootopts-vlan-static-httpks network-device-bootif-httpks network-device-default network-device-default-httpks network-device-default-ksdevice-httpks network-device-default-ksdevice-pre network-device-default-pre-hostname network-device-mac network-device-mac-httpks network-device-mac-pre network-dns-search network-missing-ifcfg-httpks network-noipv4-httpks network-noipv4-pre network-options-pre network-prefixdevname network-static network-static-2-httpks network-static-2-pre network-static-httpks network-static-to-dhcp-pre network-static-to-dhcp-pre-single onboot-activate onboot-activate-httpks onboot-bootopts-pre team team-httpks team-pre vlan-httpks vlan-pre",
    ),
    (
        # test get_tests_including_modified_sh_test part
        "e2ab4077cf828^",
        "e2ab4077cf828",
        "raid-1 raid-1-reqpart",
    ),
    (
        # test get_tests_with_modified_fragments part
        "c927cb7d86dd9^",
        "c927cb7d86dd9",
        "rpm-ostree-container-bootc rpm-ostree-container-leavebootorder rpm-ostree-container-uefi",
    ),
    (
        # test get_tests_using_modified_ks_via_variable part
        "a6246b6bed176^",
        "a6246b6bed176",
        "dns-global-exclusive-tls dns-global-exclusive-tls-httpks dns-global-exclusive-tls-initramfs"
    ),
    (
        # kind of random big chunk of changes test
        "7f1c16fdc7dfc~100",
        "7f1c16fdc7dfc",
        "anabot-1 anaconda-conf anaconda-modules authconfig authselect authselect-not-set autopart-encrypted-1 autopart-encrypted-2 autopart-encrypted-3 autopart-fstype autopart-hibernation autopart-luks-1 autopart-luks-2 autopart-luks-3 autopart-luks-4 autopart-luks-5 autopart-nohome basic-ftp basic-ostree bindtomac-bond-vlan-httpks bindtomac-bond2-httpks bindtomac-bond2-pre bindtomac-bridge-2devs-httpks bindtomac-bridge-2devs-pre bindtomac-bridge-httpks bindtomac-bridge-no-bootopts-net bindtomac-bridged-bond-httpks bindtomac-ifname-httpks bindtomac-network-device-default-httpks bindtomac-network-device-mac bindtomac-network-device-mac-httpks bindtomac-network-device-mac-pre bindtomac-network-static-2-httpks bindtomac-network-static-to-dhcp-pre-single bindtomac-onboot-activate-httpks bindtomac-onboot-bootopts-pre bindtomac-team-httpks bindtomac-team-pre bond-ks-initramfs bond-vlan-httpks bond-vlan-pre bond2-httpks bond2-pre bootloader-1 bootloader-2 bootloader-3 bootloader-4 bootloader-5 bridge-2devs bridge-2devs-httpks bridge-2devs-pre bridge-httpks bridge-no-bootopts-net bridged-bond-httpks bridged-bond-pre btrfs-1 btrfs-2 certificate clearpart-1 clearpart-2 clearpart-3 clearpart-4 container default-desktop default-fstype default-menu-auto-hide-fedora default-menu-auto-hide-rhel default-systemd-target-gui default-systemd-target-gui-graphical-provides default-systemd-target-rdp default-systemd-target-rdp-graphical-provides default-systemd-target-skipx default-systemd-target-startxonboot default-systemd-target-tui default-systemd-target-tui-graphical-provides default-systemd-target-vnc default-systemd-target-vnc-graphical-provides deprecated-rhel9-part1 deprecated-rhel9-part2 disklabel-default disklabel-gpt disklabel-mbr dns dns-global-bootopts dns-global-exclusive-tls dns-global-exclusive-tls-2 dns-global-exclusive-tls-httpks dns-global-exclusive-tls-httpks-2 dns-global-exclusive-tls-initramfs dns-global-exclusive-tls-ksnet driverdisk-disk driverdisk-disk-kargs encrypt-device encrypt-swap escrow-cert fedora-live-image-build firewall firewall-disable firewall-disable-with-options firewall-use-system-defaults firewall-use-system-defaults-ignore-options geolocation-off-by-default-with-ks groups-and-envs-1 groups-and-envs-2 groups-and-envs-3 groups-ignoremissing harddrive-install-tree harddrive-install-tree-relative harddrive-iso harddrive-iso-single hello-world hmc hostname hostname-bootopts https-repo ibft ifname-httpks ignoredisk-1 ignoredisk-2 image-deployment-1 image-deployment-2 image-deployment-2-rhel8 initial-setup-default initial-setup-disable initial-setup-enable initial-setup-gui initial-setup-reconfig iscsi iscsi-bind keyboard keyboard-bootopt-only keyboard-convert-vc keyboard-convert-x-override-bootopt keyboard-generic-argument ks-include lang liveimg log-util-check lvm-1 lvm-2 lvm-cache-1 lvm-cache-2 lvm-luks-1 lvm-luks-2 lvm-luks-3 lvm-luks-4 lvm-raid-1 lvm-raid-2 lvm-thinp-1 lvm-thinp-2 module-1 module-2 module-3 module-4 module-enable-one-module-multiple-streams module-enable-one-stream-install-different-stream module-ignoremissing module-install-no-stream-no-profile module-install-one-module-multiple-streams module-install-one-module-multiple-streams-and-profiles mountpoint-assignment-1 mountpoint-assignment-2 network-addr-gen-mode network-addr-gen-mode-dhcpall network-autoconnections-dhcpall-httpks network-autoconnections-httpks network-bootopts-bond-bootif network-bootopts-bond-dhcp-httpks network-bootopts-bond-ks-override network-bootopts-bootif-httpks network-bootopts-bridge-dhcp-httpks network-bootopts-noautodefault network-bootopts-static network-bootopts-static-legacy-httpks network-bootopts-static-mac network-bootopts-static-unspec-bootif network-bootopts-static-unspec-single network-bootopts-team-dhcp-httpks network-bootopts-vlan-static-httpks network-device-bootif-httpks network-device-default network-device-default-httpks network-device-default-ksdevice-httpks network-device-default-ksdevice-pre network-device-default-pre-hostname network-device-mac network-device-mac-httpks network-device-mac-pre network-dns-search network-missing-ifcfg-httpks network-noipv4-httpks network-noipv4-pre network-options-pre network-prefixdevname network-static network-static-2-httpks network-static-2-pre network-static-httpks network-static-to-dhcp-pre network-static-to-dhcp-pre-single nfs nosave-1 nosave-2 nosave-3 ntp-nontp-without-chrony ntp-nontp-without-chrony-gui ntp-pools ntp-with-nontp ntp-with-nontp-gui ntp-without-chrony ntp-without-chrony-gui onboot-activate onboot-activate-httpks onboot-bootopts-pre packages-and-groups-1 packages-and-groups-ignoremissing packages-default packages-excludedocs packages-ignorebroken packages-ignoremissing packages-instlangs-1 packages-instlangs-2 packages-instlangs-3 packages-multilib packages-weakdeps part-luks-1 part-luks-2 part-luks-3 part-luks-4 pre-install preexisting-btrfs proxy-auth proxy-cmdline proxy-kickstart raid-1 raid-1-reqpart raid-ddf raid-luks-1 raid-luks-2 raid-luks-3 raid-luks-4 reboot reboot-initial-setup-gui reboot-initial-setup-tui reboot-uefi repo-addrepo repo-addrepo-hd-iso repo-addrepo-hd-tree repo-baseurl repo-enable repo-exclude repo-include repo-install repo-metalink repo-mirrorlist reqpart rootpw-allow-ssh rootpw-basic rootpw-crypted rootpw-lock rootpw-lock-no-password rpm-ostree rpm-ostree-container-bootc rpm-ostree-container-leavebootorder rpm-ostree-container-luks rpm-ostree-container-silverblue rpm-ostree-container-uefi script-post script-pre script-pre-install selinux-contexts selinux-disabled selinux-enforcing selinux-permissive services snapshot-post snapshot-pre stage2-from-ks storage-multipath-autopart team team-httpks team-pre timezone-noncommon timezoneLOCAL timezoneUTC tmpfs-fixed_size ui_cmdline ui_graphical_interactive ui_graphical_noninteractive ui_rdp ui_text_interactive ui_text_noninteractive ui_vnc unified unified-cdrom unified-cmdline unified-harddrive unified-nfs url-baseurl url-metalink url-mirrorlist user-locked-root-locked-admin user-multiple user-multiple-wheel-no-root user-no-wheel-no-root user-single user-wheel-no-root vlan-httpks vlan-pre",
    ),
    (
        # kind of random changes test
        "7f1c16fdc7dfc~305",
        "7f1c16fdc7dfc~300",
        "network-bootopts-noautodefault preexisting-btrfs proxy-auth proxy-kickstart repo-baseurl stage2-from-ks url-baseurl",
    ),
]


def run_shell(cmd):
    """Run a command in shell returning standard output lines as list items"""
    output = subprocess.run(cmd, stdout=subprocess.PIPE, check=False, shell=True).stdout
    if output:
        return output.decode(sys.stdout.encoding).strip().split('\n')
    else:
        return []


def get_all_tests():
    """Get names of all tests"""
    return set(
        name[:-len(SH_SUFFIX)]
        for name in os.listdir()
        if name.endswith(SH_SUFFIX) and os.access(name, os.X_OK)
    )


def get_modified_ks_tests(all_tests, base_commit, head_commit):
    """Get names of tests with modified <TESTNAME>.ks.in file.

    Example: keyboard with modified keyboard.ks.in file
    """
    return set(
        name.removesuffix(KS_IN_SUFFIX)
        for name in
        run_shell(
            f"git diff --name-only {base_commit} {head_commit} -- *{KS_IN_SUFFIX}"
        )
        if name.removesuffix(KS_IN_SUFFIX) in all_tests
    )


def get_tests_using_modified_ks_via_variable(modified_ks_tests):
    """Get names of tests with KICKSTART_NAME set to a modified ks.in file.

    Example: dns-global-exclusive-tls-httpks using modified dns-global-exclusive-tls.ks.in
    """
    return set(
        test_match.split(":")[0][2:-len(SH_SUFFIX)]
        for test_match in
        run_shell(
            f"grep KICKSTART_NAME -- $(find -maxdepth 1 -name '*{SH_SUFFIX}' -perm -u+x)"
        )
        if test_match.split("=")[1] in modified_ks_tests
    )


def get_modified_sh_tests(base_commit, head_commit):
    """Get names of tests with modified <TESTNAME>.sh file.

    Example: keyboard with modified keyboard.sh file
    """
    return set(
        name.removesuffix(SH_SUFFIX)
        for name in
        run_shell(
            f"git diff --name-only {base_commit} {head_commit} -- $(find -maxdepth 1 -name '*{SH_SUFFIX}' -perm -u+x)"
        )
    )


def get_tests_including_modified_sh_test(modified_sh_tests):
    """Get names of tests including a modified .sh test file.

    Example: raid-1-reqpart including modified raid1.sh
    """
    result = set()
    for test in modified_sh_tests:
        result.update(
            test_match.split(":")[0][2:-len(SH_SUFFIX)]
            for test_match in
            run_shell(
                f"grep '^[.] ${{KSTESTDIR}}/{test}{SH_SUFFIX}' -- $(find -maxdepth 1 -name '*{SH_SUFFIX}' -perm -u+x)"
            )
        )
    return result


def get_tests_with_modified_libs(base_commit, head_commit):
    """Get names of tests including a modified library.

    The library is included in .ks.in file with @KSINCLUDE@.

    Example: keyboard using modified post-nochroot-lib-keyboard.sh
    """
    modified_libs = set(
        run_shell(
            f"git diff --name-only {base_commit} {head_commit} -- $(find -maxdepth 1 -name '*lib*.sh' ! -perm -u=x)"
        )
    )

    result = set()
    for lib in modified_libs:
        result.update(
            name.removesuffix(KS_IN_SUFFIX)
            for name in
            run_shell(
                f"grep -E -l '@KSINCLUDE@ +{lib}' *{KS_IN_SUFFIX}"
            )
        )
    return result


def get_tests_with_modified_fragments(base_commit, head_commit):
    """Get names of tests including modified fragments.

    The fragment is included in .ks.in file with %ksappend.

    Example: container using network/default.ks
    """
    modified_fragments = set(
        run_shell(
            f"git diff --name-only {base_commit} {head_commit} -- {FRAGMENTS_DIR}"
        )
    )

    modified_fragment_specs = set()
    for fragment in modified_fragments:
        dirs = fragment.split('/')
        if not dirs[0] == FRAGMENTS_DIR:
            sys.exit(f"Unexpected modified fragment path '{fragment}'")
        if dirs[1] == 'shared':
            included_fragment = "/".join(dirs[2:])
        elif dirs[1] == 'platform':
            included_fragment = "/".join(dirs[3:])
        else:
            sys.exit(f"Unexpected subdir '{dirs[1]}' in modified fragment path '{fragment}'")
        modified_fragment_specs.add(included_fragment)

    result = set()
    for fragment_include in modified_fragment_specs:
        result.update(
            name.removesuffix(KS_IN_SUFFIX)
            for name in
            run_shell(
                f"grep -E -l '%ksappend +{fragment_include}' *{KS_IN_SUFFIX}"
            )
        )

    return result


def get_partial_counts(base_commit, head_commit):
    all_tests = get_all_tests()
    modified_ks_tests = get_modified_ks_tests(all_tests, base_commit, head_commit)
    modified_sh_tests = get_modified_sh_tests(base_commit, head_commit)

    return [
        (get_modified_ks_tests, (all_tests, base_commit, head_commit)),
        (get_tests_using_modified_ks_via_variable, (modified_ks_tests,)),
        (get_modified_sh_tests, (base_commit, head_commit)),
        (get_tests_including_modified_sh_test, (modified_sh_tests,)),
        (get_tests_with_modified_libs, (base_commit, head_commit)),
        (get_tests_with_modified_fragments, (base_commit, head_commit)),
    ]


def get_result(partial_counts):
    return " ".join(sorted(
            set().union(*[fnc(*args) for fnc, args in partial_counts])
        ))


def parse_args():
    _parser = argparse.ArgumentParser(
        description="Detect the tests affected by a git change."
    )

    _parser.add_argument('--test', action='store_true',
                         help='Run a test using main branch commits.')
    _parser.add_argument('--debug', action='store_true',
                         help='Show details about types of modification.')
    _parser.add_argument('base_commit', metavar="BASE_COMMIT",
                         help='The base commit')
    _parser.add_argument('head_commit', metavar="HEAD_COMMIT",
                         help='The head commit')

    return _parser.parse_args()


if __name__ == "__main__":

    args = parse_args()

    base_commit = args.base_commit
    head_commit = args.head_commit

    if args.test:
        for base_commit, head_commit, result in SELF_TESTS:
            assert(get_result(get_partial_counts(base_commit, head_commit)) == result)
        sys.exit(0)

    partial_counts = get_partial_counts(base_commit, head_commit)

    if args.debug:
        for fnc, args in partial_counts:
            print(fnc.__doc__)
            print(sorted(fnc(*args)))
            print("=" * 80)
    else:
        print(get_result(partial_counts))
