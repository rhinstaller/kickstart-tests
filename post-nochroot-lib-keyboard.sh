SYSROOT=${ANA_INSTALL_PATH:-/mnt/sysimage}
RESULT_FILE=${SYSROOT}/root/RESULT

# check_current_vc_keymap VC_KEYMAP "yes"|"no"
# Check that current VC keymap is set ("yes") to VC_KEYMAP or not ("no")
function check_current_vc_keymap() {
    local vc_keymap="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    localectl | egrep -q "VC Keymap: ${vc_keymap}"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: Current VC Keymap is ${vc_keymap}: ${expected_result}" >> ${RESULT_FILE}
    fi
}

# check_current_x11_layouts X11_LAYOUTS "yes"|"no"
# Check that current x11 layouts are set ("yes") to X11_LAYOUTS or not ("no")
# X11_LAYOUTS is systemd-localed string value
function check_current_x11_layouts() {
    local x_layouts="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    localectl | egrep -q "X11 Layout: ${x_layouts}\s*$"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: Current X11 layouts are ${x_layouts}: ${expected_result}" >> ${RESULT_FILE}
    fi
}

# check_current_x11_options X11_OPTIONS "yes"|"no"
# Check that current x11 options are set ("yes") to X11_OPTIONS or not ("no")
# X11_OPTIONS is systemd-localed string value
function check_current_x11_options() {
    local x_options="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    localectl | egrep -q "X11 Options: ${x_options}\s*$"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: Current X11 Options are ${x_options}: ${expected_result}" >> ${RESULT_FILE}
    fi
}

# check_current_x11_variants X11_VARIANTS "yes"|"no"
# Check that current x11 variants are set ("yes") to X11_VARIANTS or not ("no")
# X11_VARIANTS is systemd-localed string value
function check_current_x11_variants() {
    local x_variants="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    localectl | egrep -q "X11 Variant: ${x_variants}\s*$"
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: Current X11 variants are ${x_variants}: ${expected_result}" >> ${RESULT_FILE}
    fi
}
