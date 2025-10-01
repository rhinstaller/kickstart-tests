# Validate installed packages on Fedora ELN system.

# Check that the anaconda package was correctly installed.
if ! rpm -q anaconda ; then
    echo '*** anaconda package was not installed!' >> /root/RESULT
fi
