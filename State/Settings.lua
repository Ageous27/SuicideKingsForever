SK = SK or {}
SK.Settings = SK.Settings or {}

function SK.Settings:Get()
	return SK.Saved:Settings()
end

function SK.Settings:BidDropLabel()
	local drop = self:Get().bidDrop
	if drop == "below" then
		return "immediately below the lowest other bidder"
	end
	return "last place"
end

function SK.Settings:SetBidDrop(mode)
	if not SK.Session:IsOfficer() then
		return
	end
	self:Get().bidDrop = mode == "below" and "below" or "last"
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:SetTimer(seconds)
	if not SK.Session:IsOfficer() then
		return
	end
	seconds = math.floor(tonumber(seconds) or 15)
	if seconds < 5 then
		seconds = 5
	elseif seconds > 120 then
		seconds = 120
	end
	self:Get().timer = seconds
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:SetCountdown(seconds)
	if not SK.Session:IsOfficer() then
		return
	end
	seconds = math.floor(tonumber(seconds) or 5)
	if seconds < 0 then
		seconds = 0
	elseif seconds > 30 then
		seconds = 30
	end
	self:Get().countdown = seconds
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:SetDisenchanter(name)
	if not SK.Session:IsOfficer() then
		return
	end
	name = SK.ShortName(name)
	self:Get().disenchanter = name or ""
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:SetAutoAdd(enabled)
	if not SK.Session:IsOfficer() then
		return
	end
	self:Get().autoAdd = enabled and true or false
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:SetAutoQuality(quality)
	if not SK.Session:IsOfficer() then
		return
	end
	quality = math.floor(tonumber(quality) or 2)
	if quality < 0 then
		quality = 0
	elseif quality > 5 then
		quality = 5
	end
	self:Get().autoQuality = quality
	SK.Events:Fire("SK_SETTINGS")
end

local STATUS_KEY = {
	["Bench"] = "bench",
	["Absent"] = "absent",
	["No-call/no-show"] = "nocall",
}

local function statusFallback(status)
	if status == "Bench" then
		return "raise", 1
	end
	if status == "No-call/no-show" then
		return "demote", 1
	end
	return "hold", 1
end

function SK.Settings:StatusRule(status)
	local key = STATUS_KEY[status]
	if not key then
		return nil, 0
	end
	local settings = self:Get()
	local mode = settings[key .. "Mode"]
	local steps = math.floor(tonumber(settings[key .. "Steps"]) or 1)
	if mode ~= "hold" and mode ~= "raise" and mode ~= "demote" then
		mode, steps = statusFallback(status)
	end
	if steps < 1 then
		steps = 1
	elseif steps > 20 then
		steps = 20
	end
	return mode, steps
end

function SK.Settings:SetStatusRule(status, mode, steps)
	if not SK.Session:IsOfficer() then
		return
	end
	local key = STATUS_KEY[status]
	if not key then
		return
	end
	if mode ~= "hold" and mode ~= "raise" and mode ~= "demote" then
		mode = statusFallback(status)
	end
	steps = math.floor(tonumber(steps) or 1)
	if steps < 1 then
		steps = 1
	elseif steps > 20 then
		steps = 20
	end
	local settings = self:Get()
	settings[key .. "Mode"] = mode
	settings[key .. "Steps"] = steps
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:PackStatusRules()
	local function one(status)
		local mode, steps = self:StatusRule(status)
		local flag = "r"
		if mode == "hold" then
			flag = "h"
		elseif mode == "demote" then
			flag = "d"
		end
		return flag .. tostring(steps)
	end
	return one("Bench") .. "." .. one("Absent") .. "." .. one("No-call/no-show")
end

