local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local out = {}
local function ktrans(x)
  local ok, r = pcall(vim.fn.keytrans, x)
  return ok and r or tostring(x)
end
for _, mode in ipairs {"n","i","v","x","c","t","o"} do
  local okmaps, maps = pcall(vim.api.nvim_get_keymap, mode)
  if okmaps then
    for _, m in ipairs(maps) do
      local lhs = ktrans(m.lhs)
      if not (m.lhs == "\t" and (m.rhs == "\t" or (m.rhs or "") == "<Tab>")) then
        local rhs = m.rhs and ktrans(m.rhs) or (type(m.callback) == "function" and "<lua>" or "nil")
        -- skip <Plug> and luasnip/telescope-internal plumbing: user wrist keys only
        if not (lhs:match("^<lt>Plug>") or lhs:match("^<Plug>") or desc == "" and rhs == "<lua>") then
          if not lhs:match("luasnip") and not lhs:match("TelescopeFuzzy") then
            table.insert(out, string.format("%s %s -> %s", mode, lhs, rhs))
          end
        end
      end
    end
  end
end
table.sort(out)
for _, l in ipairs(out) do __pout(l) end

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
