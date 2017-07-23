---------
-- CLI for the builder.
----
local fs = require 'luapak.fs'
local lua_finder = require 'luapak.lua_finder'
local luarocks = require 'luapak.luarocks.init'
local log = require 'luapak.logging'
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'

local errorf = utils.errorf
local find_incdir = lua_finder.find_incdir
local fmt = string.format
local is_file = fs.is_file
local luah_version = lua_finder.luah_version


local help_msg = [[
.
Usage: ${PROG_NAME} build-rock [options] ROCKSPEC...
       ${PROG_NAME} build-rock --help

Builds Lua/C module as a library archive suitable for static linking
and installs it into rocks tree.

Arguments:
  ROCKSPEC                    Path of the rockspec file to build and install.

Options:
  -C, --directory=DIR         Change directory before doing anything.

  -i, --lua-impl=NAME         The Lua implementation that should be used - "PUC" (default), or
                              "LuaJIT". This is currently used only as a hint to find the correct
                              headers when auto-detection is used (i.e. --lua-incdir unspecified).

  -I, --lua-incdir=DIR        The directory that contains Lua (or LuaJIT) headers. If not
                              specified, luapak will look for the lua.h (and luajit.h) file inside:
                              Luarock's LUA_INCDIR, ./vendor/lua, ./deps/lua, /usr/local/include,
                              and /usr/include. If --lua-version is specified, then it will also
                              try subdirectories lua<version> and lua-<version> of each of the
                              named directories and verify that the found lua.h (or luajit.h) is
                              for the specified Lua (or LuaJIT) version.

  -l, --lua-version=VERSION   The version number of Lua (or LuaJIT) headers and library to try
                              to find (e.g. "5.3", "2.0").

  -t, --rocks-tree=DIR        The prefix where to install Lua/C modules Default is ".luapak" in
                              the current directory.

  -v, --verbose               Be verbose, i.e. print debug messages.

  -h, --help                  Display this help message and exit.

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
]]


--- Runs the build-rock command.
--
-- @function __call
-- @tparam table arg List of CLI arguments.
-- @raise if some error occured.
return function (arg)
  local optparser = optparse(help_msg)
  local args, opts = optparser:parse(arg, {
      lua_impl = 'PUC',
      rocks_tree = '.luapak',
    })

  if #args == 0 then
    optparser:opterr('no ROCKSPEC specified')
  end

  if not ({ puc = 1, luajit = 1 })[opts.lua_impl:lower()] then
    optparser:opterr(fmt('--lua-impl="%s" is invalid, must be "PUC", or "LuaJIT"', opts.lua_impl))
  end

  local lua_incdir = opts.lua_incdir
  local lua_name = opts.lua_impl:lower() == 'luajit' and 'LuaJIT' or 'Lua'
  local lua_ver = opts.lua_version

  luarocks.set_link_static(true)
  luarocks.use_tree(opts.rocks_tree)

  if lua_incdir then
    if not is_file(lua_incdir..'/lua.h') then
      errorf('Cannot find lua.h in %s!', lua_incdir)
    end
  else
    lua_incdir, lua_ver = find_incdir(lua_name:lower(), lua_ver)
    if not lua_incdir then
      errorf('Cannot find headers for %s %s. Please specify --lua-incdir=DIR',
             lua_name, opts.lua_version or '')
    end
    log.debug('Using %s %s headers from: %s', lua_name, lua_ver or '', lua_incdir)
  end
  luarocks.set_variable('LUA_INCDIR', lua_incdir)

  local luaapi_ver = assert(luah_version(lua_incdir..'/lua.h')):match('^(%d+%.%d+)')
  log.debug('Detected Lua API %s', luaapi_ver)
  luarocks.change_target_lua(luaapi_ver, lua_name == 'LuaJIT' and lua_ver or nil)


  for _, rockspec in ipairs(args) do
    log.info('Building %s', rockspec)

    local ok, err = luarocks.build_and_install_rockspec(rockspec, opts.directory)
    if not ok then
      errorf('Failed to build %s: %s', rockspec, err)
    end
  end
end
