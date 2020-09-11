
require("argparse")

local record M

   type Args = {string:{string}|string|boolean}
   type Command = record
      ---@param opts   : any additional options for the command provided by the options table
      ---@param args   : the result from the argparser
      ---@return       : the exit code
      type Callback = function(
         args: Args
      ): number

      command: Callback
      -- Interface to add argparse command
      name: string
      description: string
      argparse: function(ArgparseParser.Command)

      ---@param opts   : any additional options to be set from a tlconfig file
      config: function(opts:table)

      --- The default options for this command
      options: table
   end

end

return M
