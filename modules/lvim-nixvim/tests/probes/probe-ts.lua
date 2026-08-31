local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
for _, ft in ipairs({"python","lua","c","markdown","json","yaml","nix","bash","javascript","typescript","rust","make","css","html"}) do
  local ok = pcall(vim.treesitter.get_parser, 0, ft)
  __pout("ts_" .. ft .. "=" .. tostring(ok))
end

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
