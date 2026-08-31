local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local g = vim.g
local prefs = {"loaded_comment","did_load_filetypes","loaded_man","loaded_gzip","loaded_tarPlugin","loaded_zipPlugin","loaded_netrwPlugin","loaded_tutorModePlugin","loaded_2html_plugin","loaded_matchit","loaded_matchparen","loaded_shada_plugin","loaded_remote_plugins","loaded_node_provider","loaded_perl_provider","loaded_python_provider","loaded_ruby_provider","did_install_default_menus","skip_reload_lvim"}
for _, k in ipairs(prefs) do __pout(k .. "=" .. tostring(g[k])) end
__pout("mapleader=" .. tostring(g.mapleader))
__pout("maplocalleader=" .. tostring(g.maplocalleader))
__pout("colors_name=" .. tostring(g.colors_name))

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
