source /tmp/opencode/harness/lib-common.sh
ex "edit plain.txt" 3
press_enter_if_gate
w 1.5
ex "edit notes.md" 2.5
press_enter_if_gate
w 1.2
key <C-6> 1.2
capture "$HOME_R/../c6.$ENVED.txt"
ex "bnext" 1
ex "bprev" 1
ex "wqa" 2.5
