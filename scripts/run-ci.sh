#!/bin/bash
set -eu

# rebase on current upstream main, so that we run current tests
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/rhinstaller/kickstart-tests
git fetch upstream
git rebase upstream/main

# list of tests that are changed by the current PR; ignore non-executable *.sh as these are helpers, not tests
CHANGED_TESTS=$(git diff --name-only upstream/main..HEAD -- *.ks.in $(find -maxdepth 1 -name '*.sh' -perm -u+x) | sed 's/\.ks\.in$//; s/\.sh$//' | sort -u)

TESTS=$CHANGED_TESTS

# if the PR changes anything in the test runner, or does not touch any tests, pick a few representative tests
if [ -z "$TESTS" ] || [ -n "$(git diff --name-only upstream/main..HEAD -- containers scripts)" ]; then
    TESTS="$TESTS
bindtomac-network-device-default-httpks
container
lvm-1
network-device-mac-httpks
network-static
"
fi

# Limit to 6 tests (we can't run a lot of tests on Travis), weed out duplicates
# and convert to space separated list. The changed tests should have precedence
# over the representative tests.
TESTS=$(echo "$TESTS" | head -n6 | sort -u | xargs)

echo "Running tests: $TESTS"

# HACK: /dev/kvm is root:kvm 0660 in Travis by default
sudo -n chmod 666 /dev/kvm

sudo -n containers/squid.sh start

# FIXME: Maybe it's not needed with testing farm
# With parallel jobs, each test takes a little longer than 10 minutes, which makes Travis abort
# <https://docs.travis-ci.com/user/common-build-problems/#build-times-out-because-no-output-was-received>
# Avoid this by printing a keep-alive '.' line every minute
while true; do echo '.'; sleep 60; done &
trap "kill $!" EXIT INT QUIT PIPE

source containers/runner/skip-testtypes
containers/runner/launch $TESTS --skip-testtypes $SKIP_TESTTYPES_RAWHIDE
