#!/bin/gawk -f

BEGIN {
    printf("\n\n\n%-55s | %-15s | %-10s | %s\n", "TEST", "HOST", "RESULT", "EXPLANATION");
    printf("--------------------------------------------------------+-----------------+------------+-------------------------------------------\n");
    FS=":";
    count=0;
    failed=0;
    timed_out=0;
}
/: RESULT:/ { if ($8 == "Test timed out") {
                 result = "TIMED OUT";
                 explanation = "";
                 timed_out++;
             } else if (match($0, "Traceback")) {
                 result = "FAILED";
                 explanation = "Traceback: " $11;
                 failed++;
             } else if (match($0, "traceback")) {
                 result = "FAILED";
                 explanation = "Traceback.";
                 failed++;
             } else if (match($0, "failed on line")) {
                 result = "FAILED";
                 explanation = "error in log: "$12 ":" $13 ":" $14
                 failed++;
             } else if (match($0, "SUCCESS")) {
                 result = $7;
                 explanation = "";
             } else {
                 result = $7;
                 explanation = $8
                 failed++;
             }

             printf("%-55s | %-15s | %-10s | %s\n", $5, $6, result, explanation);
             count++
           }
END {
    printf("\n");
    printf("===================================================================================================================================\n");
    printf("Test suite for kickstart tests summary:\n");
    printf("===================================================================================================================================\n");
    printf("# TOTAL:      %s\n", count);
    printf("# PASS:       %s\n", count - failed - timed_out);
    printf("# FAILED:     %s\n", failed);
    printf("# TIMED OUT:  %s\n", timed_out);
    printf("===================================================================================================================================\n");
    printf("\n\n");
}
