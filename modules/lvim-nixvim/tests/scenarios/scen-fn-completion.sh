source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
# trigger completion in insert mode after 'greet' word
ex "normal! /def g" 0.5
key Enter 1
key i 0.6
key End 0.3
sk "gr"; w 1.5
capture "$HOME_R/../cmpmenu.$ENVED.txt"
key Escape 0.5
key Escape 0.4
ex "qa!" 2.5
