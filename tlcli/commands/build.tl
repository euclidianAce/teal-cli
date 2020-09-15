
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

local options: {string:string|{string}} = {
   include: {string} = {},
   exclude: {string} = {},
   source_dir = ".",
   build_dir = ".",
}

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

local p = io.popen("stty size")
local columns = math.floor(tonumber(p:read("*a"):match("%d+ (%d+)")) / 2) - 4
p:close()

local progress = 0
local total_steps = 0
local function draw_progress_bar()
   io.write(ansi.set_cursor_column(0))
   io.write(ansi.clear_line(2))
   local filled_space = math.floor((progress / total_steps) * columns)
   io.write(("[%3d %%]"):format(math.floor(progress / total_steps * 100)))
   io.write("  [")
   io.write(("="):rep(filled_space))
   io.write(">")
   io.write((" "):rep(columns - filled_space > 0 and columns - filled_space or 0))
   io.write("]")
   io.flush()
end

local function log_update_bar(level: string, fmt: string, ...: any)
   io.write(ansi.clear_line(2))
   io.write(ansi.set_cursor_column(0))
   io.flush()
   log.log(level, fmt, ...)
   draw_progress_bar()
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
      if options.source_dir then
      else
         options.source_dir = "."
      end

      local record FileInfo
         input_name: string
         output_name: string
         has_no_errors: boolean
         err_str: string
      end

      for file in fs.match(
         options.source_dir as string,
         options.include as {string},
         options.exclude as {string}
      ) do
         local output_file = file
         if options.source_dir then
            output_file = output_file:sub(#options.source_dir as string + 2, -1)
         end
         if options.build_dir then
            -- TODO: check that it and its parents exist, if they don't, create them
            output_file = fs.path_concat(options.build_dir as string, output_file)
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
            local res, perr = util.teal.process(info.input_name, true)
            if perr then
               progress = progress + 3
            else
               progress = progress + 1
            end
            log_update_bar("normal", "Type checked %s%s%s", ansi.bright"yellow", info.input_name, ansi.reset())
            coroutine.yield(perr)
            local fh, err = io.open(info.output_name, "w") as (FILE, string)
            if err then
               progress = progress + 2
            else
               progress = progress + 1
            end
            coroutine.yield(err)
            local ok, werr = fh:write(util.teal.pretty_print_ast(res.ast as table))
            progress = progress + 1
            fh:close()
            if not ok then
               log_update_bar("error", "Error writing %s%s%s, %s", ansi.bright"yellow", info.output_name, ansi.reset(), werr)
               coroutine.yield(werr)
            end
            log_update_bar("normal", "Wrote %s%s%s", ansi.bright"yellow", info.output_name, ansi.reset())
         end))
         total_steps = total_steps + 3
      end

      while next(threads) do
         for i, t in pairs(threads) do
            if coroutine.status(t) == "dead" then
               threads[i] = nil
            else
               local ok, err = coroutine.resume(t)
               if not ok or err as boolean then
                  log_update_bar("error", "%s", err)
                  threads[i] = nil
                  exit = 1
               end
            end
            draw_progress_bar()
         end
      end
      io.write(ansi.clear_line(2))
      io.write(ansi.set_cursor_column(0))
      io.flush()

      return exit
   end,

   config = function(opts: table)
      for k, v in pairs(opts) do
         if options[k as string] then
            if type(options[k as string]) ~= type(v) then
               log.warn("build config: Key %s is of the wrong type\n   Expected %s, got %s", tostring(k), type(options[k as string]), type(v))
            else
               options[k as string] = v as string
            end
         else
            log.warn("build config: Invalid key %s", tostring(k))
         end
      end
   end,
}

return build
