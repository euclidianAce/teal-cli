local types_dir = os.getenv"HOME" .. "/dev/teal-types/types/"
return {
   include_dir = {
      types_dir .. "inspect",
      types_dir .. "luafilesystem",
      types_dir .. "argparse",
   },
   source_dir = "tlcli",
   build_dir = "build/tlcli",
   skip_compat53 = true,
}
