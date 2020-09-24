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

# Installation

## Luarocks
```
luarocks install --server=https://luarocks.org/dev teal-cli
```

## Manual

1. clone this repo
2. navigate to the root directory and run `tl build` to compile (and run `busted` if you'd like to run the test suite)
3. add the `build` directory to your lua path, or copy it somewhere in your lua path
4. add the `bin` directory of this repo to your path, or copy the executable somewhere in your path
5. To see if it works, try running `tlc build` in the repo, it should build the project into a `tmp` dir it creates

# Usage

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
This is intended to be a build system first and foremost. So most features are within the `build` command itself
 - `build`
 	- can be run from anywhere within your project, not just the root
	- only compiles when sources have changed, similar to Make and other build tools
	- your source directory doesn't have to be the same name as your module to compile, if you provide a table of the type `record source: string; name: string end` to `project "module"`, Teal will know how to search for your internal modules
	for example: if our project was laid out as such
	```
	src/
	   | thing.tl
	   | stuff.tl
	```
	and `thing.tl` had a `require("this_module.stuff")`, normal type checking wouldn't work, since by default, module searching can not be modified in such a way to accomodate this and Teal wouldn't find `this_module`, but if we specify in `tlcconfig.lua`:
	```lua
	project "module" {
	   source = "src",
	   name = "this_module",
	}
	build "options" {
	   source_dir = "src",
	   build_dir = "build",
	}
	```
	then it builds fine and is properly type checked.
	(Internally this is currently done with a tiny but non-harmful hack that can hopefully be implemented in upstream Teal)
 - Colored output/fun ANSI stuffs
 - A pretty okay api, with filesystem utilities
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
the eventual plan for this is to be able to autogenerate a rockspec file as well for luarocks dependencies

## Planned Features
 - Integration with C tools, or at the very least, be able to specify C source and a C compiler when building
 - Have a config option to point to the teal-types install location rather than force it to be in `$XDG_CONFIG_HOME/teal`
 - an `install` command and/or integration with luarocks' `install` command
 - better luarocks integration such as auto-generating rockspecs that install `.tl` files in the correct place
 - and more, but these become easier to implement the more mature `tl` itself becomes as a language.

# API documentation

Coming Eventually™

## Contributing

Contributing **requires** the dev version of `tl` itself. So make sure that's what you have before contributing. I try not to commit versions of `teal-cli` that can't build themselves, so if it can't, that could be a sign that you have an older version of `tl`.

Contributions would be helpful, but most features that I want in this require fixes/changes in upstream `tl`, so consider helping there first.
Some examples:
 - The biggest one (in general, not just for this project), is to expose the types of the teal compiler.
 	- Furthermore, being able to load a script _with a dynamically generated, but typed_ environment, would be a huge weight off the `util` module's responsibility
 - A way to interact with module loading so the `project "module"` feature doesn't have to be a hack
