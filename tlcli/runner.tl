
local util = require("tlcli.util")
local log = require("tlcli.log")
local cs = require("tlcli.ui.colorscheme")

local record Sandbox
   thread: thread
   err: string
end

local M = {
   Sandbox = Sandbox
}

function Sandbox:get_traceback(): string
   log.debug("Error in thread, getting stacktrace and removing traces from this file")
   local trace = debug.traceback(self.thread)
   local stack = util.generate(util.split(trace, "\n", true))

   -- get rid of the info from this file
   table.remove(stack, 1)
   table.remove(stack)
   table.remove(stack)

   for i, v in ipairs(stack) do
      stack[i] = v:gsub("^(%s*)(.-):(%d+)", function(ws: string, file: string, line_num: string): string
         return ws .. cs.color("file_name", file) .. ":" .. cs.color("line_number", line_num)
      end)
   end
   return table.concat(stack, "\n")
end

function Sandbox:run(): boolean, string
   log.debug("[%s] Executing...", tostring(self.thread))
   log.debug(cs.color("debug", "============================="))
   repeat
      local res: {any} = {coroutine.resume(self.thread)}
      if not res[1] then
         log.debug(cs.color("debug", "============================="))
         log.debug("[%s] Done %s", tostring(self.thread), cs.color("error", "(with error)"))
         self.err = res[2] as string
         return false, res[2] as string
      end
      table.remove(res, 1)
      if #res > 0 and coroutine.status(self.thread) ~= "dead" then
         for i, v in ipairs(res) do
            res[i] = tostring(v)
         end
         log.debug("Top level yield at line %s:\n   %s", cs.color("line_number", tostring(debug.getinfo(self.thread, 1, "l").currentline)), table.concat(res as {string}, "\n   "))
      end
   until coroutine.status(self.thread) == "dead"
   log.debug(cs.color("debug", "============================="))
   log.debug("[%s] Done", tostring(self.thread))
   return true
end

function M.wrap(f: function()): Sandbox
   local s: Sandbox = {
      thread = coroutine.create(f)
   }
   return setmetatable(s, { __index = Sandbox })
end

return M
