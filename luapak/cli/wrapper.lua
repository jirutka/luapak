---------
-- CLI for the wrapper module.
----
local fs = require 'luapak.fs'
local optparse = require 'luapak.optparse'
local wrapper = require 'luapak.wrapper'

local read_file = fs.read_file


local help_msg = [[
.
Usage: ${PROG_NAME} wrapper [options] FILE [MODULE_NAME...]
       ${PROG_NAME} wrapper --help

Wraps Lua script into a generated C file that can be compiled and linked with
Lua interpreter and Lua/C native extensions into a standalone executable.

Arguments:
  FILE                        The Lua file to embed into the wrapper.
  MODULE_NAME                 Name of native module to preload (e.g. "cjson").

Options:
  -C, --no-compress           Do not compress FILE using BriefLZ algorithm.
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

  local filename = table.remove(args, 1)
  if not filename then
    optparser:opterr('FILE not specified')
  end

  local lua_chunk = assert(read_file(filename))
  local module_names = args

  local out = opts.output == '-'
      and io.stdout
      or assert(io.open(opts.output, 'w'))

  wrapper.generate(lua_chunk, module_names,
      { compress = not opts.no_compress },
      function (...) assert(out:write(...)) end)
  assert(out:flush())

  out:close()
end
