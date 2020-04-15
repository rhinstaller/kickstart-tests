# Create a variable in the pre/post section with link to a Fedora rawhide server DVD.
# The curl tool will download this ISO and it will be processed later in the section.
_LINK="http://ftp.fi.muni.cz/pub/linux/fedora/linux/development/rawhide/Server/x86_64/iso"
ISO_LOCATION="$(curl -L $_LINK | grep -Po "Fedora-Server-dvd-x86_64-.*?.iso" | head -n 1)"
ISO_LOCATION="${_LINK}/${ISO_LOCATION}"

echo $ISO_LOCATION
