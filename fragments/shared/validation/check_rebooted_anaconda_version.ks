# Verify that the anaconda-core version installed on the target system matches
# the version in the installer. When additional_repo is configured (e.g.
# anaconda CI injects built RPMs via data/additional_repo/) this ensures the
# tested version is actually used. Without additional_repo the ISO and repo
# versions can legitimately differ, causing a known flake — but the warning is
# still valuable for local development. See gh#1606.
%post --nochroot
if rpm -q anaconda-core > /mnt/sysroot/root/installer-anaconda-version 2>/dev/null; then
    echo "Installer anaconda version captured from RPM database"
elif [ -e /root/lorax-packages.log ]; then
    grep anaconda-core /root/lorax-packages.log > /mnt/sysroot/root/installer-anaconda-version
    echo "Installer anaconda version captured from lorax-packages.log"
fi
%end

%post
cat >> /usr/libexec/kickstart-test.sh << ENDCHECK
installer_version=\$(cat /root/installer-anaconda-version 2>/dev/null)
system_version=\$(rpm -q anaconda-core)
if [ -n "\${installer_version}" ] && [[ "\${installer_version}" != "\${system_version}" ]]; then
    echo "Anaconda version in installer (\${installer_version}) and system (\${system_version}) differ."
    echo "You might need to drop the updated anaconda packages in data/additional_repo folder."
fi
ENDCHECK
%end
