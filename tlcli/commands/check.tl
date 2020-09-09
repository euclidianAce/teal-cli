
local ansi = require("tlcli.ansi")
local config = require("tlcli.config")
local log = require("tlcli.log")
local util = require("tlcli.util")
local Command = require("tlcli.commands")


local check: Command = {}
check.command = function(opts: table, ...: string): number
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
         log.log("normal", "%sType checked%s: %s", ansi.bright"green", ansi.reset(), fname)
         log.log("normal", "   Use %stlc run%s %s", ansi.bright"magenta", ansi.reset(), fname)
         log.log("normal", "      to run %s as a script", fname)
         log.log("normal", "   Use %stlc gen%s %s", ansi.bright"magenta", ansi.reset(), fname)
         log.log("normal", "      to generate %s", util.get_output_file_name(fname))
      end
   end
   return exit
end
check.config = function(opts: table)
   for k, v in pairs(opts) do
      check.options[k] = v
   end
end
check.options = setmetatable({
   keep_going = false,
}, {
   __index = function(_: table, index: any)
      error("Invalid option for check command: " .. tostring(any), 2)
   end
}) as table

return check
