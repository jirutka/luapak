---------
-- CLI for the deps_analyser module.
----
local analyser = require 'luapak.deps_analyser'
local log = require 'luapak.logging'
local optparse = require 'luapak.optparse'
local utils = require 'luapak.utils'

local concat = table.concat
local fmt = string.format
local printf = utils.printf
local push = table.insert
local analyse_with_filter = analyser.analyse_with_filter
local split = utils.split
local tableize = utils.tableize


local help_msg = [[
.
Usage: ${PROG_NAME} analyse-deps [-a|-f|-m|-g] [options] FILE...
       ${PROG_NAME} analyse-deps --help

Analyses dependency graph of Lua module(s) using static code analysis (looks
for "require" expressions).

Arguments:
  FILE                        The entry point(s); path(s) to Lua script(s) to analyse.

Options:
  -a, --all                   Print all information (default).
  -f, --found                 Print only found modules.
  -m, --missing               Print only missing modules.
  -g, --ignored               Print only excluded/ignored modules.

  -e, --excludes=PATTERNS     Module(s) to exclude from the dependencies analysis. PATTERNS is one
                              or more glob patterns matching module name in dot notation
                              (e.g. "pl.*"). Patterns may be delimited by comma or space. This
                              option can be also specified multiple times.

  -n, --ignore-errors         Ignore errors from dependencies resolution (like unredable or unparseable files).

  -P, --no-pcalls             Do not analyse pcall requires.

  -W, --no-wildcards          Do not expand "wildcard" requires.

  -p, --pkg-path=PATH         The path pattern where to search for Lua and C/Lua modules instead of
                              the default path.

  -v, --verbose               Be verbose, i.e. print debug messages.

  -h, --help                  Display this help message and exit.
]]


local function format_found (found)
  local res = {}
  for name, path in pairs(found) do
    push(res, fmt('%s\t%s', name, path))
  end

  return res
end

local function print_lines (lines, indent)
  for _, line in ipairs(lines) do
    printf('%s%s', indent or '', line)
  end
end

local function print_results (mode, found, missing, ignored)

  local nothing_printed = true
  local function print_heading (text)
    if nothing_printed then
      nothing_printed = false
    else
      printf('')
    end

    printf(text)
  end

  if mode == 'all' then
    found = format_found(found)

    if #found > 0 then
      print_heading 'Found required modules:'
      print_lines(found, '+ ')
    end

    if #missing > 0 then
      print_heading 'Missing modules:'
      print_lines(missing, '! ')
    end

    if #ignored > 0 then
      print_heading 'Excluded and ignored requires:'
      print_lines(ignored, '- ')
    end
  else
    local items = ({
      found = found,
      missing = missing,
      ignored = ignored
    })[mode]

    if items == found then
      items = format_found(found)
    end

    print_lines(items)
  end
end


--- Runs the analyse-deps command.
--
-- @function __call
-- @tparam table arg List of CLI arguments.
-- @raise if some error occured.
return function (arg)
  local optparser = optparse(help_msg)
  local args, opts = optparser:parse(arg)

  if #args == 0 then
    optparser:opterr('no FILE specified')
  end

  local mode
  for _, name in ipairs { 'all', 'found', 'missing', 'ignored' } do
    if opts[name] then
      if mode and mode ~= 'all' then
        optparser:opterr('Options --found, --missing, and --ignored are exclusive, use only one of them!')
      end
      mode = name
    end
  end
  mode = mode or 'all'

  local excludes = split('[,\n]%s*', concat(tableize(opts.excludes), ','))

  local found, missing, ignored, errors = analyse_with_filter(args, opts.pkg_path, excludes, {
    pcalls = not opts.no_pcalls,
    wildcards = not opts.no_wildcards,
  })

  if #errors > 0 then
    errors = concat(errors, '\n')
    if opts.ignore_errors then
      log.error(error)
    else
      error(errors, 0)
    end
  end

  print_results(mode, found, missing, ignored)
end
