

local enum SchedulerMode
   "round-robin"
   "stack"
   "queue"
   "staged"
end

local record SchedulerInterface
   step: function()
   run: function()
   schedule: function(thread)
   schedule_wrap: function(function)
end

local M = {
   SchedulerMode = SchedulerMode,
   SchedulerInterface = SchedulerInterface,
}

local default_wrap = function(t: {thread}): function(function)
   return function(f: function)
      table.insert(t, coroutine.create(f))
   end
end

function M.scheduler(mode: SchedulerMode): SchedulerInterface
   local scheduler: SchedulerInterface
   if mode == "round-robin" then
      local pool: {number:thread} = {}
      scheduler = {
         step = coroutine.wrap(function()
            while true do
               for k, v in pairs(pool) do
                  local ok = coroutine.resume(v)
                  if not ok then pool[k] = nil end
                  coroutine.yield()
               end
               coroutine.yield()
            end
         end) as function(),
         run = function()
            while next(pool) do
               scheduler.step()
            end
         end,
         schedule = function(t: thread)
            table.insert(pool, t)
         end,
         schedule_wrap = default_wrap(pool),
      }
   elseif mode == "stack" then
      local stack: {thread} = {}
      local t: thread
      scheduler = {
         step = coroutine.wrap(function()
            while true do
               t = table.remove(stack)
               if t then
                  while coroutine.resume(t) do
                     coroutine.yield()
                  end
                  t = nil
               else
                  coroutine.yield()
               end
            end
         end) as function(),
         run = function()
            while next(stack) as boolean or t as boolean do
               scheduler.step()
            end
         end,
         schedule = function(t: thread)
            table.insert(stack, t)
         end,
         schedule_wrap = default_wrap(stack),
      }
   elseif mode == "queue" then
      local queue: {number:thread} = {}
      local t: thread
      scheduler = {
         step = coroutine.wrap(function()
            while true do
               t = table.remove(queue, 1)
               if t then
                  while coroutine.resume(t) do
                     coroutine.yield()
                  end
                  t = nil
               else
                  coroutine.yield()
               end
            end
         end) as function(),
         run = function()
            while next(queue) as boolean or t as boolean do
               scheduler.step()
            end
         end,
         schedule = function(t: thread)
            table.insert(queue, t)
         end,
         schedule_wrap = default_wrap(queue),
      }
   elseif mode == "staged" then
      -- whenever a coroutine completes a step, it moves up a stage
      -- stages are round robined from the lowest to the highest
      local stages: {{thread}} = {{}}
      local all_stages_empty = function(): boolean
         for _, stage in ipairs(stages) do
            if #stage > 0 then
               return false
            end
         end
         return true
      end
      scheduler = {
         step = coroutine.wrap(function()
            while true do
               local i = 1
               while i <= #stages do
                  while #stages[i] > 0 do
                     local t = table.remove(stages[i])
                     local ok = coroutine.resume(t)
                     if ok then
                        if not stages[i+1] then
                           stages[i+1] = {}
                        end
                        table.insert(stages[i+1], t)
                     end
                     coroutine.yield()
                  end
                  i = i + 1
                  coroutine.yield()
               end
               coroutine.yield()
            end
         end) as function(),
         run = function()
            repeat
               scheduler.step()
            until all_stages_empty()
         end,
         schedule = function(t: thread)
            table.insert(stages[1], t)
         end,
         schedule_wrap = default_wrap(stages[1]),
      }
   else
      return nil
   end
   return scheduler
end

return M
