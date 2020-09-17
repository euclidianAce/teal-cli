
include_dir {
   os.getenv"HOME" .. "/dev/teal-types/types/argparse",
   os.getenv"HOME" .. "/dev/teal-types/types/inspect",
   os.getenv"HOME" .. "/dev/teal-types/types/luafilesystem",
}

check "keep_going"  ( true )

build "source_dir"    "tlcli"
build "build_dir"     "build"
build "exclude"     { "spec/**/*.lua" }
build "keep_going"  ( true )

