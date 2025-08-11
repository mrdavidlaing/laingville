Describe "polyfill.functions.bash"
Before "cd '$SHELLSPEC_PROJECT_ROOT'"
Before "source ./lib/shared.functions.bash"
Before "source ./lib/polyfill.functions.bash"

setup_test_files() {
  # Create a temporary directory for test files
  TEST_DIR=$(mktemp -d)
  TEST_FILE="$TEST_DIR/test_file.txt"
  TEST_SYMLINK="$TEST_DIR/test_symlink"

  # Create test files
  echo "test content" > "$TEST_FILE"
  ln -s "$TEST_FILE" "$TEST_SYMLINK" 2> /dev/null || true
}

cleanup_test_files() {
  # Clean up test files
  if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

Describe "detect_os function"
It "returns macos on Darwin"
# Mock uname command to return Darwin
uname() { echo "Darwin"; }

When call detect_os
The status should be success
The output should equal "macos"
End

It "returns linux on Linux"
# Mock uname command to return Linux
uname() { echo "Linux"; }
# Mock absence of pacman command
command() {
  case "$2" in
    pacman) return 1 ;;
    *) builtin command "$@" ;;
  esac
}

When call detect_os
The status should be success
The output should equal "linux"
End

It "returns unknown on unsupported OS"
# Mock uname command to return unsupported OS
uname() { echo "SomeWeirdOS"; }
# Mock absence of pacman command
command() {
  case "$2" in
    pacman) return 1 ;;
    *) builtin command "$@" ;;
  esac
}

When call detect_os
The status should be success
The output should equal "unknown"
End

End

Describe "canonicalize_path function"
It "fails with empty input"
When call canonicalize_path ""

The status should be failure
End

It "works with existing file"
setup_test_files

When call canonicalize_path "$TEST_FILE"

The status should be success
The output should not be blank
The output should start with "/"

cleanup_test_files
End

It "works with existing directory"
setup_test_files

When call canonicalize_path "$TEST_DIR"

The status should be success
The output should not be blank
The output should start with "/"

cleanup_test_files
End

It "works with non-existing file"
setup_test_files
non_existing="$TEST_DIR/non_existing_file.txt"

When call canonicalize_path "$non_existing"

The status should be success
The output should not be blank
The output should start with "/"

cleanup_test_files
End
End

Describe "get_file_size function"
It "fails with empty input"
When call get_file_size ""

The status should be failure
The output should equal "0"
End

It "fails with non-existing file"
When call get_file_size "/non/existing/file"

The status should be failure
The output should equal "0"
End

It "returns correct size for existing file"
setup_test_files

When call get_file_size "$TEST_FILE"

The status should be success
# The test file contains "test content\n" which should be > 0 and < 100 bytes
The output should not equal "0"

cleanup_test_files
End
End

Describe "read_symlink function"
It "fails with empty input"
When call read_symlink ""

The status should be failure
End

It "fails with non-symlink file"
setup_test_files

When call read_symlink "$TEST_FILE"

The status should be failure

cleanup_test_files
End

It "works with symlink"
setup_test_files

if [ -L "$TEST_SYMLINK" ]; then
  When call read_symlink "$TEST_SYMLINK"

  The status should be success
  The output should not be blank
else
  Skip "Symlink creation failed"
fi

cleanup_test_files
End
End

Describe "command_supports_flag function"
It "fails with empty input - empty command and flag"
When call command_supports_flag "" ""
The status should be failure
End

It "fails with empty input - command with empty flag"
When call command_supports_flag "ls" ""
The status should be failure
End

It "fails with empty input - empty command with flag"
When call command_supports_flag "" "-l"
The status should be failure
End

It "works with common commands"
# Test with ls command and -l flag (should exist on all Unix systems)
When call command_supports_flag "ls" "-l"

# This might return 0 or 1 depending on platform, but shouldn't crash
# We just verify it doesn't crash with weird exit codes
The status should not equal 127 # command not found
End
End

Describe "get_hostname function"
It "returns a non-empty hostname"
When call get_hostname

The status should be success
The output should not be blank
End

It "returns a valid hostname format"
When call get_hostname

The status should be success
# Check that hostname does not contain invalid characters
The output should not match pattern "[^a-zA-Z0-9.-]"
End

It "always returns some hostname value"
# This mainly tests that the function doesn't crash
When call get_hostname

The status should be success
# Should return either a real hostname or "unknown"
The output should not be blank
End
End

Describe "resolve_path function"
It "fails with empty input"
When call resolve_path ""

The status should be failure
End

It "works with existing file"
setup_test_files

When call resolve_path "$TEST_FILE"

The status should be success
The output should not be blank
The output should start with "/"

cleanup_test_files
End

It "works with relative path"
setup_test_files

# Change to test directory and use relative path
cd "$TEST_DIR"
relative_file="$(basename "$TEST_FILE")"

When call resolve_path "$relative_file"

The status should be success
The output should not be blank
The output should start with "/"

cleanup_test_files
End

It "handles path with dots"
setup_test_files

dotted_path="$TEST_DIR/../$(basename "$TEST_DIR")/$(basename "$TEST_FILE")"

When call resolve_path "$dotted_path"

The status should be success
The output should not be blank
The output should start with "/"

cleanup_test_files
End
End

Describe "integration test"
It "polyfill functions work on current platform"
setup_test_files

# Test that we can detect the OS
When call detect_os
The status should be success
The output should not be blank
os_type="$SHELLSPEC_STDOUT"

# Test file operations work
file_size=$(get_file_size "$TEST_FILE")
[ "$file_size" -gt 0 ]

# Test path resolution works
resolved_path=$(resolve_path "$TEST_FILE")
[ -n "$resolved_path" ]
[[ "$resolved_path" =~ ^/ ]]

# Test canonicalization works
canonical_path=$(canonicalize_path "$TEST_FILE")
[ -n "$canonical_path" ]
[[ "$canonical_path" =~ ^/ ]]

cleanup_test_files
End
End
End
