local out = {}
for _, g in ipairs({"GitSignsAdd","GitSignsChange","GitSignsDelete","WhichKey","WhichKeyGroup","WhichKeySeparator","WhichKeyDesc","NormalFloat","FloatBorder","DiagnosticSignError","DiagnosticSignWarn","DiagnosticSignHint","DiagnosticSignInfo","TelescopeBorder","TelescopePromptBorder","TelescopeNormal","TelescopePromptPrefix","TelescopeSelection","NvimTreeNormal","NvimTreeFolderName","NvimTreeOpenedFolderName","NvimTreeEmptyFolderName","NvimTreeExecFile","NvimTreeImageFile","NvimTreeSpecialFile","LspInfoBorder","CmpItemAbbr","CmpItemKind","CmpItemMenu","IBlanklineIndent","IBlanklineContextStart","IndentBlanklineChar","LualineNormalA","LualineNormalB","LualineNormalC","BufferLineFill","BufferLineBackground"}) do
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, {name = g, link = false})
  if ok and hl and next(hl) ~= nil then
    table.insert(out, g .. "=SET")
  else
    local okl, linked = pcall(vim.api.nvim_get_hl, 0, {name = g, link = true})
    table.insert(out, g .. "=" .. (okl and linked and "LINKED" or "NONE"))
  end
end
table.sort(out)
for _, l in ipairs(out) do print(l) end
