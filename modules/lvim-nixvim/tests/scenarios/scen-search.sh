source /tmp/opencode/harness/lib-common.sh
ex "edit src/main.c" 3
press_enter_if_gate
w 1
key / 0.4
txt "printf" 0.6
key Enter 1
sk n; w 0.5
sk N; w 0.5
ex "%s/hello/world/g" 1.5
key Enter 1
ex "wq" 3
