source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
key C-q 1.5
capture "$HOME_R/../qf.$ENVED.txt"
key C-q 1.2
ex "qa!" 2.5
