# The download.fedoraproject.org automatic redirector often selects download-ib01.f.o. for GitHub's cloud, which is too unreliable; manually select a good one that is nearby
export KSTEST_URL='--url=http://pubmirror2.math.uh.edu/fedora-buffet/fedora/linux/development/rawhide/Everything/$basearch/os/'
export KSTEST_MODULAR_URL='http://pubmirror2.math.uh.edu/fedora-buffet/fedora/linux/development/rawhide/Modular/$basearch/os/'
