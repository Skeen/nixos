local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local core = {"w","q","wq","qa","wa","edit","vsplit","split","new","only","close","buffer","bnext","bprev","bdelete","buffers","WhichKey","QuickFixToggle","Gitsigns","NvimTreeToggle","ToggleTerm","LvimVersion","LvimReload","LvimInfo"}
for _, c in ipairs(core) do
  __pout("CORE " .. c .. "=" .. tostring(vim.fn.exists(":" .. c) == 2))
end
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
