
local lfs = require("lfs")
local util = require("spec.util")
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
      it("should be able to split a path string into its components #fs #api", function()
         local comps = {"foo", "bar", "baz"}
         assert.are.same(comps, fs.get_path_components(make_path(comps)))
      end)
   end)
   describe("path_parents", function()
      it("should be an iterator that generates all but the last component of a path #fs #api", function()
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
   describe("dir", function()
      it("should correctly iterate over a directory #fs #api", function()
         local struct = {
            "foo",
            "bar",
            "baz",
         }
         table.sort(struct)

         local dir_name = util.create_dir(finally, struct)
         local dir_paths = {}
         for path in fs.dir(dir_name) do
            table.insert(dir_paths, path)
         end
         table.sort(dir_paths)

         for i, v in ipairs(struct) do
            struct[i] = make_path{dir_name, v}
         end
         assert.are.same(struct, dir_paths)
      end)
      it("should correctly iterate over nested directories #fs #api", function()
         local struct = {
            foo = {
               "bar",
               baz = {
                  "foo",
                  "bar",
                  "baz",
               },
            },
            "bar",
            "baz",
         }

         local dir_name = util.create_dir(finally, struct)
         local dir_paths = {}
         for path in fs.dir(dir_name) do
            table.insert(dir_paths, path)
         end
         table.sort(dir_paths)

         local expected_paths = util.structure_to_paths(struct, dir_name)
         table.sort(expected_paths)
         assert.are.same(expected_paths, dir_paths)
      end)
   end)
   describe("match", function()
      it("should correctly iterate over a directory with provided patterns #fs #api", function()
         local struct = {
            "foo.tl",
            "bar.tl",
            "baz.tl",
         }
         table.sort(struct)

         local dir_name = util.create_dir(finally, struct)
         local dir_paths = {}
         local cwd = lfs.currentdir()
         assert(lfs.chdir(dir_name))
         for path in fs.match(".", {"b*.tl"}) do
            table.insert(dir_paths, path)
         end
         assert(lfs.chdir(cwd))
         table.sort(dir_paths)

         local expected = {"bar.tl", "baz.tl"}
         table.sort(expected)
         assert.are.same(expected, dir_paths)
      end)
   end)
   describe("is_in_dir", function()
      it("should correctly report if a given directory contains another file #fs #api", function()
         local dir_name = util.create_dir(finally, {
            "hello"
         })
         assert(fs.is_in_dir(
            dir_name,
            make_path{dir_name, "hello"}
         ))
      end)
      it("should correctly report if a given directory doesn't contain another file #fs #api", function()
         local dir_name = util.create_dir(finally, {
            "hi"
         })
         assert(not fs.is_in_dir(
            dir_name,
            make_path{dir_name, "hello"}
         ))
      end)
   end)
   describe("find_project_root", function()
      it("should find tlcconfig.lua in the current directory #fs #api", function()
         local dir_name = util.create_dir(finally, {
            "tlcconfig.lua"
         })

         local cwd = lfs.currentdir()
         assert(lfs.chdir(dir_name))

         local found_path = fs.find_project_root()

         assert(lfs.chdir(cwd))
         assert.are.equal(dir_name, found_path)
      end)
      it("should find tlcconfig.lua in a parent directory #fs #api", function()
         local dir_name = util.create_dir(finally, {
            "tlcconfig.lua",
            working_dir = {
               "foo",
            }
         })

         local cwd = lfs.currentdir()
         assert(lfs.chdir(make_path{dir_name, "working_dir"}))

         local found_path = fs.find_project_root()

         assert(lfs.chdir(cwd))
         assert.are.equal(dir_name, found_path, "Expected found_path to be " .. dir_name .. ", got " .. found_path)
      end)
      it("should return the current directory when there is no tlcconfig.lua #fs #api", function()
         local dir_name = util.create_dir(finally, {
            "stuff",
            "things"
         })

         local cwd = lfs.currentdir()
         assert(lfs.chdir(dir_name))

         local found_path = fs.find_project_root()

         assert(lfs.chdir(cwd))
         assert.are.equal(dir_name, found_path)
      end)
   end)
end)
