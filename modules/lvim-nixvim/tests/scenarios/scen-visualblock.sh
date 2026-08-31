source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
key C-v 0.5
sk j; sk j; w 0.4
sk I; w 0.4
txt "X" 0.5
key Escape 0.7
ex "wq" 2.5
