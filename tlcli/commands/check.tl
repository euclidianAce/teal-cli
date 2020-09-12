
local argparse = require("argparse")
local ansi = require("tlcli.ansi")
local config = require("tlcli.config")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command
local Config = types.Config

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

   command = function(args: Args, cfg: Config): number
      local exit = 0
      for i, mod_name in ipairs(cfg.preload_modules or {}) do
         util.teal.add_module(mod_name)
      end

      for i, path_name in ipairs(cfg.include_dir or {}) do
         fs.add_to_teal_path(path_name)
      end
      for i, fname in ipairs(args["script"] as {string}) do
         local ok, err = util.teal.type_check_file(fname)
         if not ok then
            log.error(err)
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
                  fs.get_output_file_name(fname)
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
