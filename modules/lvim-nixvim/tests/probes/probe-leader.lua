local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local out = {}
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  if m.desc and m.desc ~= "" and m.lhs ~= "" then
    local b1 = m.lhs:byte(1)
    if b1 == 32 then
      table.insert(out, vim.fn.keytrans(m.lhs) .. " -> " .. m.desc)
    end
  end
end
table.sort(out)
for _, l in ipairs(out) do __pout(l) end
__pout("LEADER_COUNT=" .. #out)

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
