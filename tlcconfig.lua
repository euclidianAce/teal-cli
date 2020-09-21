
project "deps" {
   "argparse",
   "inspect",
   "luafilesystem",
}

build "options" {
   build_dir = "tmp/build",
   source_dir = "tlcli",
}

build "flags" {
   "keep_going"
}

check "flags" {
   "keep_going"
}
