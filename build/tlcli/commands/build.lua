
local argparse = require("argparse")
local lfs = require("lfs")
local tl = require("tl")

local ansi = require("tlcli.ansi")
local cs = require("tlcli.ui.colorscheme")
local fs = require("tlcli.fs")
local log = require("tlcli.log")
local util = require("tlcli.util")
local bar = require("tlcli.ui.bar")
local loader = require("tlcli.loader")
local task = require("tlcli.task")
local builder = require("tlcli.builder")

local types = require("tlcli.types")
local Args = types.Args
local Command = types.Command


local options = util.protected_proxy({
   include = {},
   exclude = {},
   source_dir = ".",
   build_dir = ".",
   object_dir = ".",
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
      cmd:option("-u --update-all", "Compile each source file as if it has been edited."):
      args(0)
      cmd:option("--no-bar", "Disable the fancy progress bar."):
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
                        log.normal("Would create directory %s", cs.color("dir_name", parent))
                     else
                        log.normal("Created directory %s", cs.color("dir_name", parent))
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
"Source directory (" .. cs.color("file_name", src_dir) .. ") is not relative") then

         return 1
      end

      if util.error_if(
fs.is_absolute(build_dir),
"Build directory (" .. cs.color("file_name", build_dir) .. ") is not relative") then

         return 1
      end

      if util.error_if(
fs.is_absolute(obj_dir),
"Object directory (" .. cs.color("file_name", obj_dir) .. ") is not relative") then

         return 1
      end


      local b
      if not args.no_bar then
         local p = io.popen("stty size")
         local columns = math.floor(tonumber(p:read("*a"):match("%d+ (%d+)")) / 2.5)
         p:close()

         b = bar.new({
            length = columns,
            show_progress = true,
         })
      end

      local function draw_progress(step, fname)
         if b then
            ansi.cursor.up(1)
            ansi.clear_line(2)
            ansi.cursor.set_column(0)

            io.stdout:write(step, ": ", fname, "\n")
            b:draw(io.stdout)
         end
      end
      local function step()
         if b then             b:step() end
      end


      local function is_source_newer(source_path, target_path)
         if not target_path then
            return ""
         end
         local retval = false
         if args.update_all then
            return "Forced update"
         end
         local src_mod_time = lfs.attributes(source_path, "modification")
         local target_mod_time = lfs.attributes(target_path, "modification")
         if not target_mod_time then
            return "Target file doesn't exist"
         end
         return src_mod_time > target_mod_time and "Source is newer than target" or nil
      end

      local output_file_names = {}
      local function get_output_file_name(file_name)
         if output_file_names[file_name] then             return output_file_names[file_name] end
         local ext = fs.get_extension(file_name)
         local result
         if ext == "lua" or ext == "d.tl" then
            result = file_name
         else
            result = fs.get_output_file_name(file_name)
         end

         if src_dir ~= "." then
            result = result:sub(#src_dir + 2, -1)
         end
         if build_dir ~= "." then
            result = fs.path_concat(build_dir, result)
         end

         output_file_names[file_name] = result
         return result
      end


      local scheduler = task.scheduler(flags.keep_going and "round-robin" or "staged")

      local exit = 0
      local total_steps = 0
      local fatal_err

      local dag = builder.build_dag(src_dir, options.include, options.exclude, function(file_name)
         if build_dir ~= "." and fs.is_in_dir(build_dir, file_name) then
            log.debug("   %s is in build dir %s", file_name, build_dir)
            return nil
         end
         if file_name == "tlcconfig.lua" then             return nil end
         log.debug("Checking file: %s", file_name)
         local ext = fs.get_extension(file_name)
         if (ext == "d.tl" or ext == "lua") and
            src_dir == build_dir then

            log.debug("   Only type checking")
            return "No target, just type check"
         end
         local out_file = get_output_file_name(file_name)
         log.debug("   Checking if source %s is newer than %s", file_name, out_file)
         return is_source_newer(file_name, out_file)
      end, { global_options.module })

      for input_file, reason in dag:marked_files() do
         local output_file = get_output_file_name(input_file)
         local ext = fs.get_extension(input_file)
         scheduler.wrap(function()
            check_parents(output_file)
         end)
         local disp_file = cs.color("file_name", input_file)
         local disp_output_file = cs.color("file_name", output_file)
         scheduler.wrap(function()
            log.verbose("Processing: %s\n    Reason: %s", disp_file, cs.color("debug", reason))

            coroutine.yield()

            draw_progress("Type checking", disp_file)

            local res, err = util.teal.process(input_file, (fs.read(input_file)))

            step()
            if err then
               exit = 1
               local start, finish = err:lower():find("^%s*error:?%s*")
               if finish then
                  err = err:sub(finish + 1, -1)
               end
               log.error("Error in processing %s: %s", disp_file, err)
               if not flags.keep_going then
                  fatal_err = err
               end
               return
            end
            if #res.syntax_errors > 0 then
               exit = 1
               log.error(util.concat_errors(res.syntax_errors))
               if not flags.keep_going then
                  fatal_err = err
               end
               return
            end
            if (ext == "tl" or ext == "d.tl") and
               #res.type_errors > 0 then
               exit = 1
               if not flags.keep_going then
                  fatal_err = err
               end
               log.error(util.concat_errors(res.type_errors))
               return
            end

            coroutine.yield()

            step()
            if not args["pretend"] then
               local ext = fs.get_extension(input_file)
               draw_progress("Writing ", disp_output_file)
               if ext == "tl" or
                  ((ext == "lua" or ext == "d.tl") and build_dir ~= src_dir) then

                  local fh = assert(io.open(output_file, "w"))
                  fh:write(tl.pretty_print_ast(res.ast), "\n")
                  fh:close()
                  log.normal("Wrote %s", disp_output_file)
               else
                  log.normal("Type checked %s", input_file)
               end
            else
               log.normal("Would write %s", disp_output_file)
            end
            step()
         end)
         total_steps = total_steps + 2
      end

      if total_steps == 0 then
         log.normal("All files up to date")
         return 0
      end

      if b then
         b:set_total_steps(total_steps)
         io.write("\n")
      end

      scheduler.run()

      if b then
         ansi.cursor.up(1)
         ansi.cursor.set_column(0)
         ansi.clear_line(2)
         ansi.cursor.down(1)
         ansi.cursor.set_column(0)
         ansi.clear_line(2)
         ansi.cursor.up(1)
         ansi.cursor.set_column(0)
         io.flush()

         log.debug("Bar finished with %d/%d progress", b.steps, b.total_steps)
      end

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
