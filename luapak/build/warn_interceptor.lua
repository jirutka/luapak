---------
-- Interceptor for LuaRock's build backends that prints a warning message.
----
local log = require 'luapak.logging'

local fmt = string.format

--- Creates an interceptor for the given build `backend` that prints warning
-- message before running `backend`'s `run` function.
return function (backend)
  local M = {}

  function M.run (rockspec)
    local rock_name = fmt('%s-%s', rockspec.name, rockspec.version)
    local build_type = rockspec.build.type

    log.warn('Rock %s uses external build backend "%s", so Luapak cannot ensure that it will '
              ..'build native modules as a static libraries!', rock_name, build_type)

    return backend.run(rockspec)
  end

  return M
end
