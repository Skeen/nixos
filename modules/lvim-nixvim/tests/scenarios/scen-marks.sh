source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3.5
press_enter_if_gate
w 2
sk "ma"; w 0.3
key G 0.4
sk "`a"; w 0.4
key_escape=1
ex "normal! gg" 0.5
sk "'a"; w 0.4
key Escape 0.3
ex "wq" 2.5
