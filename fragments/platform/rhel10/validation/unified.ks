# Validate installed packages on RHEL 10 system.

# Check that the anaconda package was correctly installed.
if ! rpm -q anaconda ; then
    echo '*** anaconda package was not installed!' >> /root/RESULT
fi
