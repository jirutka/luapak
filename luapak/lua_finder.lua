---------
-- Lua library finder.
----
local fs = require 'luapak.fs'
local luarocks = require 'luapak.luarocks.init'
local utils = require 'luapak.utils'

local check_args = utils.check_args
local filter = utils.filter
local fmt = string.format
local is_dir = fs.is_dir
local is_file = fs.is_file
local iter_dir = fs.dir
local match = string.match
local par = utils.partial
local popen = io.popen
local read_file = fs.read_file
local starts_with = utils.starts_with


local default_include_dirs = {
  luarocks.get_variable('LUA_INCDIR') or '',
  'vendor/lua', 'deps/lua', '/usr/local/include', '/usr/include'
}
local default_lib_dirs = {
  luarocks.get_variable('LUA_LIBDIR') or '.',
  'vendor/lua', 'deps/lua', '/usr/local/lib', '/usr/local/lib64', '/usr/lib', '/usr/lib64'
}

--- Looks for string specified by the `pattern` in the given binary file.
--
-- This function uses command `strings`. It works for both static and dynamic
-- library on Linux and macOS.
--
-- @tparam string pattern The string pattern to search for.
-- @tparam string filename Path of the file to scan.
-- @treturn[1] string Captured substring, or nil if not found.
-- @treturn[2] nil
-- @treturn[2] An error message.
local function find_string_in_binary (pattern, filename)
  check_args('string, string', pattern, filename)

  if not is_file(filename) then
    return nil, 'file does not exist or not readable: '..filename
  end

  local cmd = luarocks.get_variable('STRINGS') or 'strings'
  local handler, err = popen(cmd..' -n 4 '..filename)
  if not handler then
    return nil, err
  end

  local capture
  for line in handler:lines() do
    capture = match(line, pattern)
    if capture then
      break
    end
  end

  handler:close()
  return capture
end


local M = {}

--- Parses version number from the given Lua library using @{find_string_in_binary}.
--
-- @function liblua_version
-- @tparam string filename Path of the Lua library.
-- @treturn[1] string Version number in format `x.y.z`.
-- @treturn[2] nil
-- @treturn[2] string An error message.
local liblua_version = par(find_string_in_binary, '^@?%$Lua%w*: Lua (%d%.%d+%.%d+)')
M.liblua_version = liblua_version

--- Parses version number from the given LuaJIT library using @{find_string_in_binary}.
--
-- @function libluajit_version
-- @tparam string filename Path of the LuaJIT library.
-- @treturn[1] string Version number in format `x.y.z`.
-- @treturn[2] nil
-- @treturn[2] string An error message.
local libluajit_version = par(find_string_in_binary, '^LuaJIT (%d%.%d+%.%d+)')
M.libluajit_version = libluajit_version

--- Reads version number from the given `lua.h` file.
--
-- @tparam string filename Path of the `lua.h` file.
-- @treturn[1] string Version number in format `x.y.z`.
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.luah_version (filename)
  local content, err = read_file(filename)
  if not content then
    return nil, err
  end

  local x, y = content:match('#define%s+LUA_VERSION_NUM%s+(%d)0(%d)')
  if not x or not y then
    return nil, 'LUA_VERSION_NUM not found in '..filename
  end
  local z = content:match('#define%s+LUA_VERSION_RELEASE%s+"(%d+)"')
            or content:match('#define%s+LUA_RELEASE%s+"Lua %d%.%d%.(%d+)"')
            or '0'

  return fmt('%s.%s.%s', x, y, z)
end
local luah_version = M.luah_version

--- Reads version number from the given `luajit.h` file.
--
-- @tparam string filename Path of the `luajit.h` file.
-- @treturn[1] string Version number in format `x.y.z`.
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.luajith_version (filename)
  local content, err = read_file(filename)
  if not content then
    return nil, err
  end

  local x, y, z = content:match('#define%s+LUAJIT_VERSION_NUM%s+(%d)0(%d)0(%d)')
  if not x or not y or not z then
    return nil, 'LUAJIT_VERSION_NUM not found in '..filename
  end

  return fmt('%s.%s.%s', x, y, z)
