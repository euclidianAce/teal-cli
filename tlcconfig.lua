
include_dir {
	os.getenv"HOME" .. "/dev/teal-types/types/argparse",
	os.getenv"HOME" .. "/dev/teal-types/types/inspect",
	os.getenv"HOME" .. "/dev/teal-types/types/luafilesystem",
}

check {
	keep_going = true,
	not_an_option = "hi"
}

--include { "**/*" }

--exclude { "testing/**/*" }

--build_dir "build/tlcli"
--source_dir "tlcli"
