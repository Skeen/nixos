source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
key C-q 1.6
capture "$HOME_R/../qf.$ENVED.txt"
key C-q 1.4
capture "$HOME_R/../qf2.$ENVED.txt"
ex "qa!" 2.5
