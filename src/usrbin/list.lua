local tArgs = { ... }

local sDir = shell.dir()
if tArgs[1] ~= nil then
	local dir = tArgs[1]
	if dir:sub(1, 1) == "~" then
		dir = "/"..(currentUser == "root" and systemDirs.root or fs.combine(systemDirs.users, currentUser))..dir:sub(2)
	end
	sDir = shell.resolve( dir )
end

local tAll = fs.list( sDir )
local tFiles = {}
local tDirs = {}

for n, sItem in pairs( tAll ) do
	if string.sub( sItem, 1, 1 ) ~= "." then
		local sPath = fs.combine( sDir, sItem )
		if fs.isDir( sPath ) then
			table.insert( tDirs, sItem )
		else
			table.insert( tFiles, sItem )
		end
	end
end
table.sort( tDirs )
table.sort( tFiles )

if term.isColour() then
	textutils.pagedTabulate( colors.green, tDirs, colors.white, tFiles )
else
	textutils.pagedTabulate( tDirs, tFiles )
end