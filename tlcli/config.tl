local tl = require("tl")

local fs = require("tlcli.fs")
local lfs = require("lfs")
local log = require("tlcli.log")
local Command = require("tlcli.types").Command
local Config = require("tlcli.types").Config
local GlobalConfig = require("tlcli.types").GlobalConfig

local global_config_dir = os.getenv("XDG_CONFIG_HOME") or fs.path_concat(os.getenv("HOME"), ".config")
local global_config_file = fs.path_concat(global_config_dir, "config.lua")


local M = {}

local function make_global_loaders(): {string:function}, GlobalConfig
   local new_global_config: GlobalConfig = {}
   -- TODO: there could in the future be more processing with these options, but for now, we just set the config options
   local global_config_loaders = {
      include_dir = function(arg: {string}) new_global_config.include_dir = arg end,
      preload_modules = function(arg: {string}) new_global_config.preload_modules = arg end,
      quiet = function(arg: boolean) new_global_config.quiet = arg end,
      skip_compat53 = function(arg: boolean) new_global_config.skip_compat53 = arg end,
      type_dir = function(arg: {string}) new_global_config.type_dir = arg end,
   }
   return global_config_loaders, new_global_config
end

local function make_local_loaders(commands: {string:Command}): {string:function}, Config, string
   local new_config: Config = {}
   local config_loaders: {string:function} = {
      build_dir = function(dirname: string) new_config.build_dir = dirname end,
      exclude = function(patterns: {string}) new_config.exclude = patterns end,
      files = function(filenames: {string}) new_config.files = filenames end,
      include = function(patterns: {string}) new_config.include = patterns end,
      include_dir = function(filenames: {string}) new_config.include_dir = filenames end,
      preload_modules = function(modulenames: {string}) new_config.preload_modules = modulenames end,
      quiet = function(bool: boolean) new_config.quiet = bool end,
      skip_compat53 = function(bool: boolean) new_config.skip_compat53 = bool end,
      source_dir = function(filename: string) new_config.source_dir = filename end,
   }
   local warnings = {}
   for name, cmd in pairs(commands) do
      if config_loaders[name] ~= nil then
         table.insert(warnings, "Name conflict in config loaders: " .. name .. " is already defined")
      else
         config_loaders[name] = cmd.config
      end
   end
   return config_loaders, new_config, table.concat(warnings, "\n")
end

local function load_config_from_file(fname: string, commands: {string:Command}): Config, string
   local loaders, config = make_local_loaders(commands)
   -- TODO: See if tl can expose its Variable and Env type so we can use tl.load with a custom environment to get type checking
   local warnings: {string} = {}
   local chunk, load_err = loadfile(fname, "t", setmetatable(_G, {
      __index = function(_: table, key: string): any
         if loaders[key] then
            return loaders[key]
         end
         table.insert(warnings, "Attempt to use unknown global " .. tostring(key))
         return setmetatable({}, {
            __call = function(self: table, ...: any)
               local warning = {}
               table.insert(warning, "Attempt to call unknown global " .. tostring(key) .. " with arguments: ")
               for i = 1, select("#", ...) do
                  table.insert(warning, tostring((select(i, ...))))
               end
               table.insert(warnings, table.concat(warning, "\n"))
            end
         })
      end
   }) as table) as (function, string)
   if load_err then
      return nil, load_err
   end
   local ok, call_err = pcall(chunk) as (boolean, string)
   if not ok then
      return nil, call_err
   end
   setmetatable(_G, nil)
   return config, #warnings > 0 and table.concat(warnings, "\n") or nil
end

local user_home = os.getenv("HOME")
function M.is_in_dir(dirname: string, filename: string): boolean
   for file in lfs.dir(dirname) do
      if file == filename then
         return true
      end
   end
end

local config_file_name <const> = "tlcconfig.lua"
function M.find_project_root(): string
   local orig_dir = lfs.currentdir()

   -- TODO: we dont need to chdir here
   -- so... dont

   local has_local_config = M.is_in_dir(orig_dir, config_file_name)
   local found_home = false
   while not has_local_config do
      if lfs.currentdir() == user_home then
         found_home = true
         break;
      end
      lfs.chdir("..")
      has_local_config = M.is_in_dir(lfs.currentdir(), config_file_name)
   end
   local root_dir: string
   if not found_home then
      root_dir = lfs.currentdir()
   end
   lfs.chdir(orig_dir)
   return root_dir or orig_dir
end

function M.load_local_config(commands: {string:Command}): Config, string
   local dir = M.find_project_root()
   return load_config_from_file(fs.path_concat(dir, config_file_name), commands)
end

function M.load_global_config(): GlobalConfig, string
   local loaders, config = make_global_loaders()
   local chunk, load_err = loadfile(global_config_file, "t", setmetatable(_G, {__index = loaders}) as table) as (function, string)
   if load_err and not string.match(load_err, "No such file or directory$") then
      return nil, load_err
   elseif load_err then
      return {}, nil
   end
   local ok, call_err = pcall(chunk) as (boolean, string)
   if not ok then
      return nil, call_err
   end
   return config
end

return M
