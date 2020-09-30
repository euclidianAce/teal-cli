
local util = require("spec.util")

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
end)
