---------
-- Generator of a C "wrapper" for standalone Lua programs.
----
local fs = require 'luapak.fs'
local wrapper_tmpl = require 'luapak.wrapper_tmpl'
local utils = require 'luapak.utils'

local byte = string.byte
local check_args = utils.check_args
local concat = table.concat
local fmt = string.format
local push = table.insert
local read_file = fs.read_file


--- Returns copy of the given `script` with removed shebang.
--
-- @tparam string script
-- @treturn string
local function remove_shebang (script)
  return script:gsub('^#%!.-\n', '')
end

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

--- Generates definition of C function that loads and calls the given Lua module.
--
-- @tparam string name Full name of the Lua module in dot-notation.
-- @tparam string chunk Source code or bytecode of the Lua module.
-- @treturn string
local function define_luaopen_for_lua (name, chunk)
  return fmt([[
static int %s(lua_State* L) {
  int arg = lua_gettop(L);
  static const unsigned char chunk[] = %s;

  if (luaL_loadbuffer(L, (const char*)chunk, sizeof(chunk), "%s")) {
    return lua_error(L);
  }
  lua_insert(L, 1);

  lua_call(L, arg, 1);
  return 1;
}
]], luaopen_name(name), encode_c_hex(chunk), name)
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
-- @tparam string lua_main Source code or byte code of the main script.
-- @tparam {table,...} modules A list of modules to include.
-- @treturn string A generated C code.
-- @raise if some module table doesn't have required keys or has wrong "type".
local function generate_fragment (lua_main, modules)
  local buffer = {}
  local mod_names = {}

  push(buffer, define_lua_main(lua_main))

  for i, mod in ipairs(modules) do
    assert(mod.name, fmt('modules[%d].name is %s', i, mod.name))

    if mod.type == 'lua' then
      assert(mod.content, fmt('modules[%d].content is %s', i, mod.content))
      push(buffer, define_luaopen_for_lua(mod.name, mod.content))

    elseif mod.type == 'native' then
      push(buffer, declare_luaopen_func(mod.name))

    else
      error(fmt('invalid module type: %s', mod.type))
    end

    push(mod_names, mod.name)
  end

  push(buffer, define_preloaded_libs(mod_names))

  return concat(buffer, '\n')
end


local M = {}

--- Generates source code of the C "wrapper" with the given Lua script and modules.
--
-- **Module table:**
--
-- * `type:` `"lua"`, or `"native"`
-- * `name:` Full name of the module in dot-notation.
-- * `content:` Source code or bytecode of Lua module (only for type "lua").
--
-- @tparam string lua_main Source code or byte code of the main Lua script.
-- @tparam {table,...} modules A list of modules to be included.
-- @treturn string A source code in C.
-- @raise if some module table doesn't have required keys or has wrong "type".
function M.generate (lua_main, modules)
  check_args('string, table', lua_main, modules)

  return (wrapper_tmpl:gsub('//%-%-PLACEHOLDER%-%-//',
                            generate_fragment(lua_main, modules)))
end
local generate = M.generate

--- Generates source code of the C "wrapper" with the given Lua script and modules.
--
-- **Module table:**
--
-- * `type:` `"lua"`, or `"native"`
-- * `name:` Full name of the module in dot-notation.
-- * `path:` Path of the Lua module to read (required for type "lua" if `content` is not set).
-- * `content:` Source code or bytecode of the Lua module (required for type "lua"
--   if `path` is not set).
--
-- @tparam string main_file Path of the main Lua script.
-- @tparam table modules A list of modules to be included.
-- @treturn string A source code in C.
-- @raise if any path in the `modules` is unreadable or some module table doesn't have
--   required keys or has wrong "type".
function M.generate_from_files (main_file, modules)
  check_args('string, table', main_file, modules)

  local lua_main = assert(read_file(main_file))
  lua_main = remove_shebang(lua_main)

  for _, module in pairs(modules) do
    if module.path and not module.content then
      local content = assert(read_file(module.path))
      module.content = remove_shebang(content)
    end
  end

  return generate(lua_main, modules)
end

return M
