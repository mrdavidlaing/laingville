#!/bin/bash

Describe "Script heredoc test"
It "should preserve shell script in heredocs"
# Create fake script
cat > "${fake_bin}/test" << 'EOF'
#!/bin/bash
echo "fake command for testing"
exit 0
EOF
chmod +x "${fake_bin}/test"

When call test_command
The status should be success
End
End
