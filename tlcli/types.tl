
require("argparse")

local record M

   type GlobalConfig = record
      include_dir: {string}
      preload_modules: {string}
      quiet: boolean
      skip_compat53: boolean
      type_dir: {string}
   end

   type Config = record
      build_dir: string
      exclude: {string}
      files: {string}
      include: {string}
      include_dir: {string}
      preload_modules: {string}
      quiet: boolean
      skip_compat53: boolean
      source_dir: string
   end

   type Args = {string:{string}|string|boolean}
   type Command = record
      ---@param args   : the result from the argparser
      ---@param config : the local config
      ---@return       : the exit code
      type Callback = function(
         args: Args,
         config: Config
      ): number

      command: Callback
      -- Interface to add argparse command
      name: string
      description: string
      argparse: function(ArgparseParser.Command)

      config: function(string)
   end

end

return M
