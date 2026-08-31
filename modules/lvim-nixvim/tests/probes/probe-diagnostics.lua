local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local d = vim.diagnostic.config()
local function s(t)
  if t == nil then return "nil" end
  if type(t) == "boolean" then return tostring(t) end
  if type(t) == "table" then
    local parts = {}
    for k, v in pairs(t) do
      parts[#parts+1] = tostring(k) .. "=" .. (type(v) == "table" and ("{" .. table.concat(v or {}, ",") .. "}") or tostring(v))
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(t)
end
__pout("virtual_text=" .. s(d.virtual_text))
__pout("underline=" .. s(d.underline))
__pout("update_in_insert=" .. s(d.update_in_insert))
__pout("severity_sort=" .. s(d.severity_sort))
__pout("signs_active=" .. tostring(d.signs ~= nil and d.signs ~= false))
__pout("float=" .. s(d.float))

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
