#!/bin/bash
#
# Run a few tests the way the daily workflow would, without the workflow.
#
#   scripts/run-local.sh keyboard lang
#   scripts/run-local.sh -p fedora-eln --scenario fedora-eln basic-ftp
#
# containers/runner/launch already runs whichever tests you name. What it does
# not do is the setup that .github/workflows/scenarios-permian.yml does around
# it, and that setup is most of what makes a run on a restricted host behave:
# the caching proxy, and picking the payload mirror once so that the proxy has
# something stable to cache. Doing those by hand is easy to get subtly wrong -
# forget the mirror and every test resolves its own, which is the state this
# was all written to get out of - so they live here instead.
#
# Everything other than -p/--platform is handed straight to launch; see
# containers/runner/launch --help. The platform is needed here too, because the
# mirror choice is per platform.
#
# Two things the workflow does are deliberately left out. It wipes the
# workspace first, which would be a rude thing to do to a checkout you are
# working in, and it drops the squid cache, which is the opposite of what you
# want when re-running a test. Both are one-liners when you do want them:
#
#   sudo containers/squid.sh clean
#
# Runs as root, like the workflow does, and not only for /dev/kvm: squid
# intercepts traffic from the container bridge, and rootless podman uses slirp
# instead, so a rootless run quietly bypasses the cache entirely.

set -eu

cd "$(dirname "$0")/.."

PLATFORM=fedora_rawhide
launch_args=()

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            # Before any setup: asking what the options are should not start a
            # proxy or go out to MirrorManager.
            exec containers/runner/launch --help
            ;;
        *)
            launch_args+=("$1")
            shift
            ;;
    esac
done

if [ "${#launch_args[@]}" -eq 0 ]; then
    echo "usage: $0 [-p PLATFORM] [launch options] TEST [TEST..]" >&2
    echo "       $0 --help   for the options launch takes" >&2
    exit 2
fi

sudo containers/squid.sh start

# Same selection the workflow makes, remembered in the same place, so that a
# local run and a CI run on this host agree on the mirror and share the cache.
#
# Captured rather than read from a process substitution, which would report
# nothing at all if the selection failed and let the tests run against unset
# mirrors.
selection=$(./scripts/select-mirrors.sh "${PLATFORM}")

while IFS= read -r assignment; do
    [ -n "${assignment}" ] || continue
    export "${assignment?}"
done <<< "${selection}"

# sudo keeps nothing by default, and the mirror we just chose is in the
# environment. launch passes every KSTEST_ variable into the container.
preserve=$(printenv | sed -n 's/^\(KSTEST_[A-Za-z0-9_]*\)=.*/\1/p' | paste -sd, -)

exec sudo --preserve-env="${preserve},TEST_JOBS" \
     containers/runner/launch -p "${PLATFORM}" "${launch_args[@]}"
