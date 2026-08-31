local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local out = {}
for _, g in ipairs({"Comment","Normal","CursorLine","CursorLineNr","LineNr","SignColumn","StatusLine","VertSplit","WinSeparator","NvimTreeNormal","NvimTreeFolderName","NvimTreeOpenedFolderName","NvimTreeRootFolder","NvimTreeGitDirty","TelescopeBorder","TelescopeNormal","TelescopePromptTitle","TelescopePreviewTitle","TelescopeResultsTitle","TelescopeSelection","TelescopePromptPrefix","DiagnosticSignError","DiagnosticSignWarn","DiagnosticSignHint","DiagnosticSignInfo","GitSignsAdd","GitSignsChange","GitSignsDelete","CmpItemKind-x","CmpItemAbbr","CmpItemMenu","Pmenu","PmenuSel","FloatBorder","NormalFloat","Visual","Search","IncSearch","LualineNormalA","LualineNormalB","LualineNormalC","BufferLineFill","BufferLineBackground","IndentBlanklineChar","WhichKey","WhichKeyGroup","WhichKeySeparator","WhichKeyDesc"}) do
  local view = vim.api.nvim_get_hl(0, {name = g, link = true})
  if view and next(view) ~= nil and view[1] ~= nil and type(view) == "table" and view.link then
    table.insert(out, g .. "=>" .. tostring(view.link))
  else
    table.insert(out, g .. "=>" .. (view and next(view) and "own" or "default"))
  end
end
table.sort(out)
for _, l in ipairs(out) do __pout(l) end

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
