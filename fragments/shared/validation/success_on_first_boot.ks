# Report success if no errors have been reported on the first boot.
# Additional tests can be implemented in /usr/libexec/kickstart-test.sh
# by the kickstart test that includes this fragment. This file is empty
# by default.

# A somewhat different approach via systemd-sysext/overlayfs is needed
# in ostree systems with read-only /usr

%post
# detect if the system uses ostree and change path prefix if needed
if [ -f /.ostree.cfs ]; then
    # based on info from https://www.reddit.com/r/Fedora/comments/wir3cq/comment/ijhjfah
    mkdir -p /var/lib/extensions/kickstart-tests/usr/lib/extension-release.d \
        /var/lib/extensions/kickstart-tests/usr/libexec
    cp /etc/os-release /var/lib/extensions/kickstart-tests/usr/lib/extension-release.d/extension-release.kickstart-tests
    script_prefix="/var/lib/extensions/kickstart-tests"
    systemd-sysext merge
    systemctl enable systemd-sysext
else
    script_prefix=""
fi

# Create a systemd service.
cat > /etc/systemd/system/kickstart-test.service << EOF

[Unit]
Description=The kickstart test service
After=initial-setup.service
After=multi-user.target
After=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/sh ${script_prefix}/usr/libexec/kickstart-service.sh

[Install]
WantedBy=graphical.target
WantedBy=multi-user.target

EOF

# Create a script with the actual test. Print errors to stdout.
# IMPORTANT: This file should be rewritten in tests!
touch ${script_prefix}/usr/libexec/kickstart-test.sh

# Create a script for the service
cat > ${script_prefix}/usr/libexec/kickstart-service.sh << 'EOF'

# Check error messages in the syslog.
error_messages="$(/bin/sh ${script_prefix}/usr/libexec/kickstart-test.sh)"

if [[ ! -z "${error_messages}" ]]; then
    echo "*** System has started with errors:" >> /root/RESULT
    echo "${error_messages}" >> /root/RESULT
fi

# Validate the results.
if [ ! -f /root/RESULT ]; then
    echo SUCCESS > /root/RESULT
fi

# Print the results.
cat /root/RESULT

# Make the syslog accessible after the test.
# FIXME: Find a better way to do this.
journalctl >> /var/log/anaconda/syslog

# Stop the virtual machine.
shutdown now

EOF

# Enable the systemd service.
systemctl enable kickstart-test.service

%end
