local log = require 'luapak.logging'
local utils = require 'luapak.utils'

local concat = table.concat
local find = utils.find


local function has_command (command)
  -- Note: It behaves differently on Lua 5.1 and 5.2+.
  local first, _, third = os.execute('command -v '..command)
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

if not site_config.LUAROCKS_DOWNLOADER then
  site_config.LUAROCKS_DOWNLOADER =
      find_command('a downloader helper program', { 'curl', 'wget', 'fetch' })
end

if not site_config.LUAROCKS_MD5CHECKER then
  site_config.LUAROCKS_MD5CHECKER =
      find_command('a MD5 checksum calculator', { 'md5sum', 'openssl', 'md5' })
end

return site_config
