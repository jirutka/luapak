---------
-- CLI for the merger module.
----
local fs = require 'luapak.fs'
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'
local merger = require 'luapak.merger'

local read_file = fs.read_file
local split = utils.split
local unpack = table.unpack


local help_msg = [[
.
Usage: ${PROG_NAME} merge [options] MODULE...
       ${PROG_NAME} merge --help

Combines multiple Lua modules into a single file. Each module is be wrapped in
a function, or string loaded by "load" (--debug), and assigned to
"package.preload" table.

Arguments:
  MODULE                    Name and path of Lua module delimited with "="
                            (e.g. "luapak.utils=luapak/utils.lua") or just path of module.

Options:
  -g, --debug               Preserve module names and line numbers in error backtraces?
  -o, --output=FILE         Where to write the generated code. Use "-" for stdout. Default is "-".
  -v, --verbose             Be verbose, i.e. print debug messages.
  -h, --help                Display this help message and exit.
]]


--- Runs the merge command.
--
-- @function __call
-- @tparam table arg List of CLI arguments.
-- @raise if some error occured.
return function (arg)
  local optparser = optparse(help_msg)
  local args, opts = optparser:parse(arg, { output = '-' })

  local modules = {}
  for _, item in ipairs(args) do
    local name, path = unpack(split('%=', item))
    if not path then
      path = name
      name = name:gsub('[/\\]', '.'):gsub('^%.+', ''):gsub('.lua$', '')
    end
    modules[name] = assert(read_file(path))
  end

  local out = opts.output == '-'
      and io.stdout
      or assert(io.open(opts.output, 'w'))

  merger.merge_modules(modules, opts.debug, function (...)
      assert(out:write(...))
    end)
  assert(out:flush())

  out:close()
end
