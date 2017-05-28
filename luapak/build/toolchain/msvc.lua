---------
-- Implementation of the @{build.toolchain}'s functions for MSVC.
----
local utils = require 'luapak.build.toolchain.utils'

local check_args = utils.check_args
local execute = utils.execute
local push_flags = utils.push_flags
local unpack = table.unpack


local M = {}

function M.compile_object (vars, obj_file, source_file, defines, incdirs)
  check_args('?table, string, string, table|string|nil, table|string|nil',
             vars, obj_file, source_file, defines, incdirs)

  local extra = {}
  push_flags(extra, '-D%s', defines, vars)
  push_flags(extra, '-I%s', incdirs, vars)

  return execute(vars.CC..' '..vars.CFLAGS,
                 '-c',
                 '-Fo'..obj_file,
                 '-I'..vars.LUA_INCDIR,
                 source_file,
                 unpack(push_flags))
end

function M.create_static_lib (vars, out_file, objects)
  check_args('?table, string, table', vars, out_file, objects)

  return execute(vars.AR, '-out:'..out_file, unpack(objects))
end

function M.create_shared_lib (vars, so_file, objects, libs, libdirs)  --luacheck: ignore
  error 'Not implemented yet'  -- TODO
end

function M.link_binary (vars, out_file, objects, libs, libdirs)  --luacheck: ignore
  error 'Not implemented yet'  -- TODO
end

function M.strip (vars, bin_file)  --luacheck: ignore
  error 'Not implemented yet'  -- TODO
end

return M
