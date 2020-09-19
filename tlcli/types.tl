
require("argparse")

local record M

   type Args = {string:{string}|string|boolean}
   type Command = record

      ---The main function of the command
      ---@param args   : the result from the argparser
      ---@return       : the exit code
      command: function(args: Args): number

      name: string
      description: string

      -- Interface to add argparse command
      argparse: function(ArgparseParser.Command)

      -- Interface to the config file
      config: function(string): function(any)
   end

end

return M
