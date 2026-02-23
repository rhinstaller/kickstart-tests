# Common functions for %post or %pre kickstart section

# get_platform KSTEST_OS_NAME KSTEST_OS_VERSION
# Get the platform (fragments platform / --platform launch script option).
# For fedora return only "fedora" prefix (only fedora_rawhide platform is supported currently).
function get_platform {
   local os_name=$1
   local os_version=$2
   local platform=""

   if [ ${os_name} == "rhel" ] || [ ${os_name} == "centos" ] ; then
       platform=${os_name}
       os_major=$(echo "${os_version}" | grep -oE "^[[:digit:]]+")
       if [ -n "${os_major}" ] ; then
           platform="${os_name}${os_major}"
       fi
   elif [ ${os_name} == "fedora" ] ; then
       platform="fedora"
   elif [ ${os_name} == "fedora-eln" ] ; then
       platform="fedora-eln"
   fi

   echo ${platform}
}

# dumps_default_cons KSTEST_OS_NAME KSTEST_OS_VERSION
# Does the os variant dump default device connections?
# Anaconda stopped doing it in INSTALLER-3088 (F44)
function dumps_default_cons {
    platform=$(get_platform "$@")
    if [ "${platform}" == "rhel8" ] || \
            [ "${platform}" == "rhel9" ] || \
            [ "${platform}" == "rhel10" ] || \
            [ "${platform}" == "centos9" ] || \
            [ "${platform}" == "centos10" ]; then
        echo "yes"
    else
        echo "no"
    fi
}

# restore_container_file_context PATH
# Conditionally restore SELinux context if file or directory has container_file_t context.
# This addresses gh1607 where container builds cause incorrect contexts.
function restore_container_file_context {
    local path=$1

    # Check if file or directory exists and has container_file_t context
    if [ -e "${path}" ]; then
        current_context=$(stat -c %C "${path}" 2>/dev/null || echo "")
        if echo "$current_context" | grep -q "container_file_t"; then
            restorecon -irF "${path}"
        fi
    fi
}
