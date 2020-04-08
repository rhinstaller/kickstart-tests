#!/bin/sh

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <directory>"
    exit 1
fi

DIR=$1

echo ${DIR}

sudo semanage fcontext -a -t container_file_t "${DIR}(/.*)?"
sudo restorecon -R ${DIR}
