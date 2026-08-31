source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2.5
sk jjj; w 0.8
capture "$HOME_R/../status.$ENVED.txt"
ex "qa!" 2.5
