source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3
press_enter_if_gate
w 1.5
key i
txt "hello from test" 1
key Escape 0.5
ex "wq" 3
