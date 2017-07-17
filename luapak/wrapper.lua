---------
-- Generator of a C "wrapper" for standalone Lua programs.
----
local brieflz = require 'brieflz'
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

--- Generates definition of C constant `LUAPAK_SCRIPT` with the given data.
--
-- @tparam string data
-- @treturn string
local function define_script (data)
  return fmt('static const unsigned char LUAPAK_SCRIPT[] = %s;\n',
             encode_c_hex(data))
end

local function define_script_unpacked_size (size)
  return fmt('static const size_t LUAPAK_SCRIPT_UNPACKED_SIZE = %d;', size)
end

--- Generates C `#define` directive with the specified constant.
--
-- @tparam string name The constant name.
-- @param value The constant value.
-- @treturn string
local function define_macro_const (name, value)
  local value_t = type(value)

  if value_t == 'number' or value_t == 'boolean' then
    return fmt('#define %s %s', name, value)
  else
    return fmt('#define %s %q', name, tostring(value))
  end
end

--- Generates a fragment of C code that should be included in the template.
--
-- @tparam string lua_chunk The Lua chunk (source code or byte code) to embed.
-- @tparam int chunk_size Size of **uncompressed** Lua chunk.
-- @tparam {string,...} clib_names List of names of native modules to be preload.
-- @tparam table defs Table of constants to define with `#define` directive.
-- @treturn string Generated C code.
local function generate_fragment (lua_chunk, chunk_size, clib_names, defs)
  local buffer = {}

  for name, value in pairs(defs) do
    push(buffer, define_macro_const(name, value))
  end
  push(buffer, '')

  if chunk_size then
    push(buffer, define_script_unpacked_size(chunk_size))
  end
  push(buffer, define_script(lua_chunk))

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
-- @tparam {[string]=bool,...} opts Options: `compress` - enable compression.
-- @treturn string A source code in C.
function M.generate (lua_chunk, clib_names, opts)
  check_args('string, ?table, ?table', lua_chunk, clib_names, opts)

  clib_names = clib_names or {}
  opts = opts or {}

  lua_chunk = remove_shebang(lua_chunk)

  local defs = {}
  local chunk_size  -- size of *uncompressed* data

  if opts.compress then
    lua_chunk, chunk_size = brieflz.pack(lua_chunk)
    defs['LUAPAK_BRIEFLZ'] = 1
  else
    defs['LUAPAK_BRIEFLZ'] = 0
  end

  return (wrapper_tmpl:gsub('//%-%-PLACEHOLDER%-%-//',
      generate_fragment(lua_chunk, chunk_size, clib_names, defs)))
end

return M
