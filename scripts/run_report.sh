#!/bin/gawk -f

BEGIN {
    printf("\n\n\n%-55s | %-10s | %s\n", "TEST", "RESULT", "EXPLANATION");
    printf("-------------------------------+------------+--------------------------------------------------------\n");
    FS=":";
    count=0;
    failed=0;
    timed_out=0;
}
/: RESULT:/ { if ($7 == "Test timed out") {
                 result = "TIMED OUT";
                 explanation = "";
                 timed_out++;
             } else if (match($0, "Traceback")) {
                 result = "FAILED";
                 explanation = "Traceback: " $10;
                 failed++;
             } else if (match($0, "traceback")) {
                 result = "FAILED";
                 explanation = "Traceback.";
                 failed++;
             } else if (match($0, "failed on line")) {
                 result = "FAILED";
                 explanation = "error in log: "$11 $12 $13
                 failed++;
             } else if (match($0, "SUCCESS")) {
                 result = $6;
                 explanation = "";
             } else {
                 result = $6;
                 explanation = $7
                 failed++;
             }

             printf("%-55s | %-10s | %s\n", $5, result, explanation);
             count++
           }
END {
    printf("\n");
    printf("=====================================================================================================\n");
    printf("Test suite for kickstart tests summary:\n");
    printf("=====================================================================================================\n");
    printf("# TOTAL:      %s\n", count);
    printf("# PASS:       %s\n", count - failed - timed_out);
    printf("# FAILED:     %s\n", failed);
    printf("# TIMED OUT:  %s\n", timed_out);
    printf("=====================================================================================================\n");
    printf("\n\n");
}
