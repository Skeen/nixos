local out = {}
for name, c in pairs(vim.api.nvim_get_commands({})) do
  table.insert(out, string.format("CMD %s nargs=%s bang=%s", name, tostring(c.nargs), tostring(c.bang)))
end
for name, _ in pairs(vim.fn.getcompletion("", "function") and {} or {}) do end
table.sort(out)
for _, l in ipairs(out) do print(l) end
