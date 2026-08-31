local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
-- 15. leader submenu content parity: capture which-key spec
local okwk, wk = pcall(require, "which-key")
if okwk then
  local entities = {}
  pcall(function()
    for _, item in ipairs(wk.get_mappings and {} or {}) do end
  end)
end
-- 16. gitsigns config keys fingerprint
local okg, gs = pcall(require, "gitsigns.config")
if okg and gs and gs.get and type(gs.get) == "function" then
  local c = gs.get()
  local keys = {"signcolumn","current_line_blame","word_diff","attach_to_untracked","watch_gitdir","max_file_length","update_debounce","sign_priority"}
  for _, kk in ipairs(keys) do
    local v = c[kk]
    if type(v) == "table" then
      __pout("gs." .. kk .. "=TABLE")
    else
      __pout("gs." .. kk .. "=" .. tostring(v))
    end
  end
else
  __pout("gs.config=n/a")
end
-- 17. telescope defaults fingerprint
local okt, tel = pcall(require, "telescope.config")
if okt and tel and tel.values then
  local d = tel.values
  local simple = {"sorting_strategy","scroll_strategy","layout_strategy","prompt_prefix","selection_caret","entry_prefix","initial_mode","selection_strategy","winblend","path_display","color_devicons","dynamic_preview_title","cache_picker","tiebreak"}
  for _, kk in ipairs(simple) do
    local v = type(d[kk]) == "table" and "TABLE" or tostring(d[kk])
    __pout("tel.defaults." .. kk .. "=" .. v)
  end
  if d.mappings and d.mappings.i then
    local c = 0
    for _ in pairs(d.mappings.i) do c = c + 1 end
    __pout("tel.i_mappings=" .. c)
  end
  if d.vimgrep_arguments then
    __pout("tel.vimgrep=" .. table.concat(d.vimgrep_arguments, " "))
  end
  __pout("tel.pickers.buffer_initial=" .. tostring(d.pickers and d.pickers.buffers and d.pickers.buffers.initial_mode or "n/a"))
else
  __pout("tel.config=n/a")
end
-- 18. nvim-tree options fingerprint
local okn, nt = pcall(require, "nvim-tree.config")
if okn then
end
local okn2 = pcall(require, "nvim-tree")
if okn2 then
  local c = vim.g.nvim_tree.setup or {}
  local oklib, libm = pcall(require, "nvim-tree.lib")
  if oklib and libm and vim.g.nvim_tree_respects_buf_cwd ~= nil then
    __pout("nt.x=")
  end
end
local okcore, ntc = pcall(require, "nvim-tree")
if okcore then
  local cfg = require("nvim-tree").config or {}
  if type(cfg) == "table" and cfg.view then
    __pout("nt.view.width=" .. tostring(cfg.view.width))
    __pout("nt.view.side=" .. tostring(cfg.view.side))
    __pout("nt.view.number=" .. tostring(cfg.view.number))
    __pout("nt.view.cursorline=" .. tostring(cfg.view.cursorline))
    __pout("nt.git.enable=" .. tostring(cfg.git and cfg.git.enable))
    __pout("nt.actions.open_file.quit_on_open=" .. tostring(cfg.actions and cfg.actions.open_file and cfg.actions.open_file.quit_on_open))
    __pout("nt.filters.custom=" .. tostring(cfg.filters and cfg.filters.custom and table.concat(cfg.filters.custom, ",")))
    __pout("nt.update_focused_file.enable=" .. tostring(cfg.update_focused_file and cfg.update_focused_file.enable))
  end
end
-- 19. cmp config fingerprint
local okc, cmp = pcall(require, "cmp")
if okc and cmp and type(cmp.get_config) == "function" then
  local c = cmp.get_config()
  local function short(t, dep)
    if type(t) == "table" and dep then for k, _ in pairs(t) do return k end end
    return tostring(t)
  end
  __pout("cmp.completion.keyword_length=" .. tostring(c.completion and c.completion.keyword_length))
  __pout("cmp.confirm_behavior=" .. tostring(c.confirm_opts and c.confirm_opts.behavior))
  __pout("cmp.fields=" .. (c.formatting and c.formatting.fields and table.concat(c.formatting.fields, ",")))
  local srcs = {}
  if c.sources then
    for _, s in ipairs(c.sources) do srcs[#srcs+1] = s.name end
  end
  __pout("cmp.sources=" .. table.concat(srcs, ","))
  if c.window and c.window.completion and c.window.completion.border then
    local b = type(c.window.completion.border) == "table" and table.concat(c.window.completion.border, "") or tostring(c.window.completion.border)
    __pout("cmp.window.border=" .. b)
  end
  if c.mapping and c.mapping.class then __pout("cmp.mapping_class") end
  if c.experimental then
    __pout("cmp.ghost_text=" .. tostring(c.experimental.ghost_text))
  end
end
-- 20. lualine fingerprint
local okl, lualine = pcall(require, "lualine")
if okl and lualine and type(lualine.get_config) == "function" then
  local c = lualine.get_config()
  __pout("lualine.globalstatus=" .. tostring(c.options and c.options.globalstatus))
  __pout("lualine.extensions=" .. #(c.extensions or {}))
  __pout("lualine.theme=" .. type(c.options and c.options.theme))
  if c.sections and c.sections.lualine_a then
    local n = 0
    for _ in ipairs(c.sections.lualine_a) do n = n + 1 end
    __pout("lualine.a_count=" .. n)
  end
end
-- 21. dap fingerprints
local okd, dap = pcall(require, "dap")
if okd then
  local signs = vim.fn.sign_getdefined("dap-breakpoint") or {}
  local acc = {}
  for _, sgn in ipairs(signs) do acc[#acc+1] = sgn.text end
  __pout("dap.signs=" .. table.concat(acc, ","))
  __pout("dap.defaults.current_function=" .. tostring(dap.defaults and type(dap.defaults.fallback)))
end
local okdu, dapui = pcall(require, "dapui")
if okdu and dapui and dapui.setup then end
local okdu_cfg = pcall(require, "dapui.config")
if okdu_cfg then
  local c = require("dapui.config")
  __pout("dapui.layouts=" .. #(c.layouts or {}))
  __pout("dapui.repl=" .. tostring(c.mappings and c.mappings.repl))
end
local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
