source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
sk yy; w 0.4
sk p; sk p; w 0.6
sk dd; w 0.4
sk "1"; sk P; w 0.6
key Escape 0.4
ex "wq" 2.5
