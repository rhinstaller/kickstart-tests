# classify-sync-with-repo

## Description
Synchronize the classify-failures script with the current state of repository issues by moving closed issues from ISSUES list to CLOSED_ISSUES list and open issues from CLOSED_ISSUES list to ISSUES list.

## Usage
```
classify-sync-with-repo
```

## What it does
1. Reads the current classify-failures script to understand the ISSUES and CLOSED_ISSUES lists
2. Checks the current repository issues to identify which are open vs closed
3. Compares the script lists with the actual repository state
4. Creates a patch to move issues between ISSUES and CLOSED_ISSUES lists as needed

The script ensures that:
- ISSUES list contains only open repository issues
- CLOSED_ISSUES list contains only closed repository issues

This maintains the accuracy of the classify-failures script for test failure classification.