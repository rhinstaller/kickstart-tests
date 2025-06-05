installer_version="\$(grep anaconda-core /var/log/anaconda/lorax-packages.log)"
system_version="\$(rpm -q anaconda-core)"
if [[ "\${installer_version}" != "\${system_version}" ]]; then
    echo "Anaconda version in installer (\${installer_version}) and system (\${system_version}) differ."
    echo "You might need to drop the updated anaconda packages in data/additional_repo folder."
fi
