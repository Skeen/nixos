source /tmp/opencode/harness/lib-common.sh
ex "edit notes.md" 3
press_enter_if_gate
w 1
key V 0.5
key j 0.4
key > 0.6
key Escape 0.4
key g 0.2; key u; sk u; w 0.6
key Escape 0.3
ex "wq" 3
