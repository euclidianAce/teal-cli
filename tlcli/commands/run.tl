
local argparse = require("argparse")
local tl = require("tl")
local log = require("tlcli.log")
local util = require("tlcli.util")

local Command = require("tlcli.types").Command

local run: Command
run = {
   name = "run",
   description = [[Run a Teal script.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The tl script.")
         :args("+")
   end,

   command = function(opts: table, args: table, ...: string): number
      local fname = select(1, ...)
      if not fname then
         log.error("No file name provided")
         return 1
      end
      local chunk, err = util.teal.type_check_and_load(fname)
      if not chunk then
         log.error("Error loading %s: %s", fname, err)
         return 1
      end

      -- TODO: when we start using argparse this will need to be changed
      local new_args = {}
      table.move(arg, -1, select("#", ...), -3, new_args)
      for i = -1, #arg do
         arg[i] = nil
      end
      for i = -3, #new_args do
         arg[i] = new_args[i]
      end

      tl.loader()
      return chunk(select(2, ...)) as number
   end,

   config = function(opts: table)
      for k, v in pairs(opts) do
         run.options[k] = v
      end
   end,

   options = util.protected_proxy{},
}

return run
