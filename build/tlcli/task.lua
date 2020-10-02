

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
         schedule_wrap = default_wrap(pool),
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
         schedule_wrap = default_wrap(stack),
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
         schedule_wrap = default_wrap(queue),
      }
   elseif mode == "staged" then


      local stages = { {} }
      local all_stages_empty = function()
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
                        if not stages[i + 1] then
                           stages[i + 1] = {}
                        end
                        table.insert(stages[i + 1], t)
                     end
                     coroutine.yield()
                  end
                  i = i + 1
                  coroutine.yield()
               end
               coroutine.yield()
            end
         end),
         run = function()
            repeat
               scheduler.step()
            until all_stages_empty()
         end,
         schedule = function(t)
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
