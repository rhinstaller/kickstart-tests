#!/bin/bash
#
# Choose the payload mirrors for a platform, once, and remember the answer.
#
# Reads the platform's defaults, then whatever was chosen last time, and lets
# scripts/check-mirrors.sh decide whether that still stands. Mirrors picked
# here are remembered; mirrors a platform names for itself are not, so that
# changing one in the repo is not shadowed by a stale file on the runner.
#
# The state lives outside the checkout because the workspace is wiped at the
# start of every CI run, and the whole point is to keep using the same mirror
# across runs - the caching proxy keys on URL.
#
# Prints NAME=value lines on stdout, in the format $GITHUB_ENV wants, and
# explains itself on stderr. Run it by hand to see what CI would do:
#
#   scripts/select-mirrors.sh fedora_rawhide
#
# and add a state directory of your own to leave the runner's alone:
#
#   scripts/select-mirrors.sh fedora_rawhide /tmp/my-mirrors

set -eu

platform="${1:-}"
state_dir="${2:-${MIRROR_STATE_DIR:-${HOME}/.kstest-mirrors}}"

if [ -z "${platform}" ]; then
    echo "usage: $0 PLATFORM [STATE_DIR]" >&2
    exit 2
fi

# defaults.sh and the scripts it sources use paths relative to the checkout.
cd "$(dirname "$0")/.."

state="${state_dir}/${platform}.sh"
mkdir -p "${state_dir}"

source ./scripts/defaults.sh
if [ -e "./scripts/defaults-${platform}.sh" ]; then
    source "./scripts/defaults-${platform}.sh"
fi

# Last run's answer, so a mirror that still works is kept rather than rolled.
if [ -e "${state}" ]; then
    source "${state}"
fi

eval "$(./scripts/check-mirrors.sh)"

: > "${state}"
for var in KSTEST_URL KSTEST_MODULAR_URL; do
    if [ -z "${!var:-}" ]; then
        continue
    fi

    echo "${var}=${!var}"

    repo="MIRROR_REPO_${var}"
    if [ -n "${!repo:-}" ]; then
        echo "export ${var}='${!var}'" >> "${state}"
    fi
done

echo "${platform}: remembered $(grep -c . "${state}" || true) mirror(s) in ${state}" >&2
