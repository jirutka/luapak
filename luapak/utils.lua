---------
-- General utility functions.
--
-- **Note: This module is not part of public API!**
----
require 'luapak.compat'

local fmt = string.format
local gmatch = string.gmatch
local insert = table.insert
local io_type = io.type
local pairs = pairs
local select = select
local sort = table.sort
local sub = string.sub
local stdout = io.stdout
local type = type
local unpack = table.unpack

local M = {}

--- Version of the Lua interpreter running this code in format x.y.
M.LUA_VERSION = _VERSION:match(' (5%.[123])$') or '5.1'


--- Returns a function that always returns the given `value`.
--
-- @param value
-- @treturn function () -> value
function M.always (value)
  return function ()
    return value
  end
end

--- Returns true if at least one of elements of the `list` match the predicate, false otherwise.
--
-- @tparam function func The predicate function.
-- @tparam table list The list to test.
-- @treturn bool Whether the predicate is satisfied by at least one element.
function M.any (func, list)
  for _, item in ipairs(list) do
    if func(item) then
      return true
    end
  end
end

--- Checks that the given arguments have the correct type.
--
-- @usage check_args('table, string|table, ?table', a, b, c)
--
-- @tparam string type_specs A colon separated list of allowed types for each argument.
--   Multiple allowed types per argument are separated by `|` (without spaces).
-- @param ... Arguments to check against `type_specs`.
-- @raise on type mismatch.
function M.check_args (type_specs, ...)
  local n = 1
  for spec in gmatch(type_specs, '([^, ]+)') do
    local arg = select(n, ...) or nil

    local actual_type = type(arg)
    if actual_type == 'userdata' then
      actual_type = io_type(arg) or actual_type
    end

    local ok = false

    local nullable = sub(spec, 1, 1) == '?'
    if nullable then
      spec = sub(spec, 2)
    end

    if spec == actual_type then
      ok = true
    elseif nullable and actual_type == 'nil' then
      ok = true
    else
      for ttype in gmatch(spec, '([^|]+)') do
        if actual_type == ttype then
          ok = true
          break
        end
      end
    end
    if not ok then
      error(fmt("bad argument #%d: expected %s, got a %s",
            n, spec, actual_type), 2)
    end
    n = n + 1
  end
end

--- Removes repeated elements from the given `list` (in-place).
--
-- @tparam table list The list to deduplicate.
-- @treturn table A sorted list of unique elements.
function M.dedup (list)
  sort(list)

  -- Deduplicate the table in-place.
  local idx, last = 1, nil
  for _, item in ipairs(list) do
    if item ~= last then
      list[idx] = item
      last = item
      idx = idx + 1
    end
  end

  -- Remove extra items after the deduplicated part of the table.
  for i=#list, idx, -1 do
    list[i] = nil
  end

  return list
end

--- Returns `value` if it's not nil, otherwise returns `default`.
function M.default (default, value)
  if value == nil then
    return default
  else
    return value
  end
end

