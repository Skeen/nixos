source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3
press_enter_if_gate
w 2
sk Space; w 1.2
capture "$HOME_R/../wk.$ENVED.txt"
sk b; w 1.0
capture "$HOME_R/../wkb.$ENVED.txt"
key Escape 0.6
key Escape 0.3
key g 1.0
capture "$HOME_R/../wk-cond.$ENVED.txt"
key Escape 0.5
key Escape 0.3
ex "q!" 2
