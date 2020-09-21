
local tl = require("tl")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Command = types.Command

local M = {
   loaded_commands: {string:Command} = {}
}

local function typecheck(t: any, typename: string): boolean
   return type(t) == typename
end

local function find_command_path(name: string): string
   return fs.match(fs.CMD_PATH(), {name})()
end

local function load_command_from_path(path: string): Command, string
   local chunk, err = util.teal.type_check_and_load(path)
   if not chunk then
      return nil, err
   end
   local ok, res = pcall(chunk) as (boolean, function)
   if not ok then
      return nil, res as string
   end
   return res as Command
end

local function validate_command(t: table): boolean, string
   if not typecheck(t.name, "string") then return nil, "Command missing name: string field" end
   if not typecheck(t.description, "string") then return nil, "Command missing description: string field" end
   if not typecheck(t.command, "function") then return nil, "Command missing command: function(Args): number field" end
   if not typecheck(t.config, "function") then return nil, "Command missing config: function(any) field" end
   return true
end

local loaded_files: {string:boolean} = {}
function M.load_user_commands(): {Command}, string
   local ret = true
   local errors: {string} = {}
   local commands: {Command} = {}
   for fname in fs.dir(fs.CMD_PATH()) do
      if not loaded_files[fname] then
         local res, err = load_command_from_path(fname)
         if err then
            ret = false
            table.insert(errors, err)
         else
            local is_valid, reason = validate_command(res as table)
            if not is_valid then
               ret = false
               table.insert(errors, reason)
            else
               loaded_files[fname] = true
               table.insert(commands, res)
            end
         end
      end
   end
   return commands, #errors > 0 and table.concat(errors, "\n") or nil
end

function M.load_command(name: string): Command, string
   if M.loaded_commands[name] then
      return M.loaded_commands[name]
   end
   local path = find_command_path(name)
   if not path then
      return nil, "Command path not found"
   end
   local cmd, load_err = load_command_from_path(path)
   if not cmd then
      return nil, load_err
   end
   local is_valid, reason = validate_command(cmd as table)
   if not is_valid then
      return nil, reason
   end
   M.loaded_commands[name] = cmd
   return cmd
end

local opts: {string:any} = {}
local str_array = util.array_typechecker "string"
local config_env = setmetatable({
   project = util.create_setters({
      include_dir = str_array,
      preload_modules = str_array,
      deps = str_array,
   }, opts),
   compiler = util.create_switches({
      "skip_compat53"
   }, opts)
}, {
   __index = function(env: table, key: any): any
      local cmd: Command
      if key is string then
         cmd = M.load_command(key as string)
         if cmd then
            rawset(env, key as string, cmd.config)
            return cmd.config
         end
      end
      return (_G as table)[key]
   end
})
local function load_config_from_path(path: string): boolean, string
   local chunk, load_err = loadfile(path, "t", config_env as table)
   if not chunk then
      return false, load_err as string
   end
   local ok, call_err = pcall(chunk)
   if not ok then
      return false, call_err as string
   end
   return true
end

local loaded_config: {string:boolean} = {}

function M.load_config(): boolean, string
   local root = fs.find_project_root()
   if not loaded_config[root] then
      local ok, err = load_config_from_path(fs.path_concat(root, fs.ROOT_FILE()))
      if not ok then
         return nil, err
      end
      loaded_config[root] = true
   end
   return loaded_config[root]
end

function M.load_options(): table
   return opts
end

return M
