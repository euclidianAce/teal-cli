return {
   include_dir = {
      os.getenv"HOME" .. "/dev/teal-types/types/inspect",
      os.getenv"HOME" .. "/dev/teal-types/types/luafilesystem",
      os.getenv"HOME" .. "/dev/teal-types/types/argparse",
   },
   source_dir = "tlcli",
   build_dir = "build/tlcli",
}
