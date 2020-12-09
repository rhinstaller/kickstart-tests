SYSROOT=${ANA_INSTALL_PATH:-/mnt/sysimage}

# check_bridge_has_slave_nochroot BRIDGE SLAVE "yes|no"
# Check that the bridge device BRIDGE has ("yes") or has not ("no") a slave device SLAVE
function check_bridge_has_slave_nochroot() {
    local bridge="$1"
    local slave="$2"
    local expected_result="$3"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    command -v brctl > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        brctl show ${bridge} | egrep -q '^'${bridge}'.*'${slave}'$'
    else
        ip addr show ${slave} | egrep -q "master[[:space:]]*${bridge}"
    fi

    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${bridge} has slave ${slave} ${expected_result}" >> $SYSROOT/root/RESULT
    fi
}

# check_gui_configurations
# Works only for gui installations.
# Checks that the connections configurable in Network Spoke are those corresponding to configuration files of devices
function check_gui_configurations() {
    # parse added devices and connections from anaconda.log into eg
    # " bond0.222:1484c12b-0f40-445b-93b4-10bef8ec6ce3 bond0:8df1c4f6-76aa-42e3-9fa9-aa1f00c155b4 ${KSTEST_NETDEV3}:None ${KSTEST_NETDEV2}:None ${KSTEST_NETDEV1}:d3b58e36-68cb-4de1-b1fc-98707045274f "
    local dev_cons=""
    local cons_without_devs=""

    # Pass the test if not in graphical mode
    grep -q "Display mode is set to.* graphical mode" /tmp/anaconda.log
    if [[ $? -ne 0 ]]; then
        return
    fi

    old_IFS=$IFS
    IFS=$'\n'
    # use \s so that it does not match itself in the log
    for line in $(egrep -o "adding\sdevice configuration.*" /tmp/anaconda.log); do
        local device=$(echo $line | cut -d"'" -f4)
        local con=$(echo $line | cut -d"'" -f2)
        echo "${device}:${con}"
        if [ -n "${device}" ]; then
            dev_cons="${dev_cons} ${device}:${con} "
        else
            cons_without_devs="${cons_without_devs} ${con}"
        fi
    done
    IFS=$old_IFS

    # TODO: remove when network module is used in all tested releases
    # If no messages were found fall back to older version of log messages.
    if [[ -z ${dev_cons} && -z ${cons_without_devs} ]]; then
        old_IFS=$IFS
        IFS=$'\n'
        # use \s so that it does not match itself in the log
        for line in $(egrep -o "device\sconfiguration added.*" /tmp/anaconda.log); do
            local device=$(echo $line | cut -d" " -f7)
            local con=$(echo $line | cut -d" " -f5)
            dev_cons="${dev_cons} ${device}:${con} "
        done
        IFS=$old_IFS

    # bash version with process substitiutuion
    #while read -r line; do
    #    local device=$(echo $line | cut -d" " -f8)
    #    local con=$(echo $line | cut -d" " -f6)
    #    dev_cons="${dev_cons} ${device}:${con} "
    # use \s so that it does not match itself in the log
    #done < <(egrep -o "GUI, device\sconfiguration added.*" /tmp/anaconda.log)

        # take into account connections attached to devices later (like regular connections
        # for devices being slaves)
        old_IFS=$IFS
        IFS=$'\n'
        # use \s so that it does not match itself in the log
        for line in $(egrep -o "attaching\sconnection.*" /tmp/anaconda.log); do
            local device=$(echo $line | cut -d" " -f6)
            local con=$(echo $line | cut -d" " -f3)
            dev_cons=$(echo $dev_cons | sed -e "s/$device:None/$device:$con/")
        done
        IFS=$old_IFS
    fi

    # check that all requested devices supplied as arguments were added to GUI
    # and if configuration file exists it corresponds to the connection added
    for devname in "$@"
    do
        local found="no"
        # If the device is in any device configuration check that if its ifcfg exists
        # it corresponds to the connection from the device configuration
        for dev_con in ${dev_cons}; do
            local con=${dev_con##${devname}:}
            if [[ ${con} != ${dev_con} ]]; then
                # Do not require ifcfg when there is no connection, eg bond configuration from boot options.
                # Do not require ifcfg when there is a connection, eg for default connections created by NM upon start
                # (they are disabled by no-auto-default=* in RHEL installer and NetworkManager-config-server package)
                found="yes"
                if [[ ${con} != "" && ${con} != "None" ]]; then
                    local ifcfg_file="$SYSROOT/etc/sysconfig/network-scripts/ifcfg-${devname}"
                    if [[ -e ${ifcfg_file} ]]; then
                        egrep -q '^UUID="?'${con}'"?$' ${ifcfg_file}
                        ifcfg_result=$?
                    fi
                    local keyfile_file="$SYSROOT/etc/NetworkManager/system-connections/${devname}.nmconnection"
                    if [[ -e ${keyfile_file} ]]; then
                        egrep -q '^uuid="?'${con}'"?$' ${keyfile_file}
                        keyfile_result=$?
                    fi
                    # Using device-specific connection created in intramfs is
                    # acceptable as well even if there is no persistent
                    # connection (ifcfg_file or keyfile_file above) created
                    # from it by Anaconda for various reasons (eg for a bridge
                    # slave device)
                    local temporary_keyfile_file="$SYSROOT/run/NetworkManager/system-connections/${devname}.nmconnection"
                    if [[ -e ${temporary_keyfile_file} ]]; then
                        egrep -q '^uuid="?'${con}'"?$' ${temporary_keyfile_file}
                        temporary_keyfile_result=$?
                    fi
                    if [[ ${ifcfg_result} != 0 && ${keyfile_result} != 0 && ${temporary_keyfile_result} != 0 ]]; then
                        echo "*** Failed check: ${devname}:${con} added in GUI corresponds to ${ifcfg_file} or ${keyfile_file} or ${temporary_keyfile_file}" >> $SYSROOT/root/RESULT
                    fi
                fi
                break
            fi
        done

        # If the device name is not in device configurations (eg non-activated virtual device)
        # check that its ifcfg file corresponds to one of the device configurations without device
        # name assigned.
        if [[ ${found} == "no" ]]; then
            local ifcfg_file="$SYSROOT/etc/sysconfig/network-scripts/ifcfg-${devname}"
            if [[ -e ${ifcfg_file} ]]; then
                for con in ${cons_without_devs}; do
                    egrep -q '^UUID="?'${con}'"?$' ${ifcfg_file}
                    if [[ $? -eq 0 ]]; then
                        found="yes"
                        break
                    fi
                done
            fi
            local keyfile_file="$SYSROOT/etc/NetworkManager/system-connections/${devname}.nmconnection"
            if [[ -e ${keyfile_file} ]]; then
                for con in ${cons_without_devs}; do
                    egrep -q '^uuid="?'${con}'"?$' ${keyfile_file}
                    if [[ $? -eq 0 ]]; then
                        found="yes"
                        break
                    fi
                done
            fi

        fi

        if [[ ${found} == "no" ]]; then
           echo "*** Failed check: ${devname} configuration added to GUI" >> $SYSROOT/root/RESULT
        fi
    done

    # TODO check that no other devices were added
}

# Copy result from the %pre stage
function copy_pre_stage_result() {
    if [[ -e /root/RESULT ]]; then
       cp /root/RESULT $SYSROOT/root/RESULT
    fi
}

# Pass information about autoconnections configuration to target system chroot
# to be available for detect_nm_has_autoconnection_off
ANACONDA_NM_CONFIG_FILE_PATH=/etc/NetworkManager/conf.d/90-anaconda-no-auto-default.conf
CHROOT_ANACONDA_NM_CONFIG_FILE_PATH=/root/90-anaconda-no-auto-default.conf
function pass_autoconnections_info_to_chroot() {
    if [[ -e ${ANACONDA_NM_CONFIG_FILE_PATH} ]]; then
        cp ${ANACONDA_NM_CONFIG_FILE_PATH} ${SYSROOT}${CHROOT_ANACONDA_NM_CONFIG_FILE_PATH}
    else
        echo "# no anaconda config file was found => autoconnections are on" > ${SYSROOT}${CHROOT_ANACONDA_NM_CONFIG_FILE_PATH}
    fi
}
