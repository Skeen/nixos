source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
key Escape 0.4
sk Space; w 2.0
sk s; w 2.0
sk t; w 3.5
capture "$HOME_R/../mid.$ENVED.txt"
txt "greet" 0.8
key Enter 2.2
capture "$HOME_R/../grep.$ENVED.txt"
key Escape 0.7; key Escape 0.4
sk Space; w 2.0
sk b; w 1.2
sk b; w 2
capture "$HOME_R/../bufsel.$ENVED.txt"
key Escape 0.6
ex "qa!" 2.5
