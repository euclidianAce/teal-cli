
local lfs = require("lfs")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local record Node
   {Node}
   file_name: string
   should_update: boolean
   update_reason: string
end

local M = {}

local ts = require("ltreesitter")
local teal_parser = ts.require("tree-sitter-teal-parser", "teal")

local function module_name_to_file_name(mod_name: string): string
   return mod_name:gsub("%.", fs.get_path_separator()) .. ".tl"
end

local dep_query <const> = teal_parser:query[[ (function_call
                                                 .
                                                 (identifier) @func_name
                                                 .
                                                 (arguments (string) @module_name)
                                                 (#eq? @func_name "require")
                                                 (#insert_mod_name! @module_name)) ]]

function M.get_dependencies(file_name: string): {string}, string
   local content, err = fs.read(file_name)
   if not content then return nil, err end
   local tree = teal_parser:parse_string(content)

   local modules: {string} = {}
   dep_query:with{
      ["insert_mod_name!"] = function(name: string)
         if name:sub(1, 1):match("[\"\']") then
            name = name:sub(2, -2)
         else
            name = name:match("^%[=*%[(.*)%]=*%]$")
         end
         table.insert(modules, module_name_to_file_name(name))
      end
   }:exec(tree:root())

   return modules
end

function M.scan_project(root_dir: string, include_patts: {string}, exclude_patts: {string}): {string:{string}}
   local current_dir = lfs.currentdir()
   assert(lfs.chdir(root_dir))
   local deps: {string:{string}} = {}
   for fname in fs.match(
      ".",
      include_patts or {},
      exclude_patts or {}
   ) do
      deps[fs.path_concat(root_dir, fname)] = M.get_dependencies(fname)
   end
   assert(lfs.chdir(current_dir))
   return deps
end

local record DAG
   module_name: string
   nodes: {string:Node}
end
local dag_mt <const> = { __index = DAG }

local function mark_for_update(n: Node, reason: string)
   if n.should_update then return end -- if a node is already marked, so are its children
   n.should_update = true
   n.update_reason = reason or "?"
   for i, v in ipairs(n) do
      mark_for_update(v, "depends on " .. n.file_name)
   end
end

function DAG:mark_for_update(file_name: string, reason: string)
   mark_for_update(self.nodes[file_name], reason or "?")
end

function M.build_dag(
   root_dir: string,
   include_patts: {string},
   exclude_patts: {string},
   mark_predicate: function(string): (string)
): DAG
   local deps = M.scan_project(root_dir, include_patts, exclude_patts)
   local files_to_be_marked: {{string}} = {}
   local nodes: {string:Node} = setmetatable({}, {
      __index = function(self: {string:Node}, key: string): Node
         local n: Node = {}
         rawset(self, key, n)
         return n
      end
   })
   for file_name, file_dependencies in pairs(deps) do
      nodes[file_name].file_name = file_name
      for i, dependency in ipairs(file_dependencies) do
         nodes[dependency].file_name = dependency -- assert that nodes[dependency] gets a filename
         table.insert(nodes[dependency], nodes[file_name])
      end
      if mark_predicate then
         local reason = mark_predicate(file_name)
         if reason then
            table.insert(files_to_be_marked, {file_name, reason})
         end
      end
   end
   local dag = setmetatable({
      module_name = root_dir,
      nodes = setmetatable(nodes, nil)
   }, dag_mt) as DAG
   for i, v in ipairs(files_to_be_marked) do
      dag:mark_for_update(v[1], v[2])
   end
   return dag
end

function DAG:marked_files(): function(): (string, string)
   local most_dependents = 0
   local nodes: {{Node}} = setmetatable({}, {
      __index = function(self: {{Node}}, key: number): {Node}
         most_dependents = math.max(most_dependents, key)
         local n: {Node} = {}
         rawset(self, key, n)
         return n
      end
   })
   for k, v in pairs(self.nodes) do
      if v.should_update then
         table.insert(nodes[#v], v)
      end
   end
   return coroutine.wrap(function()
      for i = most_dependents, 0, -1 do
         for k, v in ipairs(nodes[i]) do
            coroutine.yield(v.file_name, v.update_reason)
         end
      end
   end) as function(): (string, string)
end

function DAG:files(): function(): string
   return coroutine.wrap(function()
      for k in pairs(self.nodes) do
         coroutine.yield(k)
      end
   end) as function(): string
end

return M
