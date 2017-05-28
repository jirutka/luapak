---------
-- Utilities for toolchain modules.
--
-- **Note: This module is not part of public API!**
----
local fs = require 'luarocks.fs'
local lrutil = require 'luarocks.util'

local log = require 'luapak.logging'

local concat = table.concat
local push = table.insert
local variable_substitutions = lrutil.variable_substitutions


local M = {}

--- Runs a command displaying its execution on standard output.
--
-- @tparam string ... The command and arguments.
-- @return bool true if command succeeds (status code 0), false otherwise.
function M.execute (...)
  log.debug('Executing: '..concat({...}, ' '))
  return fs.execute(...)
end

--- Pushes the `flag` with `values` into the given table `tab` and substitutes
-- all variables in `values`.
--
-- @tparam {string,...} tab The target table to push flags into.
-- @tparam string flag The flag with single format pattern to be substituted by `values`.
-- @tparam {string,...}|string|nil values
-- @tparam ?{[string]=...} variables
function M.push_flags (tab, flag, values, variables)
  variables = variables or {}

  if not values then
    return
  end

  if type(values) ~= 'table' then
    values = { tostring(values) }
  end
  variable_substitutions(values, variables)

  for _, v in ipairs(values) do
    push(tab, flag:format(v))
  end
end

return M
