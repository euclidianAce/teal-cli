
local util = require("spec.util")

describe("run command", function()
   local proj = util.run_mock_project
   util.do_setup(setup, teardown)
   it("should run a simple .tl script", function()
      proj(finally, {
         dir = {
            ["script.tl"] = [[print("hi")]],
         },
         output = "hi\n",
         command = "run",
         args = {"script.tl"},
      })
   end)
   it("should pass the arguments after the script name into that script via `_G.arg`", function()
      proj(finally, {
         dir = {
            ["script.tl"] = [[for i, v in ipairs(arg) do io.write(v, "-") end]],
         },
         output = "a-2-C-",
         command = "run",
         args = {"script.tl", "a", "2", "C"},
      })
   end)
   it("should pass the arguments after the script name into that script via `...`", function()
      proj(finally, {
         dir = {
            ["script.tl"] = [[for i, v in ipairs{...} do io.write(v, "-") end]],
         },
         output = "a-2-C-",
         command = "run",
         args = {"script.tl", "a", "2", "C"},
      })
   end)
end)
