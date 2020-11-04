
local log = require("tlcli.log")
local util = require("tlcli.util")
local lfs = require("lfs")

local record fs
   type File = {string:File}
   type FilePath = {string}
end

do
   local emptyref <const> = setmetatable({}, {
      __newindex = function()
         error("Attempt to assign to emptyref, stop that", 2)
      end,
      __index = function()
         error("Attempt to index into emptyref, stop that", 2)
      end
   })

   function fs.is_file(f: fs.File): boolean
      return f == emptyref
   end

   function fs._get_emptyref(): fs.File
      return emptyref
   end
end

local path_separator = package.config:sub(1, 1)
function fs.get_path_separator(): string
   return path_separator
end

local function path_components_iter(pathname: string)
   for component in util.split(pathname, path_separator) do
      coroutine.yield(component)
   end
end

function fs.path_components(pathname: string): function(): string
   return util.wrap_with(path_components_iter as (function(string): string), pathname)
end

function fs.get_path_components(pathname: string): fs.FilePath
   return util.generate(fs.path_components(pathname)) as fs.FilePath
end

local function fix_path_chunk(pathchunk: string): string
   if pathchunk == ".." then
      return nil
   end
   return pathchunk
end
local function fix_path(path: string): string, string
   local fixed_path_components: {string} = {}
   local not_relative = string.sub(path, 1, 1) == "/" --FIXME: windows
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

function fs.path_concat(...: string|{string}): string
   local path = {}
   for i = 1, select("#", ...) do
      if type(select(i, ...)) == "table" then
         for j, str in ipairs((select(i, ...)) as {string}) do
            --local fname = assert(fix_path(str))
            if #str > 0 then
               table.insert(path, str)
            end
         end
      else
         local raw_fname = select(i, ...) as string
         if i > 1 and string.sub(raw_fname, 1, 1) == "/" then --FIXME: windows
            error("Attempt to concatenate non relative paths")
         end
         --local fname = assert(fix_path(raw_fname))
         if #raw_fname > 0 then
            table.insert(path, raw_fname)
         end
      end
   end
   return table.concat(path, path_separator)
end

-- TODO: is this the best way to do this?
-- (probably not)
local HOME <const> = os.getenv("HOME")
local XDG_CONFIG_HOME <const> = os.getenv("XDG_CONFIG_HOME")
   or fs.path_concat(HOME, ".config")
local CMD_PATH <const> = fs.path_concat(XDG_CONFIG_HOME, "teal", "commands")
local GLOBAL_CONFIG_PATH <const> = fs.path_concat(XDG_CONFIG_HOME, "config.lua")
local TYPES_PATH <const> = fs.path_concat(XDG_CONFIG_HOME, "teal", "teal-types", "types")

function fs.HOME(): string return HOME end
function fs.XDG_CONFIG_HOME(): string return XDG_CONFIG_HOME end
function fs.CMD_PATH(): string return CMD_PATH end
function fs.GLOBAL_CONFIG_PATH(): string return GLOBAL_CONFIG_PATH end
function fs.TYPES_PATH(): string return TYPES_PATH end

local function trim(str: string): string
   return (str:gsub("^%s*(.-)%s*$", "%1"))
end
function fs.get_shared_library_ext(): string
   if not package.cpath or trim(package.cpath) == "" then
      return "so" -- FIXME
   end

   return package.cpath:match("%.(%w+)%s*$")
end

function fs.path_parents(pathname: string): function(): string
   local current_path: string = ""
   local comps = fs.get_path_components(pathname)
   comps[#comps] = nil
   return coroutine.wrap(function()
      for i, dir in ipairs(comps) do
         current_path = fs.path_concat(current_path, dir)
         coroutine.yield(current_path)
      end
   end) as function(): string
end

local function dir_iter(dirname: string)
   for file in assert(lfs.dir(dirname)) do
      if dirname == "." then
         dirname = ""
      end
      -- ignore hidden files/dont chdir by default TODO: users should be allowed to opt out
      if file:sub(1,1) ~= "." then
         if lfs.attributes(fs.path_concat(dirname, file), "mode") == "directory" then
            dir_iter(fs.path_concat(dirname, file))
         else
            coroutine.yield(fs.path_concat(dirname, file))
         end
      end
   end
end

function fs.dir(dirname: string): function(): string
   return util.wrap_with(dir_iter as (function(string): string), dirname)
end

local type Matcher = function(string): boolean

local function esc_str(s: string): string
   return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", function(match: string): string
      if match == "*" then
         return "[^" .. path_separator .. "]-"
      end
      return "%" .. match
   end))
end

