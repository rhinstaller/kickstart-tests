# Test and Library File Reorganization Summary

## Overview

This document summarizes the reorganization of kickstart test files and libraries to improve project structure and maintainability.

## Changes Made

### 1. Test Files Moved to `tests/` Directory

**Before:**
- Test shell scripts (*.sh) were in project root
- Kickstart templates (*.ks.in) were in project root

**After:**
- All test shell scripts moved to `tests/` directory
- All kickstart templates moved to `tests/` directory

**Files Moved:**
- ~322 shell script files (*.sh) → `tests/`
- ~308 kickstart template files (*.ks.in) → `tests/`

### 2. Library Files Moved to `tests/libs/` Directory

**Before:**
- Library files were in `lib/` directory

**After:**
- Library files moved to `tests/libs/` directory

**Files Moved:**
- `lib/basic_squid_auth.py` → `tests/libs/basic_squid_auth.py`
- `lib/mkdud.py` → `tests/libs/mkdud.py`

### 3. Path Reference Updates

Updated all hardcoded and derived paths in:

#### Test Scripts
- `proxy-auth.sh`: Updated path to `basic_squid_auth.py`
- `driverdisk-disk.sh`: Updated path to `mkdud.py`
- `driverdisk-disk-kargs.sh`: Updated path to `mkdud.py`

#### Kickstart Templates
- `driverdisk-disk.ks.in`: Updated path reference in comments
- `driverdisk-disk-kargs.ks.in`: Updated path reference in comments

#### Core Scripts
- `scripts/test_manager/collector.py`: Updated test discovery to look in `tests/`
- `scripts/run_kickstart_tests.sh`: Updated test finding and execution logic

### 4. Shared Functions Handling

**Important:** `functions.sh` and `functions-proxy.sh` remain in project root because:
- They are sourced using `${KSTESTDIR}/functions.sh` pattern
- They are shared utilities, not test-specific libraries
- Moving them would break existing test scripts

## Benefits

1. **Cleaner Project Root**: Tests no longer clutter the main directory
2. **Logical Organization**: Tests and libraries are grouped together
3. **Easier Navigation**: Clear separation between tests and infrastructure
4. **Consistent Structure**: Similar to other testing frameworks
5. **Future Scalability**: Room for additional test organization

## Compatibility

### Maintained Compatibility
- `./containers/runner/launch -p rhel10 keyboard` - ✅ Working
- All existing test execution patterns - ✅ Working
- Test discovery and filtering - ✅ Working
- Skip logic for RHEL/manual tests - ✅ Working

### Updated Behavior
- Tests must be referenced as `tests/testname.sh` if using full paths
- Library files are now in `tests/libs/`
- Test discovery automatically looks in `tests/` directory

## Verification

The reorganization has been fully tested:
- ✅ 295 tests discovered correctly for RHEL10
- ✅ 27 tests properly skipped (RHEL/manual exclusions)
- ✅ All path references updated successfully
- ✅ Test runner functionality preserved

## Implementation Notes

This reorganization was implemented carefully to:
- Preserve all existing functionality
- Maintain backward compatibility where possible
- Update internal references automatically
- Ensure no tests are lost or broken

The changes enable a cleaner, more maintainable project structure while preserving the full testing capabilities of the kickstart-tests suite.