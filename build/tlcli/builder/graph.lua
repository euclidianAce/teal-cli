
local lfs = require("lfs")
local fs = require("tlcli.fs")

local Node = {}






local DAG = {}




local graph = {
   Node = Node,
   DAG = DAG,
}

function graph.scan(
root_dir,
include_patts,
exclude_patts,
dep_query)

   return fs.do_in(root_dir, function()
      local deps = {}
      for fname in fs.match(".", include_patts, exclude_patts) do
         if fname:sub(1, 2) == "." .. fs.get_path_separator() then
            fname = fname:sub(3, -1)
         end
         local content = fs.read(fname)
         deps[fs.path_concat(root_dir, fname)] = dep_query(content)
      end
      return deps
   end)
end

local dag_mt = { __index = DAG }

local function mark_for_update(n, reason)
   if n.should_update then       return end
   n.should_update = true
   n.update_reason = reason or "?"
   for i, v in ipairs(n) do
      mark_for_update(v, "Depends on " .. n.file_name)
   end
end

function DAG:mark_for_update(file_name, reason)
   mark_for_update(self.nodes[file_name], reason or "?")
end

function graph.build_dag(
root_dir,
include_patts,
exclude_patts,
dep_query,
mark_predicate)

   local deps = graph.scan(root_dir, include_patts, exclude_patts, dep_query)
   local files_to_be_marked = {}
   local nodes = setmetatable({}, {
      __index = function(self, key)
         local n = {}
         rawset(self, key, n)
         return n
      end,
   })

   for file_name, file_dependencies in pairs(deps) do
      nodes[file_name].file_name = file_name
      for i, dependency in ipairs(file_dependencies) do
         nodes[dependency].file_name = dependency
         table.insert(nodes[dependency], nodes[file_name])
      end
      if mark_predicate then
         local reason = mark_predicate(file_name)
         if reason then
            table.insert(files_to_be_marked, { file_name, reason })
         end
      end
   end

   local dag = setmetatable({
      nodes = setmetatable(nodes, nil),
   }, dag_mt)

   for i, v in ipairs(files_to_be_marked) do
      dag:mark_for_update(v[1], v[2])
   end

   return dag
end

function DAG:marked_files()
   local most_dependents = 0
   local nodes = setmetatable({}, {
      __index = function(self, key)
         most_dependents = math.max(most_dependents, key)
         local n = {}
         rawset(self, key, n)
         return n
      end,
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
   end)
end

return graph
