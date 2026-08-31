local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
-- force telescope load (it is lazy in both, LV spec cmd-based)
if package.preload["telescope"] == nil and package.loaded["telescope"] == nil then
  local okload, _ = pcall(function()
    -- nixvim lz.n loads via cmd; simulate by loading plugin from opt packpath
    local pp = vim.o.packpath
    for _, pth in ipairs(vim.split(pp, ",")) do
      local opt = pth .. "/pack/myNeovimPackages/opt/telescope.nvim"
      if vim.fn.isdirectory(opt) == 1 then
        vim.opt.runtimepath:append(opt)
      end
    end
  end)
  pcall(require, "telescope")
  local setup_ok, _t = pcall(require, "telescope.config")
  if setup_ok and _t and _t.values then
    -- run the lz.n "after" hook via a telescope picker? No— purely check merged
    -- values reflect our nixvim defaults after nixvim auto-loads at first cmd.
  end
end
local ok, tel = pcall(require, "telescope")
local cfg = require("telescope.config").values
__pout("prompt_prefix=" .. vim.inspect(cfg.prompt_prefix))
__pout("selection_caret=" .. vim.inspect(cfg.selection_caret))
__pout("initial_mode=" .. cfg.initial_mode)
__pout("sorting_strategy=" .. cfg.sorting_strategy)
__pout("selection_strategy=" .. cfg.selection_strategy)
__pout("scroll_strategy=" .. cfg.scroll_strategy)
__pout("layout_strategy=" .. cfg.layout_strategy)
__pout("winblend=" .. tostring(cfg.winblend))
__pout("color_devicons=" .. tostring(cfg.color_devicons))
__pout("dynamic_preview_title=" .. tostring(cfg.dynamic_preview_title))
__pout("path_display=" .. (type(cfg.path_display) == "table" and table.concat(cfg.path_display, ",") or tostring(cfg.path_display)))
if cfg.vimgrep_arguments then
  __pout("vimgrep=" .. table.concat(cfg.vimgrep_arguments, " "))
end
__pout("pickers_buffers_initial=" .. (cfg.pickers and cfg.pickers.buffers and tostring(cfg.pickers.buffers.initial_mode) or "n/a"))
__pout("pickers_findfiles_hidden=" .. (cfg.pickers and cfg.pickers.find_files and tostring(cfg.pickers.find_files.hidden) or "n/a"))
__pout("pickers_livegrep_onlytext=" .. (cfg.pickers and cfg.pickers.live_grep and (cfg.pickers.live_grep.only_sort_text == nil and "n/a" or tostring(cfg.pickers.live_grep.only_sort_text)) or "n/a"))
sorted = nil
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
