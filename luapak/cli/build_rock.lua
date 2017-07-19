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

  -I, --lua-incdir=DIR        The directory that contains Lua headers.

  -l, --lua-version=VERSION   The version number of Lua headers to try to find (e.g. "5.3").

  -t, --rocks-tree=DIR        The prefix where to install Lua/C modules Default is ".luapak" in
                              the current directory.

  -v, --verbose               Be verbose, i.e. print debug messages.

  -h, --help                  Display this help message and exit.

Environment Variables:
  AR          Archive-maintaining program; default is "ar".
  CC          Command for compiling C; default is "gcc".
  CMAKE       Command for processing CMakeLists.txt files; default is "cmake".
  CFLAGS      Extra flags to give to the C compiler; default is "-O2".
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
  local args, opts = optparser:parse(arg)

  if #args == 0 then
    optparser:opterr('no ROCKSPEC specified')
  end

  local lua_incdir = opts.lua_incdir
  local lua_ver = opts.lua_version

  luarocks.set_link_static(true)
  luarocks.use_tree(opts.rocks_tree)

  if lua_incdir then
    if not is_file(lua_incdir..'/lua.h') then
      errorf('Cannot find lua.h in %s!', lua_incdir)
    elseif not lua_ver then
      lua_ver = assert(luah_version(lua_incdir..'/lua.h'))
      log.debug('Detected Lua %s', lua_ver)
    end
  else
    lua_incdir, lua_ver = find_incdir(lua_ver)
    if not lua_incdir then
      errorf('Cannot find Lua %s headers. Please specify --lua-incdir=DIR',
             opts.lua_version or '')
    end
    log.debug('Using Lua %s headers from: %s', lua_ver, lua_incdir)
  end
  luarocks.set_variable('LUA_INCDIR', lua_incdir)

  if luarocks.cfg.lua_version ~= lua_ver then
    luarocks.set_lua_version(lua_ver)
  end

  for _, rockspec in ipairs(args) do
    log.info('Building %s', rockspec)

    local ok, err = luarocks.build_and_install_rockspec(rockspec, opts.directory)
    if not ok then
      errorf('Failed to build %s: %s', rockspec, err)
    end
  end
end
