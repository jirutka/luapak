---------
-- CLI for the minifier module.
----
local fs = require 'luapak.fs'
local optparse = require 'luapak.optparse'
local minify = require 'luapak.minifier'

local read_file = fs.read_file


local help_msg = [[
.
Usage: ${PROG_NAME} minify [options] [FILE]
       ${PROG_NAME} minify --help

Minifies Lua source code - removes comments, unnecessary white spaces and
empty lines, shortens numbers and names of local variables.

Arguments:
  FILE                        Path of the Lua source file, or "-" for stdin.

Options:
  -l, --keep-lno              Do not affect line numbers.
  -n, --keep-names            Do not rename local variables.
  -o, --output=FILE           Where to write the output. Use "-" for stdout. Default is "-".
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

  if #args > 1 then
    optparser:opterr('Too many arguments given')
  end

  local filename = args[1]

  local chunk
  if not filename or filename == '-' then
    chunk = assert(io.stdin:read('*a'))
  else
    chunk = assert(read_file(filename))
  end

  local out = opts.output == '-'
      and io.stdout
      or assert(io.open(opts.output, 'w'))

  local minify_opts = {
    keep_lno = opts.keep_lno,
    keep_names = opts.keep_names,
  }
  local minified = assert(minify(minify_opts, chunk, filename))

  assert(out:write(minified))
  assert(out:write('\n'))

  out:close()
end
