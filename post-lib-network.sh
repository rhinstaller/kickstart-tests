# Common functions for %post (chrooted) kickstart section
# network tests

# check_device_ifcfg_value NIC KEY VALUE
# Check that the value of KEY in ifcfg file of device NIC is VALUE
function check_device_ifcfg_value() {
    local nic="$1"
    local key="$2"
    local value="$3"
    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${nic}"

    if [[ -e ${ifcfg_file} ]]; then
        egrep -q '^'${key}'="?'${value}'"?$' ${ifcfg_file}
        if [[ $? -ne 0 ]]; then
           echo "*** Failed check: ${key}=${value} in ${ifcfg_file}" >> /root/RESULT
        fi
    else
       echo "*** Failed check: ifcfg file ${ifcfg_file} exists" >> /root/RESULT
    fi
}

# check_device_connected NIC "yes"|"no"
# Check that the device NIC is connected ("yes") or not ("no")
function check_device_connected() {
    local nic="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    nmcli -t -f DEVICE,STATE dev | grep "${nic}:connected"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: device ${nic} connected: ${expected_result}" >> /root/RESULT
    fi
}

# check_ifcfg_key_exists NIC KEY "yes"|"no"
# Check that value of KEY is ("yes") or is not ("no") defined in ifcfg file of the device NIC
function check_ifcfg_key_exists() {
    local nic="$1"
    local key="$2"
    local expected_result="$3"

    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${nic}"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    if [[ -e ${ifcfg_file} ]]; then
        egrep -q '^'${key}'=' ${ifcfg_file}
        if [[ $? -ne ${exit_code} ]]; then
            echo "*** Failed check: ${key} exists in ${ifcfg_file}: ${expected_result}" >> /root/RESULT
        fi
    else
       echo "*** Failed check: ifcfg file ${ifcfg_file} exists" >> /root/RESULT
    fi
}

# check_device_ifcfg_bound_to_mac NIC
# Check that the ifcfg file of device NIC is bound to MAC address
function check_device_ifcfg_bound_to_mac() {
    local nic="$1"
    check_ifcfg_key_exists $nic DEVICE no
    check_ifcfg_key_exists $nic HWADDR yes
}

# check_bond_has_slave BOND SLAVE "yes"|"no"
# Check that the bond device BOND has ("yes") or has not ("no") a slave device SLAVE
function check_bond_has_slave() {
    local bond="$1"
    local slave="$2"
    local expected_result="$3"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    cat /proc/net/bonding/${bond} | egrep -q "^Slave.*${slave}"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${bond} has slave ${slave} ${expected_result}" >> /root/RESULT
    fi
}

# check_device_ipv4_address NIC ADDRESS
# Check that the device NIC has ipv4 address ADDRESS
function check_device_ipv4_address() {
    local device="$1"
    local address="$2"

    ip -f inet addr show ${device} | egrep -q '^\s+inet\s+'${address}
    if [[ $? -ne 0 ]]; then
        echo "*** Failed check: ${device} has ipv4 address ${address}" >> /root/RESULT
    fi
}

# check_device_has_ipv4_address NIC
# Check that the device NIC has an ipv4 address
function check_device_has_ipv4_address() {
    local device="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    test -n "$(ip -f inet addr show ${device})"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${device} has ipv4 address ${expected_result}" >> /root/RESULT
    fi
}

# check_number_of_device_ipv4_addresses NIC NUMBER
# Check that the device NIC has exactly NUMBER ipv4 addresses
function check_number_of_device_ipv4_addresses() {
    local device="$1"
    local number="$2"

    num_found=$(ip -f inet addr show ${device} | egrep '^\s+inet\s+' | wc -l)
    if [[ ${number} !=  ${num_found} ]]; then
        echo "*** Failed check: ${device} has ${number} ipv4 addresses" >> /root/RESULT
    fi
}

# check_team_has_slave TEAM SLAVE "yes"|"no"
# Check that the team device TEAM has ("yes") or has not ("no") a slave device SLAVE
function check_team_has_slave() {
    local team="$1"
    local slave="$2"
    local expected_result="$3"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    teamnl ${team} ports | egrep -q ' '${slave}':'
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${team} has slave ${slave} ${expected_result}" >> /root/RESULT
    fi
}

# check_team_option TEAM OPTION
# Check that the team device TEAM has option OPTION
function check_team_option() {
    local team="$1"
    local option="$2"

    teamnl ${team} options | egrep -q "${option}"
    if [[ $? -ne 0 ]]; then
        echo "*** Failed check: ${team} has option ${option}" >> /root/RESULT
    fi
}

# check_ifcfg_exists NIC "yes"|"no"
# Check that the ifcfg file for device NIC exists ("yes") or not ("no")
function check_ifcfg_exists() {
    local nic="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${nic}"
    test -e ${ifcfg_file}
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${ifcfg_file} exists ${expected_result}" >> /root/RESULT
    fi
}

# check_hostname HOSTNAME
# Check that the static hostname is set to HOSTNAME
function check_hostname() {
    local hostname="$1"

    grep -q "^${hostname}$" /etc/hostname
    if [[ $? -ne 0 ]]; then
        echo '*** Failed check: ${hostname} is set in /etc/hostname' >> /root/RESULT
    fi

    hostnamectl --static | grep -q "^${hostname}$"
    if [[ $? -ne 0 ]]; then
        echo '*** Failed check: hostnamectl --static returns ${hostname}' >> /root/RESULT
    fi

}
