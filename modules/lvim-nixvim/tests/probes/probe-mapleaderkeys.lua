local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
-- which-key registered mappings snapshot
local ok, wk = pcall(require, "which-key")
if ok and wk and type(wk.registrations) == "table" then
  local n = 0
  for _ in pairs(wk.registrations) do n = n + 1 end
  __pout("wk.registrations=" .. n)
  for key, item in pairs(wk.registrations) do
    local mode = type(item) == "table" and (item.mode or "n") or "n"
    local desc = type(item) == "table" and (item.desc or "") or ""
    __pout("WK " .. key .. " (" .. tostring(mode) .. ") -> " .. tostring(desc))
  end
end
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
