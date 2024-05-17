# Common functions for validation of Initial Setup tests
. ${KSTESTDIR}/functions.sh

# check that post install tools are config
function validate_post_install_tools() {
    disksdir=$1
    should_be_disabled=$2
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)


    # Copy the user interaction configuration file.
    run_with_timeout 1000s "virt-copy-out ${args} /etc/sysconfig/anaconda ${disksdir}"

    # Does it exist?
    if [ ! -f "${disksdir}/anaconda" ]; then
        echo '*** /etc/sysconfig/anaconda does not exist in VM image.' >> ${disksdir}/RESULT
        return 1
    else
        # Rename the file, so it does not conflict with anaconda directory.
        mv ${disksdir}/anaconda ${disksdir}/anaconda.sysconfig

        # Load the content
        real_config=$(cat "${disksdir}/anaconda.sysconfig")

        if [[ "$should_be_disabled" == "1" ]]; then
            # Check that post install tools are marked as disabled
            egrep -i "^post_install_tools_disabled = 1" ${disksdir}/anaconda.sysconfig
            if [[ $? != 0 ]]; then
                echo '*** post install tools are not marked as disabled in /etc/sysconfig/anaconda' >> ${disksdir}/RESULT

                echo "CONFIG:" >> ${disksdir}/RESULT
                echo "$real_config" >> ${disksdir}/RESULT
                echo "" >> ${disksdir}/RESULT
                return 1
            fi
        else
            # Check that post install tools are not marked as disabled
            egrep -i "^post_install_tools_disabled = 1" ${disksdir}/anaconda.sysconfig
            if [[ $? == 0 ]]; then
                echo '*** post install tools are marked as disabled in /etc/sysconfig/anaconda' >> ${disksdir}/RESULT

                echo "CONFIG:" >> ${disksdir}/RESULT
                echo "$real_config" >> ${disksdir}/RESULT
                echo "" >> ${disksdir}/RESULT
                return 1
            fi
        fi
    fi
}

# check that no firstboot command is present in output kickstart
function validate_no_firstboot_command_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^firstboot" ${disksdir}/anaconda-ks.cfg
    if [[ $? == 0 ]]; then
        echo '*** firstboot command present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}

# check the firstboot --enable command is in output kickstart
function validate_firstboot_enable_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^firstboot --enable" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** firstboot --enable command not present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}

# check the firstboot --disable command is in output kickstart
function validate_firstboot_disable_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^firstboot --disable" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** firstboot --disable command not present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}

# check the firstboot --disable command is in output kickstart
function validate_firstboot_reconfig_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^firstboot --reconfig" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** firstboot --reconfig command not present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}
