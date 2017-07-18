---------
-- Static analyser of dependencies between Lua modules.
----
local depgraph_scan = require 'depgraph.scan'
local globtopattern = require 'globtopattern'

local fs = require 'luapak.fs'
local pkgpath = require 'luapak.pkgpath'
local utils = require 'luapak.utils'

local any = utils.any
local check_args = utils.check_args
local dedup = utils.dedup
local default = utils.default
local dir_sep = pkgpath.dir_sep
local ends_with = utils.ends_with
local glob = globtopattern.globtopattern
local index_map = utils.index_map
local is_binary_file = fs.is_binary_file
local is_dir = fs.is_dir
local is_file = fs.is_file
local merge = utils.merge
local par = utils.partial
local path_mark = pkgpath.path_mark
local path_sep = pkgpath.path_sep
local push = table.insert
local push_all = utils.push_all
local read_file = fs.read_file
local reject = utils.reject
local split = utils.split
local starts_with = utils.starts_with
local unpack = table.unpack
local walk_dir = fs.walk_dir


--- Finds path of the given module `name` on the given `pkg_path`.
--
-- @tparam string name The module name in dot-notation.
-- @tparam string pkg_path The path where to look for modules (see `package.searchpath`).
-- @treturn string|nil Location of the module file (may be relative), or nil if not found.
local function locate_module (name, pkg_path)
  local ok, path = pcall(package.searchpath, name, pkg_path)
  if ok and path then
    return path
  end
end

--- Resolves requires in the given Lua source file.
--
-- @tparam string filename Path of the Lua source file to analyse.
-- @treturn[1] {table,...} A list of require info. Each info table contains the following keys:
--  `name`, `line`, `column`, and optionally: `conditional`, `lazy`, `protected`.
-- @treturn[2] nil
-- @treturn[2] string An error message.
local function resolve_requires (filename)
  local content, err = read_file(filename)
  if not content then
    return nil, err
  end

  return depgraph_scan(content)
end

