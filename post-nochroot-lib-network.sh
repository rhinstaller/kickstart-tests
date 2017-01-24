SYSROOT=${ANA_INSTALL_PATH:-/mnt/sysimage}

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
