#!/bin/sh
set -eux

DAILY_ISO_TOKEN=$1
OUTPUT_PATH=${2:-"boot.iso"}

CURL="curl -u token:$(cat $DAILY_ISO_TOKEN) --show-error --fail"
RESPONSE=$($CURL --silent https://api.github.com/repos/rhinstaller/kickstart-tests/actions/artifacts?name=images)
ZIP=$(echo "$RESPONSE" | jq --raw-output '.artifacts[0].archive_download_url')
echo "INFO: Downloading $ZIP ..."
$CURL -L -o images.zip "$ZIP"
unzip images.zip
mv boot.iso ${OUTPUT_PATH}
