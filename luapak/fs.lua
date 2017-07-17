---------
-- Utility functions for operations on a file system and paths.
-- Extends LuaFileSystem module.
--
-- **Note: This module is not part of public API!**
----
local lfs = require 'lfs'
local pkgpath = require 'luapak.pkgpath'
local utils = require 'luapak.utils'

local concat = table.concat
local cowrap = coroutine.wrap
local file_attrs = lfs.attributes
local fmt = string.format
local iter_dir = lfs.dir
local open = io.open
local yield = coroutine.yield

local UTF8_BOM = '\239\187\191'
local NUL_PATT = utils.LUA_VERSION == '5.1' and '%z' or '\0'

local function normalize_io_error (name, err)
  if err:sub(1, #name + 2) == name..': ' then
    err = err:sub(#name + 3)
  end
  return err
end


local M = {}

--- Converts the `path` to an absolute path.
--
-- Relative paths are referenced from the current working directory of
-- the process unless `relative_to` is given, in which case it will be used as
-- the starting point. If the given pathname starts with a `~` it is NOT
-- expanded, it is treated as a normal directory name.
--
-- @tparam string path The path name to convert.
-- @tparam ?string relative_to The path to prepend when making `path` absolute.
--   Defaults to the current working directory.
-- @treturn string An absolute path name.
function M.absolute_path (path, relative_to)
  local fs = require 'luarocks.fs'  -- XXX: lua-rocks implementation
  return fs.absolute_name(path, relative_to)
end

-- Returns the file name of the `path`, i.e. the last component of the `path`.
--
-- @tparam string path The path name.
-- @treturn string The file name.
function M.basename (path)
  return (path:match('[/\\]([^/\\]+)[/\\]*$')) or path
end

--- Returns the directory name of the `path`, i.e. all the path's components
-- except the last one.
--
-- @tparam string path The path name.
-- @treturn string|nil The directory name, or nil if the `path` has
--   only one component (e.g. `/foo` or `foo`).
function M.dirname (path)
  return path:match('^(.-)[/\\]+[^/\\]*[/\\]*$')
end

--- Checks if the specified file is a binary file (i.e. not textual).
--
-- @tparam string filename Path of the file.
-- @treturn[1] bool true if the file is binary, false otherwise.
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.is_binary_file (filename)
  local handler, err = open(filename, 'rb')
  if not handler then
    return false, fmt('Could not open %s: %s', filename, normalize_io_error(filename, err))
  end

  while true do
    local block = handler:read(8192)
    if not block then
      handler:close()
      return false
    elseif block:match(NUL_PATT) then
      handler:close()
      return true
    end
  end
end

--- Returns true if there's a directory on the `path`, false otherwise.
--
-- @tparam string path
-- @treturn bool
function M.is_dir (path)
  local attrs = file_attrs(path)
  return attrs and attrs.mode == 'directory'
end

--- Returns true if there's a file on the `path`, false otherwise.
--
-- @tparam string path
-- @treturn bool
function M.is_file (path)
  local attrs = file_attrs(path)
  return attrs and attrs.mode == 'file'
end

--- Joins the given path components using platform-specific separator.
--
-- @tparam string ... The path components.
-- @treturn string
function M.path_join (...)
  return concat({...}, pkgpath.dir_sep)
end
local path_join = M.path_join

--- Reads the specified file and returns its content as string.
--
-- @tparam string filename Path of the file to read.
-- @tparam string mode The mode in which to open the file, see @{io.open}.
-- @treturn[1] string A content of the file.
-- @treturn[2] nil
-- @treturn[2] string An error message.
function M.read_file (filename, mode)
  local handler, err = open(filename, mode)
  if not handler then
    return nil, fmt('Could not open %s: %s', filename, normalize_io_error(filename, err))
  end

  local contents, err = handler:read('*a')  --luacheck: ignore
  if not contents then
    return nil, fmt('Could not read %s: %s', filename, normalize_io_error(filename, err))
  end

  handler:close()

  if contents:sub(1, #UTF8_BOM) == UTF8_BOM then
    contents = contents:sub(#UTF8_BOM + 1)
  end

  return contents
end

--- Traverses all files under the specified directory recursively.
--
-- @tparam string dir_path Path of the directory to traverse.
-- @treturn coroutine A coroutine that yields file path and its attributes.
function M.walk_dir (dir_path)
  -- Trim trailing "/" or "\".
  if dir_path:sub(-1):match('[/\\]') then
    dir_path = dir_path:sub(1, -2)
  end

  local function yieldtree (dir)
    for entry in iter_dir(dir) do
      if entry ~= '.' and entry ~= '..' then
        entry = path_join(dir, entry)
        local attrs = file_attrs(entry)

        yield(entry, attrs)

        if attrs.mode == 'directory' then
          yieldtree(entry)  -- recursive call
        end
      end
    end
  end

  return cowrap(function()
    yieldtree(dir_path)
  end)
end


return setmetatable(M, {
  __index = lfs,
})
