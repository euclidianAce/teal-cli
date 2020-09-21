
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")
local bar = require("tlcli.ui.bar")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command

-- TODO: better err handler that says 'invalid option' or something
local options: {string:any} = util.protected_proxy{
   include: {string} = {},
   exclude: {string} = {},
   source_dir = ".",
   build_dir = ".",
}

local flags: {string:boolean} = util.protected_proxy{
   keep_going = false,
}

local threads: {string:{number:thread}} = {
   checkers = {},
   writers = {},
}

local create_checker = function(func: function) table.insert(threads.checkers, coroutine.create(func)) end
local create_writer  = function(func: function) table.insert(threads.writers, coroutine.create(func))  end

local build: Command = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd: ArgparseParser.Command)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to.")
         :args(0)
   end,

   command = function(args: Args): number
      local loaded_config, config_err = require("tlcli.loader").load_config()
      if not loaded_config then
         log.error("Error loading config file:\n   %s", config_err)
         return 1
      end
      -- TODO: Keep some sort of database to not rebuild files that haven't been edited a la GNU Make or Tup
      -- maybe make a .teal folder in the root of the project?

      lfs.chdir(fs.find_project_root())
      local src_dir: string = options.source_dir as string
      local build_dir: string = options.build_dir as string

      -- check if all the parents to dirname exist, and if they don't, create them
      local parents_that_exist: {string:boolean} = {}
      local function check_parents(dirname: string): boolean, string
         for parent in fs.path_parents(dirname) do
            if not parents_that_exist[parent] then
               local mode, err = lfs.attributes(parent, "mode") as (string, string)
               if mode ~= "directory" then
                  if err and err:match("No such file or directory$") then
                     if args.pretend then
                        log.queue("normal", "Would create directory %s", ansi.bright.green(parent))
                     else
                        log.queue("normal", "Created directory %s", ansi.bright.green(parent))
                        lfs.mkdir(parent)
                     end
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

      if util.error_if(
         fs.is_absolute(src_dir),
         "Source directory (" .. ansi.bright.yellow(src_dir) .. ") is not relative"
      ) then
         return 1
      end

      if util.error_if(
         fs.is_absolute(build_dir),
         "Build directory (" .. ansi.bright.yellow(build_dir) .. ") is not relative"
      ) then
         return 1
      end

      local p = io.popen("stty size") --TODO: this isn't super portable, and the progress bar should be toggleable
      local columns = math.floor(tonumber(p:read("*a"):match("%d+ (%d+)")) / 2.5)
      p:close()

      local b = bar.new{
         length = columns,
         show_progress = true,
      }

      local function draw_progress(step: string, fname: string)
         ansi.cursor.up(1)
         ansi.clear_line(2)
         ansi.cursor.set_column(0)

         io.stdout:write(step, ": ", fname, "\n")
         b:draw(io.stdout)
      end
      io.stdout:write("\n")

      local exit = 0
      local step_size: number
      local total_steps = 0
      for file in fs.match(
         src_dir,
         options.include as {string},
         options.exclude as {string}
      ) do
         local output_file = file

         if src_dir and src_dir ~= "." then
            output_file = output_file:sub(#src_dir + 2, -1)
         end
         if build_dir and build_dir ~= "." then
            output_file = fs.path_concat(build_dir, output_file)
         end

         output_file = output_file:sub(1, -3) .. "lua"

         draw_progress("Preparing", "Parent directories")
         assert(check_parents(output_file))

         local disp_file = ansi.bright.yellow(file)
         local disp_output_file = ansi.bright.yellow(output_file)
         draw_progress("Preparing", disp_file)

         create_checker(function()
            draw_progress("Type checking", disp_file)
            b:add_progress(step_size)

            local res, err = util.teal.process(file, true)
            if err then
               local start, finish = err:lower():find("^%s*error:?%s*")
               if finish then
                  err = err:sub(finish+1, -1)
               end
            end

            coroutine.yield(err)
            if not args["pretend"] then
               create_writer(function()
                  local fh = assert(io.open(output_file, "w"))

                  draw_progress("Writing", disp_output_file)

                  local ok = fh:write(util.teal.pretty_print_ast(res.ast as table))

                  b:add_progress(step_size)

                  assert(fh:close())
                  log.queue("normal", "Wrote %s", disp_output_file)
               end)
            else
               b:add_progress(step_size)
               log.queue("normal", "Would write %s", disp_output_file)
            end
         end)
         total_steps = total_steps + 2
      end

      step_size = 1 / total_steps

      local function should_break(): boolean
         return (not flags.keep_going and exit ~= 0)
      end
      local step = function(ts: {number:thread}): any
         while true do
            if should_break() then break end
            for i, t in pairs(ts) do
               if coroutine.status(t) == "dead" then
                  ts[i] = nil
               else
                  local ok, err = coroutine.resume(t)
                  if not ok or err as boolean then
                     log.queue("error", "%s", err)
                     ts[i] = nil
                     exit = 1
                     break
                  end
               end
               if i % 20 == 0 then
                  coroutine.yield()
                  break
               end
            end
            coroutine.yield()
         end
      end

      local check_step = util.wrap_with(step, threads.checkers)
      local write_step = util.wrap_with(step, threads.writers)

      while next(threads.checkers)
         or next(threads.writers)
         and not should_break()
      do
         check_step()
         if should_break() then break end
         if flags.keep_going as boolean
            or not next(threads.checkers)
            -- only write after checking everything in case of errors
            -- or if we don't care about errors
         then
            write_step()
         end
      end

      ansi.cursor.up(1)
      ansi.cursor.set_column(0)
      ansi.clear_line(2)
      ansi.cursor.down(1)
      ansi.cursor.set_column(0)
      ansi.clear_line(2)
      ansi.cursor.up(1)
      ansi.cursor.set_column(0)
      io.flush()

      log.flush()

      return exit
   end,

   config = function(opt: string): function
      if opt == "flags" then
         return function(t: {string})
            for i, v in ipairs(t) do
               flags[v] = true
            end
         end
      elseif opt == "options" then
         return function(t: {string:any})
            for i, v in pairs(t) do
               options[i] = v
            end
         end
      end
   end,
}

return build
