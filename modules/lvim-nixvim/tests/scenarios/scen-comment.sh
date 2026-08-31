source /tmp/opencode/harness/lib-common.sh
ex "edit src/main.c" 2.5
clear_prompt
w 1
sk "gcc"
w 0.8
key j 0.4
sk "g" "c" "c"
w 0.8
sk "g" "d" "d"
w 0.6
key Escape
ex "wq" 2.5
