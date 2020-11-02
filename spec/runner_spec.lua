local util = require("spec.util")

describe("tlcli.runner", function()
   local runner
   setup(function()
      runner = require("tlcli.runner")
   end)
   it("should run a simple function", function()
      assert(runner.wrap(function() end):run())
   end)
   it("should catch errors in the given function", function()
      local script = runner.wrap(function()
         error("Hello")
      end)
      script:run()
      assert.match("Hello", script.err)
   end)
end)

