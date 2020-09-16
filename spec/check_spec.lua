
local util = require("spec.util")

describe("check command", function()
   it("should type check a single file", function()
      util.run_mock_project(finally, {
         dir = {
            ["blah.tl"] = [[local x: string = "hi"]],
         },
         expected = {},
         command = "check",
         opts = {},
         result = 0,
      })
   end)
   it("should type check multiple files when given", function()
      util.run_mock_project(finally, {
         dir = {
            ["blah.tl"] = [[local x: string = "hi"]],
            ["foo.tl"] = [[local x: string = "hi"]],
            ["bar.tl"] = [[local x: string = "hi"]],
            ["baz.tl"] = [[local x: string = "hi"]],
         },
         expected = {},
         command = "check",
         opts = {},
         args = {
            script = {
               "blah.tl",
               "foo.tl",
               "bar.tl",
               "baz.tl",
            }
         },
         result = 0,
      })
   end)
end)
