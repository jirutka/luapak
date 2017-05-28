---------
-- The builtin builder based on LuaRocks builtin.
----
local cfg = require 'luarocks.cfg'
local dir = require 'luarocks.dir'
local fs = require 'luarocks.fs'
local path = require 'luarocks.path'

local utils = require 'luapak.utils'
local toolchain = require 'luapak.build.toolchain.init'

local base_name = dir.base_name
local check_args = utils.check_args
local dir_name = dir.dir_name
local dir_path = dir.path
local fmt = string.format
local fs_copy = fs.copy
local make_dir = fs.make_dir
local module_to_path = path.module_to_path
local push = table.insert
local tableize = utils.tableize


--- Installs the specified files to their destination paths.
--
-- @tparam {[string]=string,...} mapping The mapping table where key is path of a source file and
--   value is its destination path.
-- @tparam string perms The destination file permissions (e.g. "0644").
-- @treturn[1] true
-- @treturn[2] nil
-- @treturn[2] string An error message.
local function install_files (mapping, perms)
  for src, dest in pairs(mapping) do
    make_dir(dir_name(dest))

    local ok, err = fs_copy(src, dest, perms)
    if not ok then
      return nil, fmt('Failed installing %s in %s: %s', src, dest, err)
    end
  end

  return true
end


local M = {}

--- Creates a builtin builder.
-- This function is based on `luarocks.build.builtin`.
--
-- @tparam function compile_object
-- @tparam function create_library
-- @treturn function A function that accepts rockspec table.
function M.create_builder (compile_object, create_library)
  check_args('function, function', compile_object, create_library)

  --- Returns destination file name of the given module.
  --
  -- @tparam string name Name of the Lua module.
  -- @tparam string src_file Relative path of the module's source file.
  -- @treturn string File path relative to the rock's directory.
  local function luamod_install_path (name, src_file)
    local mod_dir = module_to_path(name)
    local filename = base_name(src_file)

    if filename == 'init.lua' and not name:match('%.init$') then
      mod_dir = module_to_path(name..'.init')
    else
      filename = name:match('([^.]+)$')..'.lua'
    end

    return dir_path(mod_dir, filename)
  end

  --- Builds native module.
  --
  -- @tparam string name Name of the native module.
  -- @tparam table info
  -- @tparam table vars
  -- @treturn[1] File name of the built library.
  -- @treturn[2] nil
  -- @treturn[2] string An error message.
  local function build_native_module (name, info, vars)
    local mod_dir = module_to_path(name)
    local objects = {}
    local sources = tableize(info[1] and info or info.sources)

    for _, source in ipairs(sources) do
      local obj_file = source:gsub('%f[^.]%.[^.]*$', '')..'.'..cfg.obj_extension

      local ok = compile_object(vars, obj_file, source, info.defines, info.incdirs)
      if not ok then
        return nil, 'Failed to compile: '..obj_file
      end

      push(objects, obj_file)
    end

    local lib_file = name:match('([^.]*)$')..'.'..cfg.lib_extension
    if mod_dir ~= '' then
      lib_file = dir_path(mod_dir, lib_file)

      local ok, err = make_dir(mod_dir)
      if not ok then
        return nil, err
      end
    end

    local ok = create_library(vars, lib_file, objects, info.libraries, info.libdirs)
    if not ok then
      return nil, 'Failed to create: '..lib_file
    end

    return lib_file
  end


  return function (rockspec)
    check_args('table', rockspec)

    local build = rockspec.build
    local vars = rockspec.variables
    local luadir = path.lua_dir(rockspec.name, rockspec.version)
    local libdir = path.lib_dir(rockspec.name, rockspec.version)
    local lua_modules = {}
    local native_modules = {}

    if not build.modules then
      return nil, 'Missing build.modules table'
    end

    for name, info in pairs(build.modules) do
      if type(info) == 'string' then
        if info:match('(%.[^.]+)$') == '.lua' then
          -- Lua module
          local lua_file = luamod_install_path(name, info)
          lua_modules[info] = dir_path(luadir, lua_file)
        else
          info = { info }
        end
      end

      -- Native module
      if type(info) == 'table' then
        local lib_file, err = build_native_module(name, info, vars)
        if not lib_file then
          return nil, err
        end

        native_modules[lib_file] = dir_path(libdir, lib_file)
      end
    end

    do local ok, err = install_files(lua_modules, '0644')
      if not ok then return nil, err end
    end

    do local ok, err = install_files(native_modules, '0755')
      if not ok then return nil, err end
    end

    if fs.is_dir('lua') then
      local ok, err = fs.copy_contents('lua', luadir)
      if not ok then
        return nil, 'Failed copying contents of "lua" directory: '..err
      end
    end

    return true
  end
end

--- Builds and installs the given rockspec.
--
-- @tparam table rockspec The rockspec as a table.
-- @treturn[1] true
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.run (rockspec)
  local builder
  if cfg.link_static then
    builder = M.create_builder(toolchain.compile_object, toolchain.create_static_lib)
  else
    builder = M.create_builder(toolchain.compile_object, toolchain.create_shared_lib)
  end

  return builder(rockspec)
end

return M
