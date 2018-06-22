Playbooks for deployment of hosts for running kickstart tests.

Before the deployment:
----------------------

The hosts can be provisioned for example in OpenStack using Fedora Base Cloud Image (see [linchpin](../linchpin))

Before running the playbook the inventory and configuration has to be updated based on the provisioned hosts:

* Path to private ssh key for accessing the provisioned hosts by ansible for deployment has to be added to [ansible.cfg](ansible.cfg) `private_key_file` variable.
* Remote user with non-interactive sudo privilege has to be configured in [ansible.cfg](ansible.cfg) `remote_user` variable. For Fedora cloud images the user is `fedora`.
* Host names (or IPs) have to be present in appropriate group of some [inventory](inventory) file. It can be either manually added to [inventory/hosts](inventory/hosts) or for example generated and dropped into the directory by provisioning tools.
* Some playbooks/roles may need additional configuration which should be described in the role's README.

The playbooks:
--------------

* `kstest.yml`

  * Playbook for deploying hosts on which kickstart tests can be run remotely using [kstest role](roles/kstest)
  * [inventory](inventory/hosts) group: `[kstest]`

* `kstest-master.yml`

  * Playbook for deploying hosts from which kickstart tests can be run remotely using [kstest-master role](roles/kstest-master)
  * [inventory](inventory/hosts) group: `[kstest-master]`


