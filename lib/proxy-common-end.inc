# If nothing was written to RESULT, it worked
if [[ ! -f $ANA_INSTALL_PATH/root/RESULT ]]; then
    echo 'SUCCESS' > $ANA_INSTALL_PATH/root/RESULT
fi

