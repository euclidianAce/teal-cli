
local ansi = require("tlcli.ansi")

local M = {}

local enabled = {
   ["normal"] = true,
   ["warn"] = true,
   ["error"] = true,
}
local streams = setmetatable({
   ["error"] = io.stderr,
   ["warn"] = io.stderr,
   ["debug"] = io.stderr,
}, {
   __index = function(_, key)
      return io.stdout
   end,
})

local b = ansi.bright

local prefixes = setmetatable({
   ["normal"] = { b.cyan("  Teal") .. ": ", b.cyan("   ...  ") },
   ["verbose"] = { b.cyan(" *Teal") .. ": ", b.cyan("   ...  ") },
   ["warn"] = { b.yellow("  Warn") .. ": ", b.yellow("   ...  ") },
   ["error"] = { b.red(" Error") .. ": ", b.red("   ...  ") },
   ["debug"] = { b.green(" DEBUG") .. ": ", b.green("   ...  ") },
}, { __index = function()       return { "        ", "        " } end })

local QueuedMessage = {}



local queue = {}

local buffered = false

function M.set_buffered(b)
   buffered = b
end

function M.queue(level, fmt, ...)
   table.insert(queue, {
      level = level,
      message = string.format(fmt, ...),
   })
end

local function raw_log(level, fmt, ...)
   local str = string.format(fmt .. "\n", ...)
   local lines = str:gmatch(".-\n")

   streams[level]:write(prefixes[level][1], lines())
   for line in lines do
      streams[level]:write(prefixes[level][2], line)
   end
end

function M.log(level, fmt, ...)
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

function M.set_prefix(level, new_prefix)    prefixes[level] = new_prefix end

function M.enable(level)    enabled[level] = true end
function M.disable(level)    enabled[level] = nil end
function M.toggle(level)    enabled[level] = not enabled[level] end

function M.is_enabled(level)    return enabled[level] end

function M.set_stream(level, fh)    streams[level] = fh end
function M.get_stream(level)    return streams[level] end


function M.normal(fmt, ...)    M.log("normal", fmt, ...) end
function M.verbose(fmt, ...)    M.log("verbose", fmt, ...) end
function M.warn(fmt, ...)    M.log("warn", fmt, ...) end
function M.error(fmt, ...)    M.log("error", fmt, ...) end
function M.debug(fmt, ...)    M.log("debug", fmt, ...) end









return M
