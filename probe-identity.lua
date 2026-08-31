print("appname=" .. (vim.env.NVIM_APPNAME or ""))
print("progpath_has_lvim=" .. tostring(vim.v.progpath:match("lvim") ~= nil))
print("version=" .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch)
print("scheme=" .. tostring(vim.g.colors_name))
-- actual colorscheme hl of Normal differs; just verify scheme loaded w/o error
print("synmaxcol=" .. vim.o.synmaxcol)
