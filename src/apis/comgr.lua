local processList = {}
local exit = false
local noAutoExit = false
local removeCodes = {}
function setAutoExit(val)
	noAutoExit = not val
end
function forceExit()
	exit = true
end
function run()
	exit = false
	while (function()
		local rtn = false
		for i, co in ipairs(processList) do
			if coroutine.status(co) ~= "dead" then
				rtn = true
			end
		end
		return rtn
	end)() or noAutoExit do
		if exit then
			break
		end
		local event = {os.pullEventRaw()}
		for k, co in pairs(processList) do
			if coroutine.status(co) ~= "dead" then
				coroutine.resume(co, unpack(event))
			else
				processList[k] = nil
			end
		end
		for k, code in pairs(removeCodes) do
			processList[k] = nil
		end
	end
end
function addProcess(func)
	local co = coroutine.create(func)
	processList[code] = co
	return tostring(co)
end
function removeProcess(code)
	removeCodes[code] = true
end
