
local fs = require("tlcli.fs")
local graph = require("tlcli.builder.graph")



local ts = require("ltreesitter")
local c_parser = ts.require("c")
local dep_query = c_parser:
query([[ (translation_unit
      (preproc_include path: (string_literal) @path)) ]])

local function get_dependencies(file_name)
   local file_content = fs.read(file_name)
   local tree = c_parser:parse_string(file_content)
   local includes = {}
   for fname in dep_query:capture(tree:root()) do
      table.insert(includes, fname:source():sub(2, -2))
   end
   return includes
end

local function build_dag(
root_dir,
include_patts,
exclude_patts,
mark_predicate)

   return graph.build_dag(
root_dir,
include_patts,
exclude_patts,
get_dependencies,
mark_predicate)

end

return { build_dag = build_dag }
