---------
-- Common interface for build toolchains.
--
-- This module returns @{build.toolchain.gnu} or @{build.toolchain.msvc} based
-- on the user's platform.
----
local cfg = require 'luarocks.core.cfg'

local MSVC = cfg.is_platform('win32') and not cfg.is_platform('mingw32')

------
-- Compiles the `source_file` into the object file `obj_file`.
--
-- @tparam ?table vars Table of variables.
-- @tparam string obj_file Name of the object file being created.
-- @tparam string source_file Path of the source file to compile.
-- @tparam ?{string,...} defines List of definitions; each will be prepended with `-D`, variables
--   substituted and passed to compiler.
-- @tparam ?{string,...} incdirs List of include directories; each will be prepended with `-I`,
--   variables substituted and passed to compiler.
-- @treturn bool true on success, false on failure.
-- @function compile_object
----

------
-- Creates a static library (archive).
--
-- @tparam ?table vars Table of variables.
-- @tparam string out_file Name of the output file being created.
-- @tparam {string,...} objects List of paths of the object files to pack into archive.
-- @treturn bool true on success, false on failure.
-- @function create_static_lib
----

------
-- Creates a shared library.
--
-- @tparam ?table vars Table of variables.
-- @tparam string so_file Name of the shared object file being created.
-- @tparam {string,...} objects List of paths of the object files to pack into shared object.
-- @tparam ?{string,...} libs List of libraries to link against; each will be prepended
--   with `-l`, variables substituted and passed to linker.
-- @tparam ?{string,...} libdirs List of directories where to search for libraries; each will be
--   prepended with `-L`, variables substituted and passed to linker.
-- @treturn bool true on success, false on failure.
-- @function create_shared_lib
----

------
-- Creates an executable binary.
--
-- @tparam ?table vars Table of variables.
-- @tparam string out_file Name of the binary being created.
-- @tparam {string,...} objects List of paths of the object files to pack into the binary.
-- @tparam ?{string,...} libs List of libraries to link against; each will be prepended
--   with `-l`, variables substituted and passed to linker.
-- @tparam ?{string,...} libdirs List of directories where to search for libraries; each will be
--   prepended with `-L`, variables substituted and passed to linker.
-- @treturn bool true on success, false on failure.
-- @function link_binary
----

------
-- Strips debugging symbols from the specified binary file.
--
-- @tparam ?table vars Table of variables.
-- @tparam string bin_file Name of the binary file to strip.
-- @treturn bool true on success, false on failure.
-- @function strip
----

if MSVC then
  return require('luapak.build.toolchain.msvc')
else
  return require('luapak.build.toolchain.gnu')
end
