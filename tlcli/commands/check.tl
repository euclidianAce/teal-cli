
local argparse = require("argparse")
local ansi = require("tlcli.ansi")
local config = require("tlcli.config")
local log = require("tlcli.log")
local util = require("tlcli.util")

local Command = require("tlcli.types").Command

local check: Command
check = {
   name = "check",
   description = [[Type check one or more Teal scripts.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The Teal script.")
         :args("+")
   end,

   command = function(opts: table, args: table, ...: string): number
      local exit = 0
      for i = 1, select("#", ...) do
         local fname = select(i, ...)
         local ok, err = util.teal.type_check_file(fname)
         if not ok then
            log.log("error", err)
            exit = 1
            if not opts.keep_going then
               break
            end
         else
            log.normal("%sType checked%s: %s", ansi.bright"green", ansi.reset(), fname)
            log.normal("   Use %stlc run%s %s", ansi.bright"magenta", ansi.reset(), fname)
            log.normal("      to run %s as a script", fname)
            log.normal("   Use %stlc gen%s %s", ansi.bright"magenta", ansi.reset(), fname)
            log.normal("      to generate %s", util.get_output_file_name(fname))
         end
      end
      return exit
   end,

   config = function(opts: table)
      for k, v in pairs(opts) do
         check.options[k] = v
      end
   end,

   options = util.protected_proxy{
      keep_going = false,
   },
}

return check
