SK = SK or {}
SK.Gargul = SK.Gargul or {}

local hooked = false
local wasMaster = false

local function lootIsMaster()
	if C_PartyInfo and C_PartyInfo.GetLootMethod and Enum and Enum.LootMethod then
		local ok, method = pcall(C_PartyInfo.GetLootMethod)
		if ok and method == Enum.LootMethod.Masterlooter then
			return true
		end
	end
	if GetLootMethod then
		return GetLootMethod() == "master"
	end
	return false
end

function SK.Gargul:Api()
	local GL = _G.Gargul
	if type(GL) ~= "table" or type(GL.RollOff) ~= "table" then
		return nil
	end
	return GL
end

function SK.Gargul:Loaded()
	if self:Api() then
		return true
	end
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Gargul") then
		return true
	end
	if IsAddOnLoaded and IsAddOnLoaded("Gargul") then
		return true
	end
	return false
end

function SK.Gargul:UseGargul()
	return self.engine == "gargul"
end

function SK.Gargul:HideForeignRoller()
	return self.engine == "skf"
end

function SK.Gargul:BlockGargulClicks()
	return self.engine == "skf" or self.asking and true or false
end

function SK.Gargul:ChoiceForRange(low, high)
	low = tonumber(low)
	high = tonumber(high)
	if not low or not high then
		return nil
	end
	local ranges = self.ranges
	if type(ranges) ~= "table" then
		return nil
	end
	for i = 1, #ranges do
		local row = ranges[i]
		if row.low == low and row.high == high then
			return row.choice
		end
	end
	return nil
end

local function choiceForBracket(row)
	if type(row) ~= "table" then
		return nil
	end
	local name = string.upper(SK.Trim(row[1]))
	local low = tonumber(row[2])
	local high = tonumber(row[3])
	if not low or not high then
		return nil
	end
	local choice
	if name == "MS" or name == "NEED" then
		choice = "MS"
	elseif name == "OS" or name == "GREED" or row[5] == true then
		choice = "OS"
	end
	if not choice then
		return nil
	end
	return { choice = choice, low = low, high = high }
end

function SK.Gargul:CaptureRanges()
	local GL = self:Api()
	self.ranges = {}
	if not GL or not GL.Settings or not GL.Settings.get then
		return
	end
	local brackets = GL.Settings:get("RollTracking.Brackets")
	if type(brackets) ~= "table" then
		return
	end
	if brackets[1] then
		local i = 1
		while brackets[i] do
			local mapped = choiceForBracket(brackets[i])
			if mapped then
				table.insert(self.ranges, mapped)
			end
			i = i + 1
		end
		return
	end
	for _, row in pairs(brackets) do
		local mapped = choiceForBracket(row)
		if mapped then
			table.insert(self.ranges, mapped)
		end
	end
end

function SK.Gargul:HideRoller()
	local GL = self:Api()
	if GL and GL.RollerUI and GL.RollerUI.hide and GL.RollerUI.Window then
		pcall(function()
			GL.RollerUI:hide()
		end)
	end
	local window = _G.GargulUI_RollerUI_Window
	if window and window.Hide then
		window:Hide()
	end
end

function SK.Gargul:Broadcast()
	if not self.engine or not SK.Sync or not SK.Sync.BroadcastLootEngine then
		return
	end
	if not SK.Session:IsMasterLooter() then
		return
	end
	SK.Sync:BroadcastLootEngine(self.engine)
end

function SK.Gargul:Choose(engine)
	if engine ~= "skf" and engine ~= "gargul" then
		return
	end
	self.engine = engine
	self.asking = false
	if SK.UI and SK.UI.HideGargulChoice then
		SK.UI.HideGargulChoice()
	end
	self:Broadcast()
	if engine == "skf" then
		self:HideRoller()
		SK.Print("Loot is running in Suicide Kings Forever.")
	else
		self:Stop()
		SK.Print("Loot is running in Gargul.")
	end
	if SK.Events then
		SK.Events:Fire("SK_SESSION", "engine")
	end
end

function SK.Gargul:ApplyRemote(engine)
	if engine ~= "skf" and engine ~= "gargul" then
		return
	end
	if SK.Session:IsOfficer() then
		return
	end
	self.engine = engine
	if engine == "skf" then
		self:HideRoller()
	elseif _G.SKFRaiderPopup then
		_G.SKFRaiderPopup:Hide()
	end
	if SK.Events then
		SK.Events:Fire("SK_SESSION", "engine")
	end
end

