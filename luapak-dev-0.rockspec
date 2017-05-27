-- vim: set ft=lua:

package = 'luapak'
version = 'dev-0'

source = {
  url = 'git://github.com/jirutka/luapak.git',
  branch = 'master',
}

description = {
  summary = 'Easily build a standalone executable for any Lua program.',
  detailed = [[TODO]],
  homepage = 'https://github.com/jirutka/luapak',
  maintainer = 'Jakub Jirutka <jakub@jirutka.cz>',
  license = 'MIT',
}

dependencies = {
  'lua >= 5.1',
}

build = {
  type = 'builtin',
  modules = {
  },
  install = {
    bin = {
    }
  }
}
