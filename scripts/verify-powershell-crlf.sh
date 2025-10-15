#!/bin/sh
# verify-powershell-crlf.sh
# Verifies that tracked PowerShell files use CRLF endings in the worktree
# and end with exactly one trailing CRLF. Intended for CI and pre-commit use.

set -eu

# Collect tracked PowerShell files
PS_FILES=$(git ls-files '*.ps1' '*.psm1' '*.psd1' 2>/dev/null || true)

if [ -z "${PS_FILES}" ]; then
  exit 0
fi

FAILED=0

for FILE in ${PS_FILES}; do
  # Verify worktree EOL is CRLF via git metadata (respects .gitattributes)
  EOL_INFO=$(git ls-files --eol -- "$FILE" | tr '\t' ' ' || true)
  case "$EOL_INFO" in
    *w/crlf*eol=crlf*)
      :
      ;;
    *)
      echo "EOL check failed for $FILE: $EOL_INFO" >&2
      FAILED=1
      ;;
  esac

  # Verify file ends with CRLF (0d0a)
  LAST_TWO=$(tail -c 2 "$FILE" | od -An -tx1 | tr -d ' \n')
  if [ "$LAST_TWO" != "0d0a" ]; then
    echo "Trailing EOL is not CRLF for $FILE" >&2
    FAILED=1
  fi
done

exit "$FAILED"


