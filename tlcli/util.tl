
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

--[[
function M.die(str: string, ...: string)
   log.log("error", str, ...)
   os.exit(1)
end

function M.script_path(): string
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])") or "."
end

function M.trim(str: string): string
   return (str:gsub("^%s*(.-)%s*$", "%1"))
end

function M.is_nil_or_whitespace(str: string): boolean
   return str == nil or M.trim(str) == ""
end

function M.find_in_sequence(seq: {string}, value: string): boolean
   for _, v in ipairs(seq) do
      if M.trim(v) == M.trim(value) then
         return true
      end
   end
   return false
end


function M.set<T>(arr: {T}): {T:boolean}
   local s: {T:boolean} = {}
   for i, v in ipairs(arr) do
      s[v] = true
   end
   return s
end
--]]

local function get_extension(filename: string): string
   local basename, extension = string.match(filename, "(.*)%.([a-z]+)$")
   extension = extension and extension:lower()
   return extension
end

function M.get_output_file_name(filename: string): string
   local ext = get_extension(filename)
   if ext == "lua" then
      return filename:sub(1, -4) .. "out.lua"
   elseif ext == "tl" then
      return filename:sub(1, -3) .. "lua"
   end
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

function M.teal.type_check_file(filename: string): boolean, string
   local lax = get_extension(filename) == "lua"
   local result = assert(tl.process(filename))

   if #result.syntax_errors > 0 then
      return nil, concat_errors(result.syntax_errors as {TealError})
   end
   if #result.type_errors > 0 then
      return nil, concat_errors(result.type_errors as {TealError})
   end
   return true
end

function M.teal.compile(filename: string, type_check: boolean): string, string
   local lax = get_extension(filename) == "lua"
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
   output_filename = output_filename or M.get_output_file_name(input_filename)
   local fh, ferr = io.open(output_filename, "w")
   if not fh then
      return nil, ferr
   end
   local code, err = M.teal.compile(input_filename)
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

return M
