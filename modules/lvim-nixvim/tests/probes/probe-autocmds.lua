local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local out = {}
local want = {TextYankPost=true, VimResized=true}
for _, au in ipairs(vim.api.nvim_get_autocmds({})) do
  local pat = type(au.pattern) == "table" and table.concat(au.pattern, ",") or tostring(au.pattern)
  if want[au.event] or au.desc and (au.desc:match("on yank") or au.desc:match("resize")) then
    table.insert(out, string.format("%s |%s| %s", au.event or "?", pat, au.desc or (au.command and au.command or "<lua>")))
  end
end
table.sort(out)
for _, l in ipairs(out) do __pout(l) end

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
