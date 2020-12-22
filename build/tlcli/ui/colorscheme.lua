
local ansi = require("tlcli.ansi")

 Colorscheme = {}

local M = {}

local default = {
   dir_name = ansi.bright.blue,
   normal_log = ansi.bright.cyan,
   verbose_log = ansi.bright.cyan,
   error_log = ansi.bright.red,
   warning_log = ansi.bright.yellow,
   debug_log = ansi.bright.green,

   file_name = ansi.bright.yellow,
   line_number = ansi.bright.magenta,
   normal = ansi.bright.white,
   special = ansi.bright.magenta,
}

local current_scheme = default

local no_color_scheme = setmetatable({}, {
   __index = function(_, _)
      return function(s)          return s end
   end,
})
function M.disable_colors()
   current_scheme = no_color_scheme
end

function M.color(c, str)
   return (current_scheme[c] or ansi.bright.white)(str)
end

function M.set_colorscheme(c)
   current_scheme = c
end

return M
