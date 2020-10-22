

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
   wrap: function(function)
   done: function(): boolean
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
         wrap = default_wrap(pool),
         done = function(): boolean
            if next(pool) then
               return false
            end
            return true
         end,
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
         wrap = default_wrap(stack),
         done = function(): boolean
            return #stack > 0
         end
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
         wrap = default_wrap(queue),
         done = function(): boolean
            return #queue > 0
         end,
      }
   elseif mode == "staged" then
      -- whenever a coroutine completes a step, it moves up a stage
      -- stages are round robined from the lowest to the highest
      local stages: {{number:thread}} = {{}}
      scheduler = {
         step = function()
            for i, stage in ipairs(stages) do
               if #stage > 0 then
                  local t <const> = table.remove(stage)
                  local ok <const> = coroutine.resume(t)
                  if ok then
                     if not stages[i+1] then
                        stages[i+1] = {}
                     end
                     table.insert(stages[i+1], t)
                  end
                  return
               end
            end
         end,
         run = function()
            for i, stage in ipairs(stages) do
               for k, thread in pairs(stage) do
                  local ok <const> = coroutine.resume(thread)
                  stage[k] = nil
                  if ok then
                     if not stages[i+1] then
                        stages[i+1] = {}
                     end
                     table.insert(stages[i+1], thread)
                  end
               end
            end
         end,
         schedule = function(t: thread)
            table.insert(stages[1], t)
         end,
         wrap = function(f: function)
            table.insert(stages[1], coroutine.create(f))
         end,
         done = function(): boolean
            for _, v in ipairs(stages) do
               if next(v) then return false end
            end
            return true
         end
      }
   else
      return nil
   end
   return scheduler
end

return M
