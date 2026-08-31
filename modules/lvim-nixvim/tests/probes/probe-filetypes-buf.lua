local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local out = {}
local do_ft = function(ft)
  local ok0 = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("filetype", ft, {buf = buf})
    table.insert(out, string.format("ft=%s sw=%d ts=%d et=%s cm=%s",
      vim.bo[buf].filetype, vim.bo[buf].shiftwidth, vim.bo[buf].tabstop,
      tostring(vim.bo[buf].expandtab), vim.bo[buf].commentstring))
    vim.api.nvim_buf_delete(buf, {force = true})
  end)
  if not ok0 then table.insert(out, "ft=" .. ft .. " ERROR") end
end
for _, ft in ipairs {"c","css","html","javascript","json","lua","make","markdown","nix","python","rust","sh","typescript","yaml"} do do_ft(ft) end
table.sort(out)
for _, l in ipairs(out) do __pout(l) end

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
