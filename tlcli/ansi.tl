
local M = {
   fg = {
      rgb: function(number,number,number):string = nil,
      hex: function(string|number):string = nil,
   },
   bg = {
      rgb: function(number,number,number):string = nil,
      hex: function(string|number):string = nil,
   },
   cursor = {},
}

local CSI = string.char(27) .. "[%s"

local dark = {
   black = "30m",
   red = "31m",
   green = "32m",
   yellow = "33m",
   blue = "34m",
   magenta = "35m",
   cyan = "36m",
   white = "37m",
}

local bright = {
   black = "90m",
   red = "91m",
   green = "92m",
   yellow = "93m",
   blue = "94m",
   magenta = "95m",
   cyan = "96m",
   white = "97m",
}

function M.dark(cname: string): string
   return CSI:format(dark[cname])
end

function M.bright(cname: string): string
   return CSI:format(bright[cname])
end

local CSIfg = string.char(27) .. "[38;2;%d;%d;%dm"
local CSIbg = string.char(27) .. "[48;2;%d;%d;%dm"
M.fg = {
   rgb = function(r: number, g: number, b: number): string
      return CSIfg:format(r, g, b)
   end,
   hex = function(hex: string | number): string
      if hex is string then
         if string.sub(hex, 1, 1) == "#" then
            hex = string.sub(hex, 2, -1)
         end
         hex = tonumber(hex, 16)
      end
      -- poor man's bit shifting
      local red = math.floor((hex as number) / 2 ^ 16) * 0xFF
      local green = math.floor((hex as number) / 2 ^ 8) * 0xFF
      local blue = math.floor((hex as number)) * 0xFF
      return CSI:format(red, green, blue)
   end
}
M.bg = {
   rgb = function(r: number, g: number, b: number): string
      return CSIbg:format(r, g, b)
   end,
   hex = function(hex: string | number): string
      if hex is string then
         if string.sub(hex, 1, 1) == "#" then
            hex = string.sub(hex, 2, -1)
         end
         hex = tonumber(hex, 16)
      end
      -- poor man's bit shifting
      local red = math.floor((hex as number) / 2 ^ 16) * 0xFF
      local green = math.floor((hex as number) / 2 ^ 8) * 0xFF
      local blue = math.floor((hex as number)) * 0xFF
      return CSIbg:format(red, green, blue)
   end
}

local reset = CSI:format("0m")
function M.reset(): string
   return reset
end

function M.cursor.up(n: number): string
   return CSI:format(tostring(n) .. "A")
end

function M.cursor.down(n: number): string
   return CSI:format(tostring(n) .. "B")
end

function M.cursor.right(n: number): string
   return CSI:format(tostring(n) .. "C")
end

function M.cursor.left(n: number): string
   return CSI:format(tostring(n) .. "D")
end

function M.set_cursor_pos(row: number, col: number): string
   return CSI:format(tostring(row) .. ";" .. tostring(col) .. "H")
end

function M.set_cursor_column(col: number): string
   return CSI:format(tostring(col or 0) .. "G")
end

function M.clear_line(n: number): string
   return CSI:format(tostring(n or 0) .. "K")
end

return M
