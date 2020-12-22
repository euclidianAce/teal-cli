
local lfs = require("lfs")
local fs = require("tlcli.fs")
local graph = require("tlcli.builder.graph")

local ts = require("ltreesitter")
local teal_parser = ts.require("tree-sitter-teal-parser", "teal")

local function module_name_to_file_name(mod_name: string): string
   return mod_name:gsub("%.", fs.get_path_separator()) .. ".tl"
end

local record ModuleReplacement
   name: string
   source: string
end
local module_replacements: {ModuleReplacement} = {}

local function add_module(name: string, source: string)
   table.insert(module_replacements, { name = name, source = source })
end

local special_chars <const> = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local function replace_require_prefix(prefix: string, replacement: string, require_str: string): string
   local str, num_replacements = require_str:gsub("^" .. prefix:gsub(special_chars, "%%%1"), replacement)
   if num_replacements == 0 then
      return nil
   end
   return str
end

local function make_inserter(modules: {string}): function(string)
   return function(name: string)
      if name:sub(1, 1):match("[\"\']") then
         name = name:sub(2, -2)
      else
         name = name:match("^%[=*%[(.*)%]=*%]$")
      end
      for i, mod in ipairs(module_replacements) do
         local new_req = replace_require_prefix(mod.name, mod.source, name)
         if new_req then
            table.insert(modules, module_name_to_file_name(new_req))
            return
         end
      end
      table.insert(modules, module_name_to_file_name(name))
   end
end

local dep_query <const> = teal_parser
   :query[[ (function_call
             . (identifier) @func_name
             . (arguments (string) @module_name)
             (#eq? @func_name "require")
             (#insert_mod_name! @module_name)) ]]

local function get_dependencies(file_content: string): {string}
   local tree <const> = teal_parser:parse_string(file_content)
   local modules <const>: {string} = {}
   dep_query:with{ ["insert_mod_name!"] = make_inserter(modules) }
            :exec(tree:root())

   return modules
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

return {
   build_dag = build_dag,
   add_module = add_module,
}

