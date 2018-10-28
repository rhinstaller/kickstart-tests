#!/bin/bash

TARGET=""
COMMAND="all"
CLOUD_CONFIG_DIR=~/.config/linchpin/
CLOUD_CONFIG_FILE=clouds.yml
CLOUD_PROFILE="kstests"
RESULTS_DIR=""
TEST_CONFIGURATION_FILE=""
PINFILE="PinFile"

KEY_NAME=$(uuidgen)
KEY_MODE="generate"
UPLOAD_KEY_PATH=""
PRIVATE_KEY_PATH=""
WORK_BASE_DIR=$(pwd)
USE_KEY_FOR_MASTER="no"
#STORED_PRIVATE_KEYS_DIR=$(mktemp -d -t kstest-deploymen-keys-XXXXXX)
STORED_PRIVATE_KEYS_DIR="${WORK_BASE_DIR}/linchpin/keys"

# Directory to which linchpin generates inventory of provisioned runners.
# Defined by linchpin layout configuration.
INVENTORY_DIR="linchpin/inventories"


usage () {
    cat <<HELP_USAGE

$(basename $0) [options] COMMAND TARGET

Run kickstart tests on runners temporarily provisioned by linchpin in cloud.
Linchpin target name TARGET is defined in PinFile (linchpin/PinFile).

Various commands can be used to run kickstart tests in cloud.

COMMANDs:

  test               provision TARGET, run tests, destroy TARGET
  schedule           schedule the test on TARGET using local host timer

  Breaking down the test into separate stages:

  provision          provision target TARGET from PinFile in cloud
  run                run tests in cloud on target TARGET
  destroy            destroy target TARGET in cloud

  status             show status of test running on TARGET

Options:

  --cloud NAME               name of the cloud profile to be used for cloud credentials
                             (stored in ~/.config/linchpin/cloud.yml by default)

  Provisioning options ("provision" command):

    --pinfile                name of the linchpin pinfile to use;
                             the file is located in linchpin directory, default is "PinFile"

    -k, --key-name NAME      name of the ssh key used for provisioning in cloud;
                             by default new key is generated on the cloud provider
    --key-use-existing       use the existing key --key-name from cloud
    --key-upload PATH        upload public ssh key defined by PATH (as --key-name if defined).
    --ansible-private-key PATH
                             path to private ssh key to be used for ansible deployment;
                             if not defined generated key or user's default ssh key is used;
                             this option may be required with --key-use-existing or --key-upload
    --key-use-for-master     use the deployment key also as master runner key which
                             is used by master to access other test runners;
                             without the option a new temporary master runner key is generated;
                             note that the private key will be uploaded to master.

  Test configuration options ("run" command):

    --results PATH           directory for storing results synced from master to local host
    --test-configuration PATH
                             path to file with test configuration to be used;
                             overrides default test-configuration.yml
                             (ansible/roles/kstest-master/defaults/main/test-configuration.yml)
                             which can be overriden also by file
                             ansible/roles/kstest-master/vars/main/test-configuration.yml

HELP_USAGE
}

options=$(getopt -o k: --long cloud:,results:,key-name:,key-use-existing,key-upload:,ansible-private-key:,key-use-for-master,test-configuration:,pinfile: -- "$@")
[ $? -eq 0 ] || {
    echo "Usage:"
    usage
    exit 1
}

eval set -- "$options"
while true; do
    case "$1" in
    # TODO remove -k
    -k|--key-name)
        shift;
        KEY_NAME=$1
        ;;
    --key-use-existing)
        [[ ${KEY_MODE} == "upload" ]] && {
            echo "Only one of --key-use-existing or --key-upload options can be used."
            exit 1
        }
        KEY_MODE=existing
        ;;
    --key-upload)
        [[ ${KEY_MODE} == "existing" ]] && {
            echo "Only one of --key-use-existing or --key-upload options can be used."
            exit 1
        }
        shift;
        KEY_MODE=upload
        UPLOAD_KEY_PATH=$1
        ;;
    --ansible-private-key)
        shift;
        PRIVATE_KEY_PATH=$1
        ;;
    --cloud)
        shift;
        CLOUD_PROFILE=$1
        ;;
    --results)
        shift;
        RESULTS_DIR=$1
        ;;
    --key-use-for-master)
        USE_KEY_FOR_MASTER="yes"
        ;;
    --test-configuration)
        shift;
        if [[ "$1" == "${1#/}" ]]; then
            # make relative path absolute
            TEST_CONFIGURATION_FILE="${WORK_BASE_DIR}/$1"
        else
            TEST_CONFIGURATION_FILE=$1
        fi
        ;;
    --pinfile)
        shift;
        PINFILE=$1
        ;;
    --)
        shift;
        COMMAND=$1
        shift;
        TARGET=$1
        break
        ;;
    esac
    shift
