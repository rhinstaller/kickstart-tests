SYSROOT=/mnt/sysroot
RESULT_FILE=${SYSROOT}/root/RESULT

# Check if log util can be called
function check_log_util_exist() {
    if [ ! -f /usr/libexec/anaconda/log-capture ]; then
        echo "*** log-capture util does not exist" >> ${RESULT_FILE}
    fi
}

# Check if log utils runs without failure
function check_log_util_runs() {
    local exit_code=0
    local ret_code=0

    # Trigger the log util
    /usr/libexec/anaconda/log-capture
    ret_code=$?

    if [[ ${ret_code} -ne ${exit_code} ]]; then
        echo "*** log-capture util failed with code: ${ret_code}" >> ${RESULT_FILE}
    fi
}

# Check if log utils produces log tarbal
function check_log_util_produces_log_archive() {
    # Trigger the log util
    /usr/libexec/anaconda/log-capture

    if [ ! -f /tmp/log-capture.tar.bz2 ]; then
        echo "*** log-capture util does not produced log archive" >> ${RESULT_FILE}
    fi
}
