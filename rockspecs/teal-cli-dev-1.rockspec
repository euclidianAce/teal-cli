rockspec_format = "3.0"
package = "teal-cli"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/euclidianAce/teal-cli.git"
}
description = {
   summary = "An unofficial command line iterface to the Teal compiler.",
   detailed = [[An unofficial command line interface to the Teal compiler. Intended mostly as an integrated build system for the Teal language.]],
   homepage = "https://github.com/euclidianAce/teal-cli",
   license = "MIT"
}
dependencies = {
   "compat53",
   "argparse",
   "luafilesystem",
   "tl",
}
build = {
   type = "builtin",
   modules = {
      ["tlcli.commands.build"] = "build/tlcli/commands/build.lua",
      ["tlcli.commands.check"] = "build/tlcli/commands/check.lua",
      ["tlcli.commands.gen"] = "build/tlcli/commands/gen.lua",
      ["tlcli.commands.run"] = "build/tlcli/commands/run.lua",
      ["tlcli.ui.bar"] = "build/tlcli/ui/bar.lua",
      ["tlcli.ansi"] = "build/tlcli/ansi.lua",
      ["tlcli.cli"] = "build/tlcli/cli.lua",
      ["tlcli.fs"] = "build/tlcli/fs.lua",
      ["tlcli.loader"] = "build/tlcli/loader.lua",
      ["tlcli.log"] = "build/tlcli/log.lua",
      ["tlcli.types"] = "build/tlcli/types.lua",
      ["tlcli.util"] = "build/tlcli/util.lua",
   },
   install = {
      lua = {
         ["tlcli.commands.build"] = "tlcli/commands/build.tl",
         ["tlcli.commands.check"] = "tlcli/commands/check.tl",
         ["tlcli.commands.gen"] = "tlcli/commands/gen.tl",
         ["tlcli.commands.run"] = "tlcli/commands/run.tl",
         ["tlcli.ui.bar"] = "tlcli/ui/bar.tl",
         ["tlcli.ansi"] = "tlcli/ansi.tl",
         ["tlcli.cli"] = "tlcli/cli.tl",
         ["tlcli.fs"] = "tlcli/fs.tl",
         ["tlcli.loader"] = "tlcli/loader.tl",
         ["tlcli.log"] = "tlcli/log.tl",
         ["tlcli.types"] = "tlcli/types.tl",
         ["tlcli.util"] = "tlcli/util.tl",
      },
      bin = {
         "bin/tlc",
      }
   },
}
