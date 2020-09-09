
local config = require("tlcli.config")
local fs = require("tlcli.fs")
local util = require("tlcli.util")

local lfs = require("lfs")

local type EmptyRef = METATABLE
local record Project
   dir: fs.File
   paths: {string:fs.File}
   _emptyref: EmptyRef

   config: config.Config
end

local M = {
   Project = Project
}


return M
