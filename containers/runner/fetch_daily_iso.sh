#!/bin/sh
set -eux

DAILY_ISO_TOKEN=$1
echo $DAILY_ISO_TOKEN
OUTPUT_PATH=${2:-"boot.iso"}

CURL="curl -u token:$(cat $DAILY_ISO_TOKEN) --show-error --fail"
RESPONSE=$($CURL --silent https://api.github.com/repos/rhinstaller/kickstart-tests/actions/artifacts)
ZIP=$(echo "$RESPONSE" | jq --raw-output '.artifacts | map(select(.name == "images"))[0].archive_download_url')
echo "INFO: Downloading $ZIP ..."
$CURL -L -o images.zip "$ZIP"
# there is no unzip on RHEL 7, so fall back to 7za (p7zip package)
if type unzip >/dev/null 2>&1; then unzip images.zip; else 7za x images.zip; fi
mv boot.iso ${OUTPUT_PATH}
