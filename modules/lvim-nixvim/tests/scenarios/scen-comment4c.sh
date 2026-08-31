source /tmp/opencode/harness/lib-common.sh
capture "$HOME_R/../cap0.$ENVED.txt"
ex "edit src/lib.py" 3
capture "$HOME_R/../cap1.$ENVED.txt"
clear_prompt
capture "$HOME_R/../cap2.$ENVED.txt"
w 2
sk "g"; w 0.3; sk "c"; w 0.3; sk "c"; w 1.4
capture "$HOME_R/../cap3.$ENVED.txt"
key j 0.6
sk "g"; w 0.3; sk "c"; w 0.3; sk "c"; w 1.4
capture "$HOME_R/../cap4.$ENVED.txt"
key Escape
ex "wq" 3
