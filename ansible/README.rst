Running tests on remote hosts
=============================

It is possible to run kickstart tests on multiple hosts with
``run_kickstart_tests`` script. The script distributes the local boot.iso and
kickstart tests repository to the hosts, runs the tests in parallel, and fetches
the logs from the hosts.

Provision a remote host in OpenStack
------------------------------------

To provision a remote host in OpenStack from dashboard:

Create a new instance with ``Launch Instance`` from ``Compute -> Instances`` page:

``Details``:
  - ``Select Boot Source``: Image
  - ``Create New Volume``: No
  - Select the image ``Fedora-Cloud-Base-27-1.6``

``Flavor``:
   - ``m1.xlarge`` should be fine for running 4 tests (vms) in parallel. (May need a little bigger storage?)

``Key Pair``:
   - Select or create ssh key. The key will be needed for authentication when deploying the host with ansible (below).

After creating the instance associate a floating IP: ``Actions`` column on ``Instances`` page -> ``Associate Floating IP``.


Deploy the remote hosts with ansible
------------------------------------

You need IP the addresses of the hosts and ssh key for accessing the hosts.
(Eg. the key used to provision the OpenStack instance and its floating IP in the step above)

Go to the ansible directory and configure the playbook with the key and host IP:

- Put the IPs into ``inventory`` file under ``[kstest]`` group
- Configure the ssh key used in provisioning (above) for ansible in ``ansible.cfg`` ``private_key_file`` variable.
- Add public key you want to authenticate with when running remote tests to ``roles/kstest/files/authorized_keys`` directory.
- Deploy the remote hosts running:

::

   ansible-playbook kstest.yml

Run kickstart tests from local host
-----------------------------------

The tests must be run from the local kickstart-tests git repo root.

::

  TEST_REMOTES=<IP1,IP2,...> TEST_REMOTES_ONLY=yes scripts/run_kickstart_tests.sh -i ../boot.iso -k 1 hostname.sh user.sh

It may be a good idea to capture the output into a file with ``tee`` and run ``scripts/run_report.sh`` on the file to create the results report.

``TEST_REMOTES_ONLY`` ensures that local host is not used to run the tests.

It is also possible to modify the number of jobs run in parallel on one hosts by using ``TEST_JOBS`` variable.

The repo used for installation is defined in ``scripts/defaults.sh`` (``KSTEST_URL``). The ``TEST_*`` variables can be defined there as well.

NOTE: Do not store the boot.iso in current directory (kickstart-tests git repo) as the content of the repo will be copied to the remote hosts and the iso would be copied twice in this case.

See the logs on local host
--------------------------

The logs will be fetched into ``/var/tmp/kstest-*`` directories on local host after the tests are run.


Running nightly tests in OpenStack
==================================

A remote kickstart tests host created in Chapter 5. can be configured to run
periodical (nightly) tests using ``kstest-nightly`` playbook. It can be run on
a host already deployed by ``kstest`` playbook just adding a few more steps, or on
a freshly provisioned host.

The results and logs are stored on the host (``/home/kstest/results``). There
is an option to configure ``rsync`` destination for syncing these outputs to a remote host
for furhter processing.

TODO: rotating of results

Deployment
----------

In the ``ansible`` directory.

- Put the IP into ``inventory`` file into [kstest-nightly] group
- If not already done before, configure the ssh key used in host provisioning for ansible in ``ansible.cfg`` ``private_key_file`` variable.
- Add private and public keys for ``kstest`` user which is running the tests remotely into ``roles/kstest-nightly/files/keys`` as ``kstests.pem`` and ``kstests.pub``.
- Deploy the remote hosts running:

::

   ansible-playbook kstest-nightly.yml


Configuring
-----------

To configure the nightly tests (ie which tests, when, and on what hosts to run) you can modify the variable files:

::

   ansible/roles/kstest-nightly/defaults/main.yml
   ansible/roles/kstest-nightly/vars/main.yml

and run:

::

   ansible-playbook --tags config-test kstest-nightly.yml

Values from ``ansible/roles/kstest-nightly/defaults/main.yml`` can be also set up directly when running the playbook using the ``--extra-vars`` option:

::

   ansible-playbook --tags config-test --extra-vars 'kstest_tests_to_run="hostname.sh user.sh"' kstest-nightly.yml

Syncing results to remote host
------------------------------

It is possible to set up automatic rsync of results to a remote host. Make sure
the ``kstest`` user's public ssh key is added to the authorized keys of remote user/host.  Look
at ``kstest_remote_results*`` variables in

::

   ansible/roles/kstest-nightly/defaults/main.yml

Running the tests on demand
---------------------------

To run the tests (possibly configured as in the step above) on-demand use:

::

   ansible kstest-nightly -m shell -a "PATH=$PATH:/usr/sbin /home/kstest/run_nightly_tests.sh" -u kstest

