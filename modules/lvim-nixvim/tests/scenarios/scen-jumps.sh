source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
key G 0.4; sk gg; w 0.4; key G 0.4
ex "jumps" 0.6
key Enter 0.8
key C-o 0.6
ex "wq" 2.5
