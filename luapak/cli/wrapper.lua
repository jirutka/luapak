---------
-- CLI for the wrapper module.
----
local fs = require 'luapak.fs'
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'
local wrapper = require 'luapak.wrapper'

local push = table.insert
local read_file = fs.read_file
local split = utils.split
local unpack = table.unpack


local help_msg = [[
.
Usage: ${PROG_NAME} wrapper [options] ENTRY_SCRIPT [MODULE...]
       ${PROG_NAME} wrapper [-h | --help]

Arguments:
  ENTRY_SCRIPT                Entry point of the wrapped program, i.e. the main Lua script.

  MODULE                      Name of the native module to register (e.g. "cjson"), or name and
                              path of the Lua module to embed into the wrapper as lazy-loaded
                              (e.g. "luapak.utils=luapak/utils.lua").

Options:
  -o, --output=FILE           Where to write the generated code; "-" for stdout. Default is "-".
  -v, --verbose               Be verbose, i.e. print debug messages.
  -h, --help                  Display this help message and exit.
]]


--- Runs the wrapper command.
--
-- @function __call
-- @tparam table arg List of CLI arguments.
-- @raise if some error occured.
return function (arg)
  local optparser = optparse(help_msg)
  local args, opts = optparser:parse(arg, { output = '-' })

  local lua_main = table.remove(args, 1)
  if not lua_main then
    optparser:opterr('ENTRY_SCRIPT not specified')
  end
  lua_main = assert(read_file(lua_main))

  local lua_modules = {}
  local native_modules = {}

  for _, item in ipairs(args) do
    local name, path = unpack(split('%=', item))
    if path then
      lua_modules[name] = assert(read_file(path))
    else
      push(native_modules, name)
    end
  end

  local out = opts.output == '-'
      and io.stdout
      or assert(io.open(opts.output, 'w'))

  local output = wrapper.generate(lua_main, native_modules, lua_modules)

  assert(out:write(output))
  out:close()
end