done

if [[ -z ${COMMAND} ]]; then
    echo "COMMAND is required"
    exit 1
fi

if [[ -z ${TARGET} ]]; then
    echo "TARGET is required"
    exit 1
fi


# Defined for linchpin by layout configuration
INVENTORY=${INVENTORY_DIR}/${TARGET}.inventory
TARGET_KEY_DIR=${STORED_PRIVATE_KEYS_DIR}/${TARGET}


#################################################### provision stage

if [[ ${COMMAND} == "all" || ${COMMAND} == "provision" ]]; then

    if [[ -e $INVENTORY ]]; then
        echo "Inventory ${INVENTORY} for target ${TARGET} exists, it must have been already deployed"
        exit 1
    fi

    # Use default ansible.cfg
    cp ansible/ansible.cfg .

    # Set up deployment ssh key

    if [[ ! -d ${STORED_PRIVATE_KEYS_DIR} ]]; then
        mkdir ${STORED_PRIVATE_KEYS_DIR}
    fi

    mkdir ${TARGET_KEY_DIR}
    chmod 0700 ${TARGET_KEY_DIR}
    STORED_PRIVATE_KEY_PATH="${TARGET_KEY_DIR}/${KEY_NAME}"
    STORED_PUBLIC_KEY_PATH="${TARGET_KEY_DIR}/${KEY_NAME}.pub"

    export OS_CLIENT_CONFIG_FILE=${CLOUD_CONFIG_DIR}/${CLOUD_CONFIG_FILE}
    ansible-playbook linchpin/handle-ssh-key.yml --extra-vars "key_name=${KEY_NAME} key_mode=${KEY_MODE} cloud_profile=${CLOUD_PROFILE} upload_key_file=${UPLOAD_KEY_PATH} store_private_key_path=${STORED_PRIVATE_KEY_PATH} store_public_key_path=${STORED_PUBLIC_KEY_PATH}"

    # If private key was generated and user does not provide private key,
    # use the generated one for ansible
    if [[ -z "${PRIVATE_KEY_PATH}" && -f ${STORED_PRIVATE_KEY_PATH} ]]; then
        PRIVATE_KEY_PATH=${STORED_PRIVATE_KEY_PATH}
    fi

    # If the keypair should be used also for master check that the keys are available
    if [[ ${USE_KEY_FOR_MASTER} == "yes" ]]; then
        if [[ -z ${PRIVATE_KEY_PATH} || ! -f ${PRIVATE_KEY_PATH} ]]; then
            echo "Path to private key or newly generated key is required for --key-use-for-master option"
            exit 1
        fi
        if [[ -z ${STORED_PUBLIC_KEY_PATH} ]]; then
            echo "Don't have path to public key for --key-use-for-master option"
            exit 1
        fi
    fi

    # Show configuration info

    GENERATED=""
    if [[ -f ${STORED_PRIVATE_KEY_PATH} ]]; then
        GENERATED=" (generated)"
    fi

    if [[ -n ${PRIVATE_KEY_PATH} ]]; then
        KEY_SPEC=${PRIVATE_KEY_PATH}
    else
        KEY_SPEC="default private key"
    fi

    echo "Provisioning cloud ssh keypair:   ${KEY_NAME} ${GENERATED}"
    echo "Ansible deployment private key:   ${KEY_SPEC}"
    echo "Inventory for ansible deployment: ${INVENTORY}"


    # Provision test runners (defined by target from linchpin/PinFile)
    # Generates inventory for ansible.
    linchpin -v --workspace linchpin -p ${PINFILE} -c linchpin/linchpin.conf --template-data '{ "keypair": "'${KEY_NAME}'", "cloud_profile": "'${CLOUD_PROFILE}'", "resource_name": "'${TARGET}'" }' up ${TARGET}

    if [[ ! -f ${INVENTORY} ]]; then
        echo "Can't find inventory ${INVENTORY} generated for target ${TARGET}"
        exit 1
    fi

    # Update the generated inventory with ssh key for deployment

    if [[ -n ${PRIVATE_KEY_PATH} ]]; then
        for group in kstest kstest-master ; do
            cat <<EOF >> ${INVENTORY}
