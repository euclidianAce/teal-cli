
local tl = require("tl")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Command = types.Command

local M = {
   loaded_commands = {},
}

local function typecheck(t, typename)
   return type(t) == typename
end

local function find_command_path(name)
   return fs.match(fs.CMD_PATH(), { name })()
end

local function load_command_from_path(path)
   local chunk, err = util.teal.type_check_and_load(path)
   if not chunk then
      return nil, err
   end
   local ok, res = pcall(chunk)
   if not ok then
      return nil, res
   end
   return res
end

local function validate_command(t)
   if not typecheck(t.name, "string") then       return nil, "Command missing name: string field" end
   if not typecheck(t.description, "string") then       return nil, "Command missing description: string field" end
   if not typecheck(t.command, "function") then       return nil, "Command missing command: function(Args): number field" end
   if not typecheck(t.config, "function") then       return nil, "Command missing config: function(any) field" end
   return true
end

local loaded_files = {}
function M.load_user_commands()
   local ret = true
   local errors = {}
   local commands = {}
   local ok, err = pcall(function()
      for fname in fs.dir(fs.CMD_PATH()) do
         if not loaded_files[fname] then
            local res, err = load_command_from_path(fname)
            if err then
               ret = false
               table.insert(errors, err)
            else
               local is_valid, reason = validate_command(res)
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
   end)
   if not ok then
      log.warn("Error loading user commands: ", err)
   end
   return commands, #errors > 0 and table.concat(errors, "\n") or nil
end

function M.load_command(name)
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
   local is_valid, reason = validate_command(cmd)
   if not is_valid then
      return nil, reason
   end
   M.loaded_commands[name] = cmd
   return cmd
end

local opts = {}
local str_array = util.array_typechecker("string")
local str_map = util.map_typechecker("string", "string")
local config_env = setmetatable({
   project = util.create_setters({
      include_dir = str_array,
      preload_modules = str_array,
      deps = str_array,
      module = function(x)
         if not str_map(x) then
            return
         end
         if not x.name or not x.source then
            return
         end
         return x
      end,
   }, opts, function(unknown_opt)
      log.warn("Unknown option for `project` config: %s", tostring(unknown_opt))
   end),
   compiler = util.create_switches({
      "skip_compat53",
   }, opts),
}, {
   __index = function(env, key)
      local cmd
      if type(key) == "string" then
         cmd = M.load_command(key)
         if cmd then
            rawset(env, key, cmd.config)
            return cmd.config
         end
      end
      return (_G)[key]
   end,
})
local function load_config_from_path(path)
   local chunk, load_err = loadfile(path, "t", config_env)
   if not chunk then
      return false, load_err
   end
   local ok, call_err = pcall(chunk)
   if not ok then
      return false, call_err
   end
   return true
end

local loaded_config = {}

function M.load_config()
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

function M.load_options()
   return opts
end

return M
