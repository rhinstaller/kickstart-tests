# Common functions for %post or %pre kickstart section

# is_rhel8 KSTESTS_OS_NAME KSTESTS_OS_VERSION
# Are we testing rhel 8 (based on the name and version detected from boot.iso) ?
function is_rhel8 {
   local os_name=$1
   local os_version=$2
   if [ ${os_name} == "rhel" ] && [ ${os_version:0:1} == "8" ] ; then
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
   if [ ${os_name} == "rhel" ] && [ ${os_version:0:1} == "9" ] ; then
       return 0
   else
       return 1
   fi
}
