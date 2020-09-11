
local argparse = require("argparse")
local log = require("tlcli.log")
local util = require("tlcli.util")

local Command = require("tlcli.types").Command

local gen: Command
gen = {
   name = "gen",
   description = [[Generate a Lua file for one or more Teal scripts.]],
   argparse = function(cmd: ArgparseParser.Command)
      cmd:argument("script", "The Teal script.")
         :args("+")
      cmd:option("-o --output", "Write to <filename> instead")
         :argname("<filename>")
   end,

   command = function(m_config: table, args: table, ...: string): number
      local exit = 0
      for i = 1, select("#", ...) do
         local fname = select(i, ...)
         local code, err = util.teal.compile(fname)
         if err then
            exit = 1
            if not m_config.keep_going then
               break
            end
         else
            local fh, oerr = io.open(util.get_output_file_name(fname), "w")
            if not fh then
               log.error("Unable to open %s: %s", util.get_output_file_name(fname), oerr)
               if not m_config.keep_going then
                  exit = 1
                  break
               end
            end
            local ok, werr = fh:write(code)
            fh:close()
            if not ok then
               log.error("Unable to write to %s: %s", util.get_output_file_name(fname), werr)
               if not m_config.keep_going then
                  exit = 1
                  break
               end
            else
               log.normal("Wrote %s", util.get_output_file_name(fname))
            end
         end
      end
      return exit
   end,

   config = function(opts: table)
      for k, v in pairs(opts) do
         gen.options[k] = v
      end
   end,

   options = util.protected_proxy{
      keep_going = false,
      use_same_dir = false,
      check_first = false,
   },

}
return gen
