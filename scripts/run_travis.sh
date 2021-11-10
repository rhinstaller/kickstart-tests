#!/bin/sh
set -eu

# rebase on current upstream master, so that we run current tests
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/rhinstaller/kickstart-tests
git fetch upstream
git rebase upstream/master

# list of tests that are changed by the current PR; ignore non-executable *.sh as these are helpers, not tests
CHANGED_TESTS=$(git diff --name-only upstream/master..HEAD -- *.ks.in $(find -maxdepth 1 -name '*.sh' -perm -u+x) | sed 's/\.ks\.in$//; s/\.sh$//' | sort -u)
# weed out known failures
TESTS=""
for t in $CHANGED_TESTS; do
    if grep -q 'TESTTYPE.*knownfailure' ${t}.sh; then
        echo "Not running $t as it is a known failure"
    elif grep -q 'TESTTYPE.*manual' ${t}.sh; then
        echo "Not running $t as it requires manual preparation"
    else
        TESTS="$TESTS
$t"
    fi
done

# if the PR changes anything in the test runner, or does not touch any tests, pick a few representative tests
# FIXME: Once the runner container can run groups properly, replace with a TESTTYPE="travis" group
if [ -z "$TESTS" ] || [ -n "$(git diff --name-only upstream/master..HEAD -- containers scripts)" ]; then
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

# With parallel jobs, each test takes a little longer than 10 minutes, which makes Travis abort
# <https://docs.travis-ci.com/user/common-build-problems/#build-times-out-because-no-output-was-received>
# Avoid this by printing a keep-alive '.' line every minute
while true; do echo '.'; sleep 60; done &
trap "kill $!" EXIT INT QUIT PIPE

containers/runner/launch $TESTS
