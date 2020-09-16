
local tl = require("tl")

local ansi = require("tlcli.ansi")
local log = require("tlcli.log")

local M = {
   teal = {}
}

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

function M.generate<T>(generator: function(): T): {T}
   local results: {T} = {}
   for value in generator do
      table.insert(results, value)
   end
   return results
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
             ansi.bright"yellow" .. "%s " .. ansi.reset()
                .. ansi.bright"magenta" .. "%d:%d" .. ansi.reset()
                .. " %s",
             err.filename, err.y, err.x, err.msg or ""
          )
       )
   end
   return table.concat(msgs, "\n")
end

local fstr <const> = "Attempt to %s protected table <%s>\n   with key \"%s\" %s%s"
function M.protected_proxy(t: {string:any}, err_handler: function(string)): {string:any}
   err_handler = err_handler or log.warn as function(string)
   local usage: {string} = {}
   for k, v in pairs(t) do
      table.insert(usage, k .. ": " .. type(v))
   end
   local usage_str = "\nValid entries for " .. tostring(t) .. " {\n   " .. table.concat(usage, "\n   ") .. "\n}"
   return setmetatable({}, {
      __index = function(_: table, key: any): any
         if t[key as string] == nil then
            err_handler(fstr:format("__index", tostring(t), tostring(key), "", usage_str))
            return
         end
         return t[key as string]
      end,
      __newindex = function(_: table, key: any, val: any)
         if t[key as string] == nil then
            err_handler(fstr:format("__index", tostring(t), tostring(key), "and " .. type(val) .. " value " .. tostring(val), usage_str))
            return
         end
         rawset(t, key as string, val)
      end,
   })
end

local tl_env: table
local tl_modules: {string}

local function teal_setup_env(lax: boolean, skip_compat53: boolean): table
   if not tl_env then
      tl_env = tl.init_env(lax, skip_compat53) as table
   end
end

function M.teal.add_module(name: string)
   table.insert(tl_modules, name)
end

-- TODO: use tl.Result once it's exposed
function M.teal.type_check_file(filename: string): boolean, string
   teal_setup_env(false, true)
   local result = assert(
      tl.process as function(string, table, any, table): table
      (filename, tl_env, nil, tl_modules)
   )
   tl_env = result.env as table

   if #result.syntax_errors as table > 0 then
      return nil, concat_errors(result.syntax_errors as {TealError})
   end
   if #result.type_errors as table > 0 then
      return nil, concat_errors(result.type_errors as {TealError})
   end
   return true
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
      log.error("!!Error uncaught by Teal!!\n\t%s\n\n\tThis is probably a bug caused by Teal not catching invalid Lua.\n\tPlease consider reporting this at https://github.com/teal-language/tl\n\n", lua_err)
      os.exit(1)
   end
   return chunk
end

function M.teal.compile_and_write(input_filename: string, type_check: boolean, output_filename: string): boolean, string
   output_filename = output_filename or "teal.out.lua"
   log.debug("opening file handle: %s", output_filename)
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

function M.teal.process(input_filename: string, type_check: boolean): table, string
   teal_setup_env(false, true)
   local result = assert(
      tl.process as function(string, table, any, table): table
      (input_filename, tl_env, nil, tl_modules)
   )
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

return M
