local frame = SK.UI:CreateWindow("settings", "Settings")
frame:SetSize(520, 640)
local body = frame.body

local dropLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dropLabel:SetPoint("TOPLEFT", 4, -8)
dropLabel:SetText("Bid drop")

local lastBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
lastBtn:SetSize(120, 22)
lastBtn:SetPoint("TOPLEFT", 4, -32)
lastBtn:SetText("Last place")

local belowBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
belowBtn:SetSize(220, 22)
belowBtn:SetPoint("LEFT", lastBtn, "RIGHT", 8, 0)
belowBtn:SetText("Below lowest bidder")

local timerLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
timerLabel:SetPoint("TOPLEFT", 4, -72)
timerLabel:SetText("Roll timer seconds")

local timerBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
timerBox:SetSize(60, 20)
timerBox:SetPoint("TOPLEFT", 160, -70)
timerBox:SetAutoFocus(false)
timerBox:SetNumeric(true)
timerBox:SetMaxLetters(3)

local countLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
countLabel:SetPoint("TOPLEFT", 4, -104)
countLabel:SetText("Countdown seconds")

local countBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
countBox:SetSize(60, 20)
countBox:SetPoint("TOPLEFT", 160, -102)
countBox:SetAutoFocus(false)
countBox:SetNumeric(true)
countBox:SetMaxLetters(2)

local note = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("TOPLEFT", 4, -140)
note:SetPoint("RIGHT", -8, 0)
note:SetJustifyH("LEFT")
note:SetJustifyV("TOP")
note:SetText("Start reads the timer. Award reads bid drop. Changing the timer leaves an item that is already live on the timer it started with. Disenchant sends the item to the assigned disenchanter.")

local deLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
deLabel:SetPoint("TOPLEFT", 4, -176)
deLabel:SetText("Disenchanter")

local deBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
deBtn:SetSize(180, 22)
deBtn:SetPoint("TOPLEFT", 160, -172)
deBtn:SetText("None")

local autoCheck = CreateFrame("CheckButton", nil, body)
autoCheck:SetSize(24, 24)
autoCheck:SetPoint("TOPLEFT", 0, -208)
autoCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
autoCheck:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
autoCheck:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
autoCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

local autoLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
autoLabel:SetPoint("LEFT", autoCheck, "RIGHT", 2, 0)
autoLabel:SetText("Auto add items when master looter")

local qualLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
qualLabel:SetPoint("TOPLEFT", 4, -246)
qualLabel:SetText("Auto add quality")

local qualBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
qualBtn:SetSize(180, 22)
qualBtn:SetPoint("TOPLEFT", 160, -242)
qualBtn:SetText("Uncommon")

local opacityLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
opacityLabel:SetPoint("TOPLEFT", 4, -286)
opacityLabel:SetText("Background opacity")

local opacityValue = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
opacityValue:SetPoint("TOPLEFT", 400, -286)
opacityValue:SetText("100%")

local opacitySlider = CreateFrame("Slider", nil, body)
opacitySlider:SetPoint("TOPLEFT", 160, -282)
opacitySlider:SetSize(220, 16)
opacitySlider:SetOrientation("HORIZONTAL")
opacitySlider:SetMinMaxValues(0, 100)
opacitySlider:SetValueStep(5)
opacitySlider:SetValue(100)
if opacitySlider.SetObeyStepOnDrag then
	opacitySlider:SetObeyStepOnDrag(true)
end
opacitySlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
local opacityTrack = opacitySlider:CreateTexture(nil, "BACKGROUND")
opacityTrack:SetColorTexture(0.25, 0.2, 0.1, 0.9)
opacityTrack:SetHeight(4)
opacityTrack:SetPoint("LEFT", 2, 0)
opacityTrack:SetPoint("RIGHT", -2, 0)

local resetBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
resetBtn:SetSize(200, 22)
resetBtn:SetPoint("TOPLEFT", 4, -324)
resetBtn:SetText("Reset all settings")

local clearListBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
clearListBtn:SetSize(140, 22)
clearListBtn:SetPoint("TOPLEFT", 4, -360)
clearListBtn:SetText("Clear list")

local clearHistBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
clearHistBtn:SetSize(140, 22)
clearHistBtn:SetPoint("LEFT", clearListBtn, "RIGHT", 8, 0)
clearHistBtn:SetText("Clear history")

local foot = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
foot:SetPoint("TOPLEFT", 4, -392)
foot:SetPoint("RIGHT", -8, 0)
foot:SetJustifyH("LEFT")
foot:SetText("Reset restores settings and window positions. It leaves the list and history. Clear history only clears this character.")

local QUALITY = {
	[0] = "Poor",
	[1] = "Common",
	[2] = "Uncommon",
	[3] = "Rare",
	[4] = "Epic",
	[5] = "Legendary",
}

local menu

local function hideMenu()
	if menu then
		menu:Hide()
	end
end

local function ensureMenu()
	if menu then
		return menu
	end
	menu = CreateFrame("Frame", "SKFSettingsMenu", UIParent, "BackdropTemplate")
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	menu.buttons = {}
	menu:SetScript("OnUpdate", function(self)
		if not self:IsShown() then
			return
		end
		local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
		if down then
			if not self.down then
				self.down = true
				if not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then
					self:Hide()
				end
			end
		else
			self.down = false
		end
	end)
	menu:Hide()
	return menu
end

local function openMenu(anchor, labels, onPick)
	local popup = ensureMenu()
	if popup:IsShown() and popup.anchor == anchor then
		popup:Hide()
		return
	end
	local width = math.max(anchor:GetWidth() or 160, 160)
	for i = 1, #labels do
		local button = popup.buttons[i]
		if not button then
			button = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
			popup.buttons[i] = button
		end
		button:SetSize(width, 20)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 22)
		local label = labels[i]
		button:SetText(label)
		button:SetScript("OnClick", function()
			popup:Hide()
			onPick(label, i)
		end)
		button:Show()
	end
	for i = #labels + 1, #popup.buttons do
		popup.buttons[i]:Hide()
	end
	local full = 16 + #labels * 22
	local height = full
	if height > 280 then
		height = 280
	end
	popup:SetSize(width + 16, height)
	popup.count = #labels
	popup.menuWidth = width
	popup.scroll = 0
	popup.maxScroll = math.max(0, full - height)
	if popup.SetClipsChildren then
		popup:SetClipsChildren(true)
	end
	popup.anchor = anchor
	popup.down = true
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	popup:EnableMouseWheel(true)
	popup:SetScript("OnMouseWheel", function(self, delta)
		local nextScroll = self.scroll - delta * 22
		if nextScroll < 0 then
			nextScroll = 0
		elseif nextScroll > self.maxScroll then
			nextScroll = self.maxScroll
		end
		self.scroll = nextScroll
		for i = 1, self.count do
			local button = self.buttons[i]
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 22 + nextScroll)
		end
	end)
	popup:Show()
end

local function raidNames()
	local names = {}
	local seen = {}
	local members = SK.Roster and SK.Roster:Members() or {}
	for _, info in pairs(members) do
		if info.name and info.name ~= "" and not seen[string.lower(info.name)] then
			seen[string.lower(info.name)] = true
			table.insert(names, info.name)
		end
	end
	table.sort(names)
	return names
end

local holdOpacity = false

opacitySlider:SetScript("OnValueChanged", function(self, value)
	local percent = math.floor((tonumber(value) or 100) + 0.5)
	opacityValue:SetText(tostring(percent) .. "%")
	if holdOpacity then
		return
	end
	SK.Settings:SetOpacity(percent / 100)
	SK.UI:ApplyOpacity()
end)

