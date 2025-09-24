RESULT_FILE=/root/RESULT
VC_KEYMAP_CONFIG_FILE=/etc/vconsole.conf
X11_LAYOUTS_CONFIG_FILE=/etc/X11/xorg.conf.d/00-keyboard.conf

# check_vc_keymap_config VC_KEYMAP "yes"|"no"
# Check in configuration file that VC keymap is set ("yes") to VC_KEYMAP or not ("no")
function check_vc_keymap_config() {
    local vc_keymap="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    cat ${VC_KEYMAP_CONFIG_FILE} | egrep -q "KEYMAP=\"${vc_keymap}\""
    if [[ $? -ne ${exit_code} ]]; then
        echo "*** Failed check: VC keymap is configured to ${vc_keymap}: ${expected_result}" >> ${RESULT_FILE}
    fi
}

# check_x11_layouts_config X11_LAYOUTS "yes"|"no"
# Check in configuration file that X11 layouts are set ("yes") to X11_layouts or not ("no")
# X11_LAYOUTS is systemd-localed string value
function check_x11_layouts_config() {
    local x11_layouts="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    parsed_value=$(egrep XkbLayout $X11_LAYOUTS_CONFIG_FILE | awk -F\" '{ print $4 }')
    if [[ "${parsed_value}" == "${x11_layouts}" ]]; then
        value_found=0
    else
        value_found=1
    fi
    if [[ ${value_found} -ne ${exit_code} ]]; then
        echo "*** Failed check: X11 layouts are configured to ${x11_layouts}: ${expected_result}" >> ${RESULT_FILE}
    fi
}

# check_x11_variants_config X11_VARIANTS "yes"|"no"
# Check in configuration file that X11 layouts are set ("yes") to X11_layouts or not ("no")
# X11_VARIANTS is systemd-localed string value
function check_x11_variants_config() {
    local x11_variants="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    parsed_value=$(egrep XkbVariant $X11_LAYOUTS_CONFIG_FILE | awk -F\" '{ print $4 }')
    if [[ "${parsed_value}" == "${x11_variants}" ]]; then
        value_found=0
    else
        value_found=1
    fi
    if [[ ${value_found} -ne ${exit_code} ]]; then
        echo "*** Failed check: X11 variants are configured to ${x11_variants}: ${expected_result}" >> ${RESULT_FILE}
    fi
}

# check_x11_options_config X11_OPTIONS "yes"|"no"
# Check in configuration file that X11 layouts are set ("yes") to X11_layouts or not ("no")
# X11_OPTIONS is systemd-localed string value
function check_x11_options_config() {
    local x11_options="$1"
    local expected_result="$2"
    local exit_code=0
    if [[ ${expected_result} == "no" ]]; then
        exit_code=1
    fi

    parsed_value=$(egrep XkbOptions $X11_LAYOUTS_CONFIG_FILE | awk -F\" '{ print $4 }')
    if [[ "${parsed_value}" == "${x11_options}" ]]; then
        value_found=0
    else
        value_found=1
    fi
    if [[ ${value_found} -ne ${exit_code} ]]; then
        echo "*** Failed check: X11 options are configured to ${x11_options}: ${expected_result}" >> ${RESULT_FILE}
    fi
}
