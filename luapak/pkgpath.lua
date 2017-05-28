---------
-- Utility functions for @{package}.
--
-- **Note: This module is not part of public API!**
----
local utils = require 'luapak.utils'

local concat = table.concat
local fmt = string.format
local push = table.insert
local split = utils.split

local pkgconfig = split('\n', package.config)


local M = {}

--- The directory separator string.
M.dir_sep = pkgconfig[1] or '/'

--- The character that separates templates in a path.
M.path_sep = pkgconfig[2] or ';'

--- The string that marks the substitution points in a template.
M.path_mark = pkgconfig[3] or '?'


local function fix_path (path)
  return path:gsub('/+', '/')
             :gsub('/', M.dir_sep)
             :gsub(';', M.path_sep)
             :gsub('%?', M.path_mark)
end

--- Creates standard Lua package path for pure Lua modules and optionally native modules.
--
-- @tparam string prefix The directory prefix for the path (default: "").
-- @tparam ?string lua_ver Lua API version (e.g. "5.3"). Defaults to version of this process' Lua.
-- @tparam ?string lib_ext File extension of native libraries.
--   If not specified, then path for native libraries will be omitted.
-- @tparam ?string lua_ext File extension for Lua files (default: "lua").
-- @treturn string Lua package path.
function M.fhs_path (prefix, lua_ver, lib_ext, lua_ext)
  prefix = prefix or ''
  lua_ver = lua_ver or utils.LUA_VERSION
  lua_ext = lua_ext or 'lua'

  local paths = {
    fmt('%s/share/lua/%s/?.%s', prefix, lua_ver, lua_ext),
    fmt('%s/share/lua/%s/?/init.%s', prefix, lua_ver, lua_ext),
  }
  if lib_ext then
    push(paths, fmt('%s/lib/lua/%s/?.%s', prefix, lua_ver, lib_ext))
  end

  return fix_path(concat(paths, ';'))
end

return M
