
local tl = require("tl")

local ansi = require("tlcli.ansi")
local log = require("tlcli.log")

local M = {
   teal = {},
}


function M.typechecker(typename)
   return function(x)
      if type(x) ~= typename then
         return nil
      end
      return x
   end
end
function M.array_typechecker(typename)
   return function(x)
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
function M.map_typechecker(key_typename, value_typename)
   return function(x)
      if type(x) ~= "table" then          return nil end
      for k, v in pairs(x) do
         if type(k) ~= key_typename or
            type(v) ~= value_typename then
            return nil
         end
      end
      return x
   end
end

function M.split(str, delimiter, patt_disable)
   local i = 0
   return function()
      if not i then          return end
      i = i + 1
      local prev_i = i
      local s
      s, i = str:find(delimiter, i, patt_disable)
      return str:sub(prev_i, (s or 0) - 1)
   end
end

function M.wrap_with(func, arg)
   local co = coroutine.create(func)
   return function()
      return select(2, assert(coroutine.resume(co, arg)))
   end
end

function M.generate(generator, ...)
   local results = {}
   for value in generator, ... do
      table.insert(results, value)
   end
   return results
end

function M.warn_if_not(condition, message)
   if not condition then       log.warn(message) end
   return condition
end

function M.warn_if(condition, message)
   if condition then       log.warn(message) end
   return condition
end

function M.error_if(condition, message)
   if condition then       log.error(message) end
   return condition
end

function M.error_if_not(condition, message)
   if not condition then       log.error(message) end
   return condition
end

function M.insert_into(src, snk)
   for k, v in pairs(src) do
      if type(v) == "table" then
         M.insert_into(v, snk[k])
      else
         snk[k] = v
      end
   end
end

local Hook = {}



local hooked_funcs = {}
local function call_hook(name, func)
   hooked_funcs[func] = {
      name = name,
      called = false,
   }
   return function(...)
      hooked_funcs[func].called = true
      return func(...)
   end
end

local function f()    return f end
function M.create_setters(callbacks, options, err_handler)
   return function(opt_name)
      if not callbacks[opt_name] then
         err_handler(opt_name)
         return f
      end
      return function(...)
         options[opt_name] = callbacks[opt_name](...)
      end
   end
end

local function to_set(arr)
   local set = {}
   for i, v in ipairs(arr) do
      set[v] = true
   end
   return set
end
function M.create_switches(switch_names, options)
   local names = to_set(switch_names)
   return function(opt)
      if names[opt] then
         options[opt] = not options[opt]
      end
   end
end

function M.check_hooks()
   local errs = {}
   for k, v in pairs(hooked_funcs) do
      if not v.called then
         table.insert(errs, "option " .. v.name .. " was referenced, but not set")
      end
   end
   return errs
end

local TealError = {}






local function concat_errors(errs)
   local msgs = {}
   for i, err in ipairs(errs) do
      table.insert(
msgs,
string.format(
ansi.bright.yellow("%s ") ..
      ansi.bright.magenta("%d:%d") ..
      " %s",
err.filename, err.y, err.x, err.msg or ""))


   end
   return table.concat(msgs, "\n")
end

local fstr = "Attempt to %s protected table <%s>\n   with key \"%s\" %s%s"
function M.protected_proxy(t, err_handler)
   assert(type(t) == "table")
   err_handler = err_handler or log.warn
   local usage = {}
   for k, v in pairs(t) do
      table.insert(usage, tostring(k) .. ": " .. type(v))
   end
   local usage_str = "\nValid entries for " .. tostring(t) .. " {\n   " .. table.concat(usage, "\n   ") .. "\n}"
   return setmetatable({}, {
      __index = function(_, key)
         if t[key] == nil then
            err_handler(fstr:format("__index", tostring(t), tostring(key), "", usage_str))
            return
         end
         return t[key]
      end,
      __newindex = function(_, key, val)
         if t[key] == nil then
            err_handler(fstr:format("__index", tostring(t), tostring(key), "and " .. type(val) .. " value " .. tostring(val), usage_str))
            return
         end
         rawset(t, key, val)
      end,
   })
end

local tl_env
local tl_modules = {}
local skip_compat53 = false

local function teal_setup_env(lax)
   if not tl_env then
      tl_env = tl.init_env(lax, skip_compat53)
   end
end

function M.teal.set_skip_compat53(b)
   skip_compat53 = b
end

function M.teal.add_module(name)
   table.insert(tl_modules, name)
end


function M.teal.type_check_file(file_name)
   teal_setup_env(false)
   local result, err = (tl.process)(file_name, tl_env, nil, tl_modules)
   if err then
      return nil, err
   end
   tl_env = result.env

   if #result.syntax_errors > 0 then
      return nil, concat_errors(result.syntax_errors)
   end
   if #result.type_errors > 0 then
      return nil, concat_errors(result.type_errors)
   end
   return true
end

function M.teal.build_file(filename)

end

function M.teal.compile(filename, type_check)
   local lax = filename:match("%.lua$")
   local result = assert(tl.process(filename))
   if #result.syntax_errors > 0 then
      return nil, concat_errors(result.syntax_errors)
   end
   if type_check then
      if #result.type_errors > 0 then
         return nil, concat_errors(result.type_errors)
      end
   end
   return tl.pretty_print_ast(result.ast)
end

function M.teal.type_check_and_load(filename)
   local code, err = M.teal.compile(filename, true)
   if err then
      return nil, err
   end
   local chunk, lua_err = load(code, "@" .. filename)
   if err then
      return nil, "Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. lua_err
   end
   return chunk
end

function M.teal.compile_and_write(input_filename, type_check, output_filename)
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

local proc_str = tl.process_string
function M.teal.process(input_file_name, file_content, type_check)
   teal_setup_env(false)
   local result, err = proc_str(file_content, false, tl_env, nil, tl_modules, input_file_name)
   if err then
      return nil, err
   end
   tl_env = result.env

   if #result.syntax_errors > 0 then
      return nil, concat_errors(result.syntax_errors)
   end
   if type_check then
      if #result.type_errors > 0 then
         return nil, concat_errors(result.type_errors)
      end
   end
   return result
end


function M.teal.pretty_print_ast(result)
   return (tl.pretty_print_ast)(result)
end



local old_tl_search_module = tl.search_module

local module_name_map = {}

local function make_hijacked_search_module(require_prefix, actual_name)
   return function(module_name)
      local found
      local tried = {}

      local altered_module_name = module_name:gsub("^" .. require_prefix, actual_name)
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

function M.hijack_tl_search_module(require_prefix, actual_name)
   tl.search_module = make_hijacked_search_module(require_prefix, actual_name)
end

return M
