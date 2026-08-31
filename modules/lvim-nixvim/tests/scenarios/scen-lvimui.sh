source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
ex "LvimVersion" 1.5
capture "$HOME_R/../lv.$ENVED.txt"
ex "q!" 1.5
