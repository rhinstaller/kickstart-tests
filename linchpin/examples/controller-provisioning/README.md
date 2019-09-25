Example: Provisioning of *controller* by kickstart installation
---------------------------------------------------------------

## Credentials configuration:

### Provisioning:

Kickstart to be used for controller installation: [ks.kstest-controller.cfg](ks.kstest-controller.cfg)

- public ssh key to access the host is passed in `sshkey` command

Inventory for the deployment playbook: [hosts](hosts)

- path to private ssh key is defined by `ansible_ssh_private_key` variable

### Deployment playbook configuration:

Assuming the *controller* will be used to provision *runners* in cloud, the cloud credentials and ssh keys should be passed also to the *controller*. The credentials to be uploaded are configured by the playbook variables `private_keys_to_upload`, `public_keys_to_upload`, and `cloud_config_file` in the role configuration file [kstest-controller/defaults/main.yml](../../../ansible/roles/kstest-controller/defaults/main.yml).

In this example the variables can be configured in the `[kstest-controller:vars]` section of the inventory [hosts](hosts).

## Provision and deploy:

Modify ssh key configuration in the [ks.kstest-controller.cfg](ks.kstest-controller.cfg) for your keypair.

Install the controller host using the [ks.kstest-controller.cfg](ks.kstest-controller.cfg) kickstart.

Copy the inventory [hosts](hosts) into `kickstart-tests` root and replace the <IP_ADDRESS> with the real controller IP address.

Update the credentials configuration in [hosts](hosts) - set the path to the (deployment) private key in `<PRIVATE_KEY_PATH>`. Also set credentials to be passed to the *controller* in `<PUBLIC_KEY_TO_UPLOAD_PATH>`, `<PRIVATE_KEY_TO_UPLOAD_PATH>`, `<CLOUD_CONFIG_FILE>` (or comment out the lines if you don't intend to use them on the controller).

Run the playbook from `kickstart-tests` root using the inventory:

`ansible-playbook -i hosts ansible/kstest-controller-deploy.yml`
