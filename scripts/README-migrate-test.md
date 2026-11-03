# Test Migration Script

## Overview

The `migrate-test.sh` script is designed to help migrate test files from the root directory to the `tests/` subdirectory in the kickstart-tests repository. This script maintains the improved test organization while preserving backward compatibility.

## Location

```
scripts/migrate-test.sh
```

## Features

- **Automatic Dependency Detection**: Finds and migrates library files referenced by `@KSINCLUDE@` directives
- **Batch Migration**: Can migrate multiple tests in a single command
- **Safety Checks**: Verifies files exist before migration and prompts for confirmation on overwrites
- **Detailed Feedback**: Provides colored output showing migration progress and results
- **List Functionality**: Can list all available tests in the root directory

## Usage

### Basic Commands

```bash
# Show help
scripts/migrate-test.sh --help

# List all tests available for migration
scripts/migrate-test.sh --list-root

# Migrate a single test
scripts/migrate-test.sh hostname

# Migrate multiple tests
scripts/migrate-test.sh hostname lang firewall

# Migrate tests with dependencies
scripts/migrate-test.sh keyboard  # Also migrates post-lib-keyboard.sh and post-nochroot-lib-keyboard.sh
```

### What Gets Migrated

For each test, the script moves:
1. `testname.sh` - The test shell script
2. `testname.ks.in` - The kickstart template file
3. Any dependency files referenced by `@KSINCLUDE@` directives in the kickstart template

### Example Migration

```bash
$ scripts/migrate-test.sh hostname
[INFO] Starting test migration process...
[INFO] Root directory: /home/user/kickstart-tests
[INFO] Tests directory: /home/user/kickstart-tests/tests

----------------------------------------
[INFO] Migrating test: hostname
[INFO] Found dependencies for hostname:
    - post-lib-network.sh
[SUCCESS] Moved shell script: hostname.sh
[SUCCESS] Moved kickstart template: hostname.ks.in
[SUCCESS] Moved dependency: post-lib-network.sh
[SUCCESS] Successfully migrated test: hostname

========================================
[INFO] Migration Summary:
  Total tests processed: 1
  Successful migrations: 1
  Failed migrations: 0

[SUCCESS] Migration completed! You can now run tests using:
  ./containers/runner/launch [test_name]

[INFO] The test framework will automatically find tests in both
[INFO] the root directory and tests/ subdirectory for backward compatibility.
```

## Verification

After migration, verify that the test works correctly:

```bash
# Test the migrated test with dry-run
./containers/runner/launch hostname --dry-run

# Run the actual test
./containers/runner/launch -p rhel10 hostname
```

## Backward Compatibility

The test framework has been enhanced to search for tests in both:
1. Root directory (legacy location)
2. `tests/` subdirectory (new organized location)

This means:
- Existing tests continue to work from the root directory
- Migrated tests work from the tests/ directory
- The `./containers/runner/launch` command automatically finds tests in either location

## Safety Features

- **Existence Verification**: Checks that both `.sh` and `.ks.in` files exist before migration
- **Overwrite Protection**: Prompts before overwriting existing files in the destination
- **Dependency Tracking**: Automatically finds and moves library dependencies
- **Error Handling**: Provides clear error messages for missing files or failed operations

## Script Architecture

The script consists of several key functions:
- `list_root_tests()`: Lists all available tests for migration
- `migrate_test()`: Migrates a single test with all dependencies
- `find_dependencies()`: Parses kickstart files for `@KSINCLUDE@` references
- `test_exists_in_root()` / `test_exists_in_tests()`: Validation functions

## Future Enhancements

Potential improvements could include:
- Reverse migration (from tests/ back to root)
- Batch migration with pattern matching
- Integration with git for automatic commit of migrations
- Validation of migrated tests before completion
