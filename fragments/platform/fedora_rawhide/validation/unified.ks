# Validate installed packages on Fedora rawhide system.

# Check that the test package was correctly installed.
if ! rpm -q test-rpm ; then
    echo '*** test-rpm package was not installed!' >> /root/RESULT
fi
