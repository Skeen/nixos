local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local ok, gs = pcall(require, "gitsigns.config")
if ok and gs and type(gs.get) == "function" then
  local c = gs.get() or {}
  __pout("signcolumn=" .. tostring(c.signcolumn))
  __pout("numhl=" .. tostring(c.numhl))
  __pout("linehl=" .. tostring(c.linehl))
  __pout("word_diff=" .. tostring(c.word_diff))
  __pout("attach_to_untracked=" .. tostring(c.attach_to_untracked))
  __pout("current_line_blame=" .. tostring(c.current_line_blame))
  __pout("sign_priority=" .. tostring(c.sign_priority))
  __pout("update_debounce=" .. tostring(c.update_debounce))
  __pout("max_file_length=" .. tostring(c.max_file_length))
  if c.watch_gitdir then
    __pout("watch_interval=" .. tostring(c.watch_gitdir.interval))
  end
  if c.current_line_blame_opts then
    __pout("blame_virt_text=" .. tostring(c.current_line_blame_opts.virt_text))
    __pout("blame_pos=" .. tostring(c.current_line_blame_opts.virt_text_pos))
    __pout("blame_delay=" .. tostring(c.current_line_blame_opts.delay))
  end
  if c.preview_config then
    __pout("preview_border=" .. tostring(c.preview_config.border))
    __pout("preview_style=" .. tostring(c.preview_config.style))
    __pout("preview_relative=" .. tostring(c.preview_config.relative))
  end
end
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
