--[[
This file is part of commandLineArgumentsParser. It is subject to the licence terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/pallene-modules/commandLineArgumentsParser/master/COPYRIGHT. No part of commandLineArgumentsParser, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
Copyright © 2015 The developers of commandLineArgumentsParser. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/pallene-modules/commandLineArgumentsParser/master/COPYRIGHT.
]]--


local halimede = require('halimede')
local cliargs = require('cliargs')
local type = halimede.type
local assert = halimede.assert
local deepCopy = halimede.table.deepCopy
local FileHandleStream = halimede.io.FileHandleStream


local IbmPunchedCardStandardColumns = 80

local function terminalWidth(fileDescriptor)
	assert.parameterTypeIsNumber('fileDescriptor', fileDescriptor)
	
	local columnsUnparsed = halimede.getenv("COLUMNS")
	if columnsUnparsed ~= nil then
		local columns = tonumber(columnsUnparsed, 10)
		if columns ~= nil then
			-- Checks that Lua hasn't converted something it shouldn't (eg 0 prefixed, etc)
			if tostring(columns) == columnsUnparsed then
				-- upper bound is to guard against nonsense
				if columns > 0 and columns < 16384 then
					if halimede.math.isInteger(columns) then
						return columns
					end
				end
			end
		end
	end
	
	if halimede.packageConfiguration.isProbablyWindows() then
		return IbmPunchedCardStandardColumns
	end
	
	local columns = IbmPunchedCardStandardColumns
	type.useFfiIfPresent(function(ffi)
		local syscall = require('syscall')
		if syscall.isatty(fileDescriptor) then
			local winsize = syscall.ioctl(fileDescriptor, 'TIOCGWINSZ')
			columns = winsize.ws_col
		end
	end)
	
	return columns
end

local function setColumnWidths(commandLineArgumentsParser, fileHandleStream)
	-- So on a default 80-column display the width of options is 72, matching cliargs default
	local tabIndent = 8
	local columns = terminalWidth(fileHandleStream:fileDescriptor()) - tabIndent

	local keyColumnWidth
	local descriptionColumnWidth
	if columns <= 72 then
		keyColumnWidth = halimede.math.toInteger(columns * 0.25)
		descriptionColumnWidth = halimede.math.toInteger(columns * 0.75)
	else
		keyColumnWidth = 18
		descriptionColumnWidth = columns - keyColumnWidth
	end

	commandLineArgumentsParser:set_colsz(keyColumnWidth, descriptionColumnWidth)
end

local function createCommandLineArgumentsParser(module, description, ...)
	assert.parameterTypeIsString('description', description)
	
	local commands = {...}
	
	local ourName = module.name
	
	local commandLineArgumentsParser = deepCopy(cliargs)

	local originalParseFunction = cliargs.parse
	cliargs.parse = nil
	
	commandLineArgumentsParser.setColumnWidths = setColumnWidths
	
	function commandLineArgumentsParser:parseCommandLineExpectingCommandAndExit()
	
		local nilIsOkTableIsBad = self:parseCommandLine()
	
		local exitCode
		if nilIsOkTableIsBad == nil then
			exitCode = 0
		else
			local fileHandleStreamToUse = FileHandleStream.StandardError
			self:setColumnWidths(fileHandleStreamToUse)
			fileHandleStreamToUse:write('Error: Please supply a subcommand')
			fileHandleStreamToUse:writeNewLine()
			local helpMessage = self.printer.generate_help_and_usage()
			fileHandleStreamToUse:write(helpMessage)
			exitCode = 1
		end
		os.exit(exitCode)
	end

	function commandLineArgumentsParser:parseCommandLine()
		
		-- The original cliargs:parse() function creates the help message as part of the parse if -h or --help is specified
		-- We prepare for this by making sure the terminal width is set as for standard out
		self:setColumnWidths(FileHandleStream.StandardOut)
		
		local commandLineArguments, helpOrErrorMessage = originalParseFunction(self)
		if not commandLineArguments and helpOrErrorMessage then
		
			-- cliargs is a bit naff, and doesn't distinguish help from errors
			local fileHandleStreamToUse
			local helpMessage
			local exitCode
			if helpOrErrorMessage:startsWith("Usage: ") then
				fileHandleStreamToUse = FileHandleStream.StandardOut
				self:setColumnWidths(fileHandleStreamToUse)
				helpMessage = helpOrErrorMessage
				exitCode = 0
			else
				fileHandleStreamToUse = FileHandleStream.StandardError
				self:setColumnWidths(fileHandleStreamToUse)
				fileHandleStreamToUse:write(helpOrErrorMessage)
				fileHandleStreamToUse:writeNewLine()
				helpMessage = self.printer.generate_help_and_usage()
				exitCode = 1
			end
			fileHandleStreamToUse:writeAllContentsAndClose(helpMessage)
			os.exit(exitCode)
		end
		
		return commandLineArguments
	end
	
	commandLineArgumentsParser:set_name(ourName)
	commandLineArgumentsParser:set_description(description)

	local newline = halimede.packageConfiguration.newline
	
	commandLineArgumentsParser.printer.generate_help_and_usage = function()
		local self = commandLineArgumentsParser.printer
		
		local usage = {self.generate_usage()}
		if #commands ~= 0 then
			usage[#usage + 1] = ('Usage: %s COMMAND'):format(ourName)
		end
		usage[#usage + 1] = ('Usage: %s -h|--help'):format(ourName)
		if #commands ~= 0 then
			usage[#usage + 1] = ('Usage: %s COMMAND -h|--help'):format(ourName)
		end
		
		return table.concat(usage, newline) .. newline .. self.generate_help()
	end
	
	for _, command in ipairs(commands) do
		local commandCommandLineArgumentsParser = command(commandLineArgumentsParser)
		setColumnWidths(commandCommandLineArgumentsParser, FileHandleStream.StandardOut)
		commandCommandLineArgumentsParser.printer.generate_help_and_usage = function()
			local self = commandCommandLineArgumentsParser.printer
			
			local usage = {self.generate_usage()}
			-- .name includes prefix, eg 'ourName commandName'
			usage[#usage + 1] = ('Usage: %s -h|--help'):format(commandCommandLineArgumentsParser.name)
		
			return table.concat(usage, newline) .. newline .. self.generate_help()
		end
	end
	
	return commandLineArgumentsParser
end

halimede.modulefunction(createCommandLineArgumentsParser)
