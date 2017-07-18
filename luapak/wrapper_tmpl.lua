return {
HEAD = [[
/* vim: set ft=c: */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>


/*****************************************************************************
*                        Compatibility with older Lua                        *
*****************************************************************************/

#if LUA_VERSION_NUM == 501  // Lua 5.1
  #define LUA_OK 0
#endif

/**
 * Print an error message.
 * Copied from Lua 5.3 lauxlib.h for compatibility with olders.
 */
#if !defined(lua_writestringerror)
#define lua_writestringerror(s,p) \
        (fprintf(stderr, (s), (p)), fflush(stderr))
#endif


/*****************************************************************************
*                                 Stub libdl                                 *
*****************************************************************************/

// Stub implementation of libdl (dynamic linker) to avoid linking
// with real libdl if Lua has been built with LUA_USE_DLOPEN.
#if !defined(_WIN32)
  #include <dlfcn.h>

  int dlclose(void *handle) {
    return 0;
  }

  char *dlerror(void) {
    return "libdl is not implemented";
  }

  void *dlopen(const char *filename, int flag) {
    return NULL;
  }

  void *dlsym(void *handle, const char *symbol) {
    return NULL;
  }
#endif


/*****************************************************************************
*                               Generated code                               *
*****************************************************************************/

]],
BRIEFLZ = [[
/*****************************************************************************
*                               BriefLZ depack                               *
*****************************************************************************/

// The following code is based on BriefLZ library by Joergen Ibsen,
// licensed under zlib license.
// https://github.com/jibsen/brieflz/blob/master/depack.c
#if LUAPAK_BRIEFLZ == 1

  // Internal data structure.
  struct blz_State {
    const unsigned char *src;
    unsigned char *dst;
    unsigned int tag;
    unsigned int bits_left;
  };

  static unsigned int blz_getbit (struct blz_State *bs) {
    // Check if tag is empty.
    if (!bs->bits_left--) {
      // Load next tag
      bs->tag = (unsigned int) bs->src[0]
             | ((unsigned int) bs->src[1] << 8);
      bs->src += 2;
      bs->bits_left = 15;
    }

    // Shift bit out of tag.
    const unsigned int bit = (bs->tag & 0x8000) ? 1 : 0;
    bs->tag <<= 1;

    return bit;
  }

  static size_t blz_getgamma (struct blz_State *bs) {
    size_t result = 1;

    // Input gamma2-encoded bits.
    do {
      result = (result << 1) + blz_getbit(bs);
    } while (blz_getbit(bs));

    return result;
  }

  /**
   * Decompress `depacked_size` bytes of data from `src` to `dst`
   * and return size of decompressed data.
   */
  static size_t blz_depack (const void *src, void *dst, size_t depacked_size) {
    if (depacked_size == 0) {
      return 0;
    }

    struct blz_State bs = {
      .src = (const unsigned char *) src,
      .dst = (unsigned char *) dst,
      .bits_left = 0
    };
    *bs.dst++ = *bs.src++;  // first byte verbatim

    size_t dst_size = 1;

    // Main decompression loop.
    while (dst_size < depacked_size) {
      if (blz_getbit(&bs)) {
        // Input match length and offset.
        size_t len = blz_getgamma(&bs) + 2;
        size_t off = blz_getgamma(&bs) - 2;

        off = (off << 8) + (size_t) *bs.src++ + 1;

        // Copy match.
        {
          const unsigned char *p = bs.dst - off;
          for (size_t i = len; i > 0; --i) {
            *bs.dst++ = *p++;
          }
        }
        dst_size += len;

      } else {
        // Copy literal.
        *bs.dst++ = *bs.src++;
        dst_size++;
      }
    }

    return dst_size;  // decompressed size
  }
#endif

]],
MAIN = [[
/*****************************************************************************
*                                  M a i n                                   *
*****************************************************************************/

#if LUAPAK_BRIEFLZ == 1

  /**
   * Decompress and load the embedded Lua script.
   * If there's no error, the compiled chunk is pushed on top of the stack as
   * a Lua function. Otherwise an error message is pushed on top of the stack.
   */
  static int load_script (lua_State *L) {
    const size_t unpacked_size = LUAPAK_SCRIPT_UNPACKED_SIZE;

    void *buffer = malloc(unpacked_size);
    if (buffer == NULL) {
      lua_pushstring(L, "PANIC: not enough memory for decompression");
      return LUA_ERRRUN;
    }

    if (blz_depack(LUAPAK_SCRIPT, buffer, unpacked_size) != unpacked_size) {
      lua_pushstring(L, "PANIC: decompression failed");
      return LUA_ERRRUN;
    }

    const int status = luaL_loadbuffer(L, (const char *) buffer, unpacked_size, "@main");
    free(buffer);

    return status;
  }
#else

  /**
   * Load the embedded Lua script.
   * If there's no error, the compiled chunk is pushed on top of the stack as
   * a Lua function. Otherwise an error message is pushed on top of the stack.
   */
  static int load_script (lua_State *L) {
    return luaL_loadbuffer(L, (const char *) LUAPAK_SCRIPT, sizeof(LUAPAK_SCRIPT), "@main");
  }
#endif

#if defined(LUAPAK_WITHOUT_COROUTINE) \
    || defined(LUAPAK_WITHOUT_IO) \
    || defined(LUAPAK_WITHOUT_OS) \
    || defined(LUAPAK_WITHOUT_MATH) \
    || defined(LUAPAK_WITHOUT_UTF8) \
    || defined(LUAPAK_WITHOUT_DEBUG) \
    || defined(LUAPAK_WITHOUT_BIT)

  static const luaL_Reg loadedlibs[] = {
    #if LUA_VERSION_NUM == 501  // Lua 5.1
      {"", luaopen_base},
    #else
      {"_G", luaopen_base},
    #endif
    { LUA_LOADLIBNAME, luaopen_package },
    #if !defined(LUAPAK_WITHOUT_COROUTINE) && LUA_VERSION_NUM > 501  // Lua 5.2+
      { LUA_COLIBNAME, luaopen_coroutine },
    #endif
    { LUA_TABLIBNAME, luaopen_table },
    #if !defined(LUAPAK_WITHOUT_IO)
      { LUA_IOLIBNAME, luaopen_io },
    #endif
    #if !defined(LUAPAK_WITHOUT_OS)
      { LUA_OSLIBNAME, luaopen_os },
    #endif
    { LUA_STRLIBNAME, luaopen_string },
    #if !defined(LUAPAK_WITHOUT_MATH)
      { LUA_MATHLIBNAME, luaopen_math },
    #endif
    #if !defined(LUAPAK_WITHOUT_UTF8) && LUA_VERSION_NUM >= 503  // Lua 5.3+
      { LUA_UTF8LIBNAME, luaopen_utf8 },
    #endif
    #if !defined(LUAPAK_WITHOUT_DEBUG)
      { LUA_DBLIBNAME, luaopen_debug },
    #endif
    #if !defined(LUAPAK_WITHOUT_BIT)
      #if LUA_VERSION_NUM == 502 || LUA_VERSION_NUM == 503 && defined(LUA_COMPAT_BITLIB)
        { LUA_BITLIBNAME, luaopen_bit32 },
      #elif defined(LUA_JITLIBNAME)  // LuaJIT
        { LUA_BITLIBNAME, luaopen_bit },
      #endif
    #endif
    #if defined(LUA_JITLIBNAME)  // LuaJIT
      { LUA_JITLIBNAME, luaopen_jit },
    #endif
    { NULL, NULL }
  };

  /**
   * Load Lua standard libraries from 'loadedlibs' array into global.
   */
  static void load_stdlibs (lua_State *L) {
    // Call open functions from 'loadedlibs' and set results to global table.
    for (const luaL_Reg *lib = loadedlibs; lib->func; lib++) {
      #if LUA_VERSION_NUM == 501
        lua_pushcfunction(L, lib->func);
        lua_pushstring(L, lib->name);
        lua_call(L, 1, 0);
      #else
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_pop(L, 1);  // remove lib
      #endif
    }
  }
#else  // load default libs
  #define load_stdlibs luaL_openlibs
#endif

/**
 * Set 'package.path' and 'package.cpath' to empty string, i.e. disable loading
 * modules from file system.
 */
static void clear_pkg_paths (lua_State *L) {
  lua_getglobal(L, "package");
  lua_pushstring(L, "");
  lua_setfield(L, -2, "path");  // sets package.path = ""
  lua_pushstring(L, "");
  lua_setfield(L, -2, "cpath");  // sets package.cpath = ""
  lua_pop(L, 1);  // pops 'package' table from the stack
}


// Note: The following code is based on lua.c from Lua 5.3.

static lua_State *globalL = NULL;


static void preload_bundled_libs (lua_State *L) {
  #if LUA_VERSION_NUM == 501  // Lua 5.1
    lua_getfield(L, LUA_GLOBALSINDEX, "package");
    lua_getfield(L, -1, "preload");
  #else
    luaL_getsubtable(L, LUA_REGISTRYINDEX, "_PRELOAD");
  #endif

  // Add open functions from 'LUAPAK_PRELOADED_LIBS' into 'package.preload' table.
  for (const luaL_Reg *lib = LUAPAK_PRELOADED_LIBS; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_setfield(L, -2, lib->name);
  }

  #if LUA_VERSION_NUM == 501  // Lua 5.1
    lua_pop(L, 2);  // pops 'package' and 'preload' from the stack
  #else
    lua_pop(L, 1);  // pops _PRELOAD table from the stack
  #endif
}

/**
 * Hook set by signal function to stop the interpreter.
 */
static void lstop (lua_State *L, lua_Debug *ar) {
  (void) ar;  // unused arg.
  lua_sethook(L, NULL, 0, 0);  // reset hook
  luaL_error(L, "interrupted!");
}

/**
 * Function to be called at a C signal. Because a C signal cannot
 * just change a Lua state (as there is no proper synchronization),
 * this function only sets a hook that, when called, will stop the
 * interpreter.
 */
static void laction (int i) {
  signal(i, SIG_DFL);  // if another SIGINT happens, terminate process
  lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

/**
 * Message handler used to run all chunks
 */
static int msghandler (lua_State *L) {
  #if LUA_VERSION_NUM == 501 && !defined(luaconf_h)  // Lua 5.1, but not LuaJIT
    lua_getfield(L, LUA_GLOBALSINDEX, "debug");
    if (!lua_istable(L, -1)) {
      lua_pop(L, 1);
      return 1;
    }
    lua_getfield(L, -1, "traceback");
    if (!lua_isfunction(L, -1)) {
      lua_pop(L, 2);
      return 1;
    }
    lua_pushvalue(L, 1);  // pass error message
    lua_pushinteger(L, 2);  // skip this function and traceback

    lua_call(L, 2, 1);  // call debug.traceback
  #else
    const char *msg = lua_tostring(L, 1);

    if (msg == NULL) {  // is error object not a string?
      if (luaL_callmeta(L, 1, "__tostring") &&  // does it have a metamethod
          lua_type(L, -1) == LUA_TSTRING) { // that produces a string?
        return 1;  // that is the message
      } else {
        msg = lua_pushfstring(L, "(error object is a %s value)",
                                 luaL_typename(L, 1));
      }
    }
    luaL_traceback(L, L, msg, 1);  // append a standard traceback
  #endif

  return 1;  // return the traceback
}

/**
 * Interface to 'lua_pcall', which sets appropriate message function
 * and C-signal handler. Used to run all chunks.
 */
static int docall (lua_State *L, int narg, int nres) {
  int base = lua_gettop(L) - narg;  // function index

  lua_pushcfunction(L, msghandler);  // push message handler
  lua_insert(L, base);  // put it under function and args
  globalL = L;  // to be available to 'laction'

  signal(SIGINT, laction);  // set C-signal handler
  int status = lua_pcall(L, narg, nres, base);
  signal(SIGINT, SIG_DFL);  // reset C-signal handler

  lua_remove(L, base);  // remove message handler from the stack

  return status;
}

/**
 * Create the 'arg' table, which stores all arguments from the
 * command line ('argv'). It should be aligned so that, at index 0,
 * it has 'argv[script]', which is the script name. The arguments
 * to the script (everything after 'script') go to positive indices;
 * other arguments (before the script name) go to negative indices.
 * If there is no script name, assume interpreter's name as base.
 */
static void createargtable (lua_State *L, char **argv, int argc, int script) {
  if (script == argc) script = 0;  // no script name?
  int narg = argc - (script + 1);  // number of positive indices

  lua_createtable(L, narg, script + 1);
  for (int i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i - script);
  }
  lua_setglobal(L, "arg");
}

/**
 * Push on the stack the contents of table 'arg' from 1 to #arg.
 */
static int pushargs (lua_State *L) {
  lua_getglobal(L, "arg");  // push 'arg' table onto the stack

  #if LUA_VERSION_NUM == 501  // Lua 5.1
    int n = (int) lua_objlen(L, -1);
  #else
    int n = (int) luaL_len(L, -1);
  #endif

  luaL_checkstack(L, n + 3, "too many arguments to script");

  int i = 1;
  for (; i <= n; i++) {
    lua_rawgeti(L, -i, i);
  }
  lua_remove(L, -i);  // remove table from the stack

  return n;
}


int main (int argc, char *argv[]) {
  lua_State *L = luaL_newstate();
  if (L == NULL) {
    lua_writestringerror("%s\n", "PANIC: not enough memory");
    return EXIT_FAILURE;
  }

  load_stdlibs(L);
  createargtable(L, argv, argc, 0);  // create table 'arg'

  clear_pkg_paths(L);

  preload_bundled_libs(L);

  int status = load_script(L);
  if (status == LUA_OK) {
    int n = pushargs(L);  // push arguments to script
    status = docall(L, n, LUA_MULTRET);
  }
  if (status != LUA_OK) {
    lua_writestringerror("%s\n", lua_tostring(L, -1));
    lua_close(L);
    return EXIT_FAILURE;
  }

  lua_close(L);
  return EXIT_SUCCESS;
}
]]
}
