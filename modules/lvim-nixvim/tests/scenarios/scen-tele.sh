source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
sk Space; w 1.2
sk f; w 2.5
capture "$HOME_R/../tele.$ENVED.txt"
key Escape 0.6
key Escape 0.3
ex "qa!" 2.5
