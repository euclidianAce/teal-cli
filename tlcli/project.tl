
local config = require("tlcli.config")
local fs = require("tlcli.fs")
local util = require("tlcli.util")

local lfs = require("lfs")

local types = require("tlcli.types")
--local Args = types.Args
--local Command = types.Command
local Config = types.Config
--local GlobalConfig = types.GlobalConfig

local type EmptyRef = METATABLE
local record Project
   dir: fs.File
   paths: {string:fs.File}
   _emptyref: EmptyRef

   config: Config
end

local M = {
   Project = Project
}


return M