--- Returns true if the string `str` ends with the `suffix`.
--
-- @tparam string suffix
-- @tparam string str
-- @treturn bool
function M.ends_with (suffix, str)
  return sub(str or '', -#suffix) == suffix
end

--- The same as @{error}, but with formatted message.
--
-- @tparam string message The error message.
-- @param ... Arguments for @{string.format} being applied to the `message`.
function M.errorf (message, ...)
  error(fmt(message, ...), 2)
end

--- Returns a new list containing the items in the given `list` for which
-- the `predicate` function does *not* return false or nil.
--
-- @tparam function predicate
-- @tparam table list
-- @treturn table
function M.filter (predicate, list)
  local result = {}

  for _, item in ipairs(list) do
    if predicate(item) then
      insert(result, item)
    end
  end

  return result
end

--- Searches through the `list` and returns the first value that passes
-- the `predicate` function.
--
-- @tparam function predicate
-- @tparam table list
-- @return The first list's value passing `predicate`.
function M.find (predicate, list)
  for _, item in ipairs(list) do
    if predicate(item) then
      return item
    end
  end
end

--- Returns true if the `value` is nil or empty string.
--
-- @param value
-- @treturn bool
function M.is_empty (value)
  return value == nil or value == ''
end

--- Create an index map from the `list`. The original values become keys, and
-- the associated values are the indices into the original `list`.
--
-- @tparam table list
-- @treturn table
function M.index_map (list)
  local map = {}
  for i, item in ipairs(list) do
    map[item] = i
  end
  return map
end

--- Returns the last element of the `list`.
--
-- @tparam table list
-- @return Last element of the `list`.
function M.last (list)
  return list[#list]
end

--- Returns a new table containing the contents of all the given tables.
-- Tables are iterated using @{pairs}, so this function is intended for tables
-- that represent *associative arrays*. Entries with duplicate keys are
-- overwritten with the values from a later table.
--
-- @tparam {table,...} ... The tables to merge.
-- @treturn table A new table.
function M.merge (...)
  local result = {}

  for _, tab in ipairs{...} do
    for key, val in pairs(tab) do
      result[key] = val
    end
  end

  return result
end

--- Partial application.
-- Takes a function `func` and arguments, and returns a function *func2*.
-- When applied, *func2* returns the result of applying `func` to the arguments
-- provided initially followed by the arguments provided to *func2*.
--
-- @tparam function func
-- @param ... Arguments to pass to the `func`.
-- @treturn function A partially applied function.
function M.partial (func, ...)
  local n = select('#', ...)

  if n == 1 then  -- optimisation for 1 argument
    local arg1 = select(1, ...)
    return function (...) return func(arg1, ...) end
  else
    local args = {...}
    return function (...) return func(unpack(args), ...) end
  end
end

--- Prints the given string to the stdout, ended with a newline.
--
-- @tparam string str The string to print.
-- @param ... Arguments for @{string.format} being applied to the `str`.
function M.printf (str, ...)
  stdout:write(fmt(str..'\n', ...))
end

--- Inserts items from the `src` list at the end of the `dest` list and returns
-- modified `dest` (i.e. it modifies it in-place!).
--
-- @tparam table dest The destination list to extend.
-- @tparam table src The source list to take items from.
-- @treturn table The given `dest` list.
function M.push_all (dest, src)
  for _, item in ipairs(src) do
    insert(dest, item)
  end
  return dest
end

--- Returns a new list containing the items in the given `list` for which
-- the `predicate` function returns false or nil.
--
-- @tparam function predicate
-- @tparam table list
-- @treturn table
function M.reject (predicate, list)
  local result = {}

  for _, item in ipairs(list) do
    if not predicate(item) then
      insert(result, item)
    end
  end

  return result
end

--- Returns copy of the given `chunk` without shebang.
--
-- @tparam string chunk
-- @treturn string
function M.remove_shebang (chunk)
  return (chunk:gsub('^#%!.-\n', ''))
end

--- Makes a shallow clone of the given table.
--
-- @tparam table tab
-- @treturn table
function M.shallow_clone (tab)
  local res = {}
  for k, v in pairs(tab) do
      res[k] = v
  end
  return res
end

--- Counts total number of elements in the given table; both in the array part
-- and the hash part.
--
-- @tparam table tab The table to count size of.
-- @treturn int A total number of elements.
function M.size (tab)
  local i = 0
  for _ in pairs(tab) do
    i = i + 1
  end
  return i
end

--- Splits the given `str` into a list of strings based on
-- the delimiter `delim`. If the `str` is falsy, then empty table is returned.
--
-- @tparam string delim The delimiter pattern.
-- @tparam string ?str The string to split.
-- @treturn {string,...}
function M.split (delim, str)
  if not str then return {} end

  local t = {}
  local init = 1

  while true do
    local delim_start, delim_end = str:find(delim, init)
    insert(t, str:sub(init, (delim_start or 0) - 1))
    if not delim_end then
      break
    end
    init = delim_end + 1
  end

  return t
end

--- Returns true if the string `str` starts with the `prefix`.
--
-- @tparam string prefix
-- @tparam string str
-- @treturn bool
function M.starts_with (prefix, str)
  return sub(str or '', 1, #prefix) == prefix
end

--- Wraps the given value to a table, or returns as-is if it is table.
--
-- @param value The value to wrap.
-- @treturn table A table.
function M.tableize (value)
  if type(value) == 'table' then
    return value
  else
    return { value }
  end
end

return M
