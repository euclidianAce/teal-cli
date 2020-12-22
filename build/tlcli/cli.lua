
local argparse = require("argparse")
local tl = require("tl")

local fs = require("tlcli.fs")
local loader = require("tlcli.loader")
local log = require("tlcli.log")
local runner = require("tlcli.runner")
local util = require("tlcli.util")
local cs = require("tlcli.ui.colorscheme")

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
   par:flag("--version", "Print version and exit.")


   par:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")
   par:flag("-v --verbose", "Enable verbose logging.")
   par:flag("-d --debug", "Enable debug logging.")

   par:flag("--no-color", "Disable colors in output.")


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
   if user_cmd_err and not user_cmd_err:match("No such file or directory") then
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
   if args.no_color then
      cs.disable_colors()
   end
   if not args.command then
      log.normal(par:get_usage())
      os.exit(1)
   end
   if args.debug then
      log.enable("debug")
      log.debug("Debug output enabled")
   end
   if args.no_color then
      log.debug("Colors disabled")
   end
   if args.verbose then
      log.debug("Verbose output enabled")
      log.enable("verbose")
   end
   if args.quiet then
      log.disable("normal")
      log.disable("verbose")
      log.debug("Quiet logging enabled\n   Disabled normal output\n   Disabled verbose output")
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
   local exit = 0
   local cmd = runner.wrap(function()
      tl.loader()
      exit = loader.loaded_commands[args.command].command(args)
   end)
   local ok, res = cmd:run()
   util.check_hooks()
   log.flush()
   if not ok then
      log.set_buffered(false)
      log.error("Error in command %s\n%s\n%s", args.command, res, cmd:get_traceback())
      os.exit(1)
   end
   os.exit(exit)
end
