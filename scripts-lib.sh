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
