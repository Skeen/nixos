for _, ft in ipairs({"python","lua","c","markdown","json","yaml","nix","bash","javascript","typescript","rust","make","css","html"}) do
  local has_parser = pcall(vim.treesitter.get_parser, 0, ft)
  print("ts_" .. ft .. "=" .. tostring(has_parser))
end
print("ts_active=" .. tostring(vim.treesitter.highlighter.active ~= nil))
