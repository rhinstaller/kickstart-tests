# Create a variable in the pre/post section with link to a RHEL DVD.
# The curl tool will download this ISO and it will be processed later in the section.
#_LINK=<ADD_LINK_TO_RHEL-9_ISO_HERE>
REPO_URL=@KSTEST_URL@
_LINK=${REPO_URL%os/}iso/
ISO_LOCATION="$(curl -L $_LINK | grep -Po "RHEL-9.*?-x86_64-dvd1.iso" | head -n 1)"
ISO_LOCATION="${_LINK}/${ISO_LOCATION}"

echo $ISO_LOCATION
