---------
-- Implementation of the @{build.toolchain}'s functions for GNU.
----
local cfg = require 'luarocks.core.cfg'
local utils = require 'luapak.utils'
local tc_utils = require 'luapak.build.toolchain.utils'

local check_args = utils.check_args
local execute = tc_utils.execute
local push_flags = tc_utils.push_flags
local unpack = table.unpack  --luacheck: ignore


local M = {}

function M.compile_object (vars, obj_file, source_file, defines, incdirs)
  check_args('?table, string, string, table|string|nil, table|string|nil',
             vars, obj_file, source_file, defines, incdirs)

  local extra = {}
  push_flags(extra, '-D%s', defines, vars)
  push_flags(extra, '-I%s', incdirs, vars)

  return execute(vars.CC..' '..(vars.CFLAGS or ''),
                 '-I'..vars.LUA_INCDIR,
                 '-c', source_file,
                 '-o', obj_file,
                 unpack(extra))
end

function M.create_static_lib (vars, out_file, objects)
  check_args('?table, string, table', vars, out_file, objects)

  return execute(vars.AR, 'rc', out_file, unpack(objects))
      and execute(vars.RANLIB, out_file)
end

function M.create_shared_lib (vars, so_file, objects, libs, libdirs)
  check_args('?table, string, table, table|string|nil, table|string|nil',
             vars, so_file, objects, libs, libdirs)

  local extra = { unpack(objects) }

  push_flags(extra, '-L%s', libdirs, vars)
  if cfg.gcc_rpath then
    push_flags(extra, '-Wl,-rpath,%s:', libdirs, vars)
  end

  push_flags(extra, '-l%s', libs, vars)
  if cfg.link_lua_explicitly then
    push_flags(extra, '-l%s', { 'lua' }, vars)
  end

  return execute(vars.LD..' '..vars.LIBFLAG,
                 '-o', so_file,
                 '-L'..vars.LUA_LIBDIR,
                 unpack(extra))
end

function M.link_binary (vars, out_file, objects, libs, libdirs)
  check_args('?table, string, table, table|string|nil, table|string|nil',
             vars, out_file, objects, libs, libdirs)

  local extra = { unpack(objects) }

  push_flags(extra, '-L%s', libdirs, vars)
  push_flags(extra, '-l%s', libs, vars)

  return execute(vars.LD..' '..(vars.LDFLAGS or ''),
                 '-o', out_file,
                 unpack(extra))
end

function M.strip (vars, bin_file)
  check_args('?table, string', vars, bin_file)

  return execute(vars.STRIP, bin_file)
end

return M
