
require("argparse")

local record M

   type Args = {string:{string}|string|boolean}
   type Command = record

      ---The main function of the command
      ---@param args     : the result from the argparser
      ---@return number  : the exit code
      command: function(args: Args): number

      -- Interface to add argparse command
      name: string
      description: string
      argparse: function(ArgparseParser.Command)

      -- Interface to the config file
      config: function(string): function(any): any
   end

end

return M
