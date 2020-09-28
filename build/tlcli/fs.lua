
local log = require("tlcli.log")
local util = require("tlcli.util")
local lfs = require("lfs")

local fs = {}




do
   local emptyref = setmetatable({}, {
      __newindex = function()
         error("Attempt to assign to emptyref, stop that", 2)
      end,
      __index = function()
         error("Attempt to index into emptyref, stop that", 2)
      end,
   })

   function fs.is_file(f)
      return f == emptyref
   end

   function fs._get_emptyref()
      return emptyref
   end
end

local path_separator = package.config:sub(1, 1)
function fs.get_path_separator()
   return path_separator
end

local function path_components_iter(pathname)
   for component in util.split(pathname, path_separator) do
      coroutine.yield(component)
   end
end

function fs.path_components(pathname)
   return util.wrap_with(path_components_iter, pathname)
end

function fs.get_path_components(pathname)
   return util.generate(fs.path_components(pathname))
end

local function fix_path_chunk(pathchunk)
   if pathchunk == ".." then
      return nil
   end
   return pathchunk
end
local function fix_path(path)
   local fixed_path_components = {}
   local not_relative = string.sub(path, 1, 1) == "/"
   for comp in fs.path_components(path) do
      if #comp > 0 then
         local fixed_comp = fix_path_chunk(comp)
         if not fixed_comp then
            return "Error fixing path " .. path .. ", " .. ".." .. path_separator .. " is not allowed"
         end
         table.insert(fixed_path_components, fixed_comp)
      end
   end
   if not_relative then
      table.insert(fixed_path_components, 1, "")
   end
   return table.concat(fixed_path_components, path_separator)
end

function fs.path_concat(...)
   local path = {}
   for i = 1, select("#", ...) do
      if type(select(i, ...)) == "table" then
         for j, str in ipairs((select(i, ...))) do

            if #str > 0 then
               table.insert(path, str)
            end
         end
      else
         local raw_fname = select(i, ...)
         if i > 1 and string.sub(raw_fname, 1, 1) == "/" then
            error("Attempt to concatenate non relative paths")
         end

         if #raw_fname > 0 then
            table.insert(path, raw_fname)
         end
      end
   end
   return table.concat(path, path_separator)
end

local HOME = os.getenv("HOME")
local XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME") or
fs.path_concat(HOME, ".config")
local CMD_PATH = fs.path_concat(XDG_CONFIG_HOME, "teal", "commands")
local GLOBAL_CONFIG_PATH = fs.path_concat(XDG_CONFIG_HOME, "config.lua")
local TYPES_PATH = fs.path_concat(XDG_CONFIG_HOME, "teal", "teal-types", "types")

function fs.HOME()    return HOME end
function fs.XDG_CONFIG_HOME()    return XDG_CONFIG_HOME end
function fs.CMD_PATH()    return CMD_PATH end
function fs.GLOBAL_CONFIG_PATH()    return GLOBAL_CONFIG_PATH end
function fs.TYPES_PATH()    return TYPES_PATH end

local function trim(str)
   return (str:gsub("^%s*(.-)%s*$", "%1"))
end
function fs.get_shared_library_ext()
   if not package.cpath or trim(package.cpath) == "" then
      return "so"
   end

   return package.cpath:match("%.(%w+)%s*$")
end

function fs.path_parents(pathname)
   local current_path = ""
   local comps = fs.get_path_components(pathname)
   comps[#comps] = nil
   return coroutine.wrap(function()
      for i, dir in ipairs(comps) do
         current_path = fs.path_concat(current_path, dir)
         coroutine.yield(current_path)
      end
   end)
end

local function dir_iter(dirname)
   for file in assert(lfs.dir(dirname)) do
      if dirname == "." then
         dirname = ""
      end

      if file ~= ".." and file:sub(1, 1) ~= "." then
         if lfs.attributes(fs.path_concat(dirname, file), "mode") == "directory" then
            dir_iter(fs.path_concat(dirname, file))
         elseif file:sub(1, 1) ~= "." then
            coroutine.yield(fs.path_concat(dirname, file))
         end
      end
   end
end

function fs.dir(dirname)
   return util.wrap_with(dir_iter, dirname)
end

local Matcher = {}

local function esc_str(s)
   return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", function(match)
      if match == "*" then
         return "[^" .. path_separator .. "]-"
      end
      return "%" .. match
   end))
end

