
local tl = require("tl")

local ansi = require("tlcli.ansi")
local log = require("tlcli.log")

local M = {
   teal = {},
}

-- Since we can't load custom typed stuff into a teal environment yet, use these for type checking configs and such
function M.typechecker(typename: string): function(any): any
   return function(x: any): any
      if type(x) ~= typename then
         return nil
      end
      return x
   end
end
function M.array_typechecker(typename: string): function({any}): {any}
   return function(x: {any}): {any}
      if type(x) ~= "table" then
         return nil
      end
      for i, v in ipairs(x) do
         if type(v) ~= typename then
            return nil
         end
      end
      return x
   end
end
function M.map_typechecker(key_typename: string, value_typename: string): function(table): table
   return function(x: table): table
      if type(x) ~= "table" then return nil end
      for k, v in pairs(x) do
         if type(k) ~= key_typename
            or type(v) ~= value_typename then
            return nil
         end
      end
      return x
   end
end

function M.split(str: string, delimiter: string, patt_disable: boolean): function(): string
   local i = 0
   return function(): string
      if not i then return end
      i = i + 1
      local prev_i = i
      local s: number
      s, i = str:find(delimiter, i, patt_disable)
      return str:sub(prev_i, (s or 0) - 1)
   end
end

function M.wrap_with<T, K>(func: (function(T): K), arg: T): function(): K
   local co = coroutine.create(func)
   return function(): K
      return select(2, assert(coroutine.resume(co, arg) as (boolean, K))) as K
   end
end

function M.generate<T>(generator: (function(): T), ...: any): {T}
   local results: {T} = {}
   for value in generator, ... do
      table.insert(results, value)
   end
   return results
end

function M.warn_if_not<T>(condition: T, message: string): T
   if not condition then log.warn(message) end
   return condition
end

function M.warn_if<T>(condition: T, message: string): T
   if condition then log.warn(message) end
   return condition
end

function M.error_if<T>(condition: T, message: string): T
   if condition then log.error(message) end
   return condition
end

function M.error_if_not<T>(condition: T, message: string): T
   if not condition then log.error(message) end
   return condition
end

function M.insert_into(src: table, snk: table)
   for k, v in pairs(src) do
      if v is table then
         M.insert_into(v, snk[k])
      else
         snk[k] = v
      end
   end
end

local record Hook
   name: string
   called: boolean
end
local hooked_funcs: {function:Hook} = {}
local function call_hook(name: string, func: function): function
   hooked_funcs[func] = {
      name = name,
      called = false,
   }
   return function(...: any): any...
      hooked_funcs[func].called = true
      return func(...)
   end
end

local function f(): function return f end
function M.create_setters(callbacks: {string:function}, options: {string:any}, err_handler: function): function(string): function
   return function(opt_name: string): function
      if not callbacks[opt_name] then
         err_handler(opt_name)
         return f
      end
      return function(...: any)
         options[opt_name] = callbacks[opt_name](...)
      end
   end
end

local function to_set<T>(arr: {T}): {T:boolean}
   local set: {T:boolean} = {}
   for i, v in ipairs(arr) do
      set[v] = true
   end
   return set
end
function M.create_switches(switch_names: {string}, options: {string:any}): function(string)
   local names = to_set(switch_names)
   return function(opt: string)
      if names[opt] then
         options[opt] = not options[opt]
      end
   end
end

function M.check_hooks(): {string}
   local errs = {}
   for k, v in pairs(hooked_funcs) do
      if not v.called then
         table.insert(errs, "option " .. v.name .. " was referenced, but not set")
      end
   end
   return errs
end

local record TealError
   x: number
   y: number
   filename: string
   msg: string
end

local function concat_errors(errs: {TealError}): string
   local msgs = {}
   for i, err in ipairs(errs) do
       table.insert(
          msgs,
          string.format(
             ansi.bright.yellow"%s "
                .. ansi.bright.magenta"%d:%d"
                .. " %s",
             err.filename, err.y, err.x, err.msg or ""
          )
       )
   end
   return table.concat(msgs, "\n")
end

local fstr <const> = "Attempt to %s protected table <%s>\n   with key \"%s\" %s%s"
function M.protected_proxy<T>(t: T, err_handler: function(string)): T
   assert(t is table)
   err_handler = err_handler or log.warn as function(string)
   local usage: {string} = {}
   for k, v in pairs(t as table) do
      table.insert(usage, tostring(k) .. ": " .. type(v))
   end
   local usage_str = "\nValid entries for " .. tostring(t) .. " {\n   " .. table.concat(usage, "\n   ") .. "\n}"
   return setmetatable({}, {
      __index = function(_: table, key: any): any
         if t as table [key as string] == nil then
            err_handler(fstr:format("__index", tostring(t), tostring(key), "", usage_str))
            return
         end
         return t as table [key as string]
      end,
      __newindex = function(_: table, key: any, val: any)
         if t as table [key as string] == nil then
            err_handler(fstr:format("__index", tostring(t), tostring(key), "and " .. type(val) .. " value " .. tostring(val), usage_str))
            return
         end
         rawset(t as table, key as string, val)
      end,
   }) as T
