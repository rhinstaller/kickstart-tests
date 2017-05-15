# Common functions for %post (chrooted) kickstart section
# network tests

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

function device_ifcfg_key_missing() {
    local nic="$1"
    local key="$2"
    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${nic}"

    if [[ -e ${ifcfg_file} ]]; then
        egrep -q '^'${key}'=' ${ifcfg_file}
        if [[ $? -eq 0 ]]; then
           echo "*** Failed check: no ${key} stanza in ${ifcfg_file}" >> /root/RESULT
        fi
    else
       echo "*** Failed check: ifcfg file ${ifcfg_file} exists" >> /root/RESULT
    fi
}

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

function check_device_ipv4_address() {
    local device="$1"
    local address="$2"

    ip -f inet addr show ${device} | egrep -q '^\s+inet\s+'${address}
    if [[ $? -ne 0 ]]; then
        echo "*** Failed check: ${device} has ipv4 address ${address}" >> /root/RESULT
    fi
}

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

function check_number_of_device_ipv4_addresses() {
    local device="$1"
    local number="$2"

    num_found=$(ip -f inet addr show ${device} | egrep '^\s+inet\s+' | wc -l)
    if [[ ${number} !=  ${num_found} ]]; then
        echo "*** Failed check: ${device} has ${number} ipv4 addresses" >> /root/RESULT
    fi
}

function check_ifcfg_file_does_not_exist() {
    local nic="$1"
    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${nic}"
    if [[ -e ${ifcfg_file} ]]; then
        echo "*** Failed check: ${ifcfg_file} does not exist" >> /root/RESULT
    fi
}

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

function check_team_option() {
    local team="$1"
    local option="$2"

    teamnl ${team} options | egrep -q "${option}"
    if [[ $? -ne 0 ]]; then
        echo "*** Failed check: ${team} has option ${option}" >> /root/RESULT
    fi
}

function check_ifcfg_exists() {
    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${1}"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    test -e ${ifcfg_file}
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: ${ifcfg_file} exists ${expected_result}" >> /root/RESULT
    fi
}

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
