
local argparse = require("argparse")

local ansi = require("tlcli.ansi")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command

local options = util.protected_proxy{
   keep_going = false,
   use_same_dir = false,
   check_first = false,
}

local gen: Command = {
   name = "gen",
   description = [[Generate a Lua file for one or more Teal scripts.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The Teal script.")
         :args("+")
      cmd:option("-o --output", "Write to <filename> instead")
         :argname("<filename>")
   end,

   command = function(args: Args): number
      local exit = 0
      for i, fname in ipairs(args["script"] as {string}) do
         local code, err = util.teal.compile(fname)
         if err then
            exit = 1
            if not options.keep_going then
               break
            end
         else
            local out_name = fs.get_output_file_name(fname)
            local disp_name = ansi.bright.yellow(out_name)
            local fh, oerr = io.open(out_name, "w")
            if not fh then
               log.error("Unable to open %s: %s", disp_name, oerr)
               if not options.keep_going then
                  exit = 1
                  break
               end
            end
            local ok, werr = fh:write(code)
            fh:close()
            if not ok then
               log.error("Unable to write to %s: %s", disp_name, werr)
               if not options.keep_going then
                  exit = 1
                  break
               end
            else
               log.normal("Wrote %s", disp_name)
            end
         end
      end
      return exit
   end,

   config = util.create_setters({
      keep_going = util.typechecker "boolean",
   }, options)
}

return gen
