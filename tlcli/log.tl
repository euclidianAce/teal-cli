
local cs = require("tlcli.ui.colorscheme")

local M = {}

local enabled: {string:boolean} = {
   ["normal"] = true,
   ["warn"] = true,
   ["error"] = true,
}
local streams: {string:FILE} = setmetatable({
   ["error"] = io.stderr,
   ["warn"] = io.stderr,
   ["debug"] = io.stderr,
}, {
   __index = function(): FILE
      return io.stdout
   end
})

local alignment <const> = 12
local function align(s: string): string
   return (" "):rep(alignment - #s) .. s
end
local type Prefix = {string, string, Colorizer}
local function color_with(name: string): Colorizer
   return function(s: string): string
      return cs.color(name, s)
   end
end
local prefixes: {string:Prefix} = setmetatable({
   ["normal"]  = { "Teal ",  "... ", color_with("normal_log") },
   ["verbose"] = { "*Teal ", "... ", color_with("verbose_log") },
   ["warn"] = { "Warning ", "... ", color_with("warning_log") },
   ["error"] = { "Error ", "... ", color_with("error_log") },
   ["debug"] = { "=DEBUG= ", "======= ", color_with("debug_log") },
}, {
   __index = function(): Prefix
      return {
         "???:",
         "",
         function(x: string): string
            return x
         end
      }
   end
})

local record QueuedMessage
   level: string
   message: string
end
local queue: {QueuedMessage} = {}

local buffered = false

function M.set_buffered(b: boolean)
   buffered = b
end

function M.queue(level: string, fmt: string, ...: any)
   table.insert(queue, {
      level = level,
      message = string.format(fmt, ...),
   })
end

local function color_and_align(level: string, s: string): string
   return prefixes[level][3](align(s))
end
local function raw_log(level: string, fmt: string, ...: any)
   local str = string.format(fmt .. "\n", ...)
   local lines = str:gmatch(".-\n")

   streams[level]:write(color_and_align(level, prefixes[level][1]), lines())
   for line in lines do
      streams[level]:write(color_and_align(level, prefixes[level][2]), line)
   end
end

function M.log(level: string, fmt: string, ...: any)
   if enabled[level] then
      (buffered and M.queue or raw_log)(level, fmt, ...)
   end
end

function M.flush()
   for _, m in ipairs(queue) do
      if enabled[m.level] then
         raw_log(m.level, m.message)
      end
   end
   queue = {}
end

-- function M.set_prefix(level: string, new_prefix: {string}) prefixes[level] = new_prefix end

function M.enable(level: string)  enabled[level] = true end
function M.disable(level: string) enabled[level] = nil end
function M.toggle(level: string)  enabled[level] = not enabled[level] end

function M.is_enabled(level: string): boolean return enabled[level] end

function M.set_stream(level: string, fh: FILE) streams[level] = fh end
function M.get_stream(level: string): FILE return streams[level] end

-- FIXME when teal knows about metatables
function M.normal(fmt: string, ...: any)   M.log("normal", fmt, ...) end
function M.verbose(fmt: string, ...: any)  M.log("verbose", fmt, ...) end
function M.warn(fmt: string, ...: any)     M.log("warn",   fmt, ...) end
function M.error(fmt: string, ...: any)    M.log("error",  fmt, ...) end
function M.debug(fmt: string, ...: any)    M.log("debug",  fmt, ...) end

--setmetatable(M, {
--__index = function(_: table, key: string): function(string, ...: any)
--return function(fmt: string, ...: any)
--M.log(key, fmt, ...)
--end
--end
--})

return M
