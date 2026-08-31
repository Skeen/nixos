source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
txt ":redir >> $HOME_R/lc.txt" 0.4
key Enter 0.6
w 0.6
txt ":LvimVersion" 0.5
key Enter 1.2
w 0.8
txt ":redir END" 0.4
key Enter 0.6
w 1
# reload
txt ":LvimReload" 0.5
key Enter 2
w 1
capture "$HOME_R/../reload.$ENVED.txt"
ex "qa!" 2.5
