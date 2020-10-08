
local argparse = require("argparse")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local log = require("tlcli.log")
local util = require("tlcli.util")

local Args = require("tlcli.types").Args
local Command = require("tlcli.types").Command

local run: Command = {
   name = "run",
   description = [[Run a Teal script.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The tl script.")
         :args("+")
   end,

   command = function(args: Args): number
      local script_args: {string} = args["script"] as {string}
      local fname = script_args[1]
      local chunk, err = util.teal.type_check_and_load(fname)
      if not chunk then
         log.error("Error loading %s: %s", ansi.bright.yellow(fname), err)
         return 1
      end

      local neg_arg = {}
      local nargs = #script_args
      local j = #arg
      local p = nargs
      local n = 1
      while arg[j] do
         if arg[j] == script_args[p] then
            p = p - 1
         else
            neg_arg[n] = arg[j]
            n = n + 1
         end
         j = j - 1
      end

      -- shift back all non-arguments to negative positions
      for p, a in ipairs(neg_arg) do
         arg[-p] = a
      end
      -- put script in arg[0] and arguments in positive positions
      for p, a in ipairs(script_args) do
         arg[p - 1] = a
      end
      -- cleanup the rest
      n = nargs
      while arg[n] do
         arg[n] = nil
         n = n + 1
      end

      table.remove(script_args, 1)

      tl.loader()
      local script = coroutine.create(function()
         chunk(table.unpack(script_args))
      end)

      local exit = 0
      repeat
         local ok = coroutine.resume(script)
         if not ok then
            exit = 1
            local trace = debug.traceback(script)
            local stack = util.generate(util.split(trace, "\n", true))
            -- get rid of the info from this file
            table.remove(stack, 1)
            table.remove(stack)
            table.remove(stack)

            for i, v in ipairs(stack) do
               stack[i] = v:gsub("^(%s*)(.-):(%d+)", function(ws: string, file: string, line_num: string): string
                  return ws .. ansi.bright.yellow(file) .. ":" .. ansi.bright.magenta(line_num)
               end)
            end

            log.error("Error in script %s:\nTraceback:\n%s", ansi.bright.yellow(fname), table.concat(stack, "\n"))

            break
         end
      until coroutine.status(script) == "dead"
      return exit
   end,
}

return run
