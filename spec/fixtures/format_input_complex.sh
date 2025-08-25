#!/bin/bash

# This is a comment
Describe 'Complex test cases'

# Comment before It
It 'should handle comments and empty lines'

# Inline comment
echo "test"

# Multi-line echo
echo "This is a very long line that might \
span multiple lines"

End

# Comment between blocks
Context 'edge cases'
# Another comment
It 'should handle various ShellSpec keywords'
Example 'this is an example'
echo "example"
End

Specify 'this specifies behavior'
echo "specify"
End
End
End
