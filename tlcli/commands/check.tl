
local argparse = require("argparse")
local ansi = require("tlcli.ansi")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command

local b = ansi.bright
local r = ansi.reset()

-- TODO: define a colorscheme for this type of stuff
local log_str = b.green"Type checked: " .. b.yellow"%s"
local long_log_str = log_str .. "\n"
   .. "   Use " .. b.magenta"tlc run " .. b.yellow" %s\n"
   .. "      to run " .. b.yellow"%s" .. " as a script\n"
   .. "   Use " .. b.magenta"tlc gen" .. b.yellow" %s\n"
   .. "      to generate " .. b.yellow"%s"

-- TODO: better err handler
local flags = util.protected_proxy{
   keep_going = false
}

local check: Command = {
   name = "check",
   description = [[Type check one or more Teal scripts.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The Teal script.")
         :args("+")
   end,

   command = function(args: Args): number
      require("tlcli.loader").load_config()

      local exit = 0

      for i, fname in ipairs(args["script"] as {string}) do
         local ok, err = util.teal.type_check_file(fname)
         if not ok then
            log.error(err)
            exit = 1
            if not flags.keep_going then
               break
            end
         else
            if #args["script"] as {string} > 1 then
               log.normal(log_str, fname)
            else
               log.normal(
                  long_log_str,
                  fname, fname, fname, fname,
                  fs.get_output_file_name(fname)
               )
            end
         end
      end
      return exit
   end,

   config = function(opt: string): function
      if opt == "flags" then
         return function(t: {string})
            for i, v in ipairs(t) do
               flags[v] = true
            end
         end
      else
         -- TODO warn
         log.warn("Invalid option '%s'", tostring(opt))
      end
      return function() end
   end
}

return check
