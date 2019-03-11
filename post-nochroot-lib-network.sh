SYSROOT=${ANA_INSTALL_PATH:-/mnt/sysimage}

# check_bridge_has_slave BRIDGE SLAVE "yes|no"
# Check that the bridge device BRIDGE has ("yes") or has not ("no") a slave device SLAVE
function check_bridge_has_slave() {
    local bridge="$1"
    local slave="$2"
    local expected_result="$3"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    brctl show ${bridge} | egrep -q '^'${bridge}'.*'${slave}'$'
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${bridge} has slave ${slave} ${expected_result}" >> $SYSROOT/root/RESULT
    fi
}

# check_gui_configurations
# Works only for gui installations.
# Checks that the connections configurable in Network Spoke are those corresponding to ifcfg files of devices
function check_gui_configurations() {
    # parse added devices and connections from anaconda.log into eg
    # " bond0.222:1484c12b-0f40-445b-93b4-10bef8ec6ce3 bond0:8df1c4f6-76aa-42e3-9fa9-aa1f00c155b4 ens5:None ens4:None ens3:d3b58e36-68cb-4de1-b1fc-98707045274f "
    local dev_cons=""
    local cons_without_devs=""

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
    if [[ -z ${dev_cons} && -z ${cons_without_devs} ]];
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
    # and if ifcfg file exists it corresponds to the connection added
    for devname in "$@"
    do
        local found="no"
        # If the device is in any device configuration check that if its ifcfg exists
        # it corresponds to the connection from the device configuration
        for dev_con in ${dev_cons}; do
            local con=${dev_con##${devname}:}
            if [[ ${con} != ${dev_con} ]]; then
                found="yes"
                local ifcfg_file="$SYSROOT/etc/sysconfig/network-scripts/ifcfg-${devname}"
                if [[ ${con} != "" && ${con} != "None" ]]; then
                    if [[ -e ${ifcfg_file} ]]; then
                        egrep -q '^UUID="?'${con}'"?$' ${ifcfg_file}
                        if [[ $? -ne 0 ]]; then
                           echo "*** Failed check: ${devname}:${con} added in GUI corresponds to ${ifcfg_file}" >> $SYSROOT/root/RESULT
                        fi
                    #Do not strictly require ifcfg when there is a connection, eg for default connections created by NM upon start
                    #(they are disabled by no-auto-default=* in RHEL installer and NetworkManager-config-server package)
                    #else
                    #    echo "*** Failed check: ${ifcfg_file} for ${devname}:${con} added in GUI exists" >> $SYSROOT/root/RESULT
                    fi
                else
                    if [[ -e ${ifcfg_file} ]]; then
                        echo "*** Failed check: ${ifcfg_file} for ${devname}:${con} added in GUI does not exist" >> $SYSROOT/root/RESULT
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

        fi

        if [[ ${found} == "no" ]]; then
           echo "*** Failed check: ${devname} configuration added to GUI" >> $SYSROOT/root/RESULT
        fi
    done

    # TODO check that no other devices were added
}
