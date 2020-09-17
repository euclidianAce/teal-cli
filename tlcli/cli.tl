
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local config = require("tlcli.config")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command
local Config = types.Config
local GlobalConfig = types.GlobalConfig

log.enable_level("debug")
local M = {}

local commands: {string:Command} = {}

local function validate_command(parser: ArgparseParser, cmd: Command): boolean, string
   if commands[cmd.name] then
      return nil, "Command name clash with ".. cmd.name
   end
   if not cmd.name then
      return nil, "Command doesn't have a name"
   end
   if not cmd.description then
      return nil, "Command doesn't have a description"
   end
   if not cmd.command then
      return nil, "Command doesn't have a 'command' entry"
   end
   if type(cmd.command) ~= "function" then
      return nil, "Command's 'command' entry is not a function"
   end
   local parser_cmd = parser:command(cmd.name, cmd.description)
   if cmd.argparse then
      cmd.argparse(parser_cmd)
   end
   commands[cmd.name] = cmd
   return true
end

local function load_commands(parser: ArgparseParser)
   -- defaults
   -- TODO: tl complains about doing this dynamically
   -- for now it's fine to do it manually, but if/when more and more commands
   -- are included we should probably ignore that warning / attempt to fix it upstream

   -- Ideally this would be lazily loaded
   local gen_cmd = require("tlcli.commands.gen")
   gen_cmd.argparse(parser:command(gen_cmd.name, gen_cmd.description))
   commands[gen_cmd.name] = gen_cmd

   local check_cmd = require("tlcli.commands.check")
   check_cmd.argparse(parser:command(check_cmd.name, check_cmd.description))
   commands[check_cmd.name] = check_cmd

   local run_cmd = require("tlcli.commands.run")
   run_cmd.argparse(parser:command(run_cmd.name, run_cmd.description))
   commands[run_cmd.name] = run_cmd

   local build_cmd = require("tlcli.commands.build")
   build_cmd.argparse(parser:command(build_cmd.name, build_cmd.description))
   commands[build_cmd.name] = build_cmd
end

local cmd_path = os.getenv("XDG_CONFIG_HOME")
   and fs.path_concat(os.getenv("XDG_CONFIG_HOME"), "teal", "commands")
   or fs.path_concat(os.getenv("HOME"), ".config", "teal", "commands")

local function load_user_command(parser: ArgparseParser, path: string): boolean, string
   local fh, ferr = io.open(fs.path_concat(cmd_path, path), "r")
   if not fh then
      return nil, ferr
   end
   local code = fh:read("*a")
   fh:close()
   local cmd, err = tl.load(code, path, "t", _G as {any:any}) as (function, string) --TODO: maybe put a metatable on _G or build a sandbox
   if err then
      return nil, err
   end
   local ok, cmd = pcall(cmd) as (boolean, Command)
   if not ok then
      return nil, cmd as string
   end
   do
      local ok, err = validate_command(parser, cmd)
      if not ok then
         log.error("Unable to validate command loaded from %s\n%s", path, err)
      end
   end
   return true
end

local function init_parser(): ArgparseParser
   local par = argparse("tlc", "A command line interface to Teal, a minimalistic typed dialect of Lua.")

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

   load_commands(par)

   if lfs.attributes(cmd_path, "mode") == "directory" then
      for file in lfs.dir(cmd_path) do
         if lfs.attributes(file, "mode") ~= "directory"
            and file ~= "." and file ~= ".." then
            local ok, err = load_user_command(par, file)
            if not ok then
               log.error("Failed to load user command from %s\n%s", fs.path_concat(cmd_path, file), err)
            end
         end
      end
   else
      -- TODO: create commands directory or something
      log.error("Commands directory not found or is not a directory")
   end

   return par
end

---@return config.GlobalConfig
---@return string: the path to the root of the project (if there is one)
local function load_config(): GlobalConfig, string
   local global_config, err = config.load_global_config()
   if not global_config and err then
      log.error("Unable to load global config:\n%s", err)
   end
   local dir = config.find_project_root()
   return global_config, dir
end

function M.do_the_thing()
   local p = init_parser()
   local ok, args = p:pparse() as (boolean, Args)
   if not ok then
      log.error(args as string)
      log.normal(p:get_usage())
      os.exit(1)
   end
   if not args.command then
      log.normal(p:get_usage())
      os.exit(0)
   end
   if args.quiet then
      log.disable_level("normal")
      log.disable_level("verbose")
   end
   --log.debug("Args: %s", require'inspect'(args))
   local global_config = util.error_if_not(config.load_global_config())
   local local_config = util.error_if_not(config.load_local_config(commands))
   config.check_hooks()
   os.exit(commands[args.command as string].command(args, local_config))
end

return M

