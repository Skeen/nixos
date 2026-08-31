source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
ex "Telescope" 3.5
w 2
ex "lua local c = require('telescope.config').values; local f=io.open('teleout.txt','w'); f:write('prefix='..c.prompt_prefix); f:write('\nsort='..c.sorting_strategy); f:write('\nlayout='..c.layout_strategy); f:write('\nwinblend='..tostring(c.winblend)); f:write('\nvimgrep='..table.concat(c.vimgrep_arguments or {}, ' ')); f:close()" 1
w 1.2
ex "qa!" 2.5
