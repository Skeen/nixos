source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3
clear_prompt
w 2
sk "g"; w 0.3; sk "c"; w 0.3; sk "c"; w 1.2
key j 0.6
sk "g"; w 0.3; sk "c"; w 0.3; sk "c"; w 1.2
key Escape
ex "wq" 3
