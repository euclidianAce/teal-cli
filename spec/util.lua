
local lfs = require("lfs")
local assert = require("luassert")

local current_dir = assert(lfs.currentdir())
local tlc_exe = current_dir .. "/bin/tlc"

local M = {}

M.exit_error = {nil, "exit", 1}
M.exit_ok = {true, "exit", 0}

function M.do_setup(setup, teardown)
   setup(function()
      assert(lfs.chdir("/tmp"))
   end)
   teardown(function()
      assert(lfs.chdir(current_dir))
   end)
end

local function typecheck(obj, typestr)
   if type(obj) ~= typestr then
      error("Expected " .. typestr .. ", got " .. type(obj), 3)
   end
end

local function nilable_typecheck(obj, typestr)
   if obj == nil then
      return
   end
   if type(obj) ~= typestr then
      error("Expected " .. typestr .. ", got " .. type(obj), 3)
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

function M.structure_to_paths(structure, prefix)
   prefix = prefix or ""
   local paths = {}
   for k, v in pairs(structure) do
      if type(v) == "table" then
         for _, p in ipairs(M.structure_to_paths(v, k)) do
            table.insert(paths, prefix .. "/" .. p)
         end
      else
         table.insert(paths, prefix .. "/" .. v)
      end
   end
   return paths
end

local function insert_into(tab, files)
   if not files then
      return
   end
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

function M.create_dir(finally, structure)
   local dir_name = make_tmp_dir(finally)
   populate_dir(dir_name, structure)
   return dir_name
end

local valid_commands = {
   ["build"] = true,
   ["run"] = true,
   ["check"] = true,
   ["gen"] = true,
}

function M.run_command(cmd_name, ...)
   assert(valid_commands[cmd_name], "invalid command '" .. tostring(cmd_name) .. "'")
   local pd = io.popen(tlc_exe .. " " .. cmd_name .. " " .. table.concat({...}, " ") .. " 2>&1")
   local pipe_result = {}
   pipe_result.output = pd:read("*a")
   pipe_result.close = {pd:close()}
   return pipe_result
end

function M.run_mock_project(finally, t)
   typecheck(finally, "function")
   typecheck(t, "table")
   typecheck(t.command, "string")
   assert(valid_commands[t.command], "invalid command")

   typecheck(t.dir, "table")
   nilable_typecheck(t.generated, "table")

   t.args = t.args or {}
   typecheck(t.args, "table")

   t.pipe_result = t.pipe_result or M.exit_ok
   typecheck(t.pipe_result, "table")

   nilable_typecheck(t.output, "string")
   nilable_typecheck(t.output_match, "string")

   local name = make_tmp_dir(finally)
   populate_dir(name, t.dir)
   lfs.chdir(name)

   local pd = io.popen(tlc_exe .. " " .. t.command .. (t.args and " " .. table.concat(t.args, " ") or "") .. " 2>&1")
   local actual_output = pd:read("*a")
   local actual_pipe_result = {pd:close()}

   local expected_dir_structure = {}
   insert_into(expected_dir_structure, t.dir)
   insert_into(expected_dir_structure, t.generated)
   local actual_dir_structure = get_dir_structure(name)
   lfs.chdir(current_dir)

   if t.output_match then
      assert.truthy(string.match(actual_output, t.output_match), "Output [[" .. actual_output .. "]] didn't match expected pattern: " .. t.output_match)
   elseif t.output then
      assert.are.equal(t.output, actual_output, "Output is not as expected")
   end
   assert.are.same(t.pipe_result, actual_pipe_result, "Pipe results are not as expected")
   assert.are.same(expected_dir_structure, actual_dir_structure, "Directory structure is not as expected.")
end

return M
