---------
-- The main build module that handles complete process of building standalone executable.
----
local deps_analyser = require 'luapak.deps_analyser'
local fs = require 'luapak.fs'
local log = require 'luapak.logging'
local lua_finder = require 'luapak.lua_finder'
local luarocks = require 'luapak.luarocks.init'
local pkg = require 'luapak.pkgpath'
local merger = require 'luapak.merger'
local minifier = require 'luapak.minifier'
local toolchain = require 'luapak.build.toolchain.init'
local utils = require 'luapak.utils'
local wrapper = require 'luapak.wrapper'

local absolute_path = fs.absolute_path
local basename = fs.basename
local check_args = utils.check_args
local concat = table.concat
local dirname = fs.dirname
local insert = table.insert
local is_dir = fs.is_dir
local is_file = fs.is_file
local ends_with = utils.ends_with
local errorf = utils.errorf
local find_incdir = lua_finder.find_incdir
local find_liblua = lua_finder.find_liblua
local luah_version = lua_finder.luah_version
local fmt = string.format
local last = utils.last
local push = table.insert
local read_file = fs.read_file
local remove_shebang = utils.remove_shebang
local size = utils.size
local split = utils.split
local unpack = table.unpack


--- Returns path and name of **single** CLI script specified in the rockspec.
-- Or returns nil if:
--
-- 1. the rockspec is unreadable,
-- 2. there's no script defined in `build.install.bin`,
-- 3. there's more than one script in `build.install.bin`.
--
-- @tparam string rockspec_file Path of the rockspec file.
-- @treturn[1] string Path of the script file relative to the project's dir.
-- @treturn[1] string Target name of the script.
-- @treturn[2] nil
-- @treturn[2] string An error message.
local function default_entry_script (rockspec_file)
  local rockspec, err = luarocks.load_rockspec(rockspec_file)
  if not rockspec then
    return nil, err
  end

  local exists, scripts = pcall(function ()
      return rockspec.build.install.bin
    end)

  if not exists or not next(scripts) then
    return nil, 'No bin script specified in the rockspec'
  elseif size(scripts) > 1 then
    return nil, 'More than one CLI script specified in the rockspec'
  else
    local name, file = next(scripts)
    if type(name) ~= 'string' then
      name = basename(file)
    end
    return file, name
  end
end

--- Guesses project's base directory from the rockspec path.
--
-- @tparam string rockspec_file Path of the rockspec file.
-- @treturn string Absolute path of the project's directory.
local function rockspec_project_dir (rockspec_file)
  local rockspec_dir = dirname(absolute_path(rockspec_file))

  if basename(rockspec_dir):find('^rockspecs?$') then
    return dirname(rockspec_dir)
  else
    return rockspec_dir
  end
end

--- Resolves project paths from the CLI arguments.
--
-- @tparam {string,...} proj_paths
-- @treturn {{string,string},...} A list of pairs: path of the project's base
--   directory, absolute path of the rockspec.
-- @raise if rockspec is not specified or there is no unambiguous rockspec in
--   the project's directory.
local function resolve_proj_paths (proj_paths)
  local list = {}

  for _, path in ipairs(proj_paths) do
    if path:find(':') then
      local proj_dir, rockspec_file = unpack(split('%:', path))
      push(list, { proj_dir, absolute_path(rockspec_file, proj_dir) })
    elseif ends_with('.rockspec', path) then
      push(list, { rockspec_project_dir(path), absolute_path(path) })
    else
      local rockspec_file = assert(luarocks.find_default_rockspec(path),
          fmt('No unambiguous rockspec found in %s, specify the rockspec to use', path))
      push(list, { path, rockspec_file })
    end
  end

  return list
end

--- Resolves the entry script's dependencies, logs results
-- and returns lists of modules and objects.
--
-- @tparam string entry_script Path of the the Lua script.
-- @tparam ?{string,...} extra_modules Paths of additional Lua scripts to scan.
-- @tparam ?{string,...} excludes Module(s) to exclude from the analysis; one or more
--   glob patterns matching module name in dot notation (e.g. `"pl.*"`).
-- @tparam ?string pkg_path The path where to look for modules (see `package.searchpath`).
-- @treturn {table,...} A list of module entries.
-- @treturn {string,...} A list of paths of the object files (native extensions).
-- @raise is some error accured.
local function resolve_dependencies (entry_script, extra_modules, excludes, pkg_path)
  local entry_points = { entry_script, unpack(extra_modules or {}) }
  local lib_ext = luarocks.cfg.lib_extension
  local lmods = {}
  local cmod_names = {}
  local cmod_paths = {}

  local found, missing, ignored, errors =
      deps_analyser.analyse_with_filter(entry_points, pkg_path, excludes)

  if #errors > 0 then
    error(concat(errors, '\n'))
  end
  if log.is_warn and #missing > 0 then
    log.warn('The following modules are required, but not found:\n   %s',
             concat(missing, '\n   '))
  end
  if log.is_debug and #ignored > 0 then
    log.debug('The following modules have been excluded:\n   %s',
              concat(ignored, '\n   '))
  end

  log.debug('Found required modules:')
  for name, path in pairs(found) do
    log.debug('   %s (%s)', name, path)

    if ends_with('.lua', path) then
      lmods[name] = path
    elseif ends_with('.'..lib_ext, path) then
      push(cmod_names, name)
      push(cmod_paths, path)
    else
      log.warn('Skipping module with unexpected file extension: %s', path)
    end
  end
  log.debug('')

  return lmods, cmod_names, cmod_paths
end

