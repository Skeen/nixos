local out = {}
for _, au in ipairs(vim.api.nvim_get_autocmds({})) do
  if not au.desc or not au.desc:match("nixvim") then
    local pat = type(au.pattern) == "table" and table.concat(au.pattern, ",") or tostring(au.pattern)
    table.insert(out, string.format("%s|%s|%s", au.event or "?", pat, au.desc or au.command and "<cmd>" or "<lua>"))
  end
end
table.sort(out)
for _, l in ipairs(out) do print("AU " .. l) end
