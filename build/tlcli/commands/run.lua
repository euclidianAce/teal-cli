
local argparse = require("argparse")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local log = require("tlcli.log")
local runner = require("tlcli.runner")
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

      log.debug("Creating thread...")
      local script = runner.wrap(function()
         tl.loader()
         chunk(table.unpack(script_args))
      end)

      local ok, res = script:run()
      if not ok then
         log.error("Error in script %s\n%s\n%s", ansi.bright.yellow(fname), res, script:get_traceback())
         return 1
      end
      return 0
   end,
}

return run
