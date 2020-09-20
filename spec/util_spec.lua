
local util = require("spec.util")
local assert = require("luassert")

describe("tlcli.util #api", function()
   local u
   setup(function()
      u = require("tlcli.util")
   end)
   describe("typecheckers", function()
      local str_check, num_check, table_check
      local arr_str, arr_num, arr_bool
      setup(function()
         str_check = u.typechecker "string"
         num_check = u.typechecker "number"
         table_check = u.typechecker "table"
         arr_str = u.array_typechecker "string"
         arr_num = u.array_typechecker "number"
         arr_bool = u.array_typechecker "boolean"
      end)
      describe("single-value", function()
         it("should return the same value when type is correct", function()
            assert.are.equal("hello", str_check "hello")
            assert.are.equal(10, num_check(10))
            local t = {}
            assert.are.equal(t, table_check(t))
         end)
         it("should return a falsy value when type is incorrect", function()
            assert.falsy(str_check(10))
            assert.falsy(str_check{})
            assert.falsy(str_check(false))

            assert.falsy(num_check("hello"))
            assert.falsy(num_check{})
            assert.falsy(num_check(false))

            assert.falsy(table_check(10))
            assert.falsy(table_check("hi"))
            assert.falsy(table_check(false))
         end)
      end)
      describe("array", function()
         it("should return the same value when type is correct", function()
            local t1 = {1, 2, 3, 4}
            assert.are.equal(t1, arr_num(t1))
            local t2 = {"hi", "hey", "woah"}
            assert.are.equal(t2, arr_str(t2))
            local t3 = {true, false, true}
            assert.are.equal(t3, arr_bool(t3))
         end)
         it("should return a falsy value when type is incorrect", function()
            assert.falsy(arr_num"hi")
            assert.falsy(arr_num(0))
            assert.falsy(arr_num{"a", "b"})
            assert.falsy(arr_num{1, 2, 3, 4, "a", "b"})

            assert.falsy(arr_str"hi")
            assert.falsy(arr_str(0))
            assert.falsy(arr_str{1, 2})
            assert.falsy(arr_str{1, 2, 3, 4, "a", "b"})

            assert.falsy(arr_bool"hi")
            assert.falsy(arr_bool(0))
            assert.falsy(arr_bool{1, 2})
            assert.falsy(arr_bool{1, 2, 3, 4, "a", "b"})
         end)
      end)
   end)
   describe("split", function()
      it("should iterate over chunks of a string separated by a delimiter", function()
         local chunks = {
            "this",
            "is",
            "my",
            "string"
         }
         local delimiter = " "
         local generated_chunks = {}
         for chunk in u.split(table.concat(chunks, delimiter), delimiter, true) do
            table.insert(generated_chunks, chunk)
         end
         assert.are.same(chunks, generated_chunks)
      end)
      it("should iterate over chunks of a string separated by a pattern delimiter", function()
         local chunks = {
            "this",
            "is",
            "another",
            "string",
         }
         local generated_chunks = {}
         for chunk in u.split("this)is@another>string", "%W") do
            table.insert(generated_chunks, chunk)
         end
         assert.are.same(chunks, generated_chunks)
      end)
   end)
   describe("wrap_with", function()
      it("should create an iterator", function()
         local values = {}
         for val in u.wrap_with(
            function(a)
               coroutine.yield(a)
               coroutine.yield(a:rep(2))
               coroutine.yield(a:rep(3))
            end, "a") do
            table.insert(values, val)
         end
         assert.are.same({"a", "aa", "aaa"}, values)
      end)
   end)
   describe("generate", function()
      it("should put all values produced in an array", function()
         local t = {"a", "b", "c"}
         local generator = string.gmatch("abc", ".")
         local res = u.generate(generator)
         assert.are.same(t, res)
      end)
   end)
   describe("protected_proxy", function()
      it("should call the error handler when an unknown index is accessed", function()
         local called = false
         local err_handler = function()
            called = true
         end
         local p = u.protected_proxy({}, err_handler)
         local _ = p[1]
         assert.truthy(called, "error handler wasn't called")
      end)
      it("should call the error handler when an unknown index is assigned", function()
         local called = false
         local err_handler = function()
            called = true
         end
         local p = u.protected_proxy({}, err_handler)
         p[1] = 1
         assert.truthy(called, "error handler wasn't called")
      end)
      it("should call the error handler when a known index is accessed", function()
         local called = false
         local err_handler = function()
            called = true
         end
         local p = u.protected_proxy({1}, err_handler)
         local _ = p[1]
         assert.falsy(called, "error handler was called")
      end)
      it("shouldn't call the error handler when a known index is assigned", function()
         local called = false
         local err_handler = function()
            called = true
         end
         local p = u.protected_proxy({2}, err_handler)
         p[1] = 1
         assert.falsy(called, "error handler was called")
      end)
   end)
end)
