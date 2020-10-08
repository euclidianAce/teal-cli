
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

local record CModule
   include: {string}
   exclude: {string}
   source: {string:boolean} -- set of files that were updated to check if recompilation of the whole module is needed
   o_files: {string}
end

local c_modules: {string:CModule} = {}

local function should_recompile_c_module(mod: CModule): boolean
   for k, v in pairs(mod.source) do
      if v then
         return true
      end
   end
   return false
end

local build: Command = {
   name = "build",
   description = "Build an entire Teal project based on the specifications in tlcconfig.lua.",
   argparse = function(cmd: ArgparseParser.Command)
      cmd:option("-p --pretend --dry-run", "Don't write to any files, type check and print what would be written to.")
         :args(0)
      cmd:option("-u --update-all", "Compile each source file as if it has been edited")
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
         local attrs, reason = lfs.attributes(src_dir)
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
      -- }}}
      -- {{{ Assert relative paths
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

      if util.error_if(
         fs.is_absolute(obj_dir),
         "Object directory (" .. ansi.bright.yellow(obj_dir) .. ") is not relative"
      ) then
         return 1
      end
      -- }}}
      -- {{{ Setup Progress Bar
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
      -- }}}

      local function is_source_newer(source_path: string, target_path: string): boolean
         local retval = false
         if args.update_all then
            return true
         end
         local src_mod_time = lfs.attributes(source_path, "modification")
         local target_mod_time = lfs.attributes(target_path, "modification")
         if not target_mod_time then
            retval =  true
         end
         retval = retval or src_mod_time > target_mod_time
         if retval then
            log.verbose("Source file %s is newer than %s, recompiling...", ansi.bright.yellow(source_path), ansi.bright.yellow(target_path))
         end
         return retval
      end

      -- staged will make everything get type checked first, round-robin just lets stuff happen
      local scheduler = task.scheduler(flags.keep_going and "round-robin" or "staged")

      local function get_o(input: string): string
         return input:sub(1, -2) .. "o"
      end

      local update_so = false
      local exit = 0
      local total_steps = 0
      local fatal_err: string
      for input_file in fs.match(
         src_dir,
         options.include,
         options.exclude
      ) do
         if fs.get_extension(input_file) == "tl" and not input_file:match("%.d%.tl$") then
            -- {{{ tl
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
               scheduler.wrap(function()
                  draw_progress("Type checking", disp_file)

                  local res, err = util.teal.process(input_file, true)
                  if err then
                     exit = 1
                     local start, finish = err:lower():find("^%s*error:?%s*")
                     if finish then
                        err = err:sub(finish+1, -1)
                     end
                     log.error(err)
                     if not flags.keep_going then
                        fatal_err = err
                     end
                  end

                  b:step()
                  if err then return end
                  coroutine.yield()
                  if not args["pretend"] then
                     local fh = assert(io.open(output_file, "w"))
                     draw_progress("Writing", disp_output_file)
                     local ok = fh:write(util.teal.pretty_print_ast(res.ast as table))
                     assert(fh:close())
                     log.normal("Wrote %s", disp_output_file)
                  else
                     log.normal("Would write %s", disp_output_file)
                  end
                  b:step()
               end)
               total_steps = total_steps + 2
            end
            -- }}}
         end
      end

      for modname, moddata in pairs(c_modules) do
         -- TODO: maybe optimize this by only iterating over src_dir once
         -- and check each module to see if it includes the file?
         -- for now this is fine
         for input_file in fs.match(
            src_dir,
            moddata.include or {},
            moddata.exclude or {}
         ) do
            if fs.get_extension(input_file) == "c" then
               -- {{{ C
               -- for now just assume every file is going into one .so
               local output_file = get_o(input_file)

               if src_dir ~= "." then
                  output_file = output_file:sub(#src_dir + 2, -1)
               end
               if obj_dir ~= "." then
                  output_file = fs.path_concat(obj_dir, output_file)
               end

               moddata.source[input_file] = false
               if is_source_newer(input_file, output_file) then
                  moddata.source[input_file] = true
                  check_parents(output_file)
                  scheduler.wrap(function()
                     -- forcibly move these up a couple stages
                     coroutine.yield()
                     coroutine.yield()
                     draw_progress("Compiling", input_file)
                     local cmd = "cc -c " .. input_file .. " -o " .. output_file .. " 2>&1"
                     log.verbose("%s", ansi.bright.magenta(cmd))
                     local p <const> = io.popen(cmd)
                     local output <const> = p:read("*a")
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
               table.insert(moddata.o_files, output_file)
               -- }}}
            end
         end
      end

      local c_mod_scheduler = task.scheduler("round-robin")
      for name, mod in pairs(c_modules) do
         if should_recompile_c_module(mod) then
            total_steps = total_steps + 1
            c_mod_scheduler.wrap(function()
               local output_file = name .. "." .. fs.get_shared_library_ext()
               if src_dir ~= "." then
                  output_file = output_file:sub(#src_dir + 2, -1)
               end
               if build_dir ~= "." then
                  output_file = fs.path_concat(build_dir, output_file)
               end
               check_parents(output_file)
               draw_progress("Compiling", ansi.bright.yellow(output_file))
               local cmd <const> = "cc -fPIC -shared -o " .. output_file .. " " .. table.concat(mod.o_files, " ") .. " 2>&1"
               log.verbose("%s", ansi.bright.magenta(cmd))
               local p <const> = io.popen(cmd)
               local output <const> = p:read("*a")
               local exit_ok <const> = p:close()
               if not exit_ok then
                  log.error("Error compiling module %s:\nCommand run: %s\n\n%s", ansi.bright.green(output_file), cmd, output)
                  exit = 1
               else
                  log.normal("Compiled Module %s", ansi.bright.green(output_file))
               end
            end)
         end
      end

      if total_steps == 0 then
         log.normal("Nothing to build...")
         return 0
      end

      b:set_total_steps(total_steps)

      io.write("\n")

      scheduler.run()
      c_mod_scheduler.run()

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
            for k, v in pairs(t) do
               options as {string:any}[k] = v
            end
         end
      elseif opt == "cmodule" then
         return function(t: {string:any})
            -- TODO: There are probably some util functions to help with this
            if not t.name or type(t.name) ~= "string" then
               log.error("Name not provided for c module")
               return
            end
            if c_modules[t.name as string] then
               log.error("Module \"%s\" was already specified")
               return
            end
            if not (t.include or t.exclude) then
               log.error("Specify source files for c module \"%s\" with the \"include\" and \"exclude\" fields", t.name)
               return
            end
            local m: CModule = {
               include = {},
               exclude = {},
               source = {},
               o_files = {},
            }
            if t.include then
               for i, v in ipairs(t.include as {any}) do
                  if v is string then
                     table.insert(m.include, v)
                  else
                     log.warn("Non string entry in \"include\" field")
                  end
               end
            end
            if t.exclude then
               for i, v in ipairs(t.exclude as {any}) do
                  if v is string then
                     table.insert(m.exclude, v)
                  else
                     log.warn("Non string entry in \"exclude\" field")
                  end
               end
            end
            c_modules[t.name as string] = m
         end
      end
   end,
}

return build
