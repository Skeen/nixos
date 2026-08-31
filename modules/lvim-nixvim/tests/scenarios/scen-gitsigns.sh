source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2.5
# modify a line to create a hunk, then stage via gitsigns
sk G; w 0.4
sk yy; w 0.3
sk p; w 0.4
txt "CHANGED" 0.5
key Escape 0.5
ex "w" 2.5
press_enter_if_gate
w 1.5
key <Space> 1.2
key g 0.8
sk s; w 2
capture "$HOME_R/../gs.$ENVED.txt"
ex "wq" 2.5
