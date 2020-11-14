
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

-- TODO: better err handler that says 'invalid option' or something
local options = util.protected_proxy{
   include: {string} = {},
   exclude: {string} = {},
   source_dir = ".",
   build_dir = ".",
   object_dir = ".",
}

local flags: {string:boolean} = util.protected_proxy{
   keep_going = false,
}

local build: Command = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd: ArgparseParser.Command)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to.")
         :args(0)
      cmd:option("-u --update-all", "Compile each source file as if it has been edited.")
         :args(0)
      cmd:option("--no-bar", "Disable the fancy progress bar.")
         :args(0)
   end,

   command = function(args: Args): number
      log.set_buffered(true)
      local loaded_config, config_err = loader.load_config()
      local global_options = loader.load_options()

      if not loaded_config then
         log.error("Error loading config file:\n   %s", config_err)
         return 1
      end

      lfs.chdir(fs.find_project_root())
      local src_dir: string = options.source_dir as string
      local build_dir: string = options.build_dir as string
      local obj_dir: string = options.object_dir as string

      do
         local attrs, reason = lfs.attributes(src_dir) as (any, string)
         if not attrs then
            log.error("Unable to access source dir \"%s\"\nReason: %s", src_dir, reason)
            return 1
         end
      end

      if global_options.module then
         log.debug("[build command] hijacking module searching...")
         local mod = global_options.module as {string:string}
         util.hijack_tl_search_module(mod.name, mod.source)
      end

      -- {{{ Check Parent Dirs
      local parents_that_exist: {string:boolean} = {}
      local function check_parents(dirname: string): boolean, string
         for parent in fs.path_parents(dirname) do
            if not parents_that_exist[parent] then
               local mode, err = lfs.attributes(parent, "mode") as (string, string)
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
      -- }}}
      -- {{{ Assert relative paths
      if util.error_if(
         fs.is_absolute(src_dir),
         "Source directory (" .. cs.color("file_name", src_dir) .. ") is not relative"
      ) then
         return 1
      end

      if util.error_if(
         fs.is_absolute(build_dir),
         "Build directory (" .. cs.color("file_name", build_dir) .. ") is not relative"
      ) then
         return 1
      end

      if util.error_if(
         fs.is_absolute(obj_dir),
         "Object directory (" .. cs.color("file_name", obj_dir) .. ") is not relative"
      ) then
         return 1
      end
      -- }}}
      -- {{{ Setup Progress Bar
      local b: bar.Bar
      if not args.no_bar then
         local p = io.popen("stty size") --TODO: this isn't super portable
         local columns = math.floor(tonumber(p:read("*a"):match("%d+ (%d+)")) / 2.5)
         p:close()

         b = bar.new{
            length = columns,
            show_progress = true,
         }
      end

      local function draw_progress(step: string, fname: string)
         if b then
            ansi.cursor.up(1)
            ansi.clear_line(2)
            ansi.cursor.set_column(0)

            io.stdout:write(step, ": ", fname, "\n")
            b:draw(io.stdout)
         end
      end
      local function step()
         if b then b:step() end
      end
      -- }}}

      local function is_source_newer(source_path: string, target_path: string): string
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

      local output_file_names: {string:string} = {}
      local function get_output_file_name(file_name: string): string
         if output_file_names[file_name] then return output_file_names[file_name] end
         local ext = fs.get_extension(file_name)
         local result: string
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

      -- staged will make everything get type checked first, round-robin just lets stuff happen
      local scheduler = task.scheduler(flags.keep_going and "round-robin" or "staged")

      local exit = 0
      local total_steps = 0
      local fatal_err: string

      local dag = builder.build_dag(src_dir, options.include, options.exclude, function(file_name: string): string
         log.debug("Checking file: %s", file_name)
         if build_dir ~= "." and fs.is_in_dir(build_dir, file_name) then
            log.debug("   %s is in build dir %s", file_name, build_dir)
            return nil
         end
         if file_name == "tlcconfig.lua" then return nil end
         log.debug("Checking file: %s", file_name)
         local ext <const> = fs.get_extension(file_name)
         if (ext == "d.tl" or ext == "lua")
            and src_dir == build_dir
         then
            log.debug("   Only type checking")
            return "No target, just type check"
         end
         local out_file = get_output_file_name(file_name)
         log.debug("   Checking if source %s is newer than %s", file_name, out_file)
         return is_source_newer(file_name, out_file)
      end)

      for input_file, reason in dag:marked_files() do
         local output_file <const> = get_output_file_name(input_file)
         local ext <const> = fs.get_extension(input_file)
         scheduler.wrap(function()
            check_parents(output_file)
         end)
         local disp_file = cs.color("file_name", input_file)
         local disp_output_file = cs.color("file_name", output_file)
         scheduler.wrap(function()
            log.verbose("Processing: %s\n   Reason: %s", disp_file, cs.color("debug", reason))

            coroutine.yield()

            draw_progress("Type checking", disp_file)

            local res, err = util.teal.process(input_file, (fs.read(input_file)))

            step()
            if err then
               exit = 1
               local start, finish = err:lower():find("^%s*error:?%s*")
               if finish then
                  err = err:sub(finish+1, -1)
               end
               log.error("Error in processing %s: %s", disp_file, err)
               if not flags.keep_going then
                  fatal_err = err
               end
               return
            end
            if #res.syntax_errors as table > 0 then
               exit = 1
               log.error(util.concat_errors(res.syntax_errors as table))
               if not flags.keep_going then
                  fatal_err = err
               end
               return
            end
            if (ext == "tl" or ext == "d.tl")
               and #res.type_errors as table > 0 then
               exit = 1
               if not flags.keep_going then
                  fatal_err = err
               end
               log.error(util.concat_errors(res.type_errors as table))
               return
            end

            coroutine.yield()

            step()
            if not args["pretend"] then
               local ext <const> = fs.get_extension(input_file)
               draw_progress("Writing ", disp_output_file)
               if ext == "tl"
                  or ((ext == "lua" or ext == "d.tl") and build_dir ~= src_dir)
               then
                  local fh = assert(io.open(output_file, "w"))
                  fh:write(util.teal.pretty_print_ast(res.ast as table), "\n")
                  assert(fh:close())
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

   config = function(opt: string): function
      if opt == "flags" then
         return function(t: {string})
            for i, v in ipairs(t) do
               flags[v] = true
            end
         end
      elseif opt == "options" then
         return function(t: {string:any})
            for k, v in pairs(t) do
               options as {string:any}[k] = v
            end
         end
      -- elseif opt == "cmodule" then
         -- return function(t: {string:any})
            -- TODO: There are probably some util functions to help with this
            -- if not t.name or type(t.name) ~= "string" then
               -- log.error("Name not provided for c module")
               -- return
            -- end
            -- if c_modules[t.name as string] then
               -- log.error("Module \"%s\" was already specified")
               -- return
            -- end
            -- if not (t.include or t.exclude) then
               -- log.error("Specify source files for c module \"%s\" with the \"include\" and \"exclude\" fields", t.name)
               -- return
            -- end
            -- local m: CModule = {
               -- include = {},
               -- exclude = {},
               -- source = {},
               -- o_files = {},
            -- }
            -- if t.include then
               -- for i, v in ipairs(t.include as {any}) do
                  -- if v is string then
                     -- table.insert(m.include, v)
                  -- else
                     -- log.warn("Non string entry in \"include\" field")
                  -- end
               -- end
            -- end
            -- if t.exclude then
               -- for i, v in ipairs(t.exclude as {any}) do
                  -- if v is string then
                     -- table.insert(m.exclude, v)
                  -- else
                     -- log.warn("Non string entry in \"exclude\" field")
                  -- end
               -- end
            -- end
            -- c_modules[t.name as string] = m
         -- end
      end
   end,
}

return build
