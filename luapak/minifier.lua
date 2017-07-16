---------
-- Lua minifier - wrapper for LuaSrcDiet with simplified API.
--
-- **Note: This module is not part of public API!**
----
local luasrcdiet = require 'luasrcdiet'
local utils = require 'luapak.utils'

local fmt = string.format
local optimize = luasrcdiet.optimize
local shallow_clone = utils.shallow_clone


local default_opts = {
  comments = true,
  emptylines = true,
  entropy = true,
  eols = true,
  locals = true,
  numbers = true,
  srcequiv = true,
  whitespace = true,
}

local function convert_opts (opts)
  if opts and (opts.keep_lno or opts.keep_names) then
    local _opts = shallow_clone(default_opts)

    if opts.keep_lno then
      _opts.emptylines = false
      _opts.eols = false
    end
    if opts.keep_names then
      _opts.entropy = false
      _opts.locals = false
    end

    return _opts
  else
    return default_opts
  end
end


--- Minifies the given Lua `chunk`.
--
-- @function __call
-- @tparam ?{[string]=bool,...} opts Table of options.
-- @tparam ?string chunk Lua chunk (source code) to minify.
-- @tparam ?string name The chunk name.
-- @treturn[1] function A partially applied function accepting chunk and name. (*if chunk is nil*)
-- @treturn[2] string Minified chunk. (*if chunk is not nil*)
-- @treturn[3] nil (*if chunk is not nil and minification failed*)
-- @treturn[3] string An error message. (*if chunk is not nil and minification failed*)
return function (opts, chunk, name)
  opts = convert_opts(opts or {})

  local function minify (chunk, name)  --luacheck: ignore 432
    local ok, res = pcall(optimize, opts, chunk)
    if ok then
      return res
    else
      local err = res:gsub('^[^:]+:[^:]+:%s*', '')  -- remove location info
      return nil, name and fmt('failed to minify %s: %s', name, err) or err
    end
  end

  if chunk then
    return minify(chunk, name)
  else
    return minify
  end
end
