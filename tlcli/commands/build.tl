
local argparse = require("argparse")
local lfs = require("lfs")

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
local function check_parents(dirname: string): boolean, string
   for parent in fs.path_parents(dirname) do
      local mode, err = lfs.attributes(parent, "mode") as (string, string)
      if mode ~= "directory" then
         if err and err:match("No such file or directory$") then
            lfs.mkdir(parent)
         else
            return false, "Parent " .. dirname .. " exists, but is not a directory"
         end
      end
   end
   return true
end

local build: Command
build = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd: ArgparseParser.Command)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to.")
   end,

   command = function(args: Args, cfg: Config): number
      -- TODO: Keep some sort of database to not rebuild files that haven't been edited a la GNU Make or Tup
      log.debug("Running build command")
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
      log.debug("Found project root %s", root)
      if build.options.source_dir then
         log.debug("Project has a source_dir: %s", build.options.source_dir)
      else
         build.options.source_dir = "."
      end
      log.debug("source_dir: %s", build.options.source_dir)

      local record FileInfo
         input_name: string
         output_name: string
         has_no_errors: boolean
         err_str: string
      end

      local files: {FileInfo} = {}

      for file in fs.match(
         build.options.source_dir as string,
         build.options.include as {string},
         build.options.exclude as {string}
      ) do
         log.debug("Found file %s", file)
         local output_file = file
         if build.options.source_dir then
            log.debug("removing source dir (%s) prefix from %s\n%s", build.options.source_dir, output_file, output_file:sub(#build.options.source_dir as string + 2, -1))
            output_file = output_file:sub(#build.options.source_dir as string + 2, -1)
         end
         if build.options.build_dir then
            -- TODO: check that it and its parents exist, if they don't, create them
            log.debug("adding build dir (%s) prefix to %s\n%s", build.options.build_dir, output_file, fs.path_concat(build.options.build_dir as string, output_file))
            output_file = fs.path_concat(build.options.build_dir as string, output_file)
         end
         local ext = file:match(".*%.([a-z]+)$")
         if ext == "lua" then
            output_file = output_file:sub(1, -4) .. "out.lua"
         elseif ext == "tl" then
            output_file = output_file:sub(1, -3) .. "lua"
         else
            log.debug("%s is not a .lua or .tl file", file)
         end
         local info: FileInfo = {
            input_name = file,
            output_name = output_file,
         }
         log.normal("Type checking: %s%s%s", ansi.bright"yellow", file, ansi.reset())
         info.has_no_errors, info.err_str = util.teal.type_check_file(file)
         if not info.has_no_errors then
            exit = 1
            log.error(info.err_str)
         end
         table.insert(files, info)
      end

      log.debug("file info\n%s", require('inspect')(files))

      for i, file in ipairs(files) do
         if file.has_no_errors then
            log.debug("Checking parent directories of %s", file.output_name)
            assert(check_parents(file.output_name))
            log.debug("Output file: %s", file.output_name)
            local ok, err = util.teal.compile_and_write(file.input_name, false, file.output_name)
            if not ok then
               log.error("Error compiling %s%s%s:\n%s", ansi.bright"yellow", file.input_name, ansi.reset(), err)
            else
               log.normal("Wrote %s%s%s", ansi.bright"yellow", file.output_name, ansi.reset())
            end
         else
            log.debug("Wouldn't write %s%s%s as it has errors", ansi.bright"yellow", file.output_name, ansi.reset())
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
