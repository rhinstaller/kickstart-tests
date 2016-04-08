# Look for the following as evidence that a proxy was used:
# a mirrorlist server CONNECT request (if mirrorlist https URL) OR:
# a mirrorlist request (if mirrorlist http URL) OR:
# a mirror CONNECT request (if direct https URL) OR:
# a .treeinfo request (if direct http URL)
#
# unless a direct https URL is used, we also check for:
# primary.xml from the repodata
# a package. Let's say kernel, there should definitely have been a kernel
#
# This assumes mirror lists will not return HTTPS URLs. Trying to allow
# for mirror list returning either HTTP or HTTPS would be difficult.

# HTTP mirror list; we find the hostname with the cuts
httplist=$(echo "@KSTEST_URL@" | grep -e '--mirrorlist="\?http:' | cut -d'=' -f2 | cut -d'/' -f3)
# HTTPS mirror list; ditto
httpslist=$(echo "@KSTEST_URL@" | grep -e '--mirrorlist="\?https:' | cut -d'=' -f2 | cut -d'/' -f3)
# HTTP direct mirror; ditto
httpdir=$(echo "@KSTEST_URL@" | grep -e '--url="\?http:' | cut -d'=' -f2 | cut -d'/' -f3)
# HTTPS direct mirror; we don't need to capture hostname here
httpsdir=$(echo "@KSTEST_URL@" | grep -e '--url="\?https:')

if [ "$httpslist" ]; then
    # check for CONNECT request to mirrorlist host
    grep -q "CONNECT $httpslist 443" /tmp/proxy.log
    if [[ $? -ne 0 ]]; then
        result='Connection to TLS mirrorlist server was not proxied'
    else
        result='NEXT'
    fi
elif [ "$httplist" ]; then
    # check for GET request to mirrorlist host (we can't really guess
    # any path component, even 'mirrorlist' isn't guaranteed). There's
    # a potential 'false pass' here if the mirror list and repo are on
    # the same server and the repo requests are proxied but mirror
    # requests are not.
    grep -q "$httplist" /tmp/proxy.log
    if [[ $? -ne 0 ]]; then
        result='Mirror list server request was not proxied'
    else
        result='NEXT'
    fi
elif [ "$httpsdir" ]; then
    # check for CONNECT request to mirror; this is all we can do
    grep -q "CONNECT $httpsdir 443" /tmp/proxy.log
    if [[ $? -ne 0 ]]; then
        result='Connection to TLS repository server was not proxied'
    else
        result='SUCCESS but limited testing for TLS repository server'
    fi
elif [ "$httpdir" ]; then
    # check for GET request for .treeinfo file
    grep -q '\.treeinfo$' /tmp/proxy.log
    if [[ $? -ne 0 ]]; then
        result='.treeinfo request to repository server was not proxied'
    else
        result='NEXT'
    fi
else
    result='Could not parse url line!'
fi

if [ "$result" != 'NEXT' ]; then
    # HTTPS direct (can't check specific requests) or failure:
    # write the result to the installed /root
    echo "$result" > $ANA_INSTALL_PATH/root/RESULT
else
    # HTTP direct, or mirror list (we assume mirror list does not give
    # HTTPS links): we can check for expected GETs
    grep -q 'repodata/.*primary.xml' /tmp/proxy.log
    if [[ $? -ne 0 ]]; then
        echo 'repodata requests were not proxied' >> $ANA_INSTALL_PATH/root/RESULT
    fi

    grep -q 'kernel-.*\.rpm' /tmp/proxy.log
    if [[ $? -ne 0 ]]; then
        echo 'package requests were not proxied' >> $ANA_INSTALL_PATH/root/RESULT
    fi
fi

