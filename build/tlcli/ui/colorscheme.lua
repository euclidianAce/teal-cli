
local ansi = require("tlcli.ansi")

 Colorscheme = {}

local M = {}

local default = {
   debug = ansi.bright.green,
   dir_name = ansi.bright.blue,
   error = ansi.bright.red,
   file_name = ansi.bright.yellow,
   line_number = ansi.bright.magenta,
   normal = ansi.bright.white,
   special = ansi.bright.magenta,
}

local current_scheme = default

function M.color(c, str)
   return (current_scheme[c] or ansi.bright.white)(str)
end

function M.set_colorscheme(c)
   current_scheme = c
end

return M
