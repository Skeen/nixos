local ok, lazy = pcall(require, "lazy")
if ok and lazy and type(lazy.plugins) == "function" then
  local ok2, ps = pcall(lazy.plugins)
  if ok2 and type(ps) == "table" then
    local names = {}
    for _, p in ipairs(ps) do names[#names+1] = p.name end
    table.sort(names)
    print("LAZY n=" .. #names .. " " .. table.concat(names, ","))
  else
    print("LAZY n=0")
  end
else
  print("LAZY n=0")
end