[${group}:vars]
ansible_ssh_private_key_file=${PRIVATE_KEY_PATH}
EOF
        done
    fi

    # Deploy the test runners and master

    ansible-playbook -i ${INVENTORY} ansible/deploy-kstest-runners.yml

    if [[ ${USE_KEY_FOR_MASTER} == "yes" ]]; then
        ansible-playbook -i ${INVENTORY} ansible/deploy-kstest-master.yml --extra-vars "master_private_ssh_key=${PRIVATE_KEY_PATH} master_public_ssh_key=${STORED_PUBLIC_KEY_PATH}"
    else
        ansible-playbook -i ${INVENTORY} ansible/deploy-kstest-master.yml
    fi

fi

#################################################### run stage

if [[ ${COMMAND} == "all" || ${COMMAND} == "run" ]]; then

    # Check that the target was deployed

    INVENTORY=${INVENTORY_DIR}/${TARGET}.inventory
    if [[ ! -f ${INVENTORY} ]]; then
        echo "Can't find inventory ${INVENTORY} generated for target ${TARGET}"
        exit 1
    fi

    # Configure and the test

    if [[ -n ${TEST_CONFIGURATION_FILE} ]]; then
        ansible-playbook -i ${INVENTORY} ansible/configure-test-for-kstest-master.yml --extra-vars "kstest_result_run_dir_prefix=${TARGET}. test_configuration=${TEST_CONFIGURATION_FILE}"
    else
        ansible-playbook -i ${INVENTORY} ansible/configure-test-for-kstest-master.yml --extra-vars "kstest_result_run_dir_prefix=${TARGET}."
    fi

    # Run the test

    ansible-playbook -i ${INVENTORY} ansible/run-test-from-kstest-master.yml

    # Fetch results

    if [[ -n ${RESULTS_DIR} ]]; then
        ansible-playbook -i ${INVENTORY} ansible/sync-results-from-master.yml --extra-vars "local_dir=${RESULTS_DIR}"
    fi

fi

#################################################### destroy stage

if [[ ${COMMAND} == "all" || ${COMMAND} == "destroy" ]]; then

    # Check that the target was deployed

    INVENTORY=${INVENTORY_DIR}/${TARGET}.inventory
    if [[ ! -f ${INVENTORY} ]]; then
        echo "Can't find inventory ${INVENTORY} generated for target ${TARGET}"
        exit 1
    fi

    # Destroy the provisioned hosts

    linchpin -v --workspace linchpin -p ${PINFILE} -c linchpin/linchpin.conf --template-data '{ "cloud_profile": "'${CLOUD_PROFILE}'", "resource_name": "'${TARGET}'" }' destroy ${TARGET}

    # Remove the inventory

    rm ${INVENTORY}

    # Remove generated deployment private key

    if [[ -e ${TARGET_KEY_DIR} ]]; then
        rm -rf ${TARGET_KEY_DIR}
    fi

fi

#################################################### check test run status

if [[ ${COMMAND} == "status" ]]; then

    # Check that the target was deployed

    INVENTORY=${INVENTORY_DIR}/${TARGET}.inventory
    if [[ ! -f ${INVENTORY} ]]; then
        echo "Can't find inventory ${INVENTORY} generated for target ${TARGET}"
        exit 1
    fi

    # Show status of test run

    ansible-playbook -i ${INVENTORY} ansible/kstest-status.yml

fi
