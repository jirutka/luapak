---------
-- CLI for the wrapper module.
----
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'
local wrapper = require 'luapak.wrapper'

local imap = utils.imap
local split = utils.split
local unpack = table.unpack


local help_msg = [[
.
Usage: ${PROGRAM} wrapper [options] ENTRY_SCRIPT [MODULE...]
       ${PROGRAM} wrapper [-h | --help]

Arguments:
  ENTRY_SCRIPT              Entry point of the wrapped program, i.e. the main Lua script.

  MODULE                    Name of the native module to register (e.g. "cjson"), or name and
                            path of the Lua module to embed into the wrapper as lazy-loaded
                            (e.g. "luapak.utils=luapak/utils.lua").

Options:
  -o, --output=FILE         Where to write the generated code. Use "-" for stdout. Default is "-".
  -h, --help                Display this help message and exit.
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

  local modules = imap(function (item)
      local name, path = unpack(split('%=', item))
      return path and { name = name, type = 'lua', path = path }
                  or { name = name, type = 'native' }
    end, args)

  local out = opts.output == '-'
      and io.stdout
      or assert(io.open(opts.output, 'w'))

  local output = wrapper.generate_from_files(lua_main, modules)

  assert(out:write(output))
  out:close()
end
