source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
ex "normal! /def g" 0.5
key Enter 1
sk "ci("; w 0.4
txt "name2" 0.5
key Escape 0.5
ex "normal! w" 0.4
sk daw; w 0.5
ex "wq" 2.5
