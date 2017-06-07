local const = require 'luapak.luarocks.constants'
local log = require 'luapak.logging'
local utils = require 'luapak.utils'

local concat = table.concat
local find = utils.find

local is_windows  -- initialized later


--- Returns true if there's system command `name` on PATH, false otherwise.
local function has_command (name)
  local cmd_tmpl = is_windows
      and 'where %s 2> NUL 1> NUL'
      or 'command -v %s >/dev/null'

  -- Note: It behaves differently on Lua 5.1 and 5.2+.
  local first, _, third = os.execute(cmd_tmpl:format(name))
  return third == 0 or first == 0
end

local function find_command (subject, commands)
  local cmd = find(has_command, commands)
  if not cmd then
    log.error('Cound not find %s, tried: %s', subject, concat(commands, ', '))
  end

  return cmd
end


local site_config; do
  local version_suffix = utils.LUA_VERSION:gsub('%.', '_')
  local ok

  ok, site_config = pcall(require, 'luarocks.site_config_'..version_suffix)
  if not ok or type(site_config) ~= 'table' then
    ok, site_config = pcall(require, 'luarocks.site_config')
  end
  if not ok or type(site_config) ~= 'table' then
    site_config = {}
    package.loaded['luarocks.site_config'] = site_config
  end
end

site_config.LUAROCKS_SYSCONFDIR = nil
site_config.LUAROCKS_ROCKS_TREE = nil
site_config.LUAROCKS_ROCKS_SUBDIR = nil
site_config.LUA_DIR_SET = nil

if not site_config.LUAROCKS_UNAME_S then
  site_config.LUAROCKS_UNAME_S = io.popen('uname -s'):read('*l')
end

is_windows = site_config.LUAROCKS_UNAME_S
    :gsub('^MINGW', 'Windows')
    :match('^Windows') ~= nil

if not site_config.LUAROCKS_DOWNLOADER then
  site_config.LUAROCKS_DOWNLOADER =
      find_command('a downloader helper program', { 'curl', 'wget', 'fetch' })
end

if not site_config.LUAROCKS_MD5CHECKER then
  site_config.LUAROCKS_MD5CHECKER =
      find_command('a MD5 checksum calculator', { 'md5sum', 'openssl', 'md5' })
end

if is_windows then
  -- Set specified LUAROCKS_PREFIX so we can strip it in cfg_extra.
  if not site_config.LUAROCKS_PREFIX then
    site_config.LUAROCKS_PREFIX = const.LUAROCKS_FAKE_PREFIX
  end
end

return site_config
