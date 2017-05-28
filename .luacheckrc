-- vim: set ft=lua:

stds.compat = {
  read_globals = {
    table = {
      fields = {
        unpack = {}
      }
    },
    package = {
      fields = {
        searchpath = {}
      }
    }
  }
}

std = 'min+compat'
codes = true
