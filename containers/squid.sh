#!/bin/sh
# Start/stop a transparent squid proxy in a container. System podman containers will
# automatically use this to route plain http traffic through the cache, and thus
# greatly speed up the kickstart tests.
#
# This does NOT work with user podman containers, as they don't use a bridge, but slirp.
# Transparent content caching does NOT work with https in principle.
#
# Call this with "clean" to  drop the persistent squid cache.

set -eu

MYDIR=$(dirname $(realpath "$0"))
CRUN=${CRUN:-$(which podman docker 2>/dev/null | head -n1)}

is_running() {
    [ -n "$($CRUN ps -q -f 'name=^squid$')" ]
}

start() {
    if is_running; then
        echo "Already running"
        return 0
    fi

    # clean up stopped container from previous boot (usually one does not remember to call "squid.sh stop")
    $CRUN rm squid 2>/dev/null || true
    # This image is well-maintained (auto-built) and really small
    $CRUN run --net host --name squid --detach \
        --volume "$MYDIR"/squid-cache.conf:/etc/squid/conf.d.tail/cache.conf:ro,z \
        --volume ks-squid-cache:/var/cache/squid quay.io/rhinstaller/squid

    # Redirect all traffic from external interfaces (like container bridges) through our local proxy
    # This does NOT re-route localhost traffic, as that does not go through PREROUTING.
    nft -f "$MYDIR"/squid-cache.nft

    if firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --add-port=3129/tcp
    fi
}

stop() {
    if ! is_running; then
        echo "Already stopped"
        return 0
    fi

    nft delete table squid-cache

    $CRUN rm -f squid

    if firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --remove-port=3129/tcp
    fi
}

clean() {
    stop
    if $CRUN volume inspect ks-squid-cache >/dev/null 2>&1; then
        $CRUN volume rm ks-squid-cache
    fi
}

case "${1:-}" in
    start) start ;;
    stop) stop ;;
    clean) clean ;;
    *) echo "Usage: $0 start|stop|clean" >&2; exit 1 ;;
esac
