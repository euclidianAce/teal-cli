
local ansi = require("tlcli.ansi")

global type Colorscheme = {string:Colorizer}

local M = {}

local default: Colorscheme = {
   debug = ansi.bright.green as Colorizer,
   dir_name = ansi.bright.blue as Colorizer,
   error = ansi.bright.red as Colorizer,
   file_name = ansi.bright.yellow as Colorizer,
   line_number = ansi.bright.magenta as Colorizer,
   normal = ansi.bright.white as Colorizer,
   special = ansi.bright.magenta as Colorizer,
}

local current_scheme = default

function M.color(c: string, str: string): string
   return (current_scheme[c] or ansi.bright.white)(str)
end

function M.set_colorscheme(c: Colorscheme)
   current_scheme = c
end

return M