function SK.Settings:ApplyStatusRules(text)
	if type(text) ~= "string" then
		return
	end
	local bench, absent, nocall = string.match(text, "^([rhd]%d+)%.([rhd]%d+)%.([rhd]%d+)$")
	if not bench then
		return
	end
	local function write(status, token)
		local flag = string.sub(token, 1, 1)
		local mode = "raise"
		if flag == "h" then
			mode = "hold"
		elseif flag == "d" then
			mode = "demote"
		end
		local key = STATUS_KEY[status]
		local steps = math.floor(tonumber(string.sub(token, 2)) or 1)
		if steps < 1 then
			steps = 1
		elseif steps > 20 then
			steps = 20
		end
		local settings = self:Get()
		settings[key .. "Mode"] = mode
		settings[key .. "Steps"] = steps
	end
	write("Bench", bench)
	write("Absent", absent)
	write("No-call/no-show", nocall)
end

function SK.Settings:AwaySeconds()
	local minutes = math.floor(tonumber(self:Get().awayMinutes) or 10)
	if minutes < 1 then
		minutes = 1
	elseif minutes > 120 then
		minutes = 120
	end
	return minutes * 60
end

function SK.Settings:SetAwayMinutes(minutes)
	if not SK.Session:IsOfficer() then
		return
	end
	minutes = math.floor(tonumber(minutes) or 10)
	if minutes < 1 then
		minutes = 1
	elseif minutes > 120 then
		minutes = 120
	end
	self:Get().awayMinutes = minutes
	SK.Events:Fire("SK_SETTINGS")
end

function SK.Settings:SetMinimapShown(shown)
	self:Get().minimapShown = shown and true or false
	if SK.Minimap and SK.Minimap.Apply then
		SK.Minimap:Apply()
	end
end

function SK.Settings:SetOpacity(alpha)
	alpha = tonumber(alpha) or 0.95
	if alpha < 0 then
		alpha = 0
	elseif alpha > 1 then
		alpha = 1
	end
	self:Get().opacity = alpha
end

function SK.Settings:Reset()
	local settings = self:Get()
	if SK.Session:IsOfficer() then
		settings.bidDrop = "last"
		settings.timer = 15
		settings.countdown = 5
		settings.disenchanter = ""
		settings.autoAdd = true
		settings.autoQuality = 2
		settings.benchMode = "raise"
		settings.benchSteps = 1
		settings.absentMode = "hold"
		settings.absentSteps = 1
		settings.nocallMode = "demote"
		settings.nocallSteps = 1
		settings.awayMinutes = 10
	end
	settings.opacity = 0.95
	settings.minimapShown = true
	if SK.UI and SK.UI.ResetLayout then
		SK.UI:ResetLayout()
	end
	if SK.Minimap and SK.Minimap.Apply then
		SK.Minimap:Apply()
	end
	SK.Events:Fire("SK_SETTINGS")
	return nil
end

function SK.Settings:ApplyRemote(drop, timer, countdown, disenchanter, autoAdd, autoQuality, statusRules, awayMinutes)
	if SK.Session:IsOfficer() then
		return
	end
	local settings = self:Get()
	settings.bidDrop = drop == "below" and "below" or "last"
	settings.timer = tonumber(timer) or settings.timer
	settings.countdown = tonumber(countdown) or settings.countdown
	if disenchanter ~= nil then
		settings.disenchanter = SK.ShortName(disenchanter)
	end
	if autoAdd ~= nil then
		settings.autoAdd = autoAdd == "1" or autoAdd == true
	end
	if autoQuality ~= nil then
		settings.autoQuality = tonumber(autoQuality) or settings.autoQuality or 2
	end
	if statusRules ~= nil then
		self:ApplyStatusRules(statusRules)
	end
	if awayMinutes ~= nil and awayMinutes ~= "" then
		local minutes = math.floor(tonumber(awayMinutes) or 10)
		if minutes < 1 then
			minutes = 1
		elseif minutes > 120 then
			minutes = 120
		end
		settings.awayMinutes = minutes
	end
	SK.Events:Fire("SK_SETTINGS")
end
