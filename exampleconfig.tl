
build_dir "build/tlcli"
source_dir "tlcli"

include_dir {
      os.getenv"HOME" .. "/dev/teal-types/types/inspect",
      os.getenv"HOME" .. "/dev/teal-types/types/luafilesystem",
      os.getenv"HOME" .. "/dev/teal-types/types/argparse",
}

include { "**/*" }
exclude { "testing/**/*" }

