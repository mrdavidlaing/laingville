#!/bin/bash
# Color test script to verify terminal color capabilities

echo "=== Terminal Color Capability Test ==="
echo ""

echo "Terminal environment:"
echo "TERM: $TERM"
echo "COLORTERM: $COLORTERM"
echo "COLUMNS: $COLUMNS"
echo "LINES: $LINES"
echo ""

echo "Testing 256 colors:"
for i in {0..15}; do
  printf "\033[48;5;${i}m  "
done
echo -e "\033[0m"

for i in {16..231}; do
  printf "\033[48;5;${i}m "
  if [ $(((i - 15) % 36)) -eq 0 ]; then
    echo -e "\033[0m"
  fi
done
echo -e "\033[0m"

for i in {232..255}; do
  printf "\033[48;5;${i}m  "
done
echo -e "\033[0m"
echo ""

echo "Testing true color (24-bit):"
awk 'BEGIN{
    s="/\\/\\/\\/\\/\\"; s=s s s s s s s s s s s s s s s s s s s s s s s;
    for (colnum = 0; colnum<256; colnum++) {
        r = 255-(colnum*255/255);
        g = (colnum*510/255);
        b = (colnum*255/255);
        if (g>255) g = 510-g;
        printf "\033[48;2;%d;%d;%dm", r,g,b;
        printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
        printf "%s\033[0m", substr(s,colnum+1,1);
    }
    printf "\n";
}'
echo ""

echo "Tmux color test (if running in tmux):"
if [ -n "$TMUX" ]; then
  echo "Running inside tmux - checking tmux info:"
  tmux info | grep -E "(default-terminal|terminal-overrides)"
else
  echo "Not running in tmux"
fi
echo ""

echo "=== Test Complete ==="
