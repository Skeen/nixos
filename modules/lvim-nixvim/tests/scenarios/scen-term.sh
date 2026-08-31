source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
key 'C-\' 1.6
capture "$HOME_R/../term.$ENVED.txt"
key 'C-\' 1.2
capture "$HOME_R/../term2.$ENVED.txt"
ex "qa!" 2.5
