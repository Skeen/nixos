local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local names = {}
for name, _ in pairs(vim.api.nvim_get_commands({})) do
  names[#names+1] = name
end
table.sort(names)
__pout("CMD_COUNT=" .. #names)
for _, n in ipairs(names) do __pout("HAS " .. n) end
local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
