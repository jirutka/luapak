---------
-- Lua modules merger.
----
local utils = require 'luapak.utils'

local check_args = utils.check_args
local concat = table.concat
local fmt = string.format
local push = table.insert
local remove_shebang = utils.remove_shebang


--- Wraps the given `chunk` in a function.
-- This method does not preserve file name and line numbers.
local function write_wrapped_chunk (write, chunk)
  write('(function (...)\n')
  write(chunk)
  write('\nend)\n')
end

--- Wraps the given `chunk` using @{loadstring}.
-- This method produces bigger output, but it preserve file name and line
-- numbers for error messages and trackbacks, so it's better for debugging.
local function write_wrapped_chunk_debug (write, chunk, name)
  write(fmt('assert(loadstring(\n  %q,\n  "@%s"))\n',
             chunk, name:gsub('%.', '/')..'.lua'))
end


local M = {}

--- Combines multiple Lua modules into single chunk using @{package.preload}.
--
-- @tparam {[string]=string,...} modules Map of modules name to chunks (source code).
-- @tparam bool debug Preserve module names and line numbers?
-- @tparam ?function write The writer function. If not give, an intermediate table
--   will be created and the resulting chunk returned as string.
-- @treturn ?string A Lua chunk of combined modules, or nil if the `write` function given.
function M.merge_modules (modules, debug, write)
  check_args('table, ?boolean, ?function', modules, debug, write)

  local buff
  if not write then
    buff = {}
    write = function (str) push(buff, str) end
  end

  local write_chunk = debug
      and write_wrapped_chunk_debug
      or write_wrapped_chunk

  if debug then
    write('local loadstring = _G.loadstring or _G.load\n\n')
  end

  for name, chunk in pairs(modules) do
    write(fmt('-- %s\npackage.preload["%s"] = ', name, name))
    write_chunk(write, remove_shebang(chunk), name)
    write('\n\n')
  end

  if buff then
    return concat(buff)
  end
end

return M
