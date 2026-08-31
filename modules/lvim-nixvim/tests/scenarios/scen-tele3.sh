source /tmp/opencode/harness/lib-common.sh
w 3
sk Space; w 2.0
sk s; w 2.0
sk t; w 3.5
txt "greet" 0.8
key Enter 2.2
capture "$HOME_R/../grep.$ENVED.txt"
key Escape 0.7; key Escape 0.4
ex "qa!" 2.5
