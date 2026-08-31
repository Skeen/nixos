source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
key o 0.4; txt "tail" 0.4; key Escape 0.4
ex "wq" 2.5
ex "new /tmp/opencode/harness/work-save-$ENVED.txt" 2
w 1
key i; txt "hi"; key Escape 0.5
ex "wq" 2
