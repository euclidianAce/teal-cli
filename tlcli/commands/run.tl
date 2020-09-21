
local argparse = require("argparse")
local tl = require("tl")

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
         log.error("Error loading %s: %s", fname, err)
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
      local ok = pcall(chunk, table.unpack(script_args))
      return ok and 0 or 1
   end,
}

return run
