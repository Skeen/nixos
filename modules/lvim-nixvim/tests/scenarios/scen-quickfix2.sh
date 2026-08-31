source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
ex "normal! /class F" 0.5
key Enter 1
ex "normal! dd" 0.5
ex "w" 2
press_enter_if_gate
w 0.8
ex "silent! vimgrep /def g/j src/*.py" 2.5
key Enter 1
w 0.8
ex "copen" 1.8
capture "$HOME_R/../qf.$ENVED.txt"
ex "cclose" 1
ex "wq" 2.5
