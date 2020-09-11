
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local config = require("tlcli.config")
local fs = require("tlcli.fs")
local log = require("tlcli.log")

local Args = require("tlcli.types").Args
local Command = require("tlcli.types").Command

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
   local parser_cmd = parser:command(cmd.name, cmd.description)
   if cmd.argparse then
      cmd.argparse(parser_cmd)
   end
   commands[cmd.name] = cmd
   return true
end

local function load_commands(parser: ArgparseParser)
   -- defaults
   local gen_cmd = require("tlcli.commands.gen")
   gen_cmd.argparse(parser:command(gen_cmd.name, gen_cmd.description))
   commands[gen_cmd.name] = gen_cmd

   local check_cmd = require("tlcli.commands.check")
   check_cmd.argparse(parser:command(check_cmd.name, check_cmd.description))
   commands[check_cmd.name] = check_cmd

   local run_cmd = require("tlcli.commands.run")
   run_cmd.argparse(parser:command(run_cmd.name, run_cmd.description))
   commands[run_cmd.name] = run_cmd
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
      log.debug("loadfile errored with %s", err)
      return nil, err
   end
   local ok, cmd = pcall(cmd) as (boolean, Command)
   if not ok then
      log.debug("pcall errored with %s", cmd as string)
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
   local par = argparse("tlc", "A cli to Teal, a minimalistic typed dialect of Lua.")

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

   par:require_command(false)
   par:command_target("command")

   load_commands(par)

   if lfs.attributes(cmd_path, "mode") == "directory" then
      log.debug("found cmd_path at %s", cmd_path)
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
      log.debug("commands dir not found or is not a directory")
   end

   return par
end

---@return config.GlobalConfig
---@return string: the path to the root of the project (if there is one)
local function load_config(): config.GlobalConfig, string
   local global_config, err = config.load_global_config()
   if not global_config and err then
      log.error("Unable to load global config:\n%s", err)
   end
   local root_dir, orig_dir = config.find_project_root()
end

local p = init_parser()

function M.do_the_thing()
   log.debug("Getting args from argparse")
   local ok, args = p:pparse() as (boolean, Args)
   if not ok then
      log.normal(p:get_usage())
      os.exit(1)
   end
   if not args.command then
      log.normal(p:get_usage())
      os.exit(0)
   end
   local global_config = config.load_global_config()
   local local_config = config.load_local_config()

   log.debug(require"inspect"(arg))
   log.debug(require"inspect"(args))
   log.debug("Command: %s\nCommand entry: %s", args.command as string, require"inspect"(commands[args.command as string]))

   os.exit(commands[args.command as string].command(args))
end

return M

