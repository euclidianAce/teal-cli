
include_dir {
	os.getenv"HOME" .. "/dev/teal-types/types/argparse",
	os.getenv"HOME" .. "/dev/teal-types/types/inspect",
	os.getenv"HOME" .. "/dev/teal-types/types/luafilesystem",
}

check {
	keep_going = true,
	--not_an_option = "hi"
}

--build {
	--source_dir = "src",
	--build_dir = "build",
	--include = { "" }
--}
