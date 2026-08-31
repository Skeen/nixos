for _, ft in ipairs {"python","lua","c","make","markdown","json","yaml","nix","sh","javascript","typescript","rust","css","html"} do
  vim.cmd("filetype detect")
  vim.bo_plus = nil
end
local fts = {}
for _, ft in ipairs {"python","lua","c","make","markdown","json","yaml","nix","sh","javascript","typescript","rust"} do
  vim.cmd("set filetype=" .. ft)
  table.insert(fts, string.format("ft=%s sw=%d ts=%d et=%s cin=%s commentstring=%s",
    vim.bo.filetype, vim.bo.shiftwidth, vim.bo.tabstop, tostring(vim.bo.expandtab), tostring(vim.bo.cindent), vim.bo.commentstring))
end
-- run in fresh buffers so options don't bleed
for _, ft in ipairs {"python","lua","c","make","markdown","json","yaml","nix","sh","javascript","typescript","rust"} do
  local buf = vim.api.nvim_create_buf(false, true)
  local cur = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_option(buf, "filetype", ft)
  table.insert(fts, string.format("BUF ft=%s sw=%d ts=%d et=%s commentstring=%s", vim.bo[buf].filetype, vim.bo[buf].shiftwidth, vim.bo[buf].tabstop, tostring(vim.bo[buf].expandtab), vim.bo[buf].commentstring))
  vim.api.nvim_set_current_buf(cur)
  vim.api.nvim_buf_delete(buf, {force = true})
end
table.sort(fts)
for _, l in ipairs(fts) do print(l) end
