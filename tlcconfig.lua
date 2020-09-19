
project "deps" {
   "argparse",
   "inspect",
   "luafilesystem"
}

build "build_dir"  "build/tlcli"
build "source_dir" "tlcli"
build "keep_going" (true)

check "keep_going" (true)
