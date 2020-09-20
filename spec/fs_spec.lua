
local assert = require("luassert")

describe("tlcli.fs", function()
   local fs
   local sep
   local make_path = function(t)
      return table.concat(t, sep)
   end
   setup(function()
      fs = require("tlcli.fs")
      sep = fs.get_path_separator()
   end)
   describe("path_components", function()
      it("should be able to split a path string into its components", function()
         local comps = {"foo", "bar", "baz"}
         assert.are.same(comps, fs.get_path_components(make_path(comps)))
      end)
   end)
   describe("path_parents", function()
      it("should be an iterator that generates all but the last component of a path", function()
         local comps = {"foo", "bar", "baz"}
         local generated = {}
         for parent in fs.path_parents(make_path(comps)) do
            table.insert(generated, parent)
         end
         assert.are.same({
            "foo",
            make_path{"foo", "bar"}
         }, generated)
      end)
   end)
   describe("match", function()
      pending("should correctly iterate over a directory", function()
      end)
      pending("should correctly iterate over a directory with provided patterns", function()
      end)
   end)
   describe("is_in_dir", function()
      pending("should correctly report if a given path is in another given path", function()
      end)
   end)
   describe("find_project_root", function()
      pending("should find tlcconfig.lua in the current directory", function()
      end)
      pending("should find tlcconfig.lua in a parent directory", function()
      end)
      pending("should return the current directory when there is no tlcconfig.lua", function()
      end)
   end)
end)
