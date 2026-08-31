local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
__pout("buffers=" .. #vim.fn.getbufinfo({buflisted = 1}))
__pout("tabs=" .. vim.fn.tabpagenr("$"))
__pout("windows=" .. vim.fn.winnr("$"))
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
