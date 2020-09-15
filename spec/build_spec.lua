
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
end)
