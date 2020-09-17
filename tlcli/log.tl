
local ansi = require("tlcli.ansi")

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
   __index = function(_: {string:FILE}, key: string): FILE
      return io.stdout
   end
})

local b = ansi.bright

local prefixes: {string:{string}} = setmetatable({
   ["normal"]   = {b.cyan   "  Teal" .. ": ", b.cyan    "   ...  " },
   ["verbose"]  = {b.cyan   " *Teal" .. ": ", b.cyan    "   ...  " },
   ["warn"]     = {b.yellow "  Warn" .. ": ", b.yellow  "   ...  " },
   ["error"]    = {b.red    " Error" .. ": ", b.red     "   ...  " },
   ["debug"]    = {b.green  " DEBUG" .. ": ", b.green   "   ...  " },
}, { __index = function(): {string} return {"        ", "        "} end })

local record QueuedMessage
   level: string
   message: string
end
local queue: {QueuedMessage} = {}

function M.log(level: string, fmt: string, ...: any)
   if enabled[level] then
      local str = string.format(fmt .. "\n", ...)
      local lines = str:gmatch(".-\n")

      streams[level]:write(prefixes[level][1], lines())
      for line in lines do
         streams[level]:write(prefixes[level][2], line)
      end
   end
end

function M.queue(level: string, fmt: string, ...: any)
   table.insert(
      queue,
      {
         level = level,
         message = string.format(fmt, ...),
      }
   )
end

function M.flush()
   for _, m in ipairs(queue) do
      M.log(m.level, m.message)
   end
   queue = {}
end

function M.set_prefix(level: string, new_prefix: {string}) prefixes[level] = new_prefix end

function M.enable_level(level: string)  enabled[level] = true end
function M.disable_level(level: string) enabled[level] = nil end
function M.toggle_level(level: string)  enabled[level] = not enabled[level] end

function M.is_enabled(level: string): boolean return enabled[level] end

function M.set_stream(level: string, fh: FILE) streams[level] = fh end
function M.get_stream(level: string): FILE return streams[level] end

-- FIXME when teal knows about metatables
function M.normal(fmt: string, ...: any) M.log("normal", fmt, ...) end
function M.warn(fmt: string, ...: any)   M.log("warn",   fmt, ...) end
function M.error(fmt: string, ...: any)  M.log("error",  fmt, ...) end
function M.debug(fmt: string, ...: any)  M.log("debug",  fmt, ...) end

--setmetatable(M, {
   --__index = function(_: table, key: string): function(string, ...: any)
      --return function(fmt: string, ...: any)
         --M.log(key, fmt, ...)
      --end
   --end
--})

return M
