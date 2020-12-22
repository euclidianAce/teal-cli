
local lfs <const> = require("lfs")
local fs <const> = require("tlcli.fs")

local record Node
   {Node}
   file_name: string
   should_update: boolean
   update_reason: string
end

local record DAG
   module_name: string
   nodes: {string:Node}
end

local graph <const> = {
   Node = Node,
   DAG = DAG,
}

function graph.scan(
   root_dir: string,
   include_patts: {string},
   exclude_patts: {string},
   dep_query: function(string): {string}
): {string:{string}}
   return fs.do_in(root_dir, function(): {string:{string}}
      local deps: {string:{string}} = {}
      for fname in fs.match(".", include_patts, exclude_patts) do
         if fname:sub(1,2) == "." .. fs.get_path_separator() then
            fname = fname:sub(3, -1)
         end
         local content <const> = fs.read(fname)
         deps[fs.path_concat(root_dir, fname)] = dep_query(content)
      end
      return deps
   end)
end

local dag_mt <const> = { __index = DAG }

local function mark_for_update(n: Node, reason: string)
   if n.should_update then return end -- if a node is already marked, so are its children
   n.should_update = true
   n.update_reason = reason or "?"
   for i, v in ipairs(n) do
      mark_for_update(v, "Depends on " .. n.file_name)
   end
end

function DAG:mark_for_update(file_name: string, reason: string)
   mark_for_update(self.nodes[file_name], reason or "?")
end

function graph.build_dag(
   root_dir: string,
   include_patts: {string},
   exclude_patts: {string},
   dep_query: function(string): ({string}),
   mark_predicate: function(string): (string)
): DAG
   local deps = graph.scan(root_dir, include_patts, exclude_patts, dep_query)
   local files_to_be_marked: {{string, string}} = {}
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
         nodes[dependency].file_name = dependency
         table.insert(nodes[dependency], nodes[file_name])
      end
      if mark_predicate then
         local reason = mark_predicate(file_name)
         if reason then
            table.insert(files_to_be_marked, {file_name, reason})
         end
      end
   end

   local dag: DAG = setmetatable({
      nodes = setmetatable(nodes, nil)
   }, dag_mt)

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

return graph

