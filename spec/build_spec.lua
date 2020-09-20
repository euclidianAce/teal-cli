
local util = require("spec.util")

local proj = util.run_mock_project

describe("build command", function()
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
   it("should not compile things with type errors", function()
      proj(finally, {
         dir = {
            "a.tl",
            ["b.tl"] = "local x: string = 5",
            "tlcconfig.lua",
         },
         command = "build",
         pipe_result = util.exit_error,
         generated = {
            "a.lua",
         }
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
