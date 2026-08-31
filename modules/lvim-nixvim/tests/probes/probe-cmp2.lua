local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local ok, cmp = pcall(require, "cmp")
if ok and type(cmp.get_config) == "function" then
  local c = cmp.get_config()
  local srcs = {}
  for _, s in ipairs(c.sources or {}) do srcs[#srcs+1] = s.name end
  __pout("sources=" .. table.concat(srcs, ","))
end
local ok2, c = pcall(require, "cmp")
if ok2 and c.get_config and c.get_config().confirm_opts then
  __pout("confirm=" .. tostring(c.get_config().confirm_opts.behavior))
end
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
