source /tmp/opencode/harness/lib-common.sh
ex "edit src/main.c" 3.5
press_enter_if_gate
w 2
ex "set foldmethod=indent" 0.8
w 0.5
ex "5,7fold" 1
w 0.5
ex "foldopen" 0.9
w 0.5
ex "wq" 2.5
