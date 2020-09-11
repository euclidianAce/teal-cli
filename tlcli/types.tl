
require("argparse")

local record M

   type Command = record
      ---@param opts   : any additional options for the command
      ---@param args   : the result from the argparser
      ---@param ...    : the literal command line arguments (-options will be filtered out)
      ---@return       : the exit code
      command: function(opts: table, args: table, ...: string): number

      -- Interface to add argparse command
      name: string
      description: string
      argparse: function(ArgparseParser.Command)

      ---@param opts   : any additional options to be set from a tlconfig file
      config: function(opts: table)

      --- The default options for this command
      options: table
   end

end

return M