function SK.Gargul:Announce(live)
	if self.engine ~= "skf" or not SK.Session:IsMasterLooter() or not live then
		return
	end
	local GL = self:Api()
	if not GL or not GL.RollOff or not GL.RollOff.announceStart then
		return
	end
	local link = live.link or live.raw
	if type(link) ~= "string" or not string.find(link, "item:", 1, true) then
		SK.Print("Gargul did not open. This item has no item link.")
		return
	end
	local seconds = tonumber(live.duration) or 15
	if seconds < 5 then
		seconds = 5
	end
	self:CaptureRanges()
	local ok, started = pcall(function()
		return GL.RollOff:announceStart(link, seconds, nil)
	end)
	if not ok or started == false then
		SK.Print("Gargul did not open its roll window.")
		return
	end
	self.announced = true
end

function SK.Gargul:Stop()
	if not self.announced then
		return
	end
	self.announced = false
	local GL = self:Api()
	if not GL or not GL.RollOff or not GL.RollOff.announceStop then
		return
	end
	if not GL.RollOff.inProgress then
		return
	end
	if GL.RollOff.startedByMe and not GL.RollOff:startedByMe() then
		return
	end
	pcall(function()
		GL.RollOff:announceStop()
	end)
end

function SK.Gargul:Install()
	if hooked then
		return
	end
	local GL = self:Api()
	if not GL then
		return
	end
	hooked = true
	if type(hooksecurefunc) == "function" and type(GL.RollerUI) == "table" and type(GL.RollerUI.draw) == "function" then
		hooksecurefunc(GL.RollerUI, "draw", function()
			if SK.Gargul:HideForeignRoller() then
				local function hide()
					if SK.Gargul:HideForeignRoller() then
						SK.Gargul:HideRoller()
					end
				end
				if C_Timer and C_Timer.After then
					C_Timer.After(0, hide)
				else
					hide()
				end
				return
			end
			if SK.Session:IsOfficer() or SK.Gargul.engine == "skf" then
				return
			end
			if lootIsMaster() and SK.Gargul.engine ~= "gargul" then
				SK.Gargul.engine = "gargul"
				if _G.SKFRaiderPopup then
					_G.SKFRaiderPopup:Hide()
				end
			end
		end)
	end
	if type(GL.handleItemClick) == "function" then
		local original = GL.handleItemClick
		function GL:handleItemClick(...)
			if SK.Gargul:BlockGargulClicks() then
				return
			end
			return original(self, ...)
		end
	end
end

function SK.Gargul:Watch()
	self:Install()
	local master = SK.Session:IsMasterLooter()
	if not lootIsMaster() then
		if self.announced then
			self:Stop()
		end
		if self.engine or self.asking then
			self.engine = nil
			self.asking = false
			if SK.UI and SK.UI.HideGargulChoice then
				SK.UI.HideGargulChoice()
			end
		end
		wasMaster = false
		return
	end
	if master and not wasMaster then
		self.engine = nil
		self.announced = false
		if self:Loaded() then
			self.asking = true
			if SK.UI and SK.UI.ShowGargulChoice then
				SK.UI.ShowGargulChoice()
			end
		end
	elseif not master and wasMaster then
		self.engine = nil
		self.asking = false
		self.announced = false
		if SK.UI and SK.UI.HideGargulChoice then
			SK.UI.HideGargulChoice()
		end
	elseif master and self.asking and SK.UI and SK.UI.ShowGargulChoice then
		SK.UI.ShowGargulChoice()
	end
	wasMaster = master and true or false
end

SK.Events:On("SK_SESSION", function(reason)
	if reason == "start" or reason == "rolloff" then
		if reason == "start" and SK.Session:IsMasterLooter() and SK.Gargul:Loaded() and SK.Gargul.engine ~= "gargul" and (SK.Gargul.asking or not SK.Gargul.engine) then
			SK.Gargul:Choose("skf")
		end
		local live = SK.Session:Live()
		SK.Gargul:Announce(live)
	elseif reason == "close" or reason == "award" or reason == "cancel" or reason == "disenchant" then
		SK.Gargul:Stop()
	end
end)

SK.Events:On("ADDON_LOADED", function(name)
	if name == "Gargul" then
		SK.Gargul:Watch()
	end
end)

SK.Events:On("SK_READY", function()
	SK.Gargul:Watch()
end)

SK.Events:Register("GROUP_ROSTER_UPDATE", function()
	SK.Gargul:Watch()
end)

SK.Events:Register("PLAYER_ENTERING_WORLD", function()
	SK.Gargul:Watch()
end)

if SK.Events.frame and SK.Events.frame.RegisterEvent then
	pcall(SK.Events.frame.RegisterEvent, SK.Events.frame, "PARTY_LOOT_METHOD_CHANGED")
end
SK.Events:On("PARTY_LOOT_METHOD_CHANGED", function()
	SK.Gargul:Watch()
end)
