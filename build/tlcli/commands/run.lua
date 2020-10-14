
local argparse = require("argparse")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local log = require("tlcli.log")
local util = require("tlcli.util")

local Args = require("tlcli.types").Args
local Command = require("tlcli.types").Command

local run = {
   name = "run",
   description = [[Run a Teal script.]],
   argparse = function(cmd)
      cmd:argument("script", "The tl script."):
      args("+")
   end,

   command = function(args)
      local script_args = args["script"]
      local fname = script_args[1]
      log.debug("Type checking and loading file %s", fname)
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


      for p, a in ipairs(neg_arg) do
         arg[-p] = a
      end

      for p, a in ipairs(script_args) do
         arg[p - 1] = a
      end

      n = nargs
      while arg[n] do
         arg[n] = nil
         n = n + 1
      end

      table.remove(script_args, 1)

      tl.loader()
      log.debug("Creating thread...")
      local script = coroutine.create(function()
         log.debug("[thread] Executing...")
         log.debug("=============================")
         chunk(table.unpack(script_args))
         log.debug("=============================")
         log.debug("[thread] done")
      end)

      local exit = 0
      repeat
         log.debug("Resuming thread")
         local ok, err = coroutine.resume(script)
         if not ok then
            exit = 1
            log.debug("Error in thread, getting stacktrace and removing traces from this file")
            local trace = debug.traceback(script)
            local stack = util.generate(util.split(trace, "\n", true))

            table.remove(stack, 1)
            table.remove(stack)
            table.remove(stack)

            for i, v in ipairs(stack) do
               stack[i] = v:gsub("^(%s*)(.-):(%d+)", function(ws, file, line_num)
                  return ws .. ansi.bright.yellow(file) .. ":" .. ansi.bright.magenta(line_num)
               end)
            end

            log.error("Error in script %s:\n%s\nTraceback:\n%s", ansi.bright.yellow(fname), err, table.concat(stack, "\n"))

            break
         end
      until coroutine.status(script) == "dead"
      log.debug("Returning with exit code %d", exit)
      return exit
   end,
}

return run
