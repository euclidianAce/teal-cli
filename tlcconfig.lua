
project "deps" {
   "argparse",
   "inspect",
   "luafilesystem"
}

build "build_dir"  "tmp/tlcli/build"
build "source_dir" "tlcli"
build "keep_going" (true)

check "keep_going" (true)


-- Maybe some sort of hybrid?

--[[
build "options" {
   keep_going = true
}

build "dir" {
   source = "tlcli",
   build = "build/tlcli",
}
--]]
