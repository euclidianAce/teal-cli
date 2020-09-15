
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local config = require("tlcli.config")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command
local Config = types.Config

-- check if all the parents to dirname exist, and if they don't, create them
local parents_that_exist: {string:boolean} = {}
local function check_parents(dirname: string): boolean, string
   for parent in fs.path_parents(dirname) do
      if not parents_that_exist[parent] then
         local mode, err = lfs.attributes(parent, "mode") as (string, string)
         if mode ~= "directory" then
            if err and err:match("No such file or directory$") then
               lfs.mkdir(parent)
               parents_that_exist[parent] = true
            else
               return false, "Parent " .. dirname .. " exists, but is not a directory"
            end
         else
            parents_that_exist[parent] = true
         end
      end
   end
   return true
end

local threads: {number:thread} = {}

local build: Command
build = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd: ArgparseParser.Command)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to.")
   end,

   command = function(args: Args, cfg: Config): number
      -- TODO: Keep some sort of database to not rebuild files that haven't been edited a la GNU Make or Tup
      local exit = 0

      -- TODO: this should probably be handled outside of the commands
      for i, mod_name in ipairs(cfg.preload_modules or {}) do
         util.teal.add_module(mod_name)
      end
      for i, path_name in ipairs(cfg.include_dir or {}) do
         fs.add_to_teal_path(path_name)
      end

      local current_dir = lfs.currentdir()
      local root = config.find_project_root()
      lfs.chdir(root)
      if build.options.source_dir then
      else
         build.options.source_dir = "."
      end

      local record FileInfo
         input_name: string
         output_name: string
         has_no_errors: boolean
         err_str: string
      end

      for file in fs.match(
         build.options.source_dir as string,
         build.options.include as {string},
         build.options.exclude as {string}
      ) do
         local output_file = file
         if build.options.source_dir then
            output_file = output_file:sub(#build.options.source_dir as string + 2, -1)
         end
         if build.options.build_dir then
            -- TODO: check that it and its parents exist, if they don't, create them
            output_file = fs.path_concat(build.options.build_dir as string, output_file)
         end
         local ext = file:match(".*%.([a-z]+)$")
         if ext == "lua" then
            output_file = output_file:sub(1, -4) .. "out.lua"
         elseif ext == "tl" then
            output_file = output_file:sub(1, -3) .. "lua"
         end
         assert(check_parents(output_file))
         local info: FileInfo = {
            input_name = file,
            output_name = output_file,
         }
         table.insert(threads, coroutine.create(function()
            log.normal("Type checking %s%s%s", ansi.bright"yellow", info.input_name, ansi.reset())
            local res = assert(util.teal.process(info.input_name))
            coroutine.yield()
            local fh, err = assert(io.open(info.output_name, "w")) as (FILE, string)
            coroutine.yield()
            assert(fh:write(util.teal.pretty_print_ast(res.ast as table)))
            fh:close()
            log.normal("Wrote %s%s%s", ansi.bright"yellow", info.output_name, ansi.reset())
         end))
      end

      while next(threads) do
         for i, t in pairs(threads) do
            if coroutine.status(t) == "dead" then
               threads[i] = nil
            else
               local ok, err = coroutine.resume(t)
               if not ok then
                  log.error("%s", err)
                  threads[i] = nil
                  exit = 1
               end
            end
         end
      end

      return exit
   end,

   config = function(opts: table)
      build.options = opts --FIXME
   end,

   options = {},
}
return build
