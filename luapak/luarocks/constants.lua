return {
  --- Linker flags needed for linking of LuaJIT on macOS.
  -- See http://luajit.org/install.html#embed.
  LUAJIT_MACOS_LDFLAGS = '-pagezero_size 10000 -image_base 100000000',

  --- Special "marker" prefix set in site_config on Windows to LUAROCKS_PREFIX,
  -- so it can be later recognized in variables and stripped.
  LUAROCKS_FAKE_PREFIX = 'C:\\Fake-Prefix',
}
