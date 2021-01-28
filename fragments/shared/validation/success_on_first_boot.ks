# Report success if no errors have been reported on the first boot.
# Additional tests can be implemented in /usr/libexec/kickstart-test.sh
# by the kickstart test that includes this fragment. This file is empty
# by default.

%post

# Create a systemd service.
cat > /etc/systemd/system/kickstart-test.service << EOF

[Unit]
Description=The kickstart test service
After=initial-setup.service
After=multi-user.target
After=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/sh /usr/libexec/kickstart-service.sh

[Install]
WantedBy=graphical.target
WantedBy=multi-user.target

EOF

# Create a script with the actual test. Print errors to stdout.
# IMPORTANT: This file should be rewritten in tests!
touch /usr/libexec/kickstart-test.sh

# Create a script for the service
cat > /usr/libexec/kickstart-service.sh << 'EOF'

# Check error messages in the syslog.
error_messages="$(/bin/sh /usr/libexec/kickstart-test.sh)"

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
