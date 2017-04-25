# Common functions for use in proxy tests in shell scripts

# Check if installation was proxied correctly
function check_proxy_settings() {
    tmpdir=$1

    # Checks must differ depending on the form of KSTEST_URL
    # HTTP mirror list; we find the hostname with the cuts
    httplist=$(echo "$KSTEST_URL" | grep -e '--mirrorlist="\?http:' | cut -d'=' -f2 | cut -d'/' -f3)
    # HTTPS mirror list; ditto
    httpslist=$(echo "$KSTEST_URL" | grep -e '--mirrorlist="\?https:' | cut -d'=' -f2 | cut -d'/' -f3)
    # HTTP direct mirror; ditto
    httpdir=$(echo "$KSTEST_URL" | grep -e '--url="\?http:' | cut -d'=' -f2 | cut -d'/' -f3)
    # HTTPS direct mirror; we don't need to capture hostname here
    httpsdir=$(echo "$KSTEST_URL" | grep -e '--url="\?https:')

    if [ "$httpslist" ]; then
        # check for CONNECT request to mirrorlist host
        grep -q "CONNECT $httpslist " $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'Connection to TLS mirrorlist server was not proxied' >> $tmpdir/RESULT
        fi
    elif [ "$httplist" ]; then
        # check for GET request to mirrorlist host (we can't really guess
        # any path component, even 'mirrorlist' isn't guaranteed). There's
        # a potential 'false pass' here if the mirror list and repo are on
        # the same server and the repo requests are proxied but mirror
        # requests are not.
        grep -q "$httplist" $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'Mirror list server request was not proxied' >> $tmpdir/RESULT
        fi
    elif [ "$httpsdir" ]; then
        # check for CONNECT request to mirror
        grep -q "CONNECT $httpsdir " $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'Connection to TLS repository server was not proxied' >> $tmpdir/RESULT
        fi
    elif [ "$httpdir" ]; then
        # check for .treeinfo request
        grep -q '\.treeinfo$' $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo '.treeinfo request to repository server was not proxied' >> $tmpdir/RESULT
        fi
    else
        result='Could not parse url line!'
    fi

    # unless direct https URL was used, also check for:
    if [ ! "$httpsdir" ]; then
        # primary.xml from the repodata
        grep -q 'repodata/.*primary.xml' $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'repodata requests were not proxied' >> $tmpdir/RESULT
        fi

        # the kernel package
        grep -q 'kernel-.*\.rpm' $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'package requests were not proxied' >> $tmpdir/RESULT
        fi
    fi
}
