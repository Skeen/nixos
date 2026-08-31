source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
ex "vsplit src/main.c" 3
press_enter_if_gate
w 2
key C-w 0.4
sk l; w 0.8
key C-w 0.4
sk h; w 0.8
ex "only" 1.5
ex "wqa" 2.5
