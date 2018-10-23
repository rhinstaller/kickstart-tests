# Report success if no errors have been reported to /root/RESULT
if [ ! -f /root/RESULT ]
then
    # no result file (no errors) -> success
    echo SUCCESS > /root/RESULT
else
    # some errors happened
    exit 1
fi
