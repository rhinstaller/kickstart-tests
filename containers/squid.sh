#!/bin/sh
# Start/stop a transparent squid proxy in a container. System podman containers will
# automatically use this to route plain http traffic through the cache, and thus
# greatly speed up the kickstart tests.
#
# This does NOT work with user podman containers, as they don't use a bridge, but slirp.
# Transparent content caching does NOT work with https in principle.

set -eu

MYDIR=$(dirname $(realpath "$0"))
CRUN=${CRUN:-$(which podman docker 2>/dev/null | head -n1)}

if [ "${1:-}" = start ]; then
    # clean up stopped container from previous boot (usually one does not remember to call "squid.sh stop")
    $CRUN rm squid || true
    # This image is well-maintained (auto-built) and really small
    $CRUN run --net host --name squid --detach \
        --volume "$MYDIR"/squid-cache.conf:/etc/squid/conf.d.tail/cache.conf:ro,z \
        --volume ks-squid-cache:/var/cache/squid docker.io/b4tman/squid

    # Redirect all traffic from external interfaces (like container bridges) through our local proxy
    # This does NOT re-route localhost traffic, as that does not go through PREROUTING.
    nft -f "$MYDIR"/squid-cache.nft

    if firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --add-port=3129/tcp
    fi
elif [ "${1:-}" = stop ]; then
    nft delete table squid-cache

    $CRUN rm -f squid

    if firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --remove-port=3129/tcp
    fi
else
    echo "Usage: $0 start|stop" >&2
    exit 1
fi
