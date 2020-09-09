local tl = require("tl")

local fs = require("tlcli.fs")

local global_config_dir = os.getenv("XDG_CONFIG_HOME") or fs.path_concat(os.getenv("HOME"), ".config")
local global_config_file = fs.path_concat(global_config_dir, "config.lua")

local record GlobalConfig
   exclude: {string}
   include_dir: {string}
   preload_modules: {string}
   quiet: boolean
   skip_compat53: boolean
   type_dir: {string}
end

local record Config
   build_dir: string
   exclude: {string}
   files: {string}
   include: {string}
   include_dir: {string}
   preload_modules: {string}
   quiet: boolean
   skip_compat53: boolean
   source_dir: string
end

local M = {
   Config = Config,
   GlobalConfig = GlobalConfig,
}

local function make_global_loaders(): {string:function}, GlobalConfig
   local new_global_config: GlobalConfig = {}
   -- TODO: there could in the future be more processing with these options, but for now, we just set the config options
   local global_config_loaders = {
      exclude = function(arg: {string}) new_global_config.exclude = arg end,
      include_dir = function(arg: {string}) new_global_config.include_dir = arg end,
      preload_modules = function(arg: {string}) new_global_config.preload_modules = arg end,
      quiet = function(arg: boolean) new_global_config.quiet = arg end,
      skip_compat53 = function(arg: boolean) new_global_config.skip_compat53 = arg end,
      type_dir = function(arg: {string}) new_global_config.type_dir = arg end,
   }
   return global_config_loaders, new_global_config
end

local function make_local_loaders(): {string:function}, Config
   local new_config: Config = {}
   local config_loaders = {
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
   return config_loaders, new_config
end

function M.load_config_from_file(fname: string): Config, string
   local loaders, config = make_local_loaders()
   -- TODO: See if tl can expose its Variable and Env type so we can use tl.load with a custom environment to get type checking
   local chunk, load_err = loadfile(fname, "t", setmetatable(_G, {__index = loaders}) as table) as (function, string)
   setmetatable(_G, nil)
   if load_err then
      return nil, load_err
   end
   local ok, call_err = pcall(chunk) as (boolean, string)
   if not ok then
      return nil, call_err
   end
   return config
end

function M.load_global_config(): GlobalConfig, string
   local loaders, config = make_global_loaders()
   local chunk, load_err = loadfile(global_config_file, "t", setmetatable(_G, {__index = loaders}) as table) as (function, string)
   local ok, call_err = pcall(chunk) as (boolean, string)
   if not ok then
      return nil, call_err
   end
   return config
end

return M
