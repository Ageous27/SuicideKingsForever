SK = SK or {}
SK.Debug = SK.Debug or {}

SK.Debug.on = false
SK.Debug.lines = {}
SK.Debug.filePath = nil
SK.Debug.fileError = nil

local MAX_LINES = 400
local PATHS = {
	"C:\\Games\\World of Warcraft\\_classic_beta_\\Logs\\SuicideKingsForever.log",
	"Logs\\SuicideKingsForever.log",
	"C:\\Users\\User\\Projects\\SuicideKingsForever\\debug.log",
}

local function trim(list)
	while #list > MAX_LINES do
		table.remove(list, 1)
	end
end

function SK.Debug:WriteFile()
	local body = table.concat(self.lines, "\n")
	if body ~= "" then
		body = body .. "\n"
	end
	if type(io) ~= "table" or type(io.open) ~= "function" then
		self.fileError = "io library is not available"
		return false
	end
	local lastErr = "no path"
	for i = 1, #PATHS do
		local path = PATHS[i]
		local ok, err = pcall(function()
			local handle = io.open(path, "w")
			if not handle then
				error("open failed")
			end
			handle:write(body)
			handle:close()
		end)
		if ok then
			self.filePath = path
			self.fileError = nil
			return true
		end
		lastErr = tostring(err)
	end
	self.fileError = lastErr
	return false
end

function SK.Debug:AttachSaved()
	local prior = {}
	if type(SKDB) == "table" and type(SKDB.debugLog) == "table" then
		for i = 1, #SKDB.debugLog do
			prior[#prior + 1] = SKDB.debugLog[i]
		end
	end
	for i = 1, #self.lines do
		prior[#prior + 1] = self.lines[i]
	end
	trim(prior)
	self.lines = prior
	if type(SKDB) == "table" then
		SKDB.debugLog = prior
	end
	self:WriteFile()
end

function SK.Debug:Line(module, event, detail)
	local stamp = date and date("%Y-%m-%d %H:%M:%S") or ""
	local text = string.format("%s %s %s %s", stamp, tostring(module), tostring(event), tostring(detail or ""))
	table.insert(self.lines, text)
	trim(self.lines)
	if type(SKDB) == "table" then
		SKDB.debugLog = self.lines
	end
	if self.on then
		SK.Print(text)
	end
	self:WriteFile()
end

function SK.Debug:Dump()
	if #self.lines == 0 then
		SK.Print("debug log is empty")
		return
	end
	local startAt = math.max(1, #self.lines - 40)
	for i = startAt, #self.lines do
		SK.Print(self.lines[i])
	end
end

function SK.Debug:Status()
	if self.filePath then
		return "log file " .. self.filePath
	end
	local why = self.fileError or "not written yet"
	return "log file unavailable (" .. why .. "). Lines are in SKDB.debugLog and flush to SavedVariables on /reload."
end