end
local luajith_version = M.luajith_version

--- Looking for a directory containing Lua header file `lua_name` in common locations.
--
-- @tparam ?string lua_name Base name of the Lua header file; "lua", or "luajit" (default: "lua").
-- @tparam ?string lua_ver Version of the header file to search for in format `x.y` or `x.y.z`.
-- @tparam ?{string,...} List of prefixes (directories) to search.
--   If `nil`, the default list of directories is used.
-- @treturn[1] string File path of the found directory.
-- @treturn[1] string Version of the found header file in format `x.y.z`.
-- @treturn[2] nil Not found.
function M.find_incdir (lua_name, lua_ver, dirs)
  check_args('?string, ?string, ?table', lua_name, lua_ver, dirs)
  lua_name = lua_name or 'lua'

  local header_version = lua_name == 'luajit' and luajith_version or luah_version
  local lua_ver2 = (lua_ver or ''):match('^(%d+%.%d+)')  -- extract x.y
  local suffixes = lua_ver2 ~= nil
      and { '', '/'..lua_name..lua_ver2, '/'..lua_name..'-'..lua_ver2 }
      or { '' }

  for _, dir in ipairs(dirs or default_include_dirs) do
    for _, suffix in ipairs(suffixes) do
      local path = dir..suffix
      local found_ver = header_version(fmt('%s/%s.h', path, lua_name))

      if found_ver and (lua_ver == nil or starts_with(lua_ver, found_ver)) then
        return path, found_ver
      end
    end
  end
end

--- Looking for Lua or LuaJIT library in common locations.
--
-- @tparam string lib_ext File extension of the library to search for.
-- @tparam ?string lua_name Base name of the Lua library; typically "lua", or "luajit"
--   (default: "lua").
-- @tparam ?string lua_ver Version of the Lua(JIT) library to search for (default: "5.3").
-- @tparam ?{string,...} dirs List of prefixes (directories) to search.
--   If `nil`, the default list of prefixes is used.
-- @treturn[1] string File path of the found Lua library.
-- @treturn[1] string Version of the found Lua library in format `x.y.z`.
-- @treturn[2] nil Not found.
function M.find_liblua (lib_ext, lua_name, lua_ver, dirs)
  check_args('string, ?string, ?string, ?table',
             lib_ext, lua_name, lua_ver, dirs)

  lua_name = lua_name or 'lua'
  lua_ver = lua_ver or '5.3'

  local lib_prefix = 'lib'
  local filename_patt = '^'..lib_prefix..lua_name..'[.-]?[%d.]*%.'..lib_ext..'[%d%.]*$'
  local dirname_patt = '^'..lua_name..'[.-]?[%d.]*$'
  local lualib = luarocks.get_variable('LUALIB')
  local lib_version = lua_name == 'luajit' and libluajit_version or liblua_version

  if not dirs and lualib and lualib:find(filename_patt) then
    local path = (luarocks.get_variable('LUA_LIBDIR') or '.')..'/'..lualib
    local found_ver = lib_version(path)

    if starts_with(lua_ver, found_ver) then
      return path, found_ver
    end
  end

  for _, dir in ipairs(filter(is_dir, dirs or default_lib_dirs)) do
    for entry in iter_dir(dir) do
      if entry:find(lua_name, 1, true) then
        local path = dir..'/'..entry
        local matches = false

        if entry:find(filename_patt) then
          matches = true
        elseif entry:find(dirname_patt) and is_dir(path) then
          path = path..'/'..lib_prefix..lua_name..'.'..lib_ext
          matches = true
        end

        if matches then
          local found_ver = lib_version(path)
          if starts_with(lua_ver, found_ver) then
            return path, found_ver
          end
        end
      end
    end
  end
end

return M
