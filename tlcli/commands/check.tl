
local argparse = require("argparse")
local ansi = require("tlcli.ansi")
local config = require("tlcli.config")
local log = require("tlcli.log")
local util = require("tlcli.util")

local Args = require("tlcli.types").Args
local Command = require("tlcli.types").Command

local b = ansi.bright
local r = ansi.reset()

local log_str = "%sType checked%s: %s"
local long_log_str = "%sType checked%s: %s\n"
   .. "   Use %stlc run%s %s\n"
   .. "      to run %s as a script\n"
   .. "   Use %stlc gen%s %s\n"
   .. "      to generate %s"

local check: Command
check = {
   name = "check",
   description = [[Type check one or more Teal scripts.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The Teal script.")
         :args("+")
   end,

   command = function(args: Args): number
      local exit = 0
      for i, fname in ipairs(args["script"] as {string}) do
         local ok, err = util.teal.type_check_file(fname)
         if not ok then
            log.log("error", err)
            exit = 1
            if not check.options.keep_going then
               break
            end
         else
            if #args["script"] as {string} > 1 then
               log.normal(log_str, b"green", r, fname)
            else
               log.normal(
                  long_log_str,
                  b"green", r, fname,
                  b"magenta", r, fname, fname,
                  b"magenta", r, fname,
                  util.get_output_file_name(fname)
               )
            end
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
