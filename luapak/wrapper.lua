---------
-- Generator of a C "wrapper" for standalone Lua programs.
----
local wrapper_tmpl = require 'luapak.wrapper_tmpl'
local utils = require 'luapak.utils'

local byte = string.byte
local check_args = utils.check_args
local concat = table.concat
local fmt = string.format
local push = table.insert
local remove_shebang = utils.remove_shebang


--- Encodes string into hexadecimal representation formatted as a C array.
--
-- @tparam string str
-- @treturn string
local function encode_c_hex (str)
  local buff = {}
  for ch in str:gmatch('.') do
    push(buff, fmt('0x%02x', byte(ch)))
  end
  return '{ '..concat(buff, ', ')..' }'
end

--- Converts the module name in dot-notation into name of the corresponding
-- C luaopen function.
--
-- @tparam string name
-- @treturn string
local function luaopen_name (name)
  return 'luaopen_'..name:gsub('[.-]', '_')
end

--- Generates declaration of C function for loading the specified C/Lua module.
--
-- @tparam string name Full name of the module in dot or underscore notation.
-- @treturn string
local function declare_luaopen_func (name)
  return fmt('int %s(lua_State *L);\n', luaopen_name(name))
end

--- Generates definition of C constant `LUAPAK_PRELOADED_LIBS` of type
-- `luaL_Reg` that contains an array of preloaded modules.
--
-- @tparam {string,...} names A list of full names in dot-notation.
-- @treturn string
local function define_preloaded_libs (names)
  local buff = {}

  push(buff, 'static const luaL_Reg LUAPAK_PRELOADED_LIBS[] = {')
  for _, name in ipairs(names) do
    push(buff, fmt('  { "%s", %s },', name, luaopen_name(name)))
  end
  push(buff, '  { NULL, NULL }\n};\n')

  return concat(buff, '\n')
end

--- Generates definition of C constant `LUAPAK_LUA_MAIN` with the given chunk of Lua code.
--
-- @tparam string chunk
-- @treturn string
local function define_lua_main (chunk)
  return fmt('static const unsigned char LUAPAK_LUA_MAIN[] = %s;\n',
             encode_c_hex(chunk))
end

--- Generates a fragment of C code that should be included in the template.
--
-- @tparam string lua_chunk The Lua chunk (source code or byte code) to embed.
-- @tparam {string,...} clib_names List of names of native modules to be preload.
-- @treturn string Generated C code.
local function generate_fragment (lua_chunk, clib_names)
  local buffer = {}

  push(buffer, define_lua_main(remove_shebang(lua_chunk)))

  for _, name in ipairs(clib_names) do
    push(buffer, declare_luaopen_func(name))
  end
  push(buffer, define_preloaded_libs(clib_names))

  return concat(buffer, '\n')
end


local M = {}

--- Generates source code of the C "wrapper" with the given Lua chunk and preloaded
-- native modules.
--
-- @tparam string lua_chunk The Lua chunk (source code or byte code) to embed.
-- @tparam ?{string,...} clib_names List of names of native modules to be preload.
-- @treturn string A source code in C.
function M.generate (lua_chunk, clib_names)
  check_args('string, ?table', lua_chunk, clib_names)

  return (wrapper_tmpl:gsub('//%-%-PLACEHOLDER%-%-//',
      generate_fragment(lua_chunk, clib_names or {})))
end

return M
