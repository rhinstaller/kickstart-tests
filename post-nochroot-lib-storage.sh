SYSROOT=/mnt/sysroot

# Copy results and logs to /boot so they can be extracted from a partition
# that guestfish can read (e.g. when root is on Stratis or another filesystem
# not supported by libguestfs).
function copy_results_to_boot() {
    RESULTS_DIR=$SYSROOT/boot/kstest-results

    mkdir -p $RESULTS_DIR
    cp $SYSROOT/root/RESULT $RESULTS_DIR/RESULT 2>/dev/null
    cp $SYSROOT/root/original-ks.cfg $RESULTS_DIR/ 2>/dev/null
    cp $SYSROOT/root/anaconda-ks.cfg $RESULTS_DIR/ 2>/dev/null
    mkdir -p $RESULTS_DIR/anaconda
    cp /tmp/*.log $RESULTS_DIR/anaconda/ 2>/dev/null
    cp /tmp/syslog $RESULTS_DIR/anaconda/ 2>/dev/null
}
