
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
local r = ansi.reset()

local prefixes: {string:{string}} = setmetatable({
   ["normal"]   = {b"cyan"    .. "  Teal" .. r .. ": ", b"cyan"    .. "   ...  " .. r},
   ["verbose"]  = {b"cyan"    .. " *Teal" .. r .. ": ", b"cyan"    .. "   ...  " .. r},
   ["warn"]     = {b"yellow"  .. "  Warn" .. r .. ": ", b"yellow"  .. "   ...  " .. r},
   ["error"]    = {b"red"     .. " Error" .. r .. ": ", b"red"     .. "   ...  " .. r},
   ["debug"]    = {b"green"   .. " DEBUG" .. r .. ": ", b"green"   .. "   ...  " .. r},
}, { __index = function(): {string} return {"        ", "        "} end })

function M.log(level: string, fmt: string, ...: any)
   if enabled[level] then
      local str = string.format(fmt .. "\n", ...)
      local p = 1
      for line in str:gmatch(".-\n") do
         streams[level]:write(prefixes[level][p], line)
         if p == 1 then
            p = 2
         end
      end
   end
end

function M.set_prefix(level: string, new_prefix: {string}) prefixes[level] = new_prefix end

function M.enable_level(level: string)  enabled[level] = true end
function M.disable_level(level: string) enabled[level] = nil end
function M.toggle_level(level: string)  enabled[level] = not enabled[level] end

function M.set_stream(level: string, fh: FILE) streams[level] = fh end

function M.normal(fmt: string, ...: any) M.log("normal", fmt, ...) end
function M.warn(fmt: string, ...: any)   M.log("warn", fmt, ...) end
function M.error(fmt: string, ...: any)  M.log("error", fmt, ...) end
function M.debug(fmt: string, ...: any)  M.log("debug", fmt, ...) end

return M
