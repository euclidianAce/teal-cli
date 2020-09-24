
local util = require("spec.util")

local proj = util.run_mock_project

describe("#project #config", function()
   util.do_setup(setup, teardown)
   describe("module: {string:string}", function()
      it("should allow for internal requires to be type checked", function()
         proj(finally, {
            dir = {
               ["tlcconfig.lua"] = [[
                  project "module" {
                     name = "this_module",
                     source = "src"
                  }
                  build "options" {
                     source_dir = "src",
                     build_dir = "build"
                  }
               ]],
               src = {
                  ["a.tl"] = [[  local b = require("this_module.b"); b.do_thing()  ]],
                  ["b.tl"] = [[  return { do_thing = function() print("hi") end }  ]],
               },
            },
            generated = {
               build = {
                  "a.lua",
                  "b.lua",
               }
            },
            command = "build",
         })
      end)
   end)
   describe("deps: {string}", function()
      pending("should bring in types from teal-types (provided it's in the correct path)", function()
         proj(finally, {})
      end)
   end)
end)
