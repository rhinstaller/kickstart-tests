Example: Provisioning of *controller* in cloud using linchpin
-------------------------------------------------------------

## Credentials configuration:

### Access to the cloud:

`credentials` variable of the [PinFile.controller](linchpin/PinFile.controller) define that access to the cloud is configured in `clouds.yml` file under `kstests` profile. You can put it in `.config/linchpin` folder.

### Controller deployment key:

`keypair` variable of the [PinFile.controller](linchpin/PinFile.controller) defines that the public key stored on the cloud under name `kstests` will be used for access to the controller. Path to the respective private key should be configured in [kstests-controller-provision.sh](kstests-controller-provision.sh) variable `ansible_ssh_private_key_file` so that the deployment playbook can access the provisioned controller.

### Deployment playbook configuration:

Assuming the *controller* will be used to provision *runners* in cloud, the cloud credentials and ssh keys should be passed also to the *controller*. The credentials to be uploaded are configured by the playbook variables `private_keys_to_upload`, `public_keys_to_upload`, and `cloud_config_file` in the role configuration file [kstest-controller/defaults/main.yml](../../../ansible/roles/kstest-controller/defaults/main.yml).

In this example the variables can be configured in the provisioning script [kstests-controller-provision.sh](kstests-controller-provision.sh) by updating the `[kstest-controller:vars]` section of the generated inventory.

## Provision and deploy:

Copy [PinFile.controller](linchpin/PinFile.controller) containing resources definition of *controller* host to the `linchpin` folder.

Copy [kstests-controller-provision.sh](kstests-controller-provision.sh) in `kickstart-tests` repo root and set the path to the private key in `<PRIVATE_KEY_PATH>`.
Also set credentials to be passed to the *controller* in `<PUBLIC_KEY_TO_UPLOAD_PATH>`, `<PRIVATE_KEY_TO_UPLOAD_PATH>`, `<CLOUD_CONFIG_FILE>` (or comment out the lines if you don't intend to use them on the controller).

Run [kstests-controller-provision.sh](kstests-controller-provision.sh) in `kickstart-tests` repo root.

## Destroy:

To destroy the *controller* run [kstests-controller-destroy.sh](kstests-controller-destroy.sh) in `kicstart-tests` repo root.