local function refresh()
	local settings = SK.Settings:Get()
	holdOpacity = true
	opacitySlider:SetValue((tonumber(settings.opacity) or 1) * 100)
	holdOpacity = false
	opacityValue:SetText(tostring(math.floor(((tonumber(settings.opacity) or 1) * 100) + 0.5)) .. "%")
	local officer = SK.Session:IsOfficer()
	lastBtn:SetEnabled(officer and settings.bidDrop ~= "last")
	belowBtn:SetEnabled(officer and settings.bidDrop == "last")
	timerBox:SetText(tostring(settings.timer or 15))
	countBox:SetText(tostring(settings.countdown or 5))
	timerBox:SetEnabled(officer)
	countBox:SetEnabled(officer)
	local enchanter = settings.disenchanter
	if not enchanter or enchanter == "" then
		deBtn:SetText("None")
	else
		deBtn:SetText(enchanter)
	end
	deBtn:SetEnabled(officer)
	autoCheck:SetChecked(settings.autoAdd and true or false)
	autoCheck:SetEnabled(officer)
	qualBtn:SetText((QUALITY[settings.autoQuality or 2] or "Uncommon") .. " and up")
	qualBtn:SetEnabled(officer)
	resetBtn:SetEnabled(officer)
	clearListBtn:SetEnabled(officer and not SK.Session:IsLocked())
	clearHistBtn:SetEnabled(officer)
end

lastBtn:SetScript("OnClick", function()
	SK.Settings:SetBidDrop("last")
end)
belowBtn:SetScript("OnClick", function()
	SK.Settings:SetBidDrop("below")
end)
timerBox:SetScript("OnEnterPressed", function(self)
	SK.Settings:SetTimer(self:GetText())
	self:ClearFocus()
end)
countBox:SetScript("OnEnterPressed", function(self)
	SK.Settings:SetCountdown(self:GetText())
	self:ClearFocus()
end)
deBtn:SetScript("OnClick", function(self)
	local labels = { "None" }
	local names = raidNames()
	local saved = SK.Settings:Get().disenchanter
	local seen = {}
	for i = 1, #names do
		seen[string.lower(names[i])] = true
		table.insert(labels, names[i])
	end
	if saved and saved ~= "" and not seen[string.lower(saved)] then
		table.insert(labels, saved)
	end
	openMenu(self, labels, function(label)
		SK.Settings:SetDisenchanter(label == "None" and "" or label)
	end)
end)
autoCheck:SetScript("OnClick", function(self)
	SK.Settings:SetAutoAdd(self:GetChecked())
end)
qualBtn:SetScript("OnClick", function(self)
	local labels = {}
	for i = 0, 5 do
		labels[i + 1] = QUALITY[i] .. " and up"
	end
	openMenu(self, labels, function(_, index)
		SK.Settings:SetAutoQuality(index - 1)
	end)
end)
resetBtn:SetScript("OnClick", function()
	local err = SK.Settings:Reset()
	if err then
		SK.Print(err)
	end
	refresh()
end)

StaticPopupDialogs["SKF_CLEAR_LIST"] = {
	text = "Are you sure you want to clear the list?",
	button1 = "Clear",
	button2 = "Cancel",
	OnAccept = function()
		local err = SK.List:Clear()
		if err then
			SK.Print(err)
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["SKF_CLEAR_HISTORY"] = {
	text = "Are you sure you want to clear history on this character?",
	button1 = "Clear",
	button2 = "Cancel",
	OnAccept = function()
		SK.History:Clear()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

clearListBtn:SetScript("OnClick", function()
	StaticPopup_Show("SKF_CLEAR_LIST")
end)
clearHistBtn:SetScript("OnClick", function()
	StaticPopup_Show("SKF_CLEAR_HISTORY")
end)

SK.Events:On("SK_READY", refresh)
SK.Events:Register("GROUP_ROSTER_UPDATE", function()
	if frame:IsShown() then
		refresh()
	end
end)
SK.Events:On("SK_SETTINGS", refresh)
frame:SetScript("OnShow", refresh)
frame:SetScript("OnHide", function()
	hideMenu()
	StaticPopup_Hide("SKF_CLEAR_LIST")
	StaticPopup_Hide("SKF_CLEAR_HISTORY")
end)
