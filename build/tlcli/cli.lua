
local argparse = require("argparse")
local tl = require("tl")

local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")
local loader = require("tlcli.loader")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command

local par
local function prep()
   par = argparse("tlc", "A command line interface to Teal, a minimalistic typed dialect of Lua.")

   par:option("-l --preload", "Execute the equivalent of require('modulename') before executing the Teal script(s)."):
   argname("<modulename>"):
   count("*")

   par:option("-I --include-dir", "Prepend this directory to the module search path."):
   argname("<directory>"):
   count("*")

   par:flag("--skip-compat53", "Skip compat53 insertions.")
   par:flag("--version", "Print version and exit")
   par:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")
   par:flag("-d --debug", "Enable debug logging.")


   par:flag("-p --pretend", "Do not write to any files, print what files would be generated.")

   par:require_command(true)
   par:command_target("command")

   do
      local _require = require
      for _, name in ipairs({ "check", "run", "build", "gen" }) do
         local cmd = _require("tlcli.commands." .. name)
         cmd.argparse(par:command(cmd.name, cmd.description))
         loader.loaded_commands[cmd.name] = cmd
      end
   end


   local global_config_env = setmetatable({},

{ __index = _G })
   loadfile(fs.GLOBAL_CONFIG_PATH(), "t", global_config_env)

   local function add_cmd(cmd)
      cmd.argparse(par:command(cmd.name, cmd.description))
      loader.loaded_commands[cmd.name] = cmd
   end

   local user_commands, user_cmd_err = loader.load_user_commands()
   if user_cmd_err then
      log.error("Error loading user commands:\n%s", user_cmd_err)
   end
   for i, v in ipairs(user_commands) do
      add_cmd(v)
   end

   local ok, args = par:pparse()
   if not ok then
      log.error(args)
      log.normal(par:get_usage())
      os.exit(1)
   end
   if not args.command then
      log.normal(par:get_usage())
      os.exit(0)
   end
   if args.debug then
      log.enable("debug")
   end
   if args.quiet then
      log.disable("normal")
      log.disable("verbose")
   end
   loader.load_config()
   local options = loader.load_options()
   util.teal.set_skip_compat53(options.skip_compat53)
   for i, name in ipairs(options.deps or {}) do
      fs.add_to_path(fs.path_concat(fs.TYPES_PATH(), name))
   end
   for i, dir in ipairs(options.include_dir or {}) do
      fs.add_to_path(dir)
   end
   for i, modname in ipairs(options.preload_modules or {}) do
      util.teal.add_module(modname)
   end
   return args
end

return function()
   local args = prep()
   tl.loader()
   local exit = loader.loaded_commands[args.command].command(args)
   log.flush()
   util.check_hooks()
   os.exit(exit)
end