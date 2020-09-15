
local lfs = require("lfs")
local assert = require("luassert")
local log = require("tlcli.log")
log.disable_level("normal")
log.disable_level("debug")
log.disable_level("error")
log.disable_level("warn")

local M = {}

local function typecheck(obj, typestr)
   if type(obj) ~= typestr then
      error("Expected " .. typestr .. ", got " .. type(obj), 2)
   end
end

local function nilable_typecheck(obj, typestr)
   if obj == nil then
      return
   end
   if type(obj) ~= typestr then
      error("Expected " .. typestr .. ", got " .. type(obj), 2)
   end
end

local function get_dir_structure(dirname)
   -- basically run `tree` and put it into a table
   local structure = {}
   for fname in lfs.dir(dirname) do
      if fname ~= ".." and fname ~= "." then
         if lfs.attributes(dirname .. "/" .. fname, "mode") == "directory" then
            structure[fname] = get_dir_structure(dirname .. "/" .. fname)
         else
            structure[fname] = true
         end
      end
   end
   return structure
end

local function insert_into(tab, files)
   for k, v in pairs(files) do
      if type(k) == "number" then
         tab[v] = true
      elseif type(v) == "string" then
         tab[k] = true
      elseif type(v) == "table" then
         if not tab[k] then
            tab[k] = {}
         end
         insert_into(tab[k], v)
      end
   end
end

local function make_dir(structure)
   typecheck(structure, "table")
   local dir = {}
   for k, v in pairs(structure) do
      if type(k) == "number" then
         dir[v] = true
      else
         dir[k] = make_dir(v)
      end
   end
   return dir
end

local function deep_merge_table(a, b)
   a = a or {}
   b = b or {}
   local new_tab = {}
   local function merge(t)
      for k, v in pairs(t) do
         if type(v) == "table" then
            new_tab[k] = deep_merge_table(new_tab[k], v)
         else
            new_tab[k] = v
         end
      end
   end
   merge(a)
   merge(b)
   return new_tab
end

local function populate_dir(dirname, structure)
   lfs.mkdir(dirname)
   for k, v in pairs(structure) do
      if type(v) == "table" then
         populate_dir(dirname .. "/" .. k, v)
      else
         local name
         local content
         if type(k) == "string" then
            name = k
            content = v
         else
            name = v
            content = ""
         end
         local fh = assert(io.open(dirname .. "/" .. name, "w"))
         fh:write(content)
         fh:close()
      end
   end
end

local dir_count = 0
local function make_tmp_dir(finally)
   dir_count = dir_count + 1
   local name = "/tmp/teal" .. tostring(dir_count)
   lfs.mkdir(name)
   finally(function()
      os.execute("rm -r " .. name)
   end)
   return name
end

function M.run_mock_project(finally, t)
   typecheck(finally, "function")
   typecheck(t, "table")
   typecheck(t.command, "string")
   typecheck(t.dir, "table")
   typecheck(t.generated, "table")
   typecheck(t.opts, "table")
   t.args = t.args or {}
   typecheck(t.args, "table")
   nilable_typecheck(t.config, "table")
   t.result = t.result or 0
   typecheck(t.result, "number")

   local name = make_tmp_dir(finally)
   populate_dir(name, t.dir)
   local current_dir = lfs.currentdir()

   local cmd = require("tlcli.commands." .. t.command)

   lfs.chdir(name)
   cmd.config(t.opts)
   local args = deep_merge_table({
      [t.command] = true,
      command = t.command,
   }, t.args)
   local result = cmd.command(args, t.config)
   local expected_dir_structure = {}
   insert_into(expected_dir_structure, t.dir)
   insert_into(expected_dir_structure, t.generated)
   local actual_dir_structure = get_dir_structure(name)
   lfs.chdir(current_dir)

   assert.are.same(expected_dir_structure, actual_dir_structure)
   assert.are.equal(result, t.result)
end

return M
