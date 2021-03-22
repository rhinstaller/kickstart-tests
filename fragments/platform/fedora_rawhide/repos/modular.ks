# The Fedora rawhide repository with modules.
# Install the repo, so DNF can use it in %post scripts.
repo --name=modular --baseurl @KSTEST_MODULAR_URL@ --install --cost 0
