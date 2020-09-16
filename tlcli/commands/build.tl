
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local config = require("tlcli.config")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")
local bar = require("tlcli.ui.bar")

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

local record LogInfo
   level: string
   str: string
end
local log_queue: {LogInfo} = {}

local function lazy_log(level: string, fmt: string, ...: any)
   table.insert(log_queue, {level = level, str = string.format(fmt, ...)})
end

local function flush_log_queue()
   for _, info in ipairs(log_queue) do
      log.log(info.level, info.str)
   end
   log_queue = {}
end

local threads: {number:thread} = {}

local build: Command = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd: ArgparseParser.Command)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to.")
         :args(0)
   end,

   command = function(args: Args, cfg: Config): number
      if not cfg then
         return 1
      end
      -- TODO: Keep some sort of database to not rebuild files that haven't been edited a la GNU Make or Tup
      local exit = 0

      -- TODO: this should probably be handled outside of the commands
      for i, mod_name in ipairs(cfg and cfg.preload_modules or {}) do
         util.teal.add_module(mod_name)
      end
      for i, path_name in ipairs(cfg and cfg.include_dir or {}) do
         fs.add_to_teal_path(path_name)
      end

      local current_dir = lfs.currentdir()
      local root = config.find_project_root()
      if not root then
         return 1
      end
      lfs.chdir(root)
      -- TODO: check that source_dir exists
      if options.source_dir then
      else
         options.source_dir = "."
      end

      local p = io.popen("stty size")
      local columns = math.floor(tonumber(p:read("*a"):match("%d+ (%d+)")) / 2.5)
      p:close()

      local b = bar.new{
         length = columns,
         show_progress = true,
         message = "",
         message_length = math.floor(columns / 2),
      }
      local function update_bar()
         ansi.set_cursor_column(0)
         ansi.clear_line(2)
         b:draw(io.stdout)
         io.stdout:flush()
      end

      local step_size: number
      local total_steps = 0
      for file in fs.match(
         options.source_dir as string,
         options.include as {string},
         options.exclude as {string}
      ) do
         local output_file = file
         if options.source_dir and options.source_dir ~= "." then
            output_file = output_file:sub(#options.source_dir as string + 2, -1)
         end
         if options.build_dir and options.build_dir ~= "." then
            output_file = fs.path_concat(options.build_dir as string, output_file)
         end
         local ext = file:match(".*%.([a-z]+)$")
         if ext == "lua" then
            output_file = output_file:sub(1, -4) .. "out.lua"
         elseif ext == "tl" then
            output_file = output_file:sub(1, -3) .. "lua"
         end
         assert(check_parents(output_file))
         table.insert(threads, coroutine.create(function()
            local res, perr = util.teal.process(file, true)
            if perr then
               b:add_progress(step_size * 3)
            else
               b:add_progress(step_size * 1)
            end
            lazy_log("normal", "Type checked %s%s%s", ansi.bright"yellow", file, ansi.reset())
            b:set_message("[1/3] " .. file)
            coroutine.yield(perr)
            if not args["pretend"] then
               local fh, err = io.open(output_file, "w") as (FILE, string)
               if err then
                  b:set_message("[1/3]x" .. file)
                  b:add_progress(step_size * 2)
               else
                  b:set_message("[2/3] " .. file)
                  b:add_progress(step_size)
               end
               coroutine.yield(err)
               local ok, werr = fh:write(util.teal.pretty_print_ast(res.ast as table))
               b:add_progress(step_size)
               fh:close()
               if not ok then
                  b:set_message("[2/3]x" .. file)
                  lazy_log("error", "Error writing %s%s%s, %s", ansi.bright"yellow", output_file, ansi.reset(), werr)
                  coroutine.yield(werr)
               end
               b:set_message("[3/3] " .. file)
               lazy_log("normal", "Wrote %s%s%s", ansi.bright"yellow", output_file, ansi.reset())
            else
               lazy_log("normal", "Would write %s%s%s", ansi.bright"yellow", output_file, ansi.reset())
            end
         end))
         total_steps = total_steps + 3
      end
      step_size = 1 / total_steps

      while next(threads) do
         for i, t in pairs(threads) do
            update_bar()
            if coroutine.status(t) == "dead" then
               threads[i] = nil
            else
               local ok, err = coroutine.resume(t)
               if not ok or err as boolean then
                  lazy_log("error", "%s", err)
                  threads[i] = nil
                  exit = 1
               end
            end
         end
      end

      ansi.set_cursor_column(0)
      ansi.clear_line(2)

      flush_log_queue()

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
