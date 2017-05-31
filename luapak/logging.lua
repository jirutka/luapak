---------
-- The logging module.
--
-- **Fields**:
--
-- * `output:` (**_file_**) Where to write log messages (default: @{io.stderr}).
-- * `prefix:` (@{string}) The prefix to add before every message (default: `"luapak: "`).
-- * `threshold:` (**_int_**) The minimal log level that should be logged (default: 20).
-- * `DEBUG (10)`
-- * `INFO (20)`
-- * `WARN (30)`
-- * `ERROR (40)`
----
local luapak = require 'luapak.init'
local utils = require 'luapak.utils'

local always = utils.always
local fmt = string.format
local par = utils.partial

local output = io.stderr
local prefix = luapak._NAME..': '
local threshold

local M = {}

local Level = {
  DEBUG = 10,
  INFO  = 20,
  WARN  = 30,
  ERROR = 40,
}
for k, v in pairs(Level) do
  M[k] = v
end

local level_prefix = {
  [Level.WARN] = 'warn: ',
  [Level.ERROR] = 'error: ',
}

local function set_threshold (level)
  if type(level) == 'string' then
    level = assert(Level[level], 'Invalid logging level: '..level)
  end

  threshold = level
  M.is_error = level <= Level.ERROR
  M.is_warn  = level <= Level.WARN
  M.is_info  = level <= Level.INFO
  M.is_debug = level <= Level.DEBUG
end

local function log_for_level (level)
  return function (msg, ...)
    if level >= threshold then
      M.log(level, msg, ...)
    end
  end
end

--- Logs the message with the specified level.
---
-- @tparam int level Valid log level number.
-- @tparam string msg The message to log.
-- @param ... Arguments for @{string.format} being applied to the `msg`.
function M.log (level, msg, ...)
  local prefix_ = prefix..(level_prefix[level] or '')
  output:write(fmt(prefix_..msg, ...):gsub('\n', '\n'..prefix_)..'\n')
end

--- Logs error message.
-- @function error
-- @tparam string msg The message to log.
-- @param ... Arguments for @{string.format} being applied to the `msg`.
M.error = log_for_level(Level.ERROR)

--- Logs warn message.
-- @function warn
-- @tparam string msg The message to log.
-- @param ... Arguments for @{string.format} being applied to the `msg`.
M.warn = log_for_level(Level.WARN)

--- Logs info message.
-- @function info
-- @tparam string msg The message to log.
-- @param ... Arguments for @{string.format} being applied to the `msg`.
M.info = log_for_level(Level.INFO)

--- Logs debug message.
-- @function debug
-- @tparam string msg The message to log.
-- @param ... Arguments for @{string.format} being applied to the `msg`.
M.debug = log_for_level(Level.DEBUG)

-- Set default threshold.
set_threshold(Level.INFO)


local attr_readers = {
  output = always(output),
  prefix = always(prefix),
  threshold = always(threshold),
}
local attr_writers = {
  output = function (val) output = val end,
  prefix = function (val) prefix = val end,
  threshold = set_threshold,
}

return setmetatable(M, {
  __index = function (self, key)
    return (attr_readers[key] or par(rawget, self, key))()
  end,
  __newindex = function (self, key, val)
    return (attr_writers[key] or par(rawset, self, key))(val)
  end
})
