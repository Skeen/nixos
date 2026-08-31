source /tmp/opencode/harness/lib-common.sh
w 3
key Escape 0.5
sk Space; w 2.0
capture "$HOME_R/../s1.$ENVED.txt"
sk s; w 2.0
capture "$HOME_R/../s2.$ENVED.txt"
sk t; w 3.5
capture "$HOME_R/../s3.$ENVED.txt"
key Escape; key Escape
ex "qa!" 2.5
