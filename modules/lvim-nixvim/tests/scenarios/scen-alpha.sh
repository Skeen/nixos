source /tmp/opencode/harness/lib-common.sh
w 5
sk Space; w 1.0
sk c; w 2.5
capture "$HOME_R/../alpha.$ENVED.txt"
key Escape 0.5
ex "q!" 2.5
