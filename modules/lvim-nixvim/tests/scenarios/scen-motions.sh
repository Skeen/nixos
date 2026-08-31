source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3
press_enter_if_gate
w 1
key G 0.4
key g 0.2; key g 0.4
sk d; sk d; w 0.6
sk y; sk y; sk p; w 0.6
sk "3"; sk G; w 0.4
sk d; sk d; w 0.6
sk u; w 0.6
key C-r 0.6
ex "wq" 3
