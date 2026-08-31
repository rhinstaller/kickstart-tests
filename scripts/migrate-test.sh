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
  --list-root               List all tests currently in root directory
  --analyze-dependencies    Analyze shared dependencies for all tests
  --check-test TEST         Show dependency analysis for a specific test
  --help                    Show this help message
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
                # Check if dependency exists in root directory or tests directory
                if [[ -f "$ROOT_DIR/$dep_file" || -f "$TESTS_DIR/$dep_file" ]]; then
                    dependencies+=("$dep_file")
                fi
            fi
        done < "$ks_file"
    fi
    
    printf '%s\n' "${dependencies[@]}"
}

# Find all tests that use a specific dependency file
find_tests_using_dependency() {
    local dep_file="$1"
    local using_tests=()
    
    # Search in root directory .ks.in files
    for ks_file in "$ROOT_DIR"/*.ks.in; do
        if [[ -f "$ks_file" ]] && grep -q "@KSINCLUDE@[[:space:]]*${dep_file}" "$ks_file"; then
            local test_name=$(basename "$ks_file" .ks.in)
            using_tests+=("$test_name")
        fi
    done
    
    # Search in tests directory .ks.in files
    if [[ -d "$TESTS_DIR" ]]; then
        for ks_file in "$TESTS_DIR"/*.ks.in; do
            if [[ -f "$ks_file" ]] && grep -q "@KSINCLUDE@[[:space:]]*${dep_file}" "$ks_file"; then
                local test_name=$(basename "$ks_file" .ks.in)
                using_tests+=("tests/$test_name")
            fi
        done
    fi
    
    printf '%s\n' "${using_tests[@]}"
}

# Check if dependency is shared by multiple tests
check_dependency_usage() {
    local dep_file="$1"
    local current_test="$2"
    local using_tests=($(find_tests_using_dependency "$dep_file"))
    local root_tests=()
    
    # Find tests still in root directory that use this dependency
    for test in "${using_tests[@]}"; do
        if [[ "$test" != "tests/"* && "$test" != "$current_test" ]]; then
            root_tests+=("$test")
        fi
    done
    
    echo "${#root_tests[@]}:${root_tests[*]}"
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

# Handle shared dependency migration
handle_shared_dependency() {
    local dep_file="$1"
    local test_name="$2"
    local usage_info=$(check_dependency_usage "$dep_file" "$test_name")
    local count="${usage_info%%:*}"
    local other_tests="${usage_info#*:}"
    
    if [[ $count -eq 0 ]]; then
        # No other tests use this dependency - safe to move
        return 0
    fi
    
    print_warning "Shared dependency detected: $dep_file"
    print_info "This dependency is used by $count other test(s) in root directory:"
    
    for other_test in $other_tests; do
        echo "    - $other_test"
    done
    
    echo
    echo "Options:"
    echo "  1) Move all tests that use this dependency together"
    echo "  2) Copy dependency (keep original in root for other tests)"
    echo "  3) Skip this dependency (may break migrated test)"
    echo "  4) Cancel migration"
    
    read -p "Choose option [1-4]: " -n 1 -r
    echo
    
    case $REPLY in
        1)
            print_info "Will migrate all tests using $dep_file together..."
            echo "$other_tests"
            return 1  # Signal to migrate all related tests
            ;;
        2)
            print_info "Will copy dependency instead of moving it"
            return 2  # Signal to copy instead of move
            ;;
        3)
            print_warning "Skipping dependency - migrated test may not work properly"
            return 3  # Signal to skip dependency
            ;;
        *)
            print_info "Canceling migration"
            return 4  # Signal to cancel
            ;;
    esac
}

# Copy a file instead of moving it
copy_file() {
    local src="$1"
    local dst="$2"
    local file_type="$3"
    
    if [[ ! -f "$src" ]]; then
        print_error "Source file does not exist: $src"
        return 1
    fi
    
    if [[ -f "$dst" ]]; then
        print_info "Destination file already exists: $dst"
        return 0
    fi
    
    cp "$src" "$dst"
    print_success "Copied $file_type: $(basename "$src")"
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
    local additional_tests=()
    local copy_deps=()
    local skip_deps=()
    
    # Check each dependency for shared usage
    for dep in "${dependencies[@]}"; do
        local result
        if ! result=$(handle_shared_dependency "$dep" "$test_name"); then
            case $? in
                1)  # Move all related tests together
                    local usage_info=$(check_dependency_usage "$dep" "$test_name")
                    local other_tests="${usage_info#*:}"
                    for other_test in $other_tests; do
                        if [[ ! " ${additional_tests[@]} " =~ " ${other_test} " ]]; then
                            additional_tests+=("$other_test")
                        fi
                    done
                    ;;
                2)  # Copy dependency
                    copy_deps+=("$dep")
                    ;;
                3)  # Skip dependency
                    skip_deps+=("$dep")
                    ;;
                4)  # Cancel migration
                    print_info "Migration canceled by user"
                    return 1
                    ;;
            esac
        fi
    done
    
    # If we need to migrate additional tests, do that first
    if [[ ${#additional_tests[@]} -gt 0 ]]; then
        print_info "Migrating additional tests due to shared dependencies:"
        for additional_test in "${additional_tests[@]}"; do
            echo "    - $additional_test"
        done
        echo
        
        read -p "Proceed with migrating ${#additional_tests[@]} additional tests? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Migration canceled - cannot migrate test with shared dependencies"
            return 1
        fi
        
        # Migrate additional tests first (without dependency checks to avoid recursion)
        for additional_test in "${additional_tests[@]}"; do
            print_info "Migrating related test: $additional_test"
            migrate_test_simple "$additional_test"
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
    
    # Handle dependencies based on user choices
    for dep in "${dependencies[@]}"; do
        local src_dep="$ROOT_DIR/$dep"
        local dst_dep="$TESTS_DIR/$dep"
        
        if [[ -f "$dst_dep" ]]; then
            print_info "Dependency already exists in tests/: $dep"
        elif [[ " ${skip_deps[@]} " =~ " ${dep} " ]]; then
            print_warning "Skipping dependency as requested: $dep"
        elif [[ " ${copy_deps[@]} " =~ " ${dep} " ]]; then
            if copy_file "$src_dep" "$dst_dep" "dependency"; then
                ((success++))
            fi
        else
            # Normal move (no conflicts)
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

# Simple migration without dependency conflict checking (for batch operations)
migrate_test_simple() {
    local test_name="$1"
    local sh_file="$ROOT_DIR/${test_name}.sh"
    local ks_file="$ROOT_DIR/${test_name}.ks.in"
    
    if ! test_exists_in_root "$test_name"; then
        print_warning "Test '$test_name' not found in root directory - skipping"
        return 1
    fi
    
    if test_exists_in_tests "$test_name"; then
        print_info "Test '$test_name' already in tests/ directory - skipping"
        return 0
    fi
    
    mkdir -p "$TESTS_DIR"
    
    local success=0
    
    if move_file "$sh_file" "$TESTS_DIR/$(basename "$sh_file")" "shell script"; then
        ((success++))
    fi
    
    if move_file "$ks_file" "$TESTS_DIR/$(basename "$ks_file")" "kickstart template"; then
        ((success++))
    fi
    
    if [[ $success -gt 0 ]]; then
        chmod +x "$TESTS_DIR/${test_name}.sh" 2>/dev/null || true
        return 0
    fi
    
    return 1
}

# Analyze dependencies for a specific test
analyze_test_dependencies() {
    local test_name="$1"
    local ks_file="$ROOT_DIR/${test_name}.ks.in"
    
    if ! test_exists_in_root "$test_name"; then
        print_error "Test '$test_name' not found in root directory"
        return 1
    fi
    
    print_info "Dependency analysis for test: $test_name"
    
    local dependencies=($(find_dependencies "$ks_file"))
    
    if [[ ${#dependencies[@]} -eq 0 ]]; then
        print_success "No dependencies found - safe to migrate"
        return 0
    fi
    
    print_info "Dependencies found:"
    
    local has_conflicts=false
    for dep in "${dependencies[@]}"; do
        local usage_info=$(check_dependency_usage "$dep" "$test_name")
        local count="${usage_info%%:*}"
        local other_tests="${usage_info#*:}"
        
        if [[ $count -eq 0 ]]; then
            echo "    ✅ $dep (no conflicts)"
        else
            echo "    ⚠️  $dep (shared with $count other test(s))"
            for other_test in $other_tests; do
                echo "        - $other_test"
            done
            has_conflicts=true
        fi
    done
    
    echo
    if [[ $has_conflicts == true ]]; then
        print_warning "Migration will require handling shared dependencies"
    else
        print_success "All dependencies are safe to migrate"
    fi
}

# Analyze all shared dependencies in the repository
analyze_all_dependencies() {
    print_info "Analyzing shared dependencies across all tests..."
    
    declare -A dep_usage
    declare -A dep_tests
    
    # Build dependency usage map
    for ks_file in "$ROOT_DIR"/*.ks.in; do
        if [[ -f "$ks_file" ]]; then
            local test_name=$(basename "$ks_file" .ks.in)
            local dependencies=($(find_dependencies "$ks_file"))
            
            for dep in "${dependencies[@]}"; do
                if [[ -z "${dep_usage[$dep]}" ]]; then
                    dep_usage[$dep]=0
                    dep_tests[$dep]=""
                fi
                
                dep_usage[$dep]=$((dep_usage[$dep] + 1))
                if [[ -n "${dep_tests[$dep]}" ]]; then
                    dep_tests[$dep]="${dep_tests[$dep]} $test_name"
                else
                    dep_tests[$dep]="$test_name"
                fi
            done
        fi
    done
    
    # Display results
    local shared_count=0
    local total_deps=0
    
    print_info "Dependency usage summary:"
    
    for dep in "${!dep_usage[@]}"; do
        local count=${dep_usage[$dep]}
        total_deps=$((total_deps + 1))
        
        if [[ $count -gt 1 ]]; then
            shared_count=$((shared_count + 1))
            echo "  ⚠️  $dep: used by $count tests"
            
            # Show first few tests
            local tests_array=(${dep_tests[$dep]})
            local display_tests="${tests_array[@]:0:5}"
            if [[ ${#tests_array[@]} -gt 5 ]]; then
                display_tests="$display_tests ..."
            fi
            echo "      Tests: $display_tests"
        else
            echo "  ✅ $dep: used by 1 test (${dep_tests[$dep]})"
        fi
    done
    
    echo
    print_info "Summary:"
    echo "  Total dependencies: $total_deps"
    echo "  Shared dependencies: $shared_count"
    echo "  Unique dependencies: $((total_deps - shared_count))"
    
    if [[ $shared_count -gt 0 ]]; then
        echo
        print_warning "Consider migrating tests with shared dependencies together"
        print_info "Use --check-test <testname> to analyze specific tests"
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
        --analyze-dependencies)
            analyze_all_dependencies
            exit 0
            ;;
        --check-test)
            if [[ -z "${2:-}" ]]; then
                print_error "Test name required for --check-test option"
                echo
                usage
                exit 1
            fi
            analyze_test_dependencies "$2"
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
