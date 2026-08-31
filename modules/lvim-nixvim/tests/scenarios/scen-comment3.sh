source /tmp/opencode/harness/lib-common.sh
ex "edit notes.md" 3
clear_prompt
w 2
sk "gcc"
w 0.8
key j 0.5
sk "g" "c" "c"
w 0.8
key Escape
ex "wq" 2.5