--- Expands the given module path in dot-notation (prefix) ended with a wildcard
-- (e.g. `lua-rocks.build.*`) to a list of all modules on the `pkg_path` with
-- the matching prefix.
--
-- @tparam string pattern The require string ended with a wildcard.
-- @tparam string pkg_path The path where to look for modules (see @{package.searchpath}).
-- @treturn {string,...} A list of module names.
local function expand_wildcard_require (pattern, pkg_path)
  local mod_prefix = pattern:gsub('%.?%*', '')  -- remove wildcard
                            :gsub('%.', dir_sep)  -- convert "." to "/"
  local found = {}

  for _, path_tmpl in ipairs(split('%'..path_sep, pkg_path)) do
    -- e.g. foo/bar/?.lua -> foo/bar/, .lua
    local base_path, suffix = unpack(split('%'..path_mark, path_tmpl))
    local full_prefix = base_path..mod_prefix

    -- This typically happens when pkg_path contains trailing ";;".
    if path_tmpl == '' then  --luacheck: ignore
      --continue
    -- If path_tmpl is not a template, but a file path.
    elseif not suffix then
      if starts_with(mod_prefix, path_tmpl) and is_file(path_tmpl) then
        push(found, path_tmpl)
      end
    elseif is_dir(full_prefix) then
      for path in walk_dir(full_prefix) do
        if ends_with(suffix, path) then
          local mod_name = path:sub(#base_path + 1, -#suffix - 1)
                               :gsub('[/\\]', '.')
          push(found, mod_name)
        end
      end
    end
  end

  return found
end

--- Creates a predicate function from the given list of positive and negative string patterns.
--
-- @tparam {string,...} excludes A list of patterns that should be excluded.
-- @tparam ?{string,...} includes A list of patterns that should not be excluded.
-- @treturn function string -> bool
local function filter_predicate (excludes, includes)
  if not includes or #includes == 0 then
    includes = nil
  end

  return function (name)
    local match_name = par(string.match, name)

    return (not any(match_name, excludes))
        or (includes and any(match_name, includes))
  end
end

--- Converts glob patterns into Lua patterns.
--
-- @tparam {string,...} patterns List of glob patterns.
-- @treturn {string,...} A list of positive patterns
-- @treturn {string,...} A list of negative patterns.
local function convert_globs (patterns)
  local positive = {}
  local negative = {}

  for _, patt in ipairs(patterns) do
    if starts_with('!', patt) then
      push(negative, glob(patt:sub(2)))
    else
      push(positive, glob(patt))
    end
  end

  return positive, negative
end


local M = {}

--- Recursively resolves all dependencies (modules) of the given `entry_point`.
--
-- **Flags**:
--
-- * pcalls: Analyse pcall requires? (default: true)
-- * wildcards: Expand "wildcard" requires? (default: true)
--
-- @tparam string entry_point Path of Lua script, or name of Lua module.
-- @tparam ?string pkg_path The path where to look for modules (see `package.searchpath`).
--   Default is `<package.path>;<package.cpath>;;`.
-- @tparam ?function predicate The predicate function that is called with name of each module to be
--   processed. When it returns true, the module is processed, otherwise it's skipped.
-- @tparam ?{[string]=...} flags (See above)
-- @treturn {[string]=string,...} A map of found modules; key is the module name, value is the
--   source file path.
-- @treturn {string,...} A list of missing modules.
-- @treturn {string,...} A list of ignored modules.
-- @treturn {string,...} A list of error messages.
function M.analyse (entry_point, pkg_path, predicate, flags)
  check_args('string|table, ?string, ?function, ?table',
             entry_point, pkg_path, predicate, flags)

  flags = flags or {}
  pkg_path = pkg_path or package.path..';'..package.cpath..';;'

  local pcalls = default(true, flags.pcalls)
  local wildcards = default(true, flags.wildcards)
  local visited = {}
  local found, missing, ignored, errors = {}, {}, {}, {}

  local scan_file, scan_module

  scan_module = function (name)
    if name == '' or name == '*' or visited[name] then
      return
    end
    visited[name] = true

    if predicate and not predicate(name) then
      push(ignored, name)
      return
    end

    -- module name with wildcard
    if ends_with('.*', name) then
      if not wildcards then
        push(ignored, name)
        return
      end

      local ok = false
      for _, modname in ipairs(expand_wildcard_require(name, pkg_path)) do
        scan_module(modname)
        ok = true
      end

      return ok

    -- normal module name
    else
      local path = locate_module(name, pkg_path)
      if not path then
        push(missing, name)
        return
      end
      found[name] = path

      if ends_with('.lua', path) and not is_binary_file(path) then
        scan_file(path)
      end

      return true
    end
  end

  scan_file = function (path)
    local requires, err = resolve_requires(path)
    if err then
      push(errors, err)
      return
    end

    for _, info in ipairs(requires) do
      if not pcalls and info.protected then
        push(ignored, info.name)
      else
        scan_module(info.name)
      end
    end
  end

  if is_file(entry_point) then
    scan_file(entry_point)
  elseif not scan_module(entry_point) then
    push(errors, 'Entry point not found: '..entry_point)
  end

  return found, missing, ignored, errors
end
local analyse = M.analyse

--- Recursively analyses all dependencies (modules) of the given `entry_points`.
--
-- @tparam {string,...}|string entry_points Path(s) of Lua script, or name(s) of Lua module.
-- @tparam ?string pkg_path The path where to look for modules (see `package.searchpath`).
--   Default is `<package.path>;<package.cpath>;;`.
-- @tparam ?{string,...} excludes Module(s) to exclude from the analysis; one or more
--   glob patterns matching module name in dot notation (e.g. `"pl.*"`).
-- @tparam ?{[string]=bool,...} flags See @{analyse}.
-- @treturn {[string]=string,...} A map of found modules; key is the module name, value is the
--   source file path.
-- @treturn {string,...} A list of missing modules.
-- @treturn {string,...} A list of ignored/excluded modules.
-- @treturn {string,...} A list of error messages.
function M.analyse_with_filter (entry_points, pkg_path, excludes, flags)
  check_args('string|table, ?string, ?table, ?table',
             entry_points, pkg_path, excludes, flags)

  local predicate
  if excludes and excludes[1] then
    predicate = filter_predicate(convert_globs(excludes))
  end

  if type(entry_points) == 'string' then
    return analyse(entry_points, pkg_path, predicate, flags)

  else
    local found, missing, ignored, errors = {}, {}, {}, {}

    for _, entry_point in ipairs(entry_points) do
      local f, m, i, e = analyse(entry_point, pkg_path, predicate, flags)
      push(found, f)
      push_all(missing, m)
      push_all(ignored, i)
      push_all(errors, e)
    end

    found = merge(unpack(found))
    dedup(missing)
    dedup(ignored)
    do
      local index = index_map(entry_points)
      ignored = reject(function(v) return index[v] end, ignored)
    end

    return found, missing, ignored, errors
  end
end

return M
