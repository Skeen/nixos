source /tmp/opencode/harness/lib-common.sh
ex "edit notes.md" 3.5
press_enter_if_gate
w 2
ex "split" 1.2
ex "wincmd w" 0.6
ex "edit src/main.c" 2.5
press_enter_if_gate
w 1.5
key C-w 0.3; key h 0.6
ex "close" 0.8
ex "wqa" 2.5
