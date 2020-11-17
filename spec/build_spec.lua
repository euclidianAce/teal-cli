
local assert = require("luassert")
local util = require("spec.util")
local lfs = require("lfs")

local proj = util.run_mock_project

describe("#build #command", function()
   util.do_setup(setup, teardown)
   it("should compile everything by default", function()
      proj(finally, {
         dir = {
            "tlcconfig.lua",
            "thing.tl",
            "blah.tl",
            foo = {
               "bar.tl",
               "baz.tl",
               aaa = {
                  "bbb.tl"
               },
            },
         },
         command = "build",
         generated = {
            "thing.lua",
            "blah.lua",
            foo = {
               "bar.lua",
               "baz.lua",
               aaa = {
                  "bbb.lua",
               },
            },
         },
      })
   end)
   it("should not compile when there is no config file", function()
      proj(finally, {
         dir = {
            "thing.tl",
            "blah.tl",
         },
         command = "build",
         pipe_result = util.exit_error,
         generated = {},
      })
   end)
   it("should only compile .tl files, not .lua or .d.tl files", function()
      proj(finally, {
         dir = {
            "thing.d.tl",
            "blah.lua",
            "tlcconfig.lua"
         },
         command = "build",
         generated = {},
      })
   end)
   describe("--keep-going option", function()
      it("should not compile things with type errors", function()
         proj(finally, {
            dir = {
               "a.tl",
               ["b.tl"] = "local x: string = 5",
               ["tlcconfig.lua"] = [[build "flags" { "keep_going" }]],
            },
            command = "build",
            pipe_result = util.exit_error,
            generated = { "a.lua", },
            output_match = "Error",
         })
      end)
   end)
   it("should not do anything when provided non-relative paths", function()
      proj(finally, {
         dir = {
            ["tlcconfig.lua"] = [[build "options" { build_dir = "/usr/bin/my_cool_application" }]],
         },
         command = "build",
         pipe_result = util.exit_error,
         generated = {},
         output_match = "is not relative\n$",
      })
   end)
   it("should error out when source_dir doesn't exist", function()
      proj(finally, {
         dir = {
            ["tlcconfig.lua"] = [[build "options" { source_dir = "a/directory/that/doesn't/exist" }]],
         },
         command = "build",
         pipe_result = util.exit_error,
         generated = {},
         output_match = "Unable to access source dir \"a/directory/that/doesn't/exist\"\n.*No such file or directory",
      })
   end)
   describe("-p --pretend --dry-run", function()
      it("should not compile anything", function()
         proj(finally, {
            dir = {
               "a.tl",
               "b.tl",
               "c.tl",
               "d.tl",
               "e.tl",
               "f.tl",
               "g.tl",
               "tlcconfig.lua",
            },
            command = "build",
            args = {"-p"},
            generated = {},
         })
      end)
   end)
   describe("modules", function()
      it("should be able to correctly resolve requires", function()
         proj(finally, {
            dir = {
               src = {
                  ["foo.tl"] = [[ require("my_module.bar") ]],
                  "bar.tl",
               },
               ["tlcconfig.lua"] = [[
                  project "module" {
                     source = "src",
                     name = "my_module"
                  }
               ]],
            },
            command = "build",
            generated = {
               src = {
                  "foo.lua",
                  "bar.lua",
               },
            },
         })
      end)
      pending("should correctly resolve dependencies for incremental rebuilds", function()
         -- TODO: this seems to work when done manually, but touching the file inside the test seems to not actually work
         local current_dir = lfs.currentdir()
         local dir_name = util.create_dir(finally, {
            src = {
               ["foo.tl"] = [[ require("my_module.bar") ]],
               ["bar.tl"] = [[ return {} ]],
            },
            ["tlcconfig.lua"] = [[
            build "options" {
               source_dir = "src",
               build_dir = "build",
            }
            project "module" {
               source = "src",
               name = "my_module"
            }]],
         })
         assert(lfs.chdir(dir_name))
         local first_result = util.run_command("build", "--no-bar")
         -- TODO: do this in a more portable way
         os.execute("touch " .. dir_name .. "/src/bar.tl")
         print("touching: ", dir_name .. "/src/bar.tl")
         local second_result = util.run_command("build", "--no-bar")
         assert(lfs.chdir(current_dir))

         print(require"inspect"(first_result))
         print(require"inspect"(second_result))
         assert(first_result.output:match("build/foo.lua"))
         assert(first_result.output:match("build/bar.lua"))

         assert(not second_result.output:match("up to date"), "all files were 'up to date'")
      end)
   end)
   pending("cmodule config", function()
      it("should compile a c module into a .so/.dll file", function()
         proj(finally, {
            dir = {
               "a.c",
               "b.c",
               "c.c",
               ["tlcconfig.lua"] = [[build "cmodule" {name = "my_module", include = {"a.c", "b.c", "c.c"}}]],
            },
            command = "build",
            args = {},
            generated = {
               "a.o",
               "b.o",
               "c.o",
               "my_module.so", -- TODO: tests should probably pass on windows
            },
         })
      end)
      it("should report errors in C files", function()
         proj(finally, {
            dir = {
               ["a.c"] = "#error hi",
               ["tlcconfig.lua"] = [[build "cmodule" {name = "my_module", include = {"a.c"}}]],
            },
            command = "build",
            pipe_result = util.exit_error,
            args = {},
            generated = {},
         })
      end)
      it("shouldn't compile a module if .c file has an error", function()
         proj(finally, {
            dir = {
               "b.c",
               ["a.c"] = "#error hi",
               ["tlcconfig.lua"] = [[
                  build "cmodule" {
                     name = "my_module",
                     include = {
                        "a.c",
                        "b.c",
                     }
                  }
                  build "flags" { "keep_going" }
               ]],
            },
            command = "build",
            pipe_result = util.exit_error,
            args = {},
            generated = { "b.o" },
         })
      end)
      it("should compile multiple C modules", function()
         proj(finally, {
            dir = {
               "a.c",
               "b.c",
               "c.c",
               ["tlcconfig.lua"] = [[
                  build "cmodule" {
                     name = "a",
                     include = { "a.c" }
                  }
                  build "cmodule" {
                     name = "b",
                     include = { "b.c" }
                  }
                  build "cmodule" {
                     name = "c",
                     include = { "c.c" }
                  }
                  build "flags" { "keep_going" }
               ]],
            },
            command = "build",
            pipe_result = util.exit_ok,
            args = {},
            generated = {
               "a.o",
               "b.o",
               "c.o",
               "a.so",
               "b.so",
               "c.so",
            },
         })
      end)
      it("should put C modules in build_dir", function()
         proj(finally, {
            dir = {
               "a.c",
               "b.c",
               "c.c",
               ["tlcconfig.lua"] = [[
                  build "cmodule" {
                     name = "my_module",
                     include = {
                        "a.c",
                        "b.c",
                        "c.c",
                     }
                  }
                  build "flags" { "keep_going" }
                  build "options" {
                     build_dir = "build"
                  }
               ]],
            },
            generated = {
               "a.o",
               "b.o",
               "c.o",
               build = {
                  "my_module.so"
               },
            },
            command = "build",
            pipe_result = util.exit_ok,
         })
      end)
   end)
end)
