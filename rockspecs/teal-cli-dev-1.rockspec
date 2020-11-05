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
   "ltreesitter >= 0.0.2",
}
build = {
   type = "builtin",
   modules = {
      ["tree-sitter-teal-parser"] = {
         sources = {
            "tree-sitter-teal/src/parser.c",
            "tree-sitter-teal/src/scanner.c",
         },
      },
      ["tlcli.ansi"] = "build/tlcli/ansi.lua",
      ["tlcli.builder"] = "build/tlcli/builder.lua",
      ["tlcli.cli"] = "build/tlcli/cli.lua",
      ["tlcli.commands.build"] = "build/tlcli/commands/build.lua",
      ["tlcli.commands.check"] = "build/tlcli/commands/check.lua",
      ["tlcli.commands.gen"] = "build/tlcli/commands/gen.lua",
      ["tlcli.commands.run"] = "build/tlcli/commands/run.lua",
      ["tlcli.fs"] = "build/tlcli/fs.lua",
      ["tlcli.loader"] = "build/tlcli/loader.lua",
      ["tlcli.log"] = "build/tlcli/log.lua",
      ["tlcli.runner"] = "build/tlcli/runner.lua",
      ["tlcli.task"] = "build/tlcli/task.lua",
      ["tlcli.types"] = "build/tlcli/types.lua",
      ["tlcli.ui.bar"] = "build/tlcli/ui/bar.lua",
      ["tlcli.ui.colorscheme"] = "build/tlcli/ui/colorscheme.lua",
      ["tlcli.util"] = "build/tlcli/util.lua",
   },
   install = {
      lua = {
         ["tlcli.ansi"] = "tlcli/ansi.tl",
         ["tlcli.builder"] = "tlcli/builder.tl",
         ["tlcli.cli"] = "tlcli/cli.tl",
         ["tlcli.commands.build"] = "tlcli/commands/build.tl",
         ["tlcli.commands.check"] = "tlcli/commands/check.tl",
         ["tlcli.commands.gen"] = "tlcli/commands/gen.tl",
         ["tlcli.commands.run"] = "tlcli/commands/run.tl",
         ["tlcli.fs"] = "tlcli/fs.tl",
         ["tlcli.loader"] = "tlcli/loader.tl",
         ["tlcli.log"] = "tlcli/log.tl",
         ["tlcli.runner"] = "tlcli/runner.tl",
         ["tlcli.task"] = "tlcli/task.tl",
         ["tlcli.types"] = "tlcli/types.tl",
         ["tlcli.ui.bar"] = "tlcli/ui/bar.tl",
         ["tlcli.ui.colorscheme"] = "tlcli/ui/colorscheme.tl",
         ["tlcli.util"] = "tlcli/util.tl",
      },
      bin = {
         "bin/tlc",
      }
   },
}
