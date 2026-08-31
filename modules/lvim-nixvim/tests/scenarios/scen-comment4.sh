source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3
clear_prompt
w 2
sk "g" "c" "c"
w 0.8
key j 0.5
sk "g" "c" "c"
w 0.8
key Escape
ex "wq" 2.5
