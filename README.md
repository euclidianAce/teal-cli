# teal-cli: an unofficial command line interface to the Teal compiler
[Teal is a typed dialect of Lua, get it here](https://github.com/teal-language/tl)

## Why use this over the official one?
 - This is an experimental attempt to make the interface a little more friendly looking (internally and externally)
 - Having the compiler separate from the cli means that it can be written in Teal itself a little more easily
 - Extensibility and some more conveniece features
 - Complies to freedesktop standards (the global config file goes to `$XDG_CONFIG_HOME/teal`)

## Extensibility
You can add your own commands to the cli by putting a .lua file that returns a specially formatted module (Docs coming eventually™) in `$XDG_CONFIG_HOME/teal/commands`. Additionally, some useful modules are exposed through the `tlcli` namespace. In particular `tlcli.fs`, `tlcli.util`, and `tlcli.loader` will probably be the most useful externally.

## Dependencies
 - Teal itself (along with its dependencies)
 - that's it (currently)

# Usage

No luarocks installation (yet), so currently this must be done manually.

1. clone this repo
2. navigate to the root directory and run `tl build` to compile (and run `busted` if you'd like to run the test suite)
3. add the `build` directory to your lua path, or copy it somewhere in your lua path
4. add the `bin` directory of this repo to your path, or copy the executable somewhere in your path
5. To see if it works, try running `tlc build` in the repo, it should build the project into a `tmp` dir it creates

## Current Commands
Currently the same as upstream `tl`.
 - `build`: Build a project according to a `tlcconfig.lua` file at the root of the project.
 - `check`: Type check one or more Teal scripts.
 - `gen`: Compile one or more Teal scripts (without type checking).
 - `run`: Run a Teal script.

## Config format
This is subject to change quite a bit because I am fickle ¯\\\_(ツ)\_/¯

Each command is allowed to expose one function to the config file. This function shares a name with the command.
All built in commands follow vaguely the same signature of `function(string): (function({string:any}) | function({string}))`

This type signature is illustrated more clearly by an example

```lua
build "options" {
	source_dir = "src",
	build_dir = "build",
}

build "flags" {
	"keep_going"
}
```

In short, the function signature takes advantage of Lua's syntactic sugar to make a nicer looking config file (at least imo).

## Config Options

Coming Eventually™

# Features
 - Colored output/fun ANSI stuffs
 - `build` can be run from anywhere within your project, not just the root
 - A pretty okay api
 - A (subjectively) better config format
 - listing dependencies in your `tlcconfig.lua` will add the appropriate paths to find type definitions, provided you have the [teal-types](https://github.com/teal-language/teal-types) repo installed in `$XDG_CONFIG_HOME/teal`, so instead of the current `include_dir` solution:
```lua
return {
	include_dir = {
		my_types_dir .. "/argparse",
		my_types_dir .. "/luafilesystem",
	}
}
```
you can do the following:
```lua
project "deps" {
	"argparse",
	"luafilesystem",
}
```
 -

## Planned Features
 - When building, modify the `package.path` so that your source_dir doesn't have to have the same name as your module
 - Integration with C tools, or at the very least, be able to specify C source and a C compiler when building
 - Tracking file changes for efficient `build`s like Make
 - Have a config option to point to the teal-types install location rather than force it to be in `$XDG_CONFIG_HOME/teal`
 - an `install` command and/or integration with luarocks' `install` command
 - better luarocks integration such as auto-generating rockspecs that install `.tl` files in the correct place
 - and more, but these become easier to implement the more mature `tl` itself becomes as a language.

# API documentation

Coming Eventually™

## Contributing

Contributions would be helpful, but most features that I want in this require fixes/changes in upstream `tl`, so consider helping there first.