end

local tl_env: table
local tl_modules: {string} = {}
local skip_compat53 = false

local function teal_setup_env(lax: boolean): table
   if not tl_env then
      tl_env = tl.init_env(lax, skip_compat53) as table
   end
end

function M.teal.set_skip_compat53(b: boolean)
   skip_compat53 = b
end

function M.teal.add_module(name: string)
   table.insert(tl_modules, name)
end

-- TODO: use tl.Result once it's exposed
function M.teal.type_check_file(file_name: string): boolean, string
   teal_setup_env(false)
   local result, err = (tl.process as function(string, table, any, table): table, string)(file_name, tl_env, nil, tl_modules)
   if err then
      return nil, err
   end
   tl_env = result.env as table

   if #result.syntax_errors as table > 0 then
      return nil, concat_errors(result.syntax_errors as {TealError})
   end
   if #result.type_errors as table > 0 then
      return nil, concat_errors(result.type_errors as {TealError})
   end
   return true
end

function M.teal.build_file(filename: string): boolean, string

end

function M.teal.compile(filename: string, type_check: boolean): string, string
   local lax = filename:match("%.lua$")
   local result = assert(tl.process(filename))
   if #result.syntax_errors > 0 then
      return nil, concat_errors(result.syntax_errors as {TealError})
   end
   if type_check then
      if #result.type_errors > 0 then
         return nil, concat_errors(result.type_errors as {TealError})
      end
   end
   return tl.pretty_print_ast(result.ast)
end

function M.teal.type_check_and_load(filename: string): function, string
   local code, err = M.teal.compile(filename, true)
   if err then
      return nil, err
   end
   local chunk, lua_err = load(code, "@" .. filename) as (function, string)
   if err then
      return nil, "Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. lua_err
   end
   return chunk
end

function M.teal.compile_and_write(input_filename: string, type_check: boolean, output_filename: string): boolean, string
   output_filename = output_filename or "teal.out.lua"
   local fh, ferr = io.open(output_filename, "w")
   if not fh then
      return nil, ferr
   end
   local code, err = M.teal.compile(input_filename, type_check)
   if not code then
      return nil, err
   end
   local ok, werr = fh:write(code)
   fh:close()
   if not ok then
      return nil, err
   end
   return true
end

local proc_str = tl.process_string as function(string, boolean, table, table, table, string): (table, string)
function M.teal.process(input_file_name: string, file_content: string, type_check: boolean): table, string
   teal_setup_env(false)
   local result, err = proc_str(file_content, false, tl_env, nil, tl_modules, input_file_name)
   if err then
      return nil, err
   end
   tl_env = result.env as table

   if #result.syntax_errors as table > 0 then
      return nil, concat_errors(result.syntax_errors as {TealError})
   end
   if type_check then
      if #result.type_errors as table > 0 then
         return nil, concat_errors(result.type_errors as {TealError})
      end
   end
   return result as table
end

-- TODO: remove once teal exposes its types
function M.teal.pretty_print_ast(result: table): string
   return (tl.pretty_print_ast as function(table): string)(result)
end

-- 1337H4XX0R: Horrible awful evil hack
-- TODO: allow some sort of override in tl itself for this sort of thing?
local old_tl_search_module = tl.search_module

local module_name_map: {string:string} = {}

local function make_hijacked_search_module(require_prefix: string, actual_name: string): function(string, boolean): string, FILE, {string}
   return function(module_name: string): string, FILE, {string}
      local found: string
      local tried: {string} = {}

      local altered_module_name = module_name
      if module_name:sub(1, #require_prefix) == require_prefix then
         altered_module_name = actual_name .. module_name:sub(#require_prefix+1, -1)
      end
      -- local altered_module_name = module_name:gsub("^" .. require_prefix, actual_name)
      log.queue("debug", [[Attempting to load module with modified name
      expected prefix:  %s
   replacement prefix:  %s

      module required:  %s
         altered name:  %s
      ]], require_prefix, actual_name, module_name, altered_module_name)
      local found, fd, tried = old_tl_search_module(altered_module_name, true)
      if found then
         return found, fd
      end
      log.queue("debug", "didn't find modified module name, trying regular...")
      local found, fd, also_tried = old_tl_search_module(module_name, true)
      if found then
         return found, fd
      end
      for _, v in ipairs(also_tried) do
         table.insert(tried, "no file '" .. v .. "'")
      end
      return nil, nil, tried
   end
end

function M.hijack_tl_search_module(require_prefix: string, actual_name: string)
   tl.search_module = make_hijacked_search_module(require_prefix, actual_name)
end

return M
