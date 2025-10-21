#!/bin/bash

Describe 'Heredoc test'
  It 'should preserve heredoc content'
cat > file.txt << 'EOF'
This is a heredoc
It should be preserved as-is
  Even with indentation
End
EOF
    echo "after heredoc"
  End
End
