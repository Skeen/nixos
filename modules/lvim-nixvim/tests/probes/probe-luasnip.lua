local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local ok, ls = pcall(require, "luasnip")
if ok then
  __pout("luasnip.loaded=" .. tostring(true))
  local cfg_ok = pcall(require, "luasnip.config")
  __pout("luasnip.config=" .. tostring(cfg_ok))
  local loaders_ok = pcall(require, "luasnip.loaders.from_vscode")
  __pout("luasnip.vscode_loader=" .. tostring(loaders_ok))
end
local fs = pcall(require, "luasnip.loaders.from_vscode")
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
