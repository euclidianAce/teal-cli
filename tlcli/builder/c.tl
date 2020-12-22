
local fs <const> = require("tlcli.fs")
local graph <const> = require("tlcli.builder.graph")

-- TODO: #include statements are easy enough to pattern match that
-- bringing in a whole parser isn't really needed
local ts <const> = require("ltreesitter")
local c_parser <const> = ts.require("c")
local dep_query <const> = c_parser
   :query[[ (translation_unit
      (preproc_include path: (string_literal) @path)) ]]

local function get_dependencies(file_name: string): {string}
   local file_content <const> = fs.read(file_name)
   local tree <const> = c_parser:parse_string(file_content)
   local includes <const>: {string} = {}
   for fname in dep_query:capture(tree:root()) do
      table.insert(includes, fname:source():sub(2, -2))
   end
   return includes
end

local function build_dag(
   root_dir: string,
   include_patts: {string},
   exclude_patts: {string},
   mark_predicate: function(string): (string)
): graph.DAG
   return graph.build_dag(
      root_dir,
      include_patts,
      exclude_patts,
      get_dependencies,
      mark_predicate
   )
end

return { build_dag = build_dag }

