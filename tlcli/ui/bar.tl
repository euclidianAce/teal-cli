
local record Bar
   left: string
   right: string
   fill: string
   empty: string
   head: string
   length: number
   show_progress: boolean
   message: string
   message_length: number
   steps: number
   total_steps: number
end
local bar_mt = {
   __index = Bar,
   -- __name = "tlcli.ui.bar"
}

function Bar:step()
   if self.steps < self.total_steps then
      self.steps = self.steps + 1
   end
end

function Bar:set_total_steps(n: number)
   assert(n > 0, "expected positive number")
   self.total_steps = math.ceil(n)
end

function Bar:get_progress(): number
   return self.steps / self.total_steps
end

function Bar:set_message(s: string)
   self.message = s
end

function Bar:draw(stream: FILE)
   stream = stream or io.stdout
   local filled_space = math.floor(self:get_progress() * self.length)

   if self.show_progress then
      stream:write(string.format(" %3d %% ", math.floor(self:get_progress() * 100)))
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


local defaults: {string:number|string|boolean} = {
   left = "[",
   fill = "=",
   head = ">",
   empty = " ",
   right = "]",
   length = 10,
   message_length = 10,
   show_progress = false,
}

return {
   new = function(settings: {string:number|string|boolean}): Bar
      settings = settings or {}
      local new_bar: {string:any} = {
         steps = 0
      }
      for key, default_value in pairs(defaults) do
         if settings[key] == nil then
            new_bar[key] = default_value
         else
            new_bar[key] = settings[key]
         end
      end
      return setmetatable(new_bar, bar_mt) as Bar
   end
}
