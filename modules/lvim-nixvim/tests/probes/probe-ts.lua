local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
-- capability matrix: treesitter highlighting available per language.
-- Both editors deliver identical capability; only the delivery mechanism
-- differs (LV downloads parsers at first use, nixvim ships them in the nix
-- store at build time). Here we assert the OBSERVABLE capability.
for _, ft in ipairs({"python","lua","c","markdown","json","yaml","nix","bash","javascript","typescript","rust","make","css","html"}) do
  local exists = #vim.api.nvim_get_runtime_file("parser/" .. ft .. ".so", false) > 0
  local okp = exists
  if not okp then
    local oki = pcall(vim.treesitter.language.add, ft)
    okp = oki
  end
  __pout("parser_" .. ft .. "=" .. (okp and "capable" or "INCAPABLE"))
end
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
