if not term then
	print("Not running in CraftOS.")
	return
end

if not currentUser then
	print("No current user found.")
	print("Setting user to 'user'.")
	currentUser = "user"
end

if not hostName then
	print("No host name set.")
	print("Setting host name to 'localhost'.")
	hostName = "localhost"
end

if not systemDirs then
	print("No system dirs found.")
	print("Setting default LMNet OS dirs to /.")
	systemDirs = {
		users = "/",
		root = "/",
		apps = "/",
		apis = "/",
	}
end

local parentShell = shell

local bExit = false
local sDir = (parentShell and parentShell.dir()) or ""
local sPath = (parentShell and parentShell.path()) or ".:/rom/programs"
local tAliases = (parentShell and parentShell.aliases()) or {}
local tProgramStack = {}

local shell = {}
local tEnv = {
	["shell"] = shell,
}
for i, v in pairs(_G) do
	if type(v) == "function" or type(v) == "string" or type(v) == "number" then
		tEnv[i] = v
	end
end

-- Colors
local promptColor, textColor, bgColor
if term.isColor() then
	promptColor = colors.yellow
	textColor = colors.white
	bgColor = colors.black
else
	promptColor = colors.white
	textColor = colors.white
	bgColor = colors.black
end


local function run( _sCommand, ... )
	local sPath = shell.resolveProgram( _sCommand )
	if sPath ~= nil then
		tProgramStack[#tProgramStack + 1] = sPath
   		local result = os.run( tEnv, sPath, ... )
		tProgramStack[#tProgramStack] = nil
		return result
   	else
    	printError( "No such program" )
    	return false
    end
end

local function runLine( _sLine )
	local tWords = {}
	for match in string.gmatch( _sLine, "[^ \t]+" ) do
		table.insert( tWords, match )
	end

	local sCommand = tWords[1]
	if sCommand then
		return run( sCommand, unpack( tWords, 2 ) )
	end
	return false
end

-- Install shell API
function shell.run( ... )
	return runLine( table.concat( { ... }, " " ) )
end

function shell.exit()
    bExit = true
end

function shell.dir()
	return sDir
end

function shell.setDir( _sDir )
	sDir = _sDir
end

function shell.path()
	return sPath
end

function shell.setPath( _sPath )
	sPath = _sPath
end

function shell.resolve( _sPath )
	local sStartChar = string.sub( _sPath, 1, 1 )
	if sStartChar == "/" or sStartChar == "\\" then
		return fs.combine( "", _sPath )
	else
		return fs.combine( sDir, _sPath )
	end
end

function shell.resolveProgram( _sCommand )
	-- Substitute aliases firsts
	if tAliases[ _sCommand ] ~= nil then
		_sCommand = tAliases[ _sCommand ]
	end

    -- If the path is a global path, use it directly
    local sStartChar = string.sub( _sCommand, 1, 1 )
    if sStartChar == "/" or sStartChar == "\\" then
    	local sPath = fs.combine( "", _sCommand )
    	if fs.exists( sPath ) and not fs.isDir( sPath ) then
			return sPath
    	end
		return nil
    end
    
 	-- Otherwise, look on the path variable
    for sPath in string.gmatch(sPath, "[^:]+") do
    	sPath = fs.combine( shell.resolve( sPath ), _sCommand )
    	if fs.exists( sPath ) and not fs.isDir( sPath ) then
			return sPath
    	end
    end
	
	-- Not found
	return nil
end

function shell.programs( _bIncludeHidden )
	local tItems = {}
	
	-- Add programs from the path
    for sPath in string.gmatch(sPath, "[^:]+") do
    	sPath = shell.resolve( sPath )
		if fs.isDir( sPath ) then
			local tList = fs.list( sPath )
			for n,sFile in pairs( tList ) do
				if not fs.isDir( fs.combine( sPath, sFile ) ) and
				   (_bIncludeHidden or string.sub( sFile, 1, 1 ) ~= ".") then
					tItems[ sFile ] = true
				end
			end
		end
    end	

	-- Sort and return
	local tItemList = {}
	for sItem, b in pairs( tItems ) do
		table.insert( tItemList, sItem )
	end
	table.sort( tItemList )
	return tItemList
end

function shell.getRunningProgram()
	if #tProgramStack > 0 then
		return tProgramStack[#tProgramStack]
	end
	return nil
end

function shell.setAlias( _sCommand, _sProgram )
	tAliases[ _sCommand ] = _sProgram
end

function shell.clearAlias( _sCommand )
	tAliases[ _sCommand ] = nil
end

function shell.aliases()
	-- Add aliases
	local tCopy = {}
	for sAlias, sCommand in pairs( tAliases ) do
		tCopy[sAlias] = sCommand
	end
	return tCopy
end
	
term.setBackgroundColor( bgColor )
term.setTextColor( promptColor )
print( os.version() )
term.setTextColor( textColor )

-- If this is the toplevel shell, run the startup programs
if parentShell == nil then
	-- Run the startup from the ROM first
	local sRomStartup = shell.resolveProgram( "/rom/startup" )
	if sRomStartup then
		shell.run( sRomStartup )
	end
	
	-- Then run the user created startup, from the disks or the root
	local sUserStartup = shell.resolveProgram( "/startup" )
	for n,sSide in pairs( peripheral.getNames() ) do
		if disk.isPresent( sSide ) and disk.hasData( sSide ) then
			local sDiskStartup = shell.resolveProgram( fs.combine(disk.getMountPath( sSide ), "startup") )
			if sDiskStartup then
				sUserStartup = sDiskStartup
				break
			end
		end
	end
	
	if sUserStartup then
		shell.run( sUserStartup )
	end
end

-- Run any programs passed in as arguments
local tArgs = { ... }
if tArgs[1] ~= nil then
	if tArgs[1] == "-e" then
		tEnv = _G
		table.remove(tArgs, 1)
	end
end
if #tArgs > 0 then
	shell.run( ... )
end

-- Read commands and execute them
local tCommandHistory = {}
while not bExit do
	term.setBackgroundColor( bgColor )
	term.setTextColor( promptColor )
	function iif(cond, trueval, falseval)
		if cond then
			return trueval
		else
			return falseval
		end
	end
	local dir = iif(shell.dir() == fs.combine(systemDirs.users, currentUser) or (shell.dir() == systemDirs.root and currentUser == "root"), "~", "/"..shell.dir())
	local w, h = term.getSize()
	if w < h then
		write( dir..iif(currentUser == "root", "#", "$").." " )
	else
		write( "["..currentUser.."@"..hostName.." "..dir.."]"..iif(currentUser == "root", "#", "$").." " )
	end
	term.setTextColor( textColor )

	local sLine = read( nil, tCommandHistory )
	table.insert( tCommandHistory, sLine )
	runLine( sLine )
end

-- If this is the toplevel shell, run the shutdown program
if parentShell == nil then
	if shell.resolveProgram( "shutdown" ) then
		shell.run( "shutdown" )
	end
	os.shutdown() -- just in case
end
