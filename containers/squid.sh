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
    # This image is well-maintained (auto-built) and really small
    $CRUN run --net host --name squid --detach \
        --volume "$MYDIR"/squid-cache.conf:/etc/squid/conf.d.tail/cache.conf:ro \
        --volume ks-squid-cache:/var/cache/squid docker.io/b4tman/squid

    # Redirect all traffic from external interfaces (like container bridges) through our local proxy
    # This does NOT re-route localhost traffic, as that does not go through PREROUTING.
    nft -f "$MYDIR"/squid-cache.nft

elif [ "${1:-}" = stop ]; then
    nft delete table squid-cache

    $CRUN rm -f squid

else
    echo "Usage: $0 start|stop" >&2
    exit 1
fi