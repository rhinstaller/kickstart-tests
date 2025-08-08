# Common functions for validation of Services DBus module tests
. ${KSTESTDIR}/libs/functions.sh

# check that no xconfig or skipx commands are present in output kickstart
function validate_no_xconfig_skipx_command_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^skipx" ${disksdir}/anaconda-ks.cfg
    if [[ $? == 0 ]]; then
        echo '*** skipx command present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
    egrep -i "^xconfig" ${disksdir}/anaconda-ks.cfg
    if [[ $? == 0 ]]; then
        echo '*** xconfig command present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}

# check the skipx command is in output kickstart
function validate_skipx_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^skipx" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** skipx command not present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}

# check the xconfig --startxonboot command is in output kickstart
function validate_xconfig_startxonboot_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^xconfig.*--startxonboot" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** xconfig --startxonboot command not present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}

# check the xconfig --startxonboot command is in output kickstart
function validate_xconfig_defaultdesktop_in_ks() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the output kickstart
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"
    egrep -i "^xconfig.*--defaultdesktop=" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** xconfig --defaultdesktop command not present in output kickstart' >> ${disksdir}/RESULT
        return 1
    fi
}
