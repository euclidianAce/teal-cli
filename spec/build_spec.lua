
local lfs = require("lfs")
local util = require("spec.util")

describe("build command", function()
   local starting_dir
   setup(function()
      starting_dir = lfs.currentdir()
      assert(lfs.chdir("/tmp"))
   end)
   teardown(function()
      assert(lfs.chdir(starting_dir))
   end)
   it("should compile everything by default", function()
      util.run_mock_project(finally, {
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
         config = {},
         opts = {},
         result = 0,
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
      util.run_mock_project(finally, {
         dir = {
            "thing.tl",
            "blah.tl",
         },
         command = "build",
         opts = {},
         result = 1,
         generated = {},
      })
   end)
   it("should only compile .tl files, not .lua or .d.tl files", function()
      util.run_mock_project(finally, {
         dir = {
            "thing.d.tl",
            "blah.lua",
            "tlcconfig.lua"
         },
         command = "build",
         opts = {},
         config = {},
         result = 0,
         generated = {},
      })
   end)
   it("should not compile things with type errors", function()
      util.run_mock_project(finally, {
         dir = {
            "a.tl",
            ["b.tl"] = "local x: string = 5",
            "tlcconfig.lua",
         },
         command = "build",
         opts = {},
         config = {},
         result = 1,
         generated = {
            "a.lua",
         }
      })
   end)
   describe("-p --pretend --dry-run", function()
      it("should not compile anything", function()
         util.run_mock_project(finally, {
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
            opts = {},
            args = {pretend = true},
            config = {},
            result = 0,
            generated = {},
         })
      end)
   end)
end)
