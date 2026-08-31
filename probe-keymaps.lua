local out = {}
local function ktrans(x)
  local ok, r = pcall(vim.fn.keytrans, x)
  return ok and r or tostring(x)
end
for _, mode in ipairs {"n","i","v","x","c","t","o"} do
  local okmaps, maps = pcall(vim.api.nvim_get_keymap, mode)
  if okmaps then
    for _, m in ipairs(maps) do
      local lhs = ktrans(m.lhs)
      if not (m.lhs == "\t" and (m.rhs == "\t" or (m.rhs or "") == "<Tab>")) then
        local rhs = m.rhs and ktrans(m.rhs) or (type(m.callback) == "function" and "<lua>" or "nil")
        local desc = m.desc and (" desc=" .. m.desc) or ""
        table.insert(out, string.format("%s|%s|%s%s", mode, lhs, rhs, desc))
      end
    end
  end
end
table.sort(out)
for _, l in ipairs(out) do print("MAP " .. l) end
