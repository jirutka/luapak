---------
-- Facade for interaction with LuaRocks.
----
require 'luapak.luarocks.site_config'
require 'luapak.luarocks.cfg_extra'
package.loaded['luarocks.build.builtin'] = require 'luapak.build.builtin'

local warn_interceptor = require 'luapak.build.warn_interceptor'

for _, name in ipairs { 'cmake', 'command', 'make' } do
  name =  'luarocks.build.'..name
  package.loaded[name] = warn_interceptor(require(name))
end

local cfg = require 'luarocks.cfg'
local build = require 'luarocks.build'
local fetch = require 'luarocks.fetch'
local fs = require 'luarocks.fs'
local path = require 'luarocks.path'
local util = require 'luarocks.util'

local const = require 'luapak.luarocks.constants'


local function run_in_dir (dir, func, ...)
  local old_pwd = fs.current_dir()

  if dir then fs.change_dir(dir) end
  local result = { func(...) }
  if dir then fs.change_dir(old_pwd) end

  -- XXX: Workaround for incorrect behaviour of unpack on sparse tables.
  return result[1], result[2], result[3], result[4]
end


local M = {}

--- The configuration table.
M.cfg = cfg

--- Do we run on Windows?
M.is_windows = cfg.platforms.windows

--- Builds and installs local rock specified by the rockspec.
--
-- @tparam string rockspec_file Path of the rockspec file.
-- @tparam string proj_dir The base directory with the rock's sources.
function M.build_and_install_rockspec (rockspec_file, proj_dir)
  return run_in_dir(proj_dir,
      build.build_rockspec, rockspec_file, false, true, 'one', false)
end

--- Changes the target Lua version.
--
-- @tparam string api_ver The Lua API version in format `x.y` (e.g. 5.1).
-- @tparam ?string luajit_ver The LuaJIT version, or nil if target is not LuaJIT.
function M.change_target_lua (api_ver, luajit_ver)
  cfg.lua_version = api_ver
  cfg.luajit_version = luajit_ver

  cfg.rocks_provided.lua = api_ver..'-1'
  if api_ver == '5.2' then
    cfg.rocks_provided.bit32 = '5.2-1'
  elseif api_ver == '5.3' then
    cfg.rocks_provided.utf8 = '5.3-1'
  end

  if luajit_ver then
    cfg.rocks_provided.luabitop = luajit_ver:gsub('%-', '')..'-1'

    if cfg.is_platform('macosx') then
      -- See http://luajit.org/install.html#embed.
      local ldflags = cfg.variables.LDFLAGS or ''
      cfg.variables.LDFLAGS = const.LUAJIT_MACOS_LDFLAGS..' '..ldflags
    end
  else
    cfg.rocks_provided.luabitop = nil
  end
end

--- Looks for the default rockspec file in the project's directory.
--
-- @tparam string proj_dir The project's base directory.
-- @treturn[1] string An absolute path of the found rockspec file.
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.find_default_rockspec (proj_dir)
  local filename, err = run_in_dir(proj_dir, util.get_default_rockspec)
  if not filename then
    return nil, err
  end

  return fs.absolute_name(filename)
end

--- Gets LuaRocks variable from `cfg.variables` table.
function M.get_variable (name)
  return cfg.variables[name]
end

--- Loads the specified rockspec into a table.
--
-- @tparam string rockspec_file Path of the rockspec file.
-- @treturn[1] table A rockspec's table.
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.load_rockspec (rockspec_file)
  return fetch.load_rockspec(rockspec_file)
end

--- Switches LuaRocks to use static or dynamic linking.
--
-- @tparam bool enabled true to use static linking, false to use
--   dynamic linking.
function M.set_link_static (enabled)
  if enabled then
    cfg.link_static = true
    cfg.lib_extension = cfg.static_lib_extension
  else
    cfg.link_static = false
    cfg.lib_extension = cfg.shared_lib_extension
  end

  if cfg.variables.LUALIB then
    cfg.variables.LUALIB = cfg.variables.LUALIB:gsub('%.[^.]+$', '.'..cfg.lib_extension)
  end

  cfg.variables.LIB_EXTENSION = cfg.lib_extension
end

--- Sets LuaRocks variable into `cfg.variables` table.
function M.set_variable (name, value)
  cfg.variables[name] = value
end

---
-- @tparam string dirname Path of the directory.
function M.use_tree (dirname)
  local old_root_dir = cfg.root_dir
  local prefix = cfg.variables.LUAROCKS_PREFIX

  dirname = fs.absolute_name(dirname)
  path.use_tree(dirname)

  if prefix == old_root_dir or prefix == const.LUAROCKS_FAKE_PREFIX then
    cfg.variables.LUAROCKS_PREFIX = dirname
  end
end

return M
