Example: Provisioning of *controller* by kickstart installation
---------------------------------------------------------------

### Credentials configuration

##### Provisioning:

Keypair for access to the controller:

- Public ssh key for root access the controller is passed in `sshkey` command of [kickstart](ks.kstest-controller.cfg) used for controller installation.

- If you are not using your default keypair, path to private ssh key for the controller root access by ansible may be defined by `ansible_ssh_private_key` variable.

##### Deployment playbook configuration:

The controller user is `kstest`. Ssh key for the user access is configured by `kstest_controller_user_authorized_key` variable which can be set in [inventory](hosts).

Assuming the controller will be used to provision runners in cloud, the cloud credentials need to be passed to the controller via a configuration file. Default path to the file is configured by `cloud_config_file` variable in [kstest-controller/defaults/main.yml](../../../ansible/roles/kstest-controller/defaults/main.yml). In this example it can be overriden in the [inventory](hosts).

It may be useful to pass also an ssh keypair to be further used to the controller. The keys to be passed to the controller user can be configured by the playbook variables `private_keys_to_upload`, `public_keys_to_upload` that can be set for example in the [inventory](hosts).

### Provisioning and deployment

- Modify ssh key configuration in the [kickstart](ks.kstest-controller.cfg) for your keypair.

- Install the controller host using the [kickstart](ks.kstest-controller.cfg).

- Copy the inventory [hosts](hosts) into `kickstart-tests` root and configure it:
    - Replace the `<IP_ADDRESS>` with the real controller IP address.
    - Replace the `<PUBLIC_KEY_PATH>` with ssh public key for controller user (`kstest`) access.
    - Replace the `<CLOUD_CONFIG_FILE>` with path to cloud configuration file and uncomment the variable or place the file to the default location as configured in [kstest-controller/defaults/main.yml](../../../ansible/roles/kstest-controller/defaults/main.yml).
    - If you want to pass ssh keys to the controller user set `private_keys_to_upload` or `public_keys_to_upload`.

- Run the playbook from `kickstart-tests` root using the inventory:

```
ansible-playbook -i hosts ansible/kstest-controller-deploy.yml
```
