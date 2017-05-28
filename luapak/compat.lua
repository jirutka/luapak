-- "Polyfill" for compatibility with Lua 5.1

local concat = table.concat
local open = io.open

-- Lua 5.1
if not package.searchpath then
  -- Copied from https://github.com/keplerproject/lua-compat-5.3/blob/master/compat53/module.lua.
  function package.searchpath(name, path, sep, rep)  --luacheck: ignore
    sep = (sep or '.'):gsub('(%p)', '%%%1')
    rep = (rep or package.config:sub(1, 1)):gsub('(%%)', '%%%1')

    local pname = name:gsub(sep, rep):gsub('(%%)', '%%%1')
    local msg = {}

    for subpath in path:gmatch('[^;]+') do
      local fpath = subpath:gsub('%?', pname)
      local f = open(fpath, 'r')
      if f then
        f:close()
        return fpath
      end
      msg[#msg+1] = "\n\tno file '" .. fpath .. "'"
    end

    return nil, concat(msg)
  end
end

-- Lua 5.1
if not table.unpack then
  table.unpack = unpack  --luacheck: ignore
end
