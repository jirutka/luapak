-- vim: set ft=lua:

package = 'luapak'
version = 'dev-0'

source = {
  url = 'git://github.com/jirutka/luapak.git',
  branch = 'master',
}

description = {
  summary = 'Easily build a standalone executable for any Lua program.',
  detailed = [[
This is a command-line tool that offers a complete, all-in-one (yet modular)
solution for building a standalone, zero-dependencies, possibly statically
linked executable for any Lua program. It automatically resolves all required
dependencies using LuaRocks and static analysis of requirements across Lua
sources, generates C wrapper with embedded Lua sources, compiles it and links
with Lua library and native extensions.]],
  homepage = 'https://github.com/jirutka/luapak',
  maintainer = 'Jakub Jirutka <jakub@jirutka.cz>',
  license = 'MIT',
}

dependencies = {
  'lua >= 5.1',
  'brieflz ~> 0.1.0',
  'depgraph ~> 0.1',
  'lua-glob-pattern ~> 0.2',
  'luafilesystem ~> 1.6',
  'luarocks ~> 2.4',
  'luasrcdiet ~> 0.3',
  'optparse ~> 1.1',
}

build = {
  type = 'builtin',
  modules = {
    ['luapak'] = 'luapak/init.lua',
    ['luapak.build.builtin'] = 'luapak/build/builtin.lua',
    ['luapak.build.toolchain'] = 'luapak/build/toolchain/init.lua',
    ['luapak.build.toolchain.gnu'] = 'luapak/build/toolchain/gnu.lua',
    ['luapak.build.toolchain.msvc'] = 'luapak/build/toolchain/msvc.lua',
    ['luapak.build.toolchain.utils'] = 'luapak/build/toolchain/utils.lua',
    ['luapak.cli.analyse_deps'] = 'luapak/cli/analyse_deps.lua',
    ['luapak.cli.build_rock'] = 'luapak/cli/build_rock.lua',
    ['luapak.cli.make'] = 'luapak/cli/make.lua',
    ['luapak.cli.merge'] = 'luapak/cli/merge.lua',
    ['luapak.cli.minify'] = 'luapak/cli/minify.lua',
    ['luapak.cli.wrapper'] = 'luapak/cli/wrapper.lua',
    ['luapak.compat'] = 'luapak/compat.lua',
    ['luapak.deps_analyser'] = 'luapak/deps_analyser.lua',
    ['luapak.fs'] = 'luapak/fs.lua',
    ['luapak.logging'] = 'luapak/logging.lua',
    ['luapak.lua_finder'] = 'luapak/lua_finder.lua',
    ['luapak.luarocks'] = 'luapak/luarocks/init.lua',
    ['luapak.luarocks.cfg_extra'] = 'luapak/luarocks/cfg_extra.lua',
    ['luapak.luarocks.constants'] = 'luapak/luarocks/constants.lua',
    ['luapak.luarocks.site_config'] = 'luapak/luarocks/site_config.lua',
    ['luapak.make'] = 'luapak/make.lua',
    ['luapak.merger'] = 'luapak/merger.lua',
    ['luapak.minifier'] = 'luapak/minifier.lua',
    ['luapak.optparse'] = 'luapak/optparse.lua',
    ['luapak.pkgpath'] = 'luapak/pkgpath.lua',
    ['luapak.utils'] = 'luapak/utils.lua',
    ['luapak.wrapper'] = 'luapak/wrapper.lua',
    ['luapak.wrapper_tmpl'] = 'luapak/wrapper_tmpl.lua',
  },
  install = {
    bin = {
      luapak = 'bin/luapak',
    }
  }
}
