---------
-- CLI for the make module.
----
local make = require 'luapak.make'
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'

local concat = table.concat
local fmt = string.format
local is_empty = utils.is_empty
local reject = utils.reject
local split = utils.split
local tableize = utils.tableize


local help_msg = [[
.
Usage: ${PROG_NAME} make [options] [PACKAGE...]
       ${PROG_NAME} make --help

Makes a standalone executable from Lua package(s). This is the main Luapak
command that handles entire process from installing dependencies to
compiling executable.

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
  -s, --entry-script=FILE         The entry point of your program, i.e. the main Lua script. If not
                                  specified and the last PACKAGE defines exactly one CLI script,
                                  then it's used.

  -e, --exclude-modules=PATTERNS  Module(s) to exclude from dependencies analysis and the
                                  generated binary. PATTERNS is one or more glob patterns matching
                                  module name in dot notation (e.g. "pl.*"). Patterns may be
                                  delimited by comma or space. This option can be also specified
                                  multiple times.

  -g, --debug                     Enable debug mode, i.e. preserve line numbers, module names and
                                  local variable names for error messages and backtraces.

  -i, --include-modules=PATTERNS  Extra module(s) to include in dependencies analysis and add to
                                  the generated binary. PATTERNS has the same format as in
                                  "--exclude-module".

      --lua-impl=NAME             The Lua implementation that should be used - "PUC" (default),
                                  or "LuaJIT". This is currently used only as a hint to find the
                                  correct library and headers when auto-detection is used
                                  (i.e. --lua-incdir or --lua-lib is not specified).

      --lua-incdir=DIR            The directory that contains Lua (or LuaJIT) headers. If not
                                  specified, luapak will look for the lua.h (and luajit.h) file
                                  inside: Luarock's LUA_INCDIR, ./vendor/lua, ./deps/lua,
                                  /usr/local/include, and /usr/include. If --lua-version is
                                  specified, then it will also try subdirectories lua<version> and
                                  lua-<version> of each of the named directories and verify that
                                  the found lua.h (or luajit.h) is for the specified Lua
                                  (or LuaJIT) version.

      --lua-lib=FILE              The library of Lua interpreter to include in the binary. If not
                                  specified, luapak will try to find library with version
                                  corresponding to the headers inside Luarock's LUA_LIBDIR,
                                  ./vendor/lua, ./deps/lua, /usr/local/lib, /usr/local/lib64,
                                  /usr/lib, and /usr/lib64.

      --lua-version=VERSION       The version number of Lua (or LuaJIT) headers and library to try
                                  to find (e.g. "5.3", "2.0").

  -o, --output=FILE               Output file name or path. Defaults to base name of the main
                                  script with stripped .lua extension.

  -C, --no-compress               Disable BriefLZ compression of Lua sources.

  -M, --no-minify                 Disable minification of Lua sources.

  -t, --rocks-tree=DIR            The prefix where to install required modules. Default is
                                  ".luapak" in the current directory.
  -q, --quiet                     Be quiet, i.e. print only errors.

  -v, --verbose                   Be verbose, i.e. print debug messages.

  -h, --help                      Display this help message and exit.

Environment Variables:
  AR          Archive-maintaining program; default is "ar".
  CC          Command for compiling C; default is "gcc".
  CMAKE       Command for processing CMakeLists.txt files; default is "cmake".
  CFLAGS      Extra flags to give to the C compiler; default is "-Os -fPIC".
  LD          Command for linking object files and archive files; default is "ld".
  LDFLAGS     Extra flags to give to compiler when they are supposed to invoke the linker;
              default on macOS is "-pagezero_size 10000 -image_base 100000000".
  MAKE        Command for executing Makefile; default is "make".
  RANLIB      Command for generating index to the contents of an archive; default is "ranlib".
  STRIP       Command for discarding symbols from an object file; default is "strip".
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
  local args, opts = optparser:parse(arg, { lua_impl = 'PUC' })

  if #args == 0 then
    args = { '.' }
  end

  if not ({ puc = 1, luajit = 1 })[opts.lua_impl:lower()] then
    optparser:opterr(fmt('--lua-impl="%s" is invalid, must be "PUC", or "LuaJIT"', opts.lua_impl))
  end

  local make_opts = {
    compress = not opts.no_compress,
    debug = opts.debug,
    exclude_modules = split_repeated_option(opts.exclude_modules),
    extra_modules = split_repeated_option(opts.include_modules),
    lua_impl = opts.lua_impl:lower(),
    lua_incdir = opts.lua_incdir,
    lua_lib = opts.lua_lib,
    lua_version = opts.lua_version,
    minify = not opts.no_minify,
  }

  make(args, opts.entry_script, opts.output, opts.rocks_tree, make_opts)
end
