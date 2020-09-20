
local util = require("spec.util")

describe("check command", function()
   local proj = util.run_mock_project
   util.do_setup(setup, teardown)
   it("should type check a single file #check #command", function()
      proj(finally, {
         dir = {
            ["blah.tl"] = [[local x: string = "hi"]],
         },
         expected = {},
         command = "check",
         args = {"blah.tl"}
      })
   end)
   it("should type check multiple files when given #check #command", function()
      proj(finally, {
         dir = {
            ["blah.tl"] = [[local x: string = "hi"]],
            ["foo.tl"] = [[local x: string = "hi"]],
            ["bar.tl"] = [[local x: string = "hi"]],
            ["baz.tl"] = [[local x: string = "hi"]],
         },
         expected = {},
         command = "check",
         args = {"blah.tl", "foo.tl", "bar.tl", "baz.tl"},
      })
   end)
   it("should report type errors #check #command", function()
      proj(finally, {
         dir = {
            ["foo.tl"] = [[local x: number = "hi"]],
         },
         command = "check",
         expected = {},
         pipe_result = util.exit_error,
      })
   end)
end)
