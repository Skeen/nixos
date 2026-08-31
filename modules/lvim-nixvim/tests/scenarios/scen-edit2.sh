source /tmp/opencode/harness/lib-common.sh
ex "edit src/main.c" 3.5
press_enter_if_gate
w 2
key g 0.2; key g 0.3; sk w; sk c; sk i; sk w; w 0.5
txt "world()" 0.6
key Escape 0.5
key j 0.4
sk "3"; sk w; w 0.3
sk S; w 0.3
txt '"' 0.4
txt '!important' 0.6
txt '"' 0.4
key Escape 0.5
ex "wq" 2.5
