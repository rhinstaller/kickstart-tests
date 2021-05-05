# Common functions for %post or %pre kickstart section

# is_rhel8 KSTESTS_OS_NAME KSTESTS_OS_VERSION
# Are we testing rhel 8 (based on the name and version detected from boot.iso) ?
# Returns "yes" or "no".
function is_rhel8 {
   local os_name=$1
   local os_version=$2
   if [ ${os_name} == "rhel" -a ${os_version:0:1} == "8" ] ; then
       echo "yes"
   else
       echo "no"
   fi
}
