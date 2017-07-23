local cfg = require 'luarocks.cfg'

local const = require 'luapak.luarocks.constants'
local fs = require 'luapak.fs'
local utils = require 'luapak.utils'

local basename = fs.basename
local fmt = string.format
local getenv = os.getenv
local is_empty = utils.is_empty
local starts_with = utils.starts_with

local LUAROCKS_FAKE_PREFIX = const.LUAROCKS_FAKE_PREFIX
local MSVC = cfg.is_platform('win32') and not cfg.is_platform('mingw32')


-- Always use LuaFileSystem and other modules when available.
cfg.fs_use_modules = true

-- Always validate TLS certificates!
-- Why the hack LuaRocks disables it by default?! >_<
cfg.check_certificates = true
cfg.variables.CURLNOCERTFLAG = ''
cfg.variables.WGETNOCERTFLAG = ''

if not is_empty(getenv('LUAROCKS_DEBUG')) then
  cfg.verbose = true
  require('luarocks.fs').verbose()
end

-- Change default optimization option from -O2 to -Os.
if cfg.variables.CFLAGS then
  local sep = cfg.is_platform('windows') and '/' or '-'
  cfg.variables.CFLAGS = cfg.variables.CFLAGS:gsub(sep..'O2', sep..'Os')
end

if not cfg.shared_lib_extension then
  cfg.shared_lib_extension = cfg.lib_extension
end

if not cfg.static_lib_extension then
  cfg.static_lib_extension = MSVC and 'lib' or 'a'
end

if not cfg.variables.AR then
  cfg.variables.AR = MSVC and 'lib' or 'ar'
end

if not cfg.variables.RANLIB then
  cfg.variables.RANLIB = 'ranlib'
end

if not cfg.variables.STRIP then
  cfg.variables.STRIP = 'strip'
end

if not cfg.variables.STRINGS then
  cfg.variables.STRINGS = 'strings'
end

-- LUALIB for MSVC is already defined in cfg.lua.
if not cfg.variables.LUALIB and not MSVC then
  cfg.variables.LUALIB = fmt('liblua%s.%s', cfg.lua_version:gsub('%.', ''),
                                            cfg.lib_extension)
end

if package.loaded.jit and not cfg.luajit_version then
  cfg.luajit_version = package.loaded.jit.version:match('LuaJIT (%d+%.%d+%.%d+)')
end

if cfg.is_platform('macosx') and cfg.luajit_version then
  cfg.variables.LDFLAGS = const.LUAJIT_MACOS_LDFLAGS
end

if cfg.is_platform('windows') then
  for name, value in pairs(cfg.variables) do
    -- Don't use bundled tools (set in luarocks.cfg).
    if starts_with(LUAROCKS_FAKE_PREFIX, value) then
      cfg.variables[name] = basename(value)
    end

    -- MSYS2/MinGW does not use mingw32- prefix.
    if starts_with('mingw32-', value) then
      cfg.variables[name] = value:gsub('^mingw32%-', '')
    end
  end
end

-- Allow to override the named variables by environment.
for _, name in ipairs {
  'AR', 'CC', 'CMAKE', 'CFLAGS', 'LD', 'LDFLAGS', 'MAKE', 'RANLIB', 'STRIP'
} do
  local value = getenv(name)
  if value then
    cfg.variables[name] = value
  end
end

-- Allow to override any uppercase variable by environment.
-- To avoid clashes with common variables like PWD, environment variables
-- must be prefixed with "LUAROCKS_".
-- Note: If, for example, both CFLAGS and LUAROCKS_CFLAGS is defined,
-- then the prefixed one is used.
for name, _ in pairs(cfg.variables) do
  local prefix = starts_with('LUAROCKS', name) and '' or 'LUAROCKS_'
  local value = getenv(prefix..name)
  if value then
    cfg.variables[name] = value
  end
end

return cfg