local function create_matcher(path_pattern: string): Matcher
   local comps: {string} = {}
   for chunk in util.split(path_pattern, "**" .. fs.get_path_separator()) do
      if chunk == ".." then
         error("Error in pattern \"" .. path_pattern .. "\" .." .. fs.get_path_separator() .. " is not allowed")
      end
      table.insert(comps, esc_str(chunk))
   end
   comps[1] = "^" .. comps[1]
   comps[#comps] = comps[#comps] .. "$"
   return function(s: string): boolean
      local idx = 1
      local s_idx: number

      for i, comp in ipairs(comps) do
         s_idx, idx = string.find(s, comp, idx)
         if not s_idx then
            return false
         end
      end
      return true
   end
end

local function match_arr(patts: {Matcher}, str: string): number
   for i, v in ipairs(patts) do
      if v(str) then
         return i
      end
   end
end

function fs.get_file_tree(dirname: string): fs.File
   local dir: fs.File = {}

   for path in fs.dir(dirname) do
      local current: fs.File = dir
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

function fs.get_file_paths(dirname: string): {string}
   return util.generate(fs.dir(dirname))
end

function fs.match(dirname: string, include: {string}, exclude: {string}): function(): string
   local inc_matchers: {Matcher} = {}
   local exc_matchers: {Matcher} = {}

   for i, patt in ipairs(include or {}) do
      table.insert(inc_matchers, create_matcher(patt))
   end
   for i, patt in ipairs(exclude or {}) do
      table.insert(exc_matchers, create_matcher(patt))
   end

   return coroutine.wrap(function()
      for fname in fs.dir(dirname) do
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
   end) as function(): string
end

function fs.add_to_path(dirname: string)
   local path_str = dirname

   if string.sub(path_str, -1) == path_separator then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. path_separator

   local lib_path_str = path_str .. "?." .. fs.get_shared_library_ext() .. ";"
   local lua_path_str = path_str .. "?.lua" .. ";"
      .. path_str ..  "?" .. path_separator .. "init.lua;"

   package.path = lua_path_str .. package.path
   package.cpath = lib_path_str .. package.cpath
end

function fs.split_extension(filename: string): string, string
   local basename, extension = string.match(filename, "(.-)%.([^" .. fs.get_path_separator() .. "]*)$")
   extension = extension and extension:lower()
   return basename, extension
end

function fs.get_extension(filename: string): string
   local _, extension = fs.split_extension(filename)
   return extension
end

function fs.get_basename(filename: string): string
   local basename = fs.split_extension(filename)
   return basename
end

function fs.get_output_file_name(filename: string): string
   local ext = fs.get_extension(filename)
   if ext == "lua" then
      return filename:sub(1, -4) .. "out.lua"
   elseif ext == "tl" then
      return filename:sub(1, -3) .. "lua"
   elseif ext == "c" then
      return filename:sub(1, -2) .. "o"
   end
end

function fs.get_output_file_name_components(filename: string): {string}
   local comps = fs.get_path_components(filename)
   comps[#comps] = fs.get_output_file_name(comps[#comps])
   return comps
end

function fs.is_absolute(path: string): boolean
   return path:sub(1,1) == "/" --FIXME: windows
end

local USER_HOME <const> = os.getenv("HOME")
function fs.is_in_dir(dirname: string, filename: string): boolean
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

function fs.get_tail(path: string): string
   return string.match(path, "[^" .. path_separator .. "]*$")
end

-- basically the Tupfile/Makefile that indicates the root of the project
local root_file <const> = "tlcconfig.lua"
function fs.ROOT_FILE(): string return root_file end
function fs.find_project_root(): string
   local orig_dir = lfs.currentdir()

   -- TODO: we dont need to chdir here
   -- so... dont

   local has_local_config = fs.is_in_dir(orig_dir, root_file)
   local found_home = false
   while not has_local_config do
      if lfs.currentdir() == USER_HOME or lfs.currentdir() == "/" then -- TODO: windows root "[A-Z]:\" ?
         found_home = true
         break
      end
      lfs.chdir("..")
      has_local_config = fs.is_in_dir(lfs.currentdir(), root_file)
   end
   local root_dir: string
   if not found_home then
      root_dir = lfs.currentdir()
   end
   lfs.chdir(orig_dir)
   return root_dir or orig_dir
end

local file_content_cache: {string:string} = setmetatable({}, { __mode = "kv" })
function fs.read(filename: string): string, string
   if file_content_cache[filename] then
      return file_content_cache[filename]
   end
   local fh, err = io.open(filename, "r")
   if not fh then return nil, err end
   file_content_cache[filename] = fh:read("*a")
   fh:close()
   return file_content_cache[filename]
end

return fs

