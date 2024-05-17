# The library for nochroot post scripts of the UI kickstart tests.

# Specify the result file.
SYSROOT=/mnt/sysroot
RESULT_FILE=${SYSROOT}/root/RESULT

# Check that the current display mode is set to the expected value.
function check_display_mode() {
    local expected_mode="$1"
    local display_mode

    display_mode="$(grep 'Display mode is set to ' /tmp/anaconda.log | cut -d \' -f2)"

    if [ "$display_mode" != "$expected_mode" ]; then
        echo "*** incorrect display mode (got $display_mode; expected $expected_mode)" >> ${RESULT_FILE}
    fi
}

# Check that the VNC server is running.
function check_vnc_server_is_running() {
    grep -q "The VNC server is now running." /tmp/anaconda.log

    if [[ $? -ne 0 ]]; then
        echo "*** the VNC server is not running" >> ${RESULT_FILE}
    fi
}
