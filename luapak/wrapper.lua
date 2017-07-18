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


--- Converts the module name in dot-notation into name of the corresponding
-- C luaopen function.
--
-- @tparam string name
-- @treturn string
local function luaopen_name (name)
  return 'luaopen_'..name:gsub('[.-]', '_')
end

--- Encodes the given data into hexadecimal representation formatted as a C array.
--
-- @tparam func write The writer function.
-- @tparam string data
local function encode_c_hex (write, data)
  write '{\n'

  local is_first = true
  for ch in data:gmatch('.') do
    if is_first then
      is_first = false
    else
      write ', '
    end
    write(fmt('0x%02x', byte(ch)))
  end

  write '\n}'
end

--- Formats C `#define` directive with the specified constant.
--
-- @tparam function write
-- @tparam string name The constant name.
-- @param value The constant value.
local function define_macro_const (write, name, value)
  local value_t = type(value)

  if value_t == 'number' or value_t == 'boolean' then
    write(fmt('#define %s %s\n', name, value))
  else
    write(fmt('#define %s %q\n', name, tostring(value)))
  end
end

--- Writes code for preloading of the specified Lua/C modules.
--
-- @tparam func write The writer function.
-- @tparam {string,...} names A list of full names in dot-notation.
local function define_preloaded_libs (write, names)
  for _, name in ipairs(names) do
    write(fmt('int %s(lua_State *L);\n', luaopen_name(name)))
  end

  write '\nstatic const luaL_Reg LUAPAK_PRELOADED_LIBS[] = {\n'
  for _, name in ipairs(names) do
    write(fmt('  { "%s", %s },\n', name, luaopen_name(name)))
  end
  write '  { NULL, NULL }\n};\n\n'
end

--- Writes the Lua script encoded as a C array of bytes in hexa.
--
-- @tparam function write
-- @tparam string data Lua chunk or compressed Lua chunk.
-- @tparam ?int unpacked_size Size of **uncompressed** Lua chunk.
local function define_script (write, data, unpacked_size)
  if unpacked_size then
    write(fmt('static const size_t LUAPAK_SCRIPT_UNPACKED_SIZE = %d;\n', unpacked_size))
  end

  write 'static const unsigned char LUAPAK_SCRIPT[] = '
  encode_c_hex(write, data)
  write ';\n\n'
end


local M = {}

--- Generates source code of the C "wrapper" with the given Lua chunk and preloaded
-- native modules.
--
-- @tparam string lua_chunk The Lua chunk (source code or byte code) to embed.
-- @tparam ?{string,...} clib_names List of names of native modules to be preload.
-- @tparam ?{[string]=bool,...} opts Options: `compress` - enable compression.
-- @tparam ?function write The writer function. If not give, an intermediate table
--   will be created and generated code returned as string.
-- @treturn ?string A generated source code, or nil if the `write` function given.
function M.generate (lua_chunk, clib_names, opts, write)
  check_args('string, ?table, ?table, ?function', lua_chunk, clib_names, opts, write)

  lua_chunk = remove_shebang(lua_chunk)
  clib_names = clib_names or {}
  opts = opts or {}

  local buff
  if not write then
    buff = {}
    write = function (str) push(buff, str) end
  end

  write(wrapper_tmpl.HEAD)

  if opts.compress then
    define_macro_const(write, 'LUAPAK_BRIEFLZ', 1)
    define_script(write, brieflz.pack(lua_chunk))
  else
    define_macro_const(write, 'LUAPAK_BRIEFLZ', 0)
    define_script(write, lua_chunk)
  end

  define_preloaded_libs(write, clib_names)

  if opts.compress then
    write(wrapper_tmpl.BRIEFLZ)
  end
  write(wrapper_tmpl.MAIN)

  if buff then
    return concat(buff)
  end
end

return M
