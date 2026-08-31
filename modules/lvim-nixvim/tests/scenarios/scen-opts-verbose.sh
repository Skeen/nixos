source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
txt ":verbose set nu? cursorline? signcolumn?" 0.5
key Enter 1.2
w 1.5
capture "$HOME_R/../vopts.$ENVED.txt"
ex "q!" 2
