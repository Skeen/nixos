source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3.5
press_enter_if_gate
w 2
txt ":lua local f=io.open(vim.env.HOME..'/cmds.txt','w'); local names={'BufferKill','QuickFixToggle','LvimReload','LvimVersion','LvimInfo','Telescope','NvimTreeToggle'}; for _,n in ipairs(names) do f:write(n..'='..tostring(vim.api.nvim_get_commands({})[n]~=nil)..'\n') end; f:close()" 0.6
key Enter 1
w 1
ex "qa!" 2.5
