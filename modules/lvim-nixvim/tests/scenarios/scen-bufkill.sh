source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
ex "edit notes.md" 3
press_enter_if_gate
w 1.5
ex "edit plain.txt" 3
press_enter_if_gate
w 1.5
key <Space> 1.2
sk c; w 1.5
capture "$HOME_R/../buf.$ENVED.txt"
ex "qa!" 2.5
