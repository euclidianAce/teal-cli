
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local config = require("tlcli.config")
local fs = require("tlcli.fs")
local log = require("tlcli.log")

local M = {}

local command_callbacks: {string:function} = {}

local function load_commands(parser: ArgparseParser)
   -- defaults
   local gen_cmd = require("tlcli.commands.gen")
   gen_cmd.argparse(parser:command(gen_cmd.name, gen_cmd.description))
   command_callbacks[gen_cmd.name] = gen_cmd.command

   local check_cmd = require("tlcli.commands.check")
   check_cmd.argparse(parser:command(check_cmd.name, check_cmd.description))
   command_callbacks[check_cmd.name] = check_cmd.command

   local run_cmd = require("tlcli.commands.run")
   run_cmd.argparse(parser:command(run_cmd.name, run_cmd.description))
   command_callbacks[run_cmd.name] = run_cmd.command

end

local cmd_path = os.getenv("XDG_CONFIG_HOME")
   and fs.path_concat(os.getenv("XDG_CONFIG_HOME"), "teal", "commands")
   or fs.path_concat(os.getenv("HOME"), ".config", "teal", "commands")

local function load_user_command(parser: ArgparseParser, path: string): boolean, string
   --log.debug("load_user_command called with parser %s and path %s", tostring(parser), path)
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
   local ok, res = pcall(cmd) as (boolean, string)
   if not ok then
      log.debug("pcall errored with %s", res)
      return nil, res
   end
   return true
end

function M.init_parser(): ArgparseParser
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
   par:flag("-p --pretend", "Do not write to any files, print what files would be generated.")

   par:require_command(false)
   par:command_target("command")

   load_commands(par)

   for file in lfs.dir(cmd_path) do
      if lfs.attributes(file, "mode") ~= "directory"
         and file ~= "." and file ~= ".." then
         local ok, err = load_user_command(par, file)
         if not ok then
            log.error("Failed to load user command from %s\n%s", fs.path_concat(cmd_path, file), err)
         end
      end
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

log.enable_level("debug")
local p = M.init_parser()
local args = p:parse()
log.debug(require"inspect"(arg))
log.debug(require"inspect"(args))
log.debug("Command: %s\nCommand entry: %s", args.command, require"inspect"(command_callbacks[args.command as string]))

return M

