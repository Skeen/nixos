local ok, wk = pcall(require, "which-key")
local out = {}
if ok then
  local okplug, wplugin = pcall(require, "which-key.plugins")
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if m.desc and (m.desc:match("%S") == nil) then end
  end
end
-- just dump all n-mode maps with desc having leader semantics
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  if m.desc and m.desc ~= "" then
    if m.lhs:byte(1) == 32 then
      table.insert(out, "LEADER " .. vim.fn.keytrans(m.lhs) .. " -> " .. tostring(m.desc))
    end
  end
end
table.sort(out)
for _, l in ipairs(out) do print(l) end
print("LEADER total=" .. #out)
