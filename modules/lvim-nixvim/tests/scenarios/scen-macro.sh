source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3
press_enter_if_gate
w 1
sk q; sk a; w 0.4
key I 0.4
txt "# " 0.5
key Escape 0.5
sk j; w 0.3
sk q; w 0.5
sk "3"; sk @; sk a; w 1.2
ex "wq" 3
