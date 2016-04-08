# testpkg-http-core from the addon repo
grep -q 'testpkg-http-core.*\.rpm' /tmp/proxy.log
if [[ $? -ne 0 ]]; then
    echo 'addon repo package requests were not proxied' >> $ANA_INSTALL_PATH/root/RESULT
fi

# Check that the addon repo file was installed
if [[ ! -f $ANA_INSTALL_PATH/etc/yum.repos.d/kstest-http.repo ]]; then
    echo 'kstest-http.repo does not exist' >> $ANA_INSTALL_PATH/root/RESULT
fi

# Check that the proxy configuration was written to the repo file
grep -q 'PROXY_TEXT' $ANA_INSTALL_PATH/etc/yum.repos.d/kstest-http.repo
if [[ $? -ne 0 ]]; then
    echo 'kstest-http.repo does not contain proxy information' >> $ANA_INSTALL_PATH/root/RESULT
fi

# Check that the installed repo file is usable
# dnf exits with 0 even if something goes wrong, so do a repoquery and look for
# the package in the output
chroot $ANA_INSTALL_PATH \
    dnf --disablerepo=\* --enablerepo=kstest-http --quiet repoquery testpkg-http-core 2>/dev/null | \
    grep -q 'testpkg-http-core'
if [[ $? -ne 0 ]]; then
    echo 'unable to query kstest-http repo' >> $ANA_INSTALL_PATH/root/RESULT
fi

# Finally, check that the repoquery used the proxy
tail -1 /tmp/proxy.log | grep -q repodata
if [[ $? -ne 0 ]]; then
    echo 'repoquery on installed system was not proxied' >> $ANA_INSTALL_PATH/root/RESULT
fi

