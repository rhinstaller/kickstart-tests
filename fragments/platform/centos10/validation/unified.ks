# Validate installed packages on CentOS 10 system.

# Check that the anaconda package was correctly installed.
if ! rpm -q anaconda ; then
    echo '*** anaconda package was not installed!' >> /root/RESULT
fi
