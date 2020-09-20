
local argparse = require("argparse")
local tl = require("tl")

local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")
local loader = require("tlcli.loader")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command

log.enable("debug")

local par: ArgparseParser
local function prep(): Args
   par = argparse("tlc", "A command line interface to Teal, a minimalistic typed dialect of Lua.")

   par:option("-l --preload", "Execute the equivalent of require('modulename') before executing the Teal script(s).")
      :argname("<modulename>")
      :count("*")

   par:option("-I --include-dir", "Prepend this directory to the module search path.")
      :argname("<directory>")
      :count("*")

   par:flag("--skip-compat53", "Skip compat53 insertions.")
   par:flag("--version", "Print version and exit")
   par:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

   -- This will probably be moved to the build command and maybe gen
   par:flag("-p --pretend", "Do not write to any files, print what files would be generated.")

   par:require_command(true)
   par:command_target("command")

   do -- TODO upstream: Teal complains about dynamic requires, but only for literal `require` calls
      local _require = require
      for _, name in ipairs{ "check", "run", "build", "gen" } do
         local cmd = _require("tlcli.commands." .. name) as Command
         cmd.argparse(par:command(cmd.name, cmd.description))
         loader.loaded_commands[cmd.name] = cmd
      end
   end

   -- global config loading
   local global_config_env <const> = setmetatable({
      -- TODO: put stuff here that does stuff
   }, { __index = _G })
   loadfile(fs.GLOBAL_CONFIG_PATH(), "t", global_config_env as table)

   local function add_cmd(cmd: Command)
      cmd.argparse(par:command(cmd.name, cmd.description))
   end

   -- TODO: user command loading
   --for path in fs.dir(fs.CMD_PATH()) do
      --add_cmd(loader.load_command(path))
   --end

   local ok, args = par:pparse() as (boolean, Args)
   if not ok then
      log.error(args as string)
      log.normal(par:get_usage())
      os.exit(1)
   end
   if not args.command then
      log.normal(par:get_usage())
      os.exit(0)
   end
   if args.quiet then
      log.disable("normal")
      log.disable("verbose")
   end
   loader.load_config()
   local options = loader.load_options()
   for i, name in ipairs(options.deps as {string} or {}) do
      fs.add_to_path(fs.path_concat(fs.TYPES_PATH(), name))
   end
   for i, dir in ipairs(options.include_dir as {string} or {}) do
      fs.add_to_path(dir)
   end
   return args
end

return function()
   local args = prep()
   tl.loader()
   local exit = loader.loaded_commands[args.command as string].command(args)
   util.check_hooks()
   os.exit(exit)
end