local function create_matcher(path_pattern)
   local comps = {}
   for chunk in util.split(path_pattern, "**" .. fs.get_path_separator()) do
      if chunk == ".." then
         error("Error in pattern \"" .. path_pattern .. "\" .." .. fs.get_path_separator() .. " is not allowed")
      end
      table.insert(comps, esc_str(chunk))
   end
   comps[1] = "^" .. comps[1]
   comps[#comps] = comps[#comps] .. "$"
   return function(s)
      local idx = 1
      local s_idx

      for i, comp in ipairs(comps) do
         s_idx, idx = string.find(s, comp, idx)
         if not s_idx then
            return false
         end
      end
      return true
   end
end

local function match_arr(patts, str)
   for i, v in ipairs(patts) do
      if v(str) then
         return i
      end
   end
end

function fs.get_file_tree(dirname)
   local dir = {}

   for path in fs.dir(dirname) do
      local current = dir
      local components = fs.get_path_components(path)
      for i, component in ipairs(components) do
         if i == #components then
            current[component] = fs._get_emptyref()
         elseif not current[component] then
            current[component] = {}
         end
         current = current[component]
      end
   end
   return dir
end

function fs.get_file_paths(dirname)
   return util.generate(fs.dir(dirname))
end

function fs.match(dirname, include, exclude)
   local inc_matchers = {}
   local exc_matchers = {}

   for i, patt in ipairs(include or {}) do
      table.insert(inc_matchers, create_matcher(patt))
   end
   for i, patt in ipairs(exclude or {}) do
      table.insert(exc_matchers, create_matcher(patt))
   end

   return coroutine.wrap(function()
      for fname in fs.dir(dirname) do
         if fname:match("%.tl$") and not fname:match("%.d%.tl$") then
            local is_included = true
            if #inc_matchers > 0 and not match_arr(inc_matchers, fname) then
               is_included = false
            end

            if #exc_matchers > 0 then
               if is_included and match_arr(exc_matchers, fname) then
                  is_included = false
               end
            end

            if is_included then
               coroutine.yield(fname)
            end
         end
      end
   end)
end

function fs.add_to_path(dirname)
   local path_str = dirname

   if string.sub(path_str, -1) == path_separator then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. path_separator

   local lib_path_str = path_str .. "?." .. fs.get_shared_library_ext() .. ";"
   local lua_path_str = path_str .. "?.lua" .. ";" ..
   path_str .. "?" .. path_separator .. "init.lua;"

   package.path = lua_path_str .. package.path
   package.cpath = lib_path_str .. package.cpath
end

local function get_extension(filename)
   local basename, extension = string.match(filename, "(.*)%.([a-z]+)$")
   extension = extension and extension:lower()
   return extension
end

function fs.get_output_file_name(filename)
   local comps = fs.get_path_components(filename)
   local local_filename = comps[#comps]
   local ext = get_extension(local_filename)
   if ext == "lua" then
      return local_filename:sub(1, -4) .. "out.lua"
   elseif ext == "tl" then
      return local_filename:sub(1, -3) .. "lua"
   end
end

function fs.get_output_file_name_components(filename)
   local comps = fs.get_path_components(filename)
   local ext = get_extension(comps[#comps])
   if ext == "lua" then
      comps[#comps] = comps[#comps]:sub(1, -4) .. "out.lua"
   elseif ext == "tl" then
      comps[#comps] = comps[#comps]:sub(1, -3) .. "lua"
   end
   return comps
end

function fs.is_absolute(path)
   return path:sub(1, 1) == "/"
end

local USER_HOME = os.getenv("HOME")
function fs.is_in_dir(dirname, filename)
   local dir_comps = fs.get_path_components(dirname)
   local file_comps = fs.get_path_components(filename)
   while file_comps[1] == dir_comps[1] do
      table.remove(file_comps, 1)
      table.remove(dir_comps, 1)
   end
   filename = fs.path_concat(file_comps)
   for file in lfs.dir(dirname) do
      if file == filename then
         return true
      end
   end
end

function fs.get_tail(path)
   return string.match(path, "[^" .. path_separator .. "]*$")
end


local root_file = "tlcconfig.lua"
function fs.ROOT_FILE()    return root_file end
function fs.find_project_root()
   local orig_dir = lfs.currentdir()




   local has_local_config = fs.is_in_dir(orig_dir, root_file)
   local found_home = false
   while not has_local_config do
      if lfs.currentdir() == USER_HOME or lfs.currentdir() == "/" then
         found_home = true
         break
      end
      lfs.chdir("..")
      has_local_config = fs.is_in_dir(lfs.currentdir(), root_file)
   end
   local root_dir
   if not found_home then
      root_dir = lfs.currentdir()
   end
   lfs.chdir(orig_dir)
   return root_dir or orig_dir
end

return fs
