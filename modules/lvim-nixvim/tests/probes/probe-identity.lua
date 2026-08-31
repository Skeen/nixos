local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local mods = {"which-key","gitsigns","lualine","bufferline","nvim-treesitter","nvim-autopairs","Comment"}
for _, m in ipairs(mods) do
  local key = m:gsub("[.-]", "_")
  __pout("loaded_" .. m .. "=" .. tostring(package.loaded[m] ~= nil))
end
local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
