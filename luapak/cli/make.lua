---------
-- CLI for the make module.
----
local make = require 'luapak.make'
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'

local concat = table.concat
local is_empty = utils.is_empty
local reject = utils.reject
local split = utils.split
local tableize = utils.tableize


local help_msg = [[
.
Usage: ${PROG_NAME} make [options] [PACKAGE...]
       ${PROG_NAME} make --help

Arguments:
  PACKAGE                         Lua package to build specified as <source-dir>:<rockspec>.
                                  :<rockspec> may be omitted if the <source-dir> or
                                  <source-dir>/rockspec(s) contains single rockspec, or multiple
                                  rockspecs for the same package (i.e. with different version).
                                  In the further case rockspec with the highest version is used.
                                  <source-dir>: may be omitted if the <rockspec> is in the
                                  project's source directory or rockspec(s) subdirectory.
                                  If no argument is given, the current directory is used as
                                  <source-dir>.

Options:
  -e, --exclude-modules=PATTERNS  Module(s) to exclude from dependencies analysis and the
                                  generated binary. PATTERNS is one or more glob patterns matching
                                  module name in dot notation (e.g. "pl.*"). Patterns may be
                                  delimited by comma or space. This option can be also specified
                                  multiple times.

  -i, --include-modules=PATTERNS  Extra module(s) to include in dependencies analysis and add to
                                  the generated binary. PATTERNS has the same format as in
                                  "--exclude-module".

  -o, --output=FILE               Output file name or path. Defaults to base name of the main
                                  script with stripped .lua extension.

  -s, --entry-script=FILE         The entry point of your program, i.e. the main Lua script. If not
                                  specified and the last PACKAGE defines exactly one CLI script,
                                  then it's used.

  -t, --rocks-tree=DIR            The prefix where to install required modules. Default is
                                  ".luapak" in the current directory.

      --lua-incdir=DIR            The directory that contains Lua headers. If not specified, luapak
                                  will look for the lua.h file inside: Luarock's LUA_INCDIR,
                                  ./vendor/lua, ./deps/lua, /usr/local/include, and /usr/include.
                                  If --lua-version is specified, then it will also try
                                  subdirectories lua<version> and lua-<version> of each of the
                                  named directories and verify that the found lua.h is for the
                                  specified Lua version.

      --lua-lib=FILE              The library of Lua interpreter to include in the binary. If not
                                  specified, luapak will try to find library with version
                                  corresponding to the headers inside Luarock's LUA_LIBDIR,
                                  ./vendor/lua, ./deps/lua, /usr/local/lib, /usr/local/lib64,
                                  /usr/lib, and /usr/lib64.

      --lua-version=VERSION       The version number of Lua headers and library to try to find
                                  (e.g. "5.3").

  -q, --quiet                     Be quiet, i.e. print only errors.

  -v, --verbose                   Be verbose, i.e. print debug messages.

  -h, --help                      Display this help message and exit.
]]


-- @tparam {string,...}|string|nil value The option value(s).
-- @treturn {string,...}
local function split_repeated_option (value)
  if not value then
    return {}
  else
    -- TODO: This is inefficient, use iterator-based functions.
    return reject(is_empty, split('[,\n]%s*', concat(tableize(value), ',')))
  end
end

--- Runs the make command.
--
-- @function __call
-- @tparam table arg List of CLI arguments.
-- @raise if some error occured.
return function (arg)
  local optparser = optparse(help_msg)
  local args, opts = optparser:parse(arg)

  if #args == 0 then
    args = { '.' }
  end

  local make_opts = {
    exclude_modules = split_repeated_option(opts.exclude_modules),
    extra_modules = split_repeated_option(opts.include_modules),
    lua_incdir = opts.lua_incdir,
    lua_lib = opts.lua_lib,
    lua_version = opts.lua_version,
  }

  make(args, opts.entry_script, opts.output, opts.rocks_tree, make_opts)
end
