source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
sk G; w 0.4
sk o; w 0.4
txt "added-line" 0.5
key Escape 0.5
ex "w" 2.5
key Escape 0.4
ex "qa" 2.5
w 1.5
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
sk u; w 1
ex "wq" 2.5
