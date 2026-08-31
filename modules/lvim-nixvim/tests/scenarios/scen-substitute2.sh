source /tmp/opencode/harness/lib-common.sh
ex "edit notes.md" 3.5
press_enter_if_gate
w 2
ex "%s/item/ITEM/gc" 0.8; key y 0.3; key y 0.3
w 0.6
ex "1,2s/^/>> /" 1
w 0.5
ex "wq" 2.5
