#!/bin/sh

usage () {
    cat <<HELP_USAGE

    $0  [-c]

    Run kickstart tests on hosts provisioned by linchpin and deployed with ansible,
    syncing results to a remote host.

   -c  Run configuration check.
HELP_USAGE
}

CHECK_ONLY="no"

while getopts "c" opt; do
    case $opt in
        c)
            # Run only configuration check
            CHECK_ONLY="yes"
            ;;
        *)
            echo "Usage:"
            usage
            exit 1
            ;;
    esac
done

DEFAULT_CRED_FILENAME="clouds.yml"
CRED_DIR="${HOME}/.config/linchpin"
CRED_FILE_PATH=${CRED_DIR}/${DEFAULT_CRED_FILENAME}
TOPOLOGY_FILE_PATH="linchpin/topologies/kstests.yml"
ANSIBLE_CFG_PATH="ansible/ansible.cfg"
MASTER_CFG_PATH="ansible/roles/kstest-master/vars/main.yml"
MASTER_DEFAULTS_PATH="ansible/roles/kstest-master/defaults/main.yml"
AUTHORIZED_KEYS_DIR="ansible/roles/kstest/files/authorized_keys"

test ! -f "${HOME}/.config/kstests/cloud.conf" || . "${HOME}/.config/kstests/cloud.conf"

CHECK_RESULT=0


############################## Check the configuration

echo
echo "========= Dependencies are installed"
echo "linchpin and ansible are required to be installed."
echo "For linchpin installation instructions see:"
echo "https://linchpin.readthedocs.io/en/latest/installation.html"
echo

if ! type ansible &> /dev/null; then
    echo "=> FAILED: ansible package is not installed"
    CHECK_RESULT=1
else
    echo "=> OK: ansible is installed"
fi

if ! type linchpin &> /dev/null; then
    echo "=> FAILED: linchpin is not installed"
    CHECK_RESULT=1
else
    echo "=> OK: linchpin is installed"
fi


echo
echo "========= Linchpin cloud credentials configuration"
echo "The credentials file for linchpin provisioner should be in ${CRED_DIR}"
echo "The name of the file and the profile to be used is defined by"
echo "   resource_groups.credentials variables in the topology file"
echo "   (${TOPOLOGY_FILE_PATH})"
echo

config_changed=0
if [[ -f ${TOPOLOGY_FILE_PATH} ]]; then
    grep -q 'filename:.*'${DEFAULT_CRED_FILENAME} ${TOPOLOGY_FILE_PATH}
    config_changed=$?
fi

if [[ ${config_changed} -eq 0 ]]; then
    if [[ -f ${CRED_FILE_PATH} ]]; then
        echo "=> OK: ${CRED_FILE_PATH} exists"
    else
        echo "=> FAILED: ${CRED_FILE_PATH} does not exist"
        CHECK_RESULT=1
    fi
else
    echo "=> NOT CHECKING: seems like this has been configured in a different way"
fi


echo
echo "========== Deployment ssh key configuration"
echo "The ssh key used for deployment with ansible has to be defined by"
echo "private_key_file variable in ${ANSIBLE_CFG_PATH}"
echo "and match the key used for provisioning of the machines with linchpin"
echo "which is defined by resource_groups.resource_definitions.keypair variable"
echo "in topology file (${TOPOLOGY_FILE_PATH})."
echo


linchpin_keypair=$(grep "keypair:" ${TOPOLOGY_FILE_PATH} | uniq)
echo "=> INFO: should be the same key as ${TOPOLOGY_FILE_PATH}: ${linchpin_keypair}"


echo
echo "========== Master ssh key configuration"
echo "Master's ssh key for accessing remote hosts has to be defined by"
echo "kstest.master.private_ssh_key variable in ${MASTER_CFG_PATH}"
echo "and it has to be authorized by remote hosts by adding the public key"
echo "into ${AUTHORIZED_KEYS_DIR} directory."
echo

master_key_defined_line=$(grep '\S*private_ssh_key:.*[^\S]' ${MASTER_CFG_PATH})
if [[ -n "${master_key_defined_line}" ]]; then
    echo "=> OK: master ssh key: ${MASTER_CFG_PATH}: ${master_key_defined_line}"
else
    echo "=> FAILED: master ssh key not defined in ${MASTER_CFG_PATH}"
    CHECK_RESULT=1
fi

authorized_keys=$(ls ${AUTHORIZED_KEYS_DIR})
if [[ -n "${authorized_keys}" ]]; then
    echo "=> INFO: should be among ${AUTHORIZED_KEYS_DIR}: ${authorized_keys}"
else
    echo "=> FAILED: master ssh key not among authorized keys in ${AUTHORIZED_KEYS_DIR}"
    CHECK_RESULT=1
fi


echo
echo "========== Results host configuration"
echo "Host for syncing the results from master before the provisioned hosts are"
echo "destroyed has to be defined by kstest_remote_results_path variable in"
echo "${MASTER_DEFAULTS_PATH} file."
echo "Master's ssh key should be authorized to access the results host."
echo

results_host_defined_line=$(grep '^[\S]*kstest_remote_results_path:.*@.*' ${MASTER_DEFAULTS_PATH})
if [[ -n "${results_host_defined_line}" ]]; then
    echo "=> OK: results location: ${MASTER_DEFAULTS_PATH}: ${results_host_defined_line}"
else
    echo "=> FAILED: results location not defined in ${MASTER_DEFAULTS_PATH}"
    CHECK_RESULT=1
fi


echo
echo "========== Test configuration"
echo "The test is configured in ${MASTER_DEFAULTS_PATH}:"
echo
cat ${MASTER_DEFAULTS_PATH}

if [[ ${CHECK_RESULT} -ne 0 ]]; then
echo
echo "=> Configuration check FAILED, see FAILED messages above."
echo
fi

if [[ ${CHECK_ONLY} == "yes" || ${CHECK_RESULT} -ne 0 ]]; then
    exit ${CHECK_RESULT}
fi


############################## Run the test

set -x

### Clean the linchpin generated inventory
rm -rf linchpin/inventories/*.inventory

### Provision test hosts (all which are defined in the PinFile)
linchpin -v --workspace linchpin -p PinFile -c linchpin/linchpin.conf up

### Pass inventory generated by linchpin to ansible
cp linchpin/inventories/*.inventory ansible/inventory/linchpin.inventory

cd ansible

### Deploy the remote hosts
ansible-playbook kstest.yml
### Deploy the master and configure the test
ansible-playbook kstest-master.yml
### Run the test and sync results
ansible kstest-master -m shell -a 'PATH=$PATH:/usr/sbin ~/run_tests.sh' -u kstest

cd -

### Destroy the provisioned hosts
linchpin -v --workspace linchpin -p PinFile -c linchpin/linchpin.conf destroy
