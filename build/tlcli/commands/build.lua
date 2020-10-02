
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")
local bar = require("tlcli.ui.bar")
local loader = require("tlcli.loader")
local task = require("tlcli.task")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command


local options = util.protected_proxy({
   include = {},
   exclude = {},
   source_dir = ".",
   build_dir = ".",
   object_dir = ".",
   module_name = "",
})

local flags = util.protected_proxy({
   keep_going = false,
})

local build = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to."):
      args(0)
      cmd:option("-u --update-all", "Compile each source file as if it has been edited"):
      args(0)
   end,

   command = function(args)
      log.set_buffered(true)
      local loaded_config, config_err = loader.load_config()
      local global_options = loader.load_options()

      if not loaded_config then
         log.error("Error loading config file:\n   %s", config_err)
         return 1
      end

      lfs.chdir(fs.find_project_root())
      local src_dir = options.source_dir
      local build_dir = options.build_dir
      local obj_dir = options.object_dir

      do
         local attrs, reason = lfs.attributes(src_dir)
         if not attrs then
            log.error("Unable to access source dir \"%s\"\nReason: %s", src_dir, reason)
            return 1
         end
      end

      if global_options.module then
         log.debug("[build command] hijacking module searching...")
         local mod = global_options.module
         util.hijack_tl_search_module(mod.name, mod.source)
      end


      local parents_that_exist = {}
      local function check_parents(dirname)
         for parent in fs.path_parents(dirname) do
            if not parents_that_exist[parent] then
               local mode, err = lfs.attributes(parent, "mode")
               if mode ~= "directory" then
                  if err and err:match("No such file or directory$") then
                     if args.pretend then
                        log.normal("Would create directory %s", ansi.bright.green(parent))
                     else
                        log.normal("Created directory %s", ansi.bright.green(parent))
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
"Source directory (" .. ansi.bright.yellow(src_dir) .. ") is not relative") then

         return 1
      end

      if util.error_if(
fs.is_absolute(build_dir),
"Build directory (" .. ansi.bright.yellow(build_dir) .. ") is not relative") then

         return 1
      end

      if util.error_if(
fs.is_absolute(obj_dir),
"Object directory (" .. ansi.bright.yellow(obj_dir) .. ") is not relative") then

         return 1
      end

      local p = io.popen("stty size")
      local columns = math.floor(tonumber(p:read("*a"):match("%d+ (%d+)")) / 2.5)
      p:close()

      local b = bar.new({
         length = columns,
         show_progress = true,
      })

      local function draw_progress(step, fname)
         ansi.cursor.up(1)
         ansi.clear_line(2)
         ansi.cursor.set_column(0)

         io.stdout:write(step, ": ", fname, "\n")
         b:draw(io.stdout)
      end

      local function is_source_newer(source_path, target_path)
         local retval = false
         if args.update_all then
            return true
         end
         local src_mod_time = lfs.attributes(source_path, "modification")
         local target_mod_time = lfs.attributes(target_path, "modification")
         if not target_mod_time then
            retval = true
         end
         retval = retval or src_mod_time > target_mod_time
         if retval then
            log.verbose("Source file %s is newer than %s, recompiling...", ansi.bright.yellow(source_path), ansi.bright.yellow(target_path))
         end
         return retval
      end


      local scheduler = task.scheduler(flags.keep_going and "round-robin" or "staged")

      local function get_o(input)
         return input:sub(1, -2) .. "o"
      end

      local o_files = {}

      local update_so = false
      local exit = 0
      local total_steps = 0
      local fatal_err
      for input_file in fs.match(
src_dir,
options.include,
options.exclude) do

         if fs.get_extension(input_file) == "tl" and not input_file:match("%.d%.tl$") then

            local output_file = input_file

            if src_dir ~= "." then
               output_file = output_file:sub(#src_dir + 2, -1)
            end
            if build_dir ~= "." then
               output_file = fs.path_concat(build_dir, output_file)
            end

            output_file = output_file:sub(1, -3) .. "lua"

            assert(check_parents(output_file))

            local disp_file = ansi.bright.yellow(input_file)
            local disp_output_file = ansi.bright.yellow(output_file)

            if is_source_newer(input_file, output_file) then
               scheduler.schedule_wrap(function()
                  draw_progress("Type checking", disp_file)

                  local res, err = util.teal.process(input_file, true)
                  if err then
                     local start, finish = err:lower():find("^%s*error:?%s*")
                     if finish then
                        err = err:sub(finish + 1, -1)
                     end
                     log.error(err)
                     if not flags.keep_going then
                        exit = 1
                        fatal_err = err
                     end
                  end

                  b:step()
                  coroutine.yield()

                  if not args["pretend"] then
                     local fh = assert(io.open(output_file, "w"))
                     draw_progress("Writing", disp_output_file)
                     local ok = fh:write(util.teal.pretty_print_ast(res.ast))
                     assert(fh:close())
                     log.normal("Wrote %s", disp_output_file)
                  else
                     log.normal("Would write %s", disp_output_file)
                  end
                  b:step()
               end)
               total_steps = total_steps + 2
            end

         elseif fs.get_extension(input_file) == "c" then
            if options.module_name == "" then
               log.error("Build error: c files are present in project, but a module name wasn't specified")
               return 1
            end

            local output_file = get_o(input_file)

            assert(check_parents(output_file))

            if src_dir ~= "." then
               output_file = output_file:sub(#src_dir + 2, -1)
            end
            if obj_dir ~= "." then
               output_file = fs.path_concat(obj_dir, output_file)
            end

            if is_source_newer(input_file, output_file) then
               check_parents(output_file)
               update_so = true
               scheduler.schedule_wrap(function()

                  coroutine.yield()
                  coroutine.yield()
                  draw_progress("Compiling", input_file)
                  local cmd = "cc -c " .. input_file .. " -o " .. output_file .. " 2>&1"
                  local p = io.popen(cmd)
                  local output = p:read("*a")
                  local exit_ok = p:close()
                  if not exit_ok then
                     log.error("Error compiling %s:\nCommand run: %s\n\n%s", ansi.bright.yellow(input_file), cmd, output)
                     exit = 1
                     fatal_err = output
                  else
                     log.normal("Compiled %s -> %s", ansi.bright.yellow(input_file), ansi.bright.green(output_file))
                     b:step()
                  end
               end)
               total_steps = total_steps + 1
            end
            table.insert(o_files, output_file)
         end
      end

      if total_steps == 0 then
         log.normal("Nothing to build...")
         return 0
      end

      b:set_total_steps(total_steps)

      io.write("\n")
      scheduler.run()

      if not fatal_err and (update_so or args.update_all) and #o_files > 0 then
         local output_file = options.module_name
         if src_dir ~= "." then
            output_file = output_file:sub(#src_dir + 2, -1)
         end
         if build_dir ~= "." then
            output_file = fs.path_concat(build_dir, output_file)
         end
         check_parents(output_file)
         draw_progress("Compiling", ansi.bright.yellow(output_file))
         local cmd = "cc -fPIC -shared -o " .. output_file .. " " .. table.concat(o_files, " ")
         local p = io.popen(cmd)
         local output = p:read("*a")
         local exit_ok = p:close()
         if not exit_ok then
            log.error("Error compiling module %s:\nCommand run: %s\n\n%s", ansi.bright.green(output_file), cmd, output)
            exit = 1
         else
            log.normal("Compiled Module %s", ansi.bright.green(output_file))
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

   config = function(opt)
      if opt == "flags" then
         return function(t)
            for i, v in ipairs(t) do
               flags[v] = true
            end
         end
      elseif opt == "options" then
         return function(t)
            for k, v in pairs(t) do
               options[k] = v
            end
         end
      end
   end,
}

return build
