
local ansi = require("tlcli.ansi")
local util = require("tlcli.util")
local log = require("tlcli.log")

local Sandbox = {}




local M = {
   Sandbox = Sandbox,
}

function Sandbox:get_traceback()
   log.debug("Error in thread, getting stacktrace and removing traces from this file")
   local trace = debug.traceback(self.thread)
   local stack = util.generate(util.split(trace, "\n", true))

   table.remove(stack, 1)
   table.remove(stack)
   table.remove(stack)

   for i, v in ipairs(stack) do
      stack[i] = v:gsub("^(%s*)(.-):(%d+)", function(ws, file, line_num)
         return ws .. ansi.bright.yellow(file) .. ":" .. ansi.bright.magenta(line_num)
      end)
   end
   return table.concat(stack, "\n")
end

function Sandbox:run()
   log.debug("[%s] Executing...", tostring(self.thread))
   log.debug(ansi.dark.green("============================="))
   repeat
      local ok, err = coroutine.resume(self.thread)
      if not ok then
         log.debug("=============================")
         log.debug("[%s] Done (with error)", tostring(self.thread))
         self.err = err
         return false, err
      end
   until coroutine.status(self.thread) == "dead"
   log.debug(ansi.dark.green("============================="))
   log.debug("[%s] Done", tostring(self.thread))
   return true
end

function M.wrap(f)
   local s = {
      thread = coroutine.create(f),
   }
   return setmetatable(s, { __index = Sandbox })
end

return M
