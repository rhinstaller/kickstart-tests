# Common functions for %post or %pre kickstart section

# get_platform KSTEST_OS_NAME KSTEST_OS_VERSION
# Get the platform (fragments platform / --platform launch script option).
# For fedora return only "fedora" prefix (only fedora_rawhide platform is supported currently).
function get_platform {
   local os_name=$1
   local os_version=$2
   local platform=""

   if [ ${os_name} == "rhel" ] || [ ${os_name} == "centos" ] ; then
       platform=rhel
       os_major=$(echo "${os_version}" | grep -oE "^[[:digit:]]+")
       if [ -n "${os_major}" ] ; then
           platform="rhel${os_major}"
       fi
   fi
   if [ ${os_name} == "fedora" ] ; then
       platform=fedora
   fi

   echo ${platform}
}


# is_rhel8 KSTESTS_OS_NAME KSTESTS_OS_VERSION
# Are we testing rhel 8 (based on the name and version detected from boot.iso) ?
function is_rhel8 {
   local os_name=$1
   local os_version=$2
   if [ "$(get_platform ${os_name} ${os_version})" == "rhel8" ] ; then
       return 0
   else
       return 1
   fi
}


# is_rhel9 KSTESTS_OS_NAME KSTESTS_OS_VERSION
# Are we testing rhel 9 (based on the name and version detected from boot.iso) ?
function is_rhel9 {
   local os_name=$1
   local os_version=$2
   if [ "$(get_platform ${os_name} ${os_version})" == "rhel9" ] ; then
       return 0
   else
       return 1
   fi
}
