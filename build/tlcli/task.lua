

local SchedulerMode = {}






local SchedulerInterface = {}






local M = {
   SchedulerMode = SchedulerMode,
   SchedulerInterface = SchedulerInterface,
}

local default_wrap = function(t)
   return function(f)
      table.insert(t, coroutine.create(f))
   end
end

function M.scheduler(mode)
   local scheduler
   if mode == "round-robin" then
      local pool = {}
      scheduler = {
         step = coroutine.wrap(function()
            while true do
               for k, v in pairs(pool) do
                  local ok = coroutine.resume(v)
                  if not ok then                      pool[k] = nil end
                  coroutine.yield()
               end
               coroutine.yield()
            end
         end),
         run = function()
            while next(pool) do
               scheduler.step()
            end
         end,
         schedule = function(t)
            table.insert(pool, t)
         end,
         wrap = default_wrap(pool),
      }
   elseif mode == "stack" then
      local stack = {}
      local t
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
         end),
         run = function()
            while next(stack) or t do
               scheduler.step()
            end
         end,
         schedule = function(t)
            table.insert(stack, t)
         end,
         wrap = default_wrap(stack),
      }
   elseif mode == "queue" then
      local queue = {}
      local t
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
         end),
         run = function()
            while next(queue) or t do
               scheduler.step()
            end
         end,
         schedule = function(t)
            table.insert(queue, t)
         end,
         wrap = default_wrap(queue),
      }
   elseif mode == "staged" then


      local stages = { {} }
      scheduler = {
         step = function()
            for i, stage in ipairs(stages) do
               if #stage > 0 then
                  local t = table.remove(stage)
                  local ok = coroutine.resume(t)
                  if ok then
                     if not stages[i + 1] then
                        stages[i + 1] = {}
                     end
                     table.insert(stages[i + 1], t)
                  end
                  return
               end
            end
         end,
         run = function()
            for i, stage in ipairs(stages) do
               for k, thread in pairs(stage) do
                  local ok = coroutine.resume(thread)
                  stage[k] = nil
                  if ok then
                     if not stages[i + 1] then
                        stages[i + 1] = {}
                     end
                     table.insert(stages[i + 1], thread)
                  end
               end
            end
         end,
         schedule = function(t)
            table.insert(stages[1], t)
         end,
         wrap = function(f)
            table.insert(stages[1], coroutine.create(f))
         end,
      }
   else
      return nil
   end
   return scheduler
end

return M
