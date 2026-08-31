local d = vim.diagnostic.config()
local function s(t)
  if t == nil then return "nil" end
  if type(t) == "boolean" then return tostring(t) end
  if type(t) == "table" then
    local parts = {}
    for k, v in pairs(t) do
      parts[#parts+1] = tostring(k) .. "=" .. (type(v) == "table" and "{" .. tostring(v[1] or tostring(v)) .. "}" or tostring(v))
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(t)
end
print("virtual_text=" .. s(d.virtual_text))
print("underline=" .. s(d.underline))
print("update_in_insert=" .. s(d.update_in_insert))
print("severity_sort=" .. s(d.severity_sort))
print("signs=" .. s(type(d.signs) == "table" and (d.signs.text or d.signs) or d.signs))
print("float=" .. s(d.float))
