
local util = require("spec.util")

describe("gen command", function()
   local proj = util.run_mock_project
   util.do_setup(setup, teardown)
   it("should generate a properly named file #gen #command", function()
      proj(finally, {
         dir = {"my_file.tl"},
         generated = {"my_file.lua"},
         command = "gen",
         args = {"my_file.tl"},
      })
   end)
   it("should generate many files when provided with many arguments #gen #command", function()
      proj(finally, {
         dir = {
            "my_file.tl",
            "my_other_file.tl",
            "foo.tl",
            "yet_another_file.tl",
            "bar.tl",
         },
         generated = {
            "my_file.lua",
            "my_other_file.lua",
            "foo.lua",
            "yet_another_file.lua",
            "bar.lua",
         },
         command = "gen",
         args = {
            "my_file.tl",
            "my_other_file.tl",
            "foo.tl",
            "yet_another_file.tl",
            "bar.tl",
         },
      })
   end)
   describe("-o --output", function()
      it("should generate a properly named file #gen #command", function()
         proj(finally, {
            dir = {"my_file.tl"},
            generated = {"a_cool_name_for_a_file.lua"},
            command = "gen",
            args = {"my_file.tl --output a_cool_name_for_a_file.lua"},
         })
      end)
      it("should not work when given multiple files #gen #command", function()
         proj(finally, {
            dir = {
               "my_file.tl",
               "my_other_file.tl"
            },
            generated = {},
            command = "gen",
            args = {
               "my_file.tl",
               "my_other_file.tl",
               "--output a_cool_name_for_a_file.lua"
            },
            pipe_result = { nil, "exit", 1 },
         })
      end)
   end)
end)
