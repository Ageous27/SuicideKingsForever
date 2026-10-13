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

function SK.Settings:SetOpacity(alpha)
	alpha = tonumber(alpha) or 1
	if alpha < 0 then
		alpha = 0
	elseif alpha > 1 then
		alpha = 1
	end
	self:Get().opacity = alpha
end

function SK.Settings:Reset()
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	local settings = self:Get()
	settings.bidDrop = "last"
	settings.timer = 15
	settings.countdown = 5
	settings.disenchanter = ""
	settings.autoAdd = false
	settings.autoQuality = 2
	settings.opacity = 1
	if SK.UI and SK.UI.ResetLayout then
		SK.UI:ResetLayout()
	end
	SK.Events:Fire("SK_SETTINGS")
	return nil
end

function SK.Settings:ApplyRemote(drop, timer, countdown, disenchanter, autoAdd, autoQuality)
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
	SK.Events:Fire("SK_SETTINGS")
end
