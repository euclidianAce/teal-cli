
local record TlcliCommand
   ---@param opts   : any additional options for the command
   ---@param ...    : the literal command line arguments (-options will be filtered out)
   ---@return       : the exit code
   command: function(opts: table, ...: string): number

   ---@param opts   : any additional options to be set from a tlconfig file
   config: function(opts: table)

   --- The default options for this command
   options: table
end

return TlcliCommand
