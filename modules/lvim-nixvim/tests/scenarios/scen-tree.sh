source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
sk Space; w 1.2
sk e; w 2.5
capture "$HOME_R/../tree.$ENVED.txt"
key Escape 0.5
ex "qa!" 2.5
