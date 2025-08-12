#!/bin/bash
#
# migrate-test.sh - Migrate tests from root directory to tests/ subdirectory
#
# This script moves test files (.sh and .ks.in) from the root directory to the tests/
# subdirectory, along with any library files they depend on via @KSINCLUDE@ directives.
#
# Usage: migrate-test.sh [test1] [test2] [test3] ...
#
# Examples:
#   migrate-test.sh hostname
#   migrate-test.sh hostname lang firewall
#

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$ROOT_DIR/tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [test1] [test2] [test3] ...

Migrate test files from root directory to tests/ subdirectory.

This script will:
  1. Check if test files (.sh and .ks.in) exist in the root directory
  2. Find any library dependencies via @KSINCLUDE@ directives
  3. Move test files and dependencies to tests/ directory
  4. Provide detailed feedback on the migration process

Examples:
  $0 hostname                    # Migrate single test
  $0 hostname lang firewall      # Migrate multiple tests
  $0 --list-root                 # List all tests in root directory
  $0 --help                      # Show this help

Options:
  --list-root    List all tests currently in root directory
  --help         Show this help message
EOF
}

# List all tests in root directory
list_root_tests() {
    print_info "Tests currently in root directory:"
    
    local count=0
    local sh_files=("$ROOT_DIR"/*.sh)
    
    # Check if any .sh files exist
    if [[ ! -e "${sh_files[0]}" ]]; then
        print_warning "No .sh files found in root directory"
        return 0
    fi
    
    for sh_file in "${sh_files[@]}"; do
        # Skip if not a regular file or not executable
        if [[ ! -f "$sh_file" || ! -x "$sh_file" ]]; then
            continue
        fi
        
        local test_name=$(basename "$sh_file" .sh)
        local ks_file="$ROOT_DIR/${test_name}.ks.in"
        
        if [[ -f "$ks_file" ]]; then
            echo "  - $test_name (has both .sh and .ks.in)"
            count=$((count + 1))
        else
            echo "  - $test_name (only .sh file, missing .ks.in)"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_warning "No complete test pairs (.sh and .ks.in) found in root directory"
    else
        print_info "Found $count complete test(s) that can be migrated"
    fi
}

# Check if a test exists in root directory
test_exists_in_root() {
    local test_name="$1"
    local sh_file="$ROOT_DIR/${test_name}.sh"
    local ks_file="$ROOT_DIR/${test_name}.ks.in"
    
    [[ -f "$sh_file" && -f "$ks_file" ]]
}

# Check if a test already exists in tests directory
test_exists_in_tests() {
    local test_name="$1"
    local sh_file="$TESTS_DIR/${test_name}.sh"
    local ks_file="$TESTS_DIR/${test_name}.ks.in"
    
    [[ -f "$sh_file" || -f "$ks_file" ]]
}

# Find library dependencies in kickstart file
find_dependencies() {
    local ks_file="$1"
    local dependencies=()
    
    if [[ -f "$ks_file" ]]; then
        # Extract files referenced by @KSINCLUDE@
        while IFS= read -r line; do
            if [[ "$line" =~ @KSINCLUDE@[[:space:]]+([^[:space:]]+) ]]; then
                local dep_file="${BASH_REMATCH[1]}"
                if [[ -f "$ROOT_DIR/$dep_file" ]]; then
                    dependencies+=("$dep_file")
                fi
            fi
        done < "$ks_file"
    fi
    
    printf '%s\n' "${dependencies[@]}"
}

# Move a single file with validation
move_file() {
    local src="$1"
    local dst="$2"
    local file_type="$3"
    
    if [[ ! -f "$src" ]]; then
        print_error "Source file does not exist: $src"
        return 1
    fi
    
    if [[ -f "$dst" ]]; then
        print_warning "Destination file already exists: $dst"
        read -p "Overwrite? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping $file_type file: $(basename "$src")"
            return 0
        fi
    fi
    
    mv "$src" "$dst"
    print_success "Moved $file_type: $(basename "$src")"
}

# Migrate a single test
migrate_test() {
    local test_name="$1"
    local sh_file="$ROOT_DIR/${test_name}.sh"
    local ks_file="$ROOT_DIR/${test_name}.ks.in"
    
    print_info "Migrating test: $test_name"
    
    # Check if test exists in root
    if ! test_exists_in_root "$test_name"; then
        print_error "Test '$test_name' not found in root directory (missing .sh or .ks.in file)"
        return 1
    fi
    
    # Check if test already exists in tests directory
    if test_exists_in_tests "$test_name"; then
        print_warning "Test '$test_name' already exists in tests/ directory"
        read -p "Continue with migration? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping test: $test_name"
            return 0
        fi
    fi
    
    # Create tests directory if it doesn't exist
    mkdir -p "$TESTS_DIR"
    
    # Find dependencies
    local dependencies=($(find_dependencies "$ks_file"))
    
    if [[ ${#dependencies[@]} -gt 0 ]]; then
        print_info "Found dependencies for $test_name:"
        for dep in "${dependencies[@]}"; do
            echo "    - $dep"
        done
    fi
    
    # Move test files
    local success=0
    
    if move_file "$sh_file" "$TESTS_DIR/$(basename "$sh_file")" "shell script"; then
        ((success++))
    fi
    
    if move_file "$ks_file" "$TESTS_DIR/$(basename "$ks_file")" "kickstart template"; then
        ((success++))
    fi
    
    # Move dependencies
    for dep in "${dependencies[@]}"; do
        local src_dep="$ROOT_DIR/$dep"
        local dst_dep="$TESTS_DIR/$dep"
        
        if [[ -f "$dst_dep" ]]; then
            print_info "Dependency already exists in tests/: $dep"
        else
            if move_file "$src_dep" "$dst_dep" "dependency"; then
                ((success++))
            fi
        fi
    done
    
    if [[ $success -gt 0 ]]; then
        print_success "Successfully migrated test: $test_name"
        
        # Make sure shell script is executable
        chmod +x "$TESTS_DIR/${test_name}.sh" 2>/dev/null || true
        
        return 0
    else
        print_error "Failed to migrate test: $test_name"
        return 1
    fi
}

# Main script
main() {
    cd "$ROOT_DIR"
    
    # Handle special arguments
    case "${1:-}" in
        --help|-h)
            usage
            exit 0
            ;;
        --list-root)
            list_root_tests
            exit 0
            ;;
        "")
            print_error "No test names provided"
            echo
            usage
            exit 1
            ;;
    esac
    
    print_info "Starting test migration process..."
    print_info "Root directory: $ROOT_DIR"
    print_info "Tests directory: $TESTS_DIR"
    echo
    
    local total_tests=$#
    local successful_migrations=0
    local failed_migrations=0
    
    # Process each test
    for test_name in "$@"; do
        echo "----------------------------------------"
        if migrate_test "$test_name"; then
            ((successful_migrations++))
        else
            ((failed_migrations++))
        fi
        echo
    done
    
    # Summary
    echo "========================================"
    print_info "Migration Summary:"
    echo "  Total tests processed: $total_tests"
    echo "  Successful migrations: $successful_migrations"
    echo "  Failed migrations: $failed_migrations"
    
    if [[ $successful_migrations -gt 0 ]]; then
        echo
        print_success "Migration completed! You can now run tests using:"
        echo "  ./containers/runner/launch [test_name]"
        echo
        print_info "The test framework will automatically find tests in both"
        print_info "the root directory and tests/ subdirectory for backward compatibility."
    fi
    
    return $failed_migrations
}

# Run main function with all arguments
main "$@"
