
local M = {
   bright = {},
   dark = {},
   fg = {
      rgb = nil,
      hex = nil,
   },
   bg = {
      rgb = nil,
      hex = nil,
   },
   cursor = {},
}

local CSI = string.char(27) .. "[%s"
local reset = CSI:format("0m")
function M.reset()
   return reset
end

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

for color, esc_seq in pairs(bright) do
   M.bright[color] = function(s)
      return CSI:format(bright[color]) .. s .. reset
   end
end
for color, esc_seq in pairs(dark) do
   M.dark[color] = function(s)
      return CSI:format(dark[color]) .. s .. reset
   end
end

local CSIfg = string.char(27) .. "[38;2;%d;%d;%dm"
local CSIbg = string.char(27) .. "[48;2;%d;%d;%dm"
M.fg = {
   rgb = function(r, g, b)
      return CSIfg:format(r, g, b)
   end,
   hex = function(hex)
      if type(hex) == "string" then
         if string.sub(hex, 1, 1) == "#" then
            hex = string.sub(hex, 2, -1)
         end
         hex = tonumber(hex, 16)
      end

      local red = math.floor((hex) / 2 ^ 16) * 0xFF
      local green = math.floor((hex) / 2 ^ 8) * 0xFF
      local blue = math.floor((hex)) * 0xFF
      return CSIfg:format(red, green, blue)
   end,
}
M.bg = {
   rgb = function(r, g, b)
      return CSIbg:format(r, g, b)
   end,
   hex = function(hex)
      if type(hex) == "string" then
         if string.sub(hex, 1, 1) == "#" then
            hex = string.sub(hex, 2, -1)
         end
         hex = tonumber(hex, 16)
      end

      local red = math.floor((hex) / 2 ^ 16) * 0xFF
      local green = math.floor((hex) / 2 ^ 8) * 0xFF
      local blue = math.floor((hex)) * 0xFF
      return CSIbg:format(red, green, blue)
   end,
}

function M.cursor.up(n)
   io.write(CSI:format(tostring(n or 1) .. "A"))
end

function M.cursor.down(n)
   io.write(CSI:format(tostring(n or 1) .. "B"))
end

function M.cursor.right(n)
   io.write(CSI:format(tostring(n or 1) .. "C"))
end

function M.cursor.left(n)
   io.write(CSI:format(tostring(n or 1) .. "D"))
end

function M.cursor.set_pos(row, col)
   io.write(CSI:format(tostring(row) .. ";" .. tostring(col) .. "H"))
end

function M.cursor.set_column(col)
   io.write(CSI:format(tostring(col or 0) .. "G"))
end

function M.clear_line(n)
   io.write(CSI:format(tostring(n or 0) .. "K"))
end

return M
