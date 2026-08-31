source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
key / 0.4
txt "def greet" 0.6
key Enter 1
sk n; w 0.5
key Escape 0.3
ex "vimgrep /pass/j **/*.py" 3
press_enter_if_gate
w 1.5
ex "copen" 2
capture "$HOME_R/../qflist.$ENVED.txt"
ex "cclose" 1.5
ex "wq!" 2.5