local function init_minifier (opts)
  local min_opts = opts.debug
      and { keep_lno = true, keep_names = true }
      or {}
  local minify = minifier(min_opts)

  return function (chunk, name)
    local minified, err = minify(chunk, name)
    if err then
      log.warn(err)
    end
    return minified or chunk
  end
end

local function generate_wrapper (output_file, entry_script, lua_modules, native_modules, opts)
  local file = assert(io.open(output_file, 'w'))

  local buff = {}
  merger.merge_modules(lua_modules, opts.debug, function (data)
      push(buff, data)
    end)
  push(buff, remove_shebang(entry_script))

  wrapper.generate(concat(buff), native_modules, opts, function (...)
      assert(file:write(...))
    end)

  assert(file:flush())
  file:close()
end

local function build (proj_paths, entry_script, output_file, pkg_path, lua_lib, opts)
  local main_src = output_file:gsub('.exe$', '')..'.c'
  local main_obj = main_src:gsub('c$', '')..luarocks.cfg.obj_extension

  for _, item in ipairs(proj_paths) do
    local proj_dir, rockspec_file = unpack(item)

    log.info('Building %s (%s)', rockspec_file, proj_dir)

    local ok, err = luarocks.build_and_install_rockspec(rockspec_file, proj_dir)
    if not ok then
      errorf('Failed to build %s: %s', rockspec_file, err)
    end
  end

  log.info('Resolving dependencies...')
  local lua_modules, native_modules, objects = resolve_dependencies(
      entry_script, opts.extra_modules, opts.exclude_modules, pkg_path)
  insert(objects, 1, main_obj)
  push(objects, lua_lib)

  local minify
  if opts.minify then
    log.info('Loading and minifying Lua modules...')
    minify = init_minifier(opts)
  else
    log.info('Loading Lua modules...')
    minify = function (...) return ... end
  end

  entry_script = minify(assert(read_file(entry_script)))
  for name, path in pairs(lua_modules) do
    lua_modules[name] = minify(assert(read_file(path)))
  end

  log.info('Generating %s...', main_src)
  generate_wrapper(main_src, entry_script, lua_modules, native_modules, opts)

  luarocks.set_variable('CFLAGS', '-std=c99 '..luarocks.get_variable('CFLAGS'))
  local vars = luarocks.cfg.variables

  log.info('Compiling %s...', main_obj)
  assert(toolchain.compile_object(vars, main_obj, main_src), 'Failed to compile '..main_obj)

  log.info('Linking %s...', output_file)
  assert(toolchain.link_binary(vars, output_file, objects, { 'm' }),  -- "m" is math library
         'Failed to link '..output_file)
  if not opts.debug then
    assert(toolchain.strip(vars, output_file), 'Failed to strip '..output_file)
  end

  log.info('Build completed: %s', output_file)

  os.remove(main_src)
  os.remove(main_obj)
end


--- Makes a standalone executable from the Lua project(s).
--
-- @function __call
-- @tparam {string,...} proj_paths
-- @tparam ?string entry_script Path of the main Lua script.
-- @tparam ?string output_file Name of the output binary.
-- @tparam ?string rocks_dir Directory where to install required modules.
-- @tparam ?table opts Options.
-- @raise if some error occurred.
return function (proj_paths, entry_script, output_file, rocks_dir, opts)
  check_args('table, ?string, ?string, ?string, ?table',
             proj_paths, entry_script, output_file, rocks_dir, opts)

  proj_paths = resolve_proj_paths(proj_paths)
  rocks_dir = rocks_dir or '.luapak'
  opts = opts or {}

  local lua_lib = opts.lua_lib
  local lua_incdir = opts.lua_incdir
  local lua_name = opts.lua_impl == 'luajit' and 'LuaJIT' or 'Lua'
  local lua_ver = opts.lua_version

  luarocks.set_link_static(true)
  luarocks.use_tree(rocks_dir)

  if not entry_script then
    local proj_dir, rockspec = unpack(last(proj_paths))
    local file, name = default_entry_script(rockspec)
    if not file then
      errorf('%s, please specify entry_script', name)
    end
    entry_script = proj_dir..'/'..file
    output_file = 'dist/'..name:gsub('%.lua', '')

    log.debug('Using entry script: %s', entry_script)
  elseif not output_file then
    output_file = basename(entry_script):gsub('%.lua', '')
  end

  if luarocks.is_windows and not ends_with('.exe') then
    output_file = output_file..'.exe'
  end

  if is_dir(output_file) then
    errorf('Cannot create file "%s", because it is a directory', output_file)
  end

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

  if not lua_lib then
    lua_lib = find_liblua(luarocks.cfg.lib_extension, lua_name:lower(), lua_ver)
    if not lua_lib then
      errorf('Cannot find %s %s library. Please specify --lua-lib=PATH', lua_name, lua_ver)
    end
    log.debug('Using %s %s library: %s', lua_name, lua_ver, lua_lib)
  elseif not is_file(lua_lib) then
    errorf('File %s does not exist!', lua_lib)
  end
  luarocks.set_variable('LUA_LIBDIR', dirname(lua_lib))
  luarocks.set_variable('LUALIB', basename(lua_lib))

  -- Create output directory if not exists.
  if not is_dir(dirname(output_file) or '.') then
    assert(fs.mkdir(dirname(output_file)))
  end

  local pkg_path = pkg.fhs_path(rocks_dir, luaapi_ver, luarocks.cfg.lib_extension)

  return build(proj_paths, entry_script, output_file, pkg_path, lua_lib, opts)
end
