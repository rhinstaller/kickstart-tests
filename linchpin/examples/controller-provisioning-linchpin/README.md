Example: Provisioning of *controller* in cloud using linchpin
-------------------------------------------------------------

### Credentials configuration

##### Access to the cloud for controller provisioning:

`credentials` variable of the [PinFile.controller](PinFile.controller) define that access to the cloud is configured in `clouds.yml` file under `kstests` profile. You can put it in `.config/linchpin` folder.

##### Controller deployment key:

`keypair` variable of the [PinFile.controller](PinFile.controller) defines that the public key stored on the cloud under name `kstests` will be used for access to the controller. Path to the respective private key should be configured in [kstests-controller-provision.sh](kstests-controller-provision.sh) variable `ansible_ssh_private_key_file` so that the deployment playbook can access the provisioned controller.

##### Deployment playbook configuration:

The controller user is `kstest`. Ssh key for the user access is configured by `kstest_controller_user_authorized_key` variable which can be set in inventory via [kstests-controller-provision.sh](kstests-controller-provision.sh).

Assuming the controller will be used to provision runners in cloud, the cloud credentials need to be passed to the controller via a configuration file. Default path to the file is configured by `cloud_config_file` variable in [kstest-controller/defaults/main.yml](../../../ansible/roles/kstest-controller/defaults/main.yml). In this example it can be overriden in the inventory via [kstests-controller-provision.sh](kstests-controller-provision.sh).

It may be useful to pass also an ssh keypair to be further used to the controller. The keys to be passed to the controller user can be configured by the playbook variables `private_keys_to_upload`, `public_keys_to_upload` that can be set for example in the inventory via [kstests-controller-provision.sh](kstests-controller-provision.sh).

### Provision and deploy

- Update the deployment key name in [PinFile.controller](PinFile.controller) variable `keypair` to the keypair you want to use.

- Copy [kstests-controller-provision.sh](kstests-controller-provision.sh) in `kickstart-tests` repo root and configure the inventory:
    - Replace the `<PRIVATE_KEY_PATH>` with path to the private key of the cloud keypair used above (if it is not your default key).
    - Replace the `<PUBLIC_KEY_PATH>` with ssh public key for controller user (`kstest`) access.
    - Replace the `<CLOUD_CONFIG_FILE>` with path to the cloud configuration file and uncomment the variable or place the file to the default location as configured in [kstest-controller/defaults/main.yml](../../../ansible/roles/kstest-controller/defaults/main.yml).
    - If you want to pass ssh keys to the controller user set `private_keys_to_upload` or `public_keys_to_upload`.

- Run [kstests-controller-provision.sh](kstests-controller-provision.sh) from `kickstart-tests` repo root.

- Run the playbook from `kickstart-tests` root using the inventory created by the provisioning:

```
ansible-playbook -i linchpin/inventories/kstest-controller.inventory ansible/kstest-controller-deploy.yml
```
### Destroy

To destroy the controller run [kstests-controller-destroy.sh](kstests-controller-destroy.sh) from `kicstart-tests` repo root.

