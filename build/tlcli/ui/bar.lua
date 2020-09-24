local Bar = {}











local bar_mt = {
   __index = Bar,

}

function Bar:draw(stream)
   stream = stream or io.stdout
   local filled_space = math.floor(self.progress * self.length)

   if self.show_progress then
      stream:write(string.format(" %3d %% ", math.floor(self.progress * 100)))
   end
   if self.message then
      stream:write(" ")
      if #self.message >= self.message_length then
         stream:write(self.message:sub(1, self.message_length))
      else
         stream:write(self.message, (" "):rep(self.message_length - #self.message))
      end
      stream:write(" ")
   end

   stream:write(self.left)
   stream:write(self.fill:rep(filled_space))
   stream:write(self.head)
   stream:write(self.empty:rep(self.length - filled_space))
   stream:write(self.right)
   stream:flush()
end

local function clamp(n)
   if n > 1 then       return 1 end
   if n < 0 then       return 0 end
   return n
end

function Bar:set_progress(p)
   self.progress = clamp(p)
end

function Bar:get_progress()
   return self.progress
end

function Bar:add_progress(p)
   self.progress = clamp(self.progress + p)
end

function Bar:set_message(s)
   self.message = s
end

local defaults = {
   left = "[",
   fill = "=",
   head = ">",
   empty = " ",
   right = "]",
   progress = 0,
   length = 10,
   message_length = 10,
   show_progress = false,
}

return {
   new = function(settings)
      settings = settings or {}
      local new_bar = {}
      for key, default_value in pairs(defaults) do
         if settings[key] == nil then
            new_bar[key] = default_value
         else
            new_bar[key] = settings[key]
         end
      end
      return setmetatable(new_bar, bar_mt)
   end,
}
