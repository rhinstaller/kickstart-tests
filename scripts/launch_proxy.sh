#!/bin/bash

BASE_DIR="$1"

PORT_START=9000
PORT_END=9100

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Launch squid server with opened port between 9000-9100 and"
    echo "return this port number in format \"port <number>\""
    echo ""
    echo "Usage:"
    echo "./launch_proxy base_dir"
    echo ""
    echo "base_dir - directory where the conf file is and where the logs"
    echo "           and pid file will be placed"
    echo ""
    exit 0
fi

PROXY_BIN=$(which squid 2>/dev/null)

if [ "$?" -ne 0 ]; then
    echo "Program squid must be installed for this kickstart test!" >&2
    exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
    echo "You must specify base directory for the test!" >&2
    exit 1
fi


# Try to run squid on different ports to find usable port
for i in $(shuf -i "${PORT_START}-${PORT_END}" -n 60); do
    sed -e "s;@PROXY_PORT@;$i;g" -e "s;@TMP_DIR@;$BASE_DIR;g" $BASE_DIR/squid.conf > $BASE_DIR/squid_mod.conf

    $PROXY_BIN -f $BASE_DIR/squid_mod.conf
    sleep 2

    if [ -f $BASE_DIR/squid.pid ]; then
        echo "port $i"
        exit 0
    fi
done

echo "Can't find usable port!" >&2
exit 2
