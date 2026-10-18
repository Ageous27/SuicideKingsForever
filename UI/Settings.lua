local frame = SK.UI:CreateWindow("settings", "Settings")
frame:SetSize(1100, 768)
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

local function showBidDropTip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText("Bid drop")
	GameTooltip:AddLine("Last place moves the winner to the bottom of that list. A sole bidder goes last.", 1, 1, 1, true)
	GameTooltip:AddLine("Below lowest bidder moves the winner to the spot just under the lowest other bidder. A sole bidder still goes last.", 1, 1, 1, true)
	GameTooltip:AddLine("Someone set to hold keeps their position. The winner can still move past them. Only the list this item is on moves.", 1, 1, 1, true)
	GameTooltip:Show()
end

local function hookBidDropTip(owner)
	owner:SetScript("OnEnter", function(self)
		showBidDropTip(self)
	end)
	owner:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

hookBidDropTip(lastBtn)
hookBidDropTip(belowBtn)

local dropHit = CreateFrame("Frame", nil, body)
dropHit:SetPoint("TOPLEFT", 0, -4)
dropHit:SetSize(84, 22)
dropHit:EnableMouse(true)
hookBidDropTip(dropHit)

local function choiceMark(button)
	local bar = button:CreateTexture(nil, "OVERLAY")
	bar:SetHeight(2)
	bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 4, -1)
	bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -4, -1)
	bar:SetColorTexture(1, 0.82, 0, 1)
	bar:Hide()
	button.mark = bar
end

local function shadeFill(button, selected)
	local shade = selected and 0.8 or 1
	local function paint(tex)
		if tex and tex ~= button.mark and tex.SetVertexColor then
			tex:SetVertexColor(shade, shade, shade)
		end
	end
	local pushed = button.GetPushedTexture and button:GetPushedTexture()
	local normal = button.GetNormalTexture and button:GetNormalTexture()
	if pushed or normal then
		paint(pushed)
		paint(normal)
		return
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	local regions = { button:GetRegions() }
	for i = 1, #regions do
		local region = regions[i]
		if region and region ~= highlight and region.GetObjectType and region:GetObjectType() == "Texture" then
			paint(region)
		end
	end
end

local function paintChoice(button, selected, officer)
	button:SetEnabled(officer)
	button.mark:SetShown(selected)
	button:SetNormalFontObject(GameFontNormal)
	shadeFill(button, selected and officer)
	if selected and officer then
		button:SetHighlightFontObject(GameFontNormal)
		button:SetButtonState("PUSHED", true)
	else
		button:SetHighlightFontObject(GameFontHighlight)
		button:SetButtonState("NORMAL", false)
	end
end

choiceMark(lastBtn)
choiceMark(belowBtn)

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
note:SetWidth(460)
note:SetJustifyH("LEFT")
note:SetJustifyV("TOP")
note:SetWordWrap(true)
note:SetHeight(32)
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
opacityValue:SetText("95%")

local opacitySlider = CreateFrame("Slider", nil, body)
opacitySlider:SetPoint("TOPLEFT", 160, -282)
opacitySlider:SetSize(220, 16)
opacitySlider:SetOrientation("HORIZONTAL")
opacitySlider:SetMinMaxValues(0, 100)
opacitySlider:SetValueStep(5)
opacitySlider:SetValue(95)
if opacitySlider.SetObeyStepOnDrag then
	opacitySlider:SetObeyStepOnDrag(true)
end
opacitySlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
local opacityTrack = opacitySlider:CreateTexture(nil, "BACKGROUND")
opacityTrack:SetColorTexture(0.25, 0.2, 0.1, 0.9)
opacityTrack:SetHeight(4)
opacityTrack:SetPoint("LEFT", 2, 0)
opacityTrack:SetPoint("RIGHT", -2, 0)

local STATUS_ROWS = {
	{ label = "Bench", status = "Bench" },
	{ label = "Absent", status = "Absent" },
	{ label = "No-call/no-show", status = "No-call/no-show" },
}

local statusHead = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusHead:SetPoint("TOPLEFT", 4, -318)
statusHead:SetText("Bench, Absent, and No-call")

local statusWidgets = {}
for i = 1, #STATUS_ROWS do
	local info = STATUS_ROWS[i]
	local y = -342 - (i - 1) * 30
	local label = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 4, y)
	label:SetWidth(140)
	label:SetJustifyH("LEFT")
	label:SetText(info.label)
	local function modeButton(text, width, x)
		local button = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
		button:SetSize(width, 22)
		button:SetPoint("TOPLEFT", x, y + 2)
		button:SetText(text)
		return button
	end
	local holdBtn = modeButton("Hold", 64, 148)
	local raiseBtn = modeButton("Raise", 64, 216)
	local demoteBtn = modeButton("Demote", 72, 284)
	choiceMark(holdBtn)
	choiceMark(raiseBtn)
	choiceMark(demoteBtn)
	local stepsBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
	stepsBox:SetSize(36, 20)
	stepsBox:SetPoint("TOPLEFT", 364, y + 2)
	stepsBox:SetAutoFocus(false)
	stepsBox:SetNumeric(true)
	stepsBox:SetMaxLetters(2)
	local stepsLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	stepsLabel:SetPoint("LEFT", stepsBox, "RIGHT", 6, 0)
	stepsLabel:SetText("positions")
	local function pick(mode)
		local _, steps = SK.Settings:StatusRule(info.status)
		SK.Settings:SetStatusRule(info.status, mode, stepsBox:GetText() ~= "" and stepsBox:GetText() or steps)
	end
	holdBtn:SetScript("OnClick", function()
		pick("hold")
	end)
	raiseBtn:SetScript("OnClick", function()
		pick("raise")
	end)
	demoteBtn:SetScript("OnClick", function()
		pick("demote")
	end)
	stepsBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	stepsBox:SetScript("OnEditFocusLost", function(self)
		local mode = SK.Settings:StatusRule(info.status)
		SK.Settings:SetStatusRule(info.status, mode, self:GetText())
	end)
	statusWidgets[info.status] = {
		hold = holdBtn,
		raise = raiseBtn,
		demote = demoteBtn,
		box = stepsBox,
		steps = stepsLabel,
	}
end

local statusNote = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statusNote:SetPoint("TOPLEFT", 4, -432)
statusNote:SetWidth(460)
statusNote:SetJustifyH("LEFT")
statusNote:SetJustifyV("TOP")
statusNote:SetWordWrap(true)
statusNote:SetHeight(44)
statusNote:SetText("Hold and Raise apply when the status is set. Demote sets Hold, and moves them down that many positions on each list when you lock. Last place stays last.")

local awayLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
awayLabel:SetPoint("TOPLEFT", 4, -484)
awayLabel:SetText("End raid when out of group and out of instance for")

local awayBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
awayBox:SetSize(36, 20)
awayBox:SetPoint("LEFT", awayLabel, "RIGHT", 8, 0)
awayBox:SetAutoFocus(false)
awayBox:SetNumeric(true)
awayBox:SetMaxLetters(3)

local awayMinutesLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
awayMinutesLabel:SetPoint("LEFT", awayBox, "RIGHT", 6, 0)
awayMinutesLabel:SetText("minutes")

local mapCheck = CreateFrame("CheckButton", nil, body)
mapCheck:SetSize(24, 24)
mapCheck:SetPoint("TOPLEFT", 0, -512)
mapCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
mapCheck:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
mapCheck:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
mapCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

local mapLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mapLabel:SetPoint("LEFT", mapCheck, "RIGHT", 2, 0)
mapLabel:SetText("Show minimap button")

local resetBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
resetBtn:SetSize(200, 22)
resetBtn:SetPoint("TOPLEFT", 4, -544)
resetBtn:SetText("Reset all settings")

local clearListBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
clearListBtn:SetSize(140, 22)
clearListBtn:SetPoint("TOPLEFT", 4, -576)
clearListBtn:SetText("Clear list")

local clearHistBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
clearHistBtn:SetSize(140, 22)
clearHistBtn:SetPoint("LEFT", clearListBtn, "RIGHT", 8, 0)
clearHistBtn:SetText("Clear history")

local foot = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
foot:SetPoint("TOPLEFT", 4, -608)
foot:SetWidth(460)
foot:SetJustifyH("LEFT")
foot:SetJustifyV("TOP")
foot:SetWordWrap(true)
foot:SetHeight(48)
foot:SetText("Bid drop, the timer, end raid, the disenchanter, auto add, status defaults, and clear list stay with the officer. Opacity, the minimap button, window positions, and clear history stay on this character. Reset leaves the list and history.")

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

local refresh

local teamHead = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
teamHead:SetPoint("TOPLEFT", 500, -8)
teamHead:SetText("Raid teams")

local teamScroll = CreateFrame("ScrollFrame", nil, body)
teamScroll:SetPoint("TOPLEFT", 496, -30)
teamScroll:SetSize(180, 128)
local teamContent = CreateFrame("Frame", nil, teamScroll)
teamContent:SetSize(168, 28)
teamScroll:SetScrollChild(teamContent)
if teamScroll.SetClipsChildren then
	teamScroll:SetClipsChildren(true)
end

local lockRaidBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
lockRaidBtn:SetSize(160, 22)
lockRaidBtn:SetPoint("TOPLEFT", 500, -164)
lockRaidBtn:SetText("Lock raid")

local newTeamBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
newTeamBtn:SetSize(160, 22)
newTeamBtn:SetPoint("TOPLEFT", 500, -196)
newTeamBtn:SetText("New team")

local listHead = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listHead:SetPoint("TOPLEFT", 688, -8)
listHead:SetPoint("RIGHT", -8, 0)
listHead:SetJustifyH("LEFT")
listHead:SetText("Lists")

local listScroll = CreateFrame("ScrollFrame", nil, body)
listScroll:SetPoint("TOPLEFT", 688, -30)
listScroll:SetPoint("TOPRIGHT", -8, -30)
listScroll:SetHeight(160)
local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetSize(300, 40)
listScroll:SetScrollChild(listContent)
if listScroll.SetClipsChildren then
	listScroll:SetClipsChildren(true)
end

local newListBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
newListBtn:SetSize(120, 22)
newListBtn:SetPoint("TOPLEFT", 688, -196)
newListBtn:SetText("New list")

local rulePane = CreateFrame("Frame", nil, body, "BackdropTemplate")
rulePane:SetPoint("TOPLEFT", 688, -226)
rulePane:SetPoint("TOPRIGHT", -8, -226)
rulePane:SetHeight(400)
rulePane:SetBackdrop({
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 12,
})
rulePane:SetBackdropBorderColor(0.75, 0.62, 0.28, 0.9)
local ruleBg = rulePane:CreateTexture(nil, "BACKGROUND")
ruleBg:SetPoint("TOPLEFT", 4, -4)
ruleBg:SetPoint("BOTTOMRIGHT", -4, 4)
ruleBg:SetColorTexture(0.06, 0.05, 0.04, 0.92)

local ruleTitle = rulePane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ruleTitle:SetPoint("TOPLEFT", 10, -10)
ruleTitle:SetText("Main")

local ruleEmpty = rulePane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
ruleEmpty:SetPoint("TOPLEFT", 10, -32)
ruleEmpty:SetPoint("RIGHT", -10, 0)
ruleEmpty:SetJustifyH("LEFT")
ruleEmpty:SetWordWrap(true)
ruleEmpty:SetText("No rules. This list gets items no other list claims.")

local slotBtn = CreateFrame("Button", nil, rulePane, "UIPanelButtonTemplate")
slotBtn:SetSize(140, 22)
slotBtn:SetPoint("BOTTOMLEFT", 8, 36)
slotBtn:SetText("Add a slot")

local itemEdit = CreateFrame("EditBox", nil, rulePane, "InputBoxTemplate")
itemEdit:SetSize(150, 20)
itemEdit:SetPoint("BOTTOMLEFT", 12, 10)
itemEdit:SetAutoFocus(false)
itemEdit:SetMaxLetters(80)

local itemAdd = CreateFrame("Button", nil, rulePane, "UIPanelButtonTemplate")
itemAdd:SetSize(90, 22)
itemAdd:SetPoint("BOTTOMRIGHT", -8, 8)
itemAdd:SetText("Add item")

local teamRows = {}
local listRows = {}
local chipRows = {}

local function wheel(scroll, content, step)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
		local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * step))
		self:SetVerticalScroll(nextValue)
	end)
end
wheel(teamScroll, teamContent, 28)
wheel(listScroll, listContent, 40)

local function paintRow(row, selected, title, sub)
	row.name:SetText(title or "")
	if row.sub then
		row.sub:SetText(sub or "")
	end
	if selected then
		row.bar:Show()
		row.name:SetTextColor(1, 1, 1)
		if row.bg.SetColorTexture then
			row.bg:SetColorTexture(0.22, 0.16, 0.06, 0.95)
		end
	else
		row.bar:Hide()
		row.name:SetTextColor(1, 1, 1)
		if row.bg.SetColorTexture then
			row.bg:SetColorTexture(0.1, 0.09, 0.08, 0.9)
		end
	end
end

local function makeRow(parent, height, withSub)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(height)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bar = row:CreateTexture(nil, "ARTWORK")
	row.bar:SetWidth(3)
	row.bar:SetPoint("TOPLEFT", 1, -2)
	row.bar:SetPoint("BOTTOMLEFT", 1, 2)
	row.bar:SetColorTexture(1, 0.82, 0, 1)
	row.bar:Hide()
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetJustifyH("LEFT")
	if withSub then
		row.name:SetPoint("TOPLEFT", 12, -4)
		row.name:SetPoint("RIGHT", -6, 0)
		row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.sub:SetPoint("TOPLEFT", 12, -20)
		row.sub:SetPoint("RIGHT", -6, 0)
		row.sub:SetJustifyH("LEFT")
	else
		row.name:SetPoint("LEFT", 12, 0)
		row.name:SetPoint("RIGHT", -6, 0)
	end
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return row
end

local DIALOG = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local ctx = CreateFrame("Frame", "SKFTeamMenu", UIParent, "BackdropTemplate")
ctx:SetFrameStrata("TOOLTIP")
ctx:SetClampedToScreen(true)
ctx:EnableMouse(true)
ctx:Hide()
ctx:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
ctx:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
ctx:SetBackdropBorderColor(0.75, 0.62, 0.28, 1)

local function menuItem(parent, label, destructive)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(140, 20)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetPoint("LEFT", 8, 0)
	button.text:SetPoint("RIGHT", -8, 0)
	button.text:SetJustifyH("LEFT")
	button.text:SetText(label)
	button.baseR, button.baseG, button.baseB = 1, 1, 1
	if destructive then
		button.baseR, button.baseG, button.baseB = 1, 0.45, 0.4
	end
	button.text:SetTextColor(button.baseR, button.baseG, button.baseB)
	button.hi = button:CreateTexture(nil, "BACKGROUND")
	button.hi:SetAllPoints()
	if button.hi.SetColorTexture then
		button.hi:SetColorTexture(1, 0.82, 0, 0.16)
	end
	button.hi:Hide()
	button:SetScript("OnEnter", function(self)
		self.hi:Show()
		self.text:SetTextColor(1, 0.82, 0)
	end)
	button:SetScript("OnLeave", function(self)
		self.hi:Hide()
		self.text:SetTextColor(self.baseR, self.baseG, self.baseB)
	end)
	return button
end

ctx.renameBtn = menuItem(ctx, "Rename", false)
ctx.removeBtn = menuItem(ctx, "Remove", true)
ctx:SetScript("OnUpdate", function(self)
	if not self:IsShown() then
		return
	end
	local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if down then
		if not self.arming and not self:IsMouseOver() then
			self:Hide()
		end
	else
		self.arming = false
	end
end)

local function hideContext()
	ctx:Hide()
end

local function showContext(hasRename, onRename, onRemove)
	ctx.renameBtn:SetShown(hasRename)
	ctx.removeBtn:SetShown(onRemove ~= nil)
	ctx.renameBtn:ClearAllPoints()
	ctx.removeBtn:ClearAllPoints()
	if hasRename then
		ctx.renameBtn:SetPoint("TOPLEFT", 4, -4)
		ctx.removeBtn:SetPoint("TOPLEFT", ctx.renameBtn, "BOTTOMLEFT", 0, -2)
		ctx:SetSize(148, onRemove and 50 or 28)
	else
		ctx.removeBtn:SetPoint("TOPLEFT", 4, -4)
		ctx:SetSize(148, 28)
	end
	ctx.renameBtn:SetScript("OnClick", function()
		hideContext()
		if onRename then
			onRename()
		end
	end)
	ctx.removeBtn:SetScript("OnClick", function()
		hideContext()
		if onRemove then
			onRemove()
		end
	end)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ctx:ClearAllPoints()
	ctx:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	ctx.arming = true
	ctx:Show()
end

local ask = CreateFrame("Frame", "SKFAskName", UIParent, "BackdropTemplate")
ask:SetSize(320, 128)
ask:SetFrameStrata("DIALOG")
ask:SetClampedToScreen(true)
ask:SetBackdrop(DIALOG)
ask:Hide()
ask:SetPoint("CENTER")
ask.title = ask:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ask.title:SetPoint("TOP", 0, -16)
ask.title:SetText("Name")
ask.edit = CreateFrame("EditBox", nil, ask, "InputBoxTemplate")
ask.edit:SetSize(200, 20)
ask.edit:SetPoint("TOP", 0, -48)
ask.edit:SetAutoFocus(false)
ask.edit:SetMaxLetters(32)
ask.cancel = CreateFrame("Button", nil, ask, "UIPanelButtonTemplate")
ask.cancel:SetSize(90, 22)
ask.cancel:SetPoint("BOTTOMLEFT", 40, 16)
ask.cancel:SetText("Cancel")
ask.accept = CreateFrame("Button", nil, ask, "UIPanelButtonTemplate")
ask.accept:SetSize(90, 22)
ask.accept:SetPoint("BOTTOMRIGHT", -40, 16)
ask.accept:SetText("Save")

local function hideAsk()
	ask:Hide()
	ask.edit:ClearFocus()
end

local function showAsk(title, acceptLabel, initial, onAccept)
	ask.title:SetText(title)
	ask.accept:SetText(acceptLabel)
	ask.edit:SetText(initial or "")
	ask.onAccept = onAccept
	ask:Show()
	ask.edit:SetFocus()
	ask.edit:HighlightText()
end

ask.cancel:SetScript("OnClick", hideAsk)
ask.accept:SetScript("OnClick", function()
	local fn = ask.onAccept
	local text = ask.edit:GetText()
	hideAsk()
	if fn then
		local err = fn(text)
		if err then
			SK.Print(err)
		end
	end
end)
ask.edit:SetScript("OnEnterPressed", function(self)
	ask.accept:Click()
end)
ask.edit:SetScript("OnEscapePressed", function(self)
	hideAsk()
end)

local newList = CreateFrame("Frame", "SKFNewList", UIParent, "BackdropTemplate")
newList:SetSize(340, 168)
newList:SetFrameStrata("HIGH")
newList:SetClampedToScreen(true)
newList:SetBackdrop(DIALOG)
newList:Hide()
newList:SetPoint("CENTER")
local newListTitle = newList:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
newListTitle:SetPoint("TOP", 0, -16)
newListTitle:SetText("New list")
local newListEdit = CreateFrame("EditBox", nil, newList, "InputBoxTemplate")
newListEdit:SetSize(180, 20)
newListEdit:SetPoint("TOP", 20, -50)
newListEdit:SetAutoFocus(false)
newListEdit:SetMaxLetters(32)
local newListName = newList:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
newListName:SetPoint("RIGHT", newListEdit, "LEFT", -8, 0)
newListName:SetText("Name")
local listCopy = nil
local listCopyBtn = CreateFrame("Button", nil, newList, "UIPanelButtonTemplate")
listCopyBtn:SetSize(180, 22)
listCopyBtn:SetPoint("TOP", 20, -82)
listCopyBtn:SetText("Blank positions")
local listCopyLabel = newList:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
listCopyLabel:SetPoint("RIGHT", listCopyBtn, "LEFT", -8, 0)
listCopyLabel:SetText("People")
local newListCancel = CreateFrame("Button", nil, newList, "UIPanelButtonTemplate")
newListCancel:SetSize(90, 22)
newListCancel:SetPoint("BOTTOMLEFT", 48, 16)
newListCancel:SetText("Cancel")
local newListCreate = CreateFrame("Button", nil, newList, "UIPanelButtonTemplate")
newListCreate:SetSize(90, 22)
newListCreate:SetPoint("BOTTOMRIGHT", -48, 16)
newListCreate:SetText("Create")

local function hideNewList()
	newList:Hide()
	newListEdit:ClearFocus()
end

local function openNewList()
	listCopy = nil
	listCopyBtn:SetText("Blank positions")
	newListEdit:SetText("")
	newList:Show()
	newListEdit:SetFocus()
end

listCopyBtn:SetScript("OnClick", function(self)
	local rows = {
		{
			label = "Blank positions",
			fn = function()
				listCopy = nil
				listCopyBtn:SetText("Blank positions")
			end,
		},
	}
	local lists = SK.Teams:Lists()
	for i = 1, #lists do
		local entry = lists[i]
		table.insert(rows, {
			label = "Copy from " .. entry.name,
			fn = function()
				listCopy = entry.id
				listCopyBtn:SetText(entry.name)
			end,
		})
	end
	SK.UI:Pick(self, rows)
end)
newListCancel:SetScript("OnClick", hideNewList)
newListCreate:SetScript("OnClick", function()
	local err = SK.Teams:AddList(newListEdit:GetText(), listCopy)
	if err then
		SK.Print(err)
		return
	end
	hideNewList()
end)
newListEdit:SetScript("OnEnterPressed", function()
	newListCreate:Click()
end)
newListEdit:SetScript("OnEscapePressed", hideNewList)

local function commitRule(err)
	if err then
		SK.Print(err)
		return
	end
	err = SK.Teams:Save()
	if err then
		SK.Print(err)
	end
end

local function teamRow(index)
	local row = teamRows[index]
	if row then
		return row
	end
	row = makeRow(teamContent, 28, false)
	row:SetWidth(160)
	row:SetPoint("TOPLEFT", 0, -((index - 1) * 28))
	teamRows[index] = row
	return row
end

local function listRow(index)
	local row = listRows[index]
	if row then
		return row
	end
	row = makeRow(listContent, 40, true)
	row:SetWidth(300)
	row:SetPoint("TOPLEFT", 0, -((index - 1) * 40))
	listRows[index] = row
	return row
end

local function chipRow(index)
	local chip = chipRows[index]
	if chip then
		return chip
	end
	chip = CreateFrame("Button", nil, rulePane, "UIPanelButtonTemplate")
	chip:SetSize(148, 20)
	chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	chipRows[index] = chip
	return chip
end

local function openRowMenu(canRemove, onRename, onRemove)
	if not SK.Session:IsOfficer() then
		return
	end
	showContext(true, onRename, canRemove and onRemove or nil)
end

newTeamBtn:SetScript("OnClick", function()
	showAsk("New team", "Create", "", function(text)
		return SK.Teams:AddTeam(text)
	end)
end)
lockRaidBtn:SetScript("OnClick", function()
	if not SK.Session:IsOfficer() then
		return
	end
	local err
	if SK.Session:IsLocked() then
		err = SK.Session:UnlockRaid()
	else
		err = SK.Session:LockRaid()
	end
	if err then
		SK.Print(err)
	end
end)
newListBtn:SetScript("OnClick", openNewList)
slotBtn:SetScript("OnClick", function(self)
	local labels = SK.Item.SLOTS or {}
	openMenu(self, labels, function(label)
		commitRule(SK.Teams:DraftAddSlot(label))
	end)
end)
itemAdd:SetScript("OnClick", function()
	commitRule(SK.Teams:DraftAddItem(itemEdit:GetText()))
	if itemEdit:GetText() ~= "" then
		local rows = SK.Teams:RuleRows()
		local id = tonumber(itemEdit:GetText()) or tonumber(string.match(itemEdit:GetText(), "item:(%d+)"))
		if id then
			for i = 1, #rows do
				if rows[i].kind == "items" and rows[i].key == tostring(id) then
					itemEdit:SetText("")
					break
				end
			end
		end
	end
end)
itemEdit:SetScript("OnEnterPressed", function(self)
	itemAdd:Click()
	self:ClearFocus()
end)

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

function refresh()
	local settings = SK.Settings:Get()
	holdOpacity = true
	opacitySlider:SetValue((tonumber(settings.opacity) or 0.95) * 100)
	holdOpacity = false
	opacityValue:SetText(tostring(math.floor(((tonumber(settings.opacity) or 0.95) * 100) + 0.5)) .. "%")
	local officer = SK.Session:IsOfficer()
	paintChoice(lastBtn, settings.bidDrop ~= "below", officer)
	paintChoice(belowBtn, settings.bidDrop == "below", officer)
	if not awayBox:HasFocus() then
		awayBox:SetText(tostring(settings.awayMinutes or 10))
	end
	awayBox:SetEnabled(officer)
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
	mapCheck:SetChecked(settings.minimapShown ~= false)
	autoCheck:SetChecked(settings.autoAdd and true or false)
	autoCheck:SetEnabled(officer)
	qualBtn:SetText((QUALITY[settings.autoQuality or 2] or "Uncommon") .. " and up")
	qualBtn:SetEnabled(officer)
	for n = 1, #STATUS_ROWS do
		local info = STATUS_ROWS[n]
		local widget = statusWidgets[info.status]
		local mode, steps = SK.Settings:StatusRule(info.status)
		paintChoice(widget.hold, mode == "hold", officer)
		paintChoice(widget.raise, mode == "raise", officer)
		paintChoice(widget.demote, mode == "demote", officer)
		local showSteps = mode == "demote"
		widget.box:SetShown(showSteps)
		widget.steps:SetShown(showSteps)
		widget.box:SetEnabled(officer and showSteps)
		if not widget.box:HasFocus() then
			widget.box:SetText(tostring(steps))
		end
	end
	resetBtn:SetEnabled(true)
	local viewLocked = SK.Session:TeamIsLocked()
	clearListBtn:SetEnabled(officer and not viewLocked)
	clearHistBtn:SetEnabled(true)
	local live = SK.Session:Live()
	local rulesOpen = officer and not viewLocked
	hideContext()
	newTeamBtn:SetEnabled(officer and not live)
	newListBtn:SetEnabled(rulesOpen and not live)
	slotBtn:SetEnabled(rulesOpen)
	itemEdit:SetEnabled(rulesOpen)
	itemAdd:SetEnabled(rulesOpen)
	if SK.Session:IsLocked() then
		lockRaidBtn:SetText("Unlock raid")
	else
		lockRaidBtn:SetText("Lock raid")
	end
	lockRaidBtn:SetEnabled(officer)
	if viewLocked then
		listHead:SetTextColor(0.45, 0.45, 0.45)
		ruleTitle:SetTextColor(0.45, 0.45, 0.45)
		rulePane:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)
		ruleBg:SetColorTexture(0.06, 0.05, 0.04, 0.45)
	else
		listHead:SetTextColor(1, 0.82, 0)
		ruleTitle:SetTextColor(1, 0.82, 0)
		rulePane:SetBackdropBorderColor(0.75, 0.62, 0.28, 0.9)
		ruleBg:SetColorTexture(0.06, 0.05, 0.04, 0.92)
	end
	local teamId = SK.Teams:TeamId()
	local catalog = SK.Teams:Catalog()
	listHead:SetText("Lists on " .. SK.Teams:TeamName())
	for i = 1, #catalog do
		local entry = catalog[i]
		local row = teamRow(i)
		local selected = entry.id == teamId
		local label = entry.name
		if SK.Session:TeamIsLocked(entry.id) then
			label = entry.name .. "  ·  locked"
		end
		paintRow(row, selected, label)
		row:SetScript("OnClick", function(_, mouse)
			if mouse == "RightButton" then
				if not officer or SK.Session:TeamIsLocked(entry.id) then
					return
				end
				local teamCount = #SK.Teams:Catalog()
				openRowMenu(teamCount > 1, function()
					showAsk("Rename team", "Rename", entry.name, function(text)
						return SK.Teams:RenameTeam(text, entry.id)
					end)
				end, function()
					local err = SK.Teams:RemoveTeam(entry.id)
					if err then
						SK.Print(err)
					end
				end)
				return
			end
			local err = SK.Teams:SelectTeam(entry.id)
			if err then
				SK.Print(err)
			end
		end)
		row:Show()
	end
	for i = #catalog + 1, #teamRows do
		teamRows[i]:Hide()
	end
	teamContent:SetHeight(math.max(28, #catalog * 28))
	local listId = SK.Teams:ListId()
	local lists = SK.Teams:Lists()
	for i = 1, #lists do
		local entry = lists[i]
		local row = listRow(i)
		local selected = entry.id == listId
		paintRow(row, selected, entry.name, SK.Teams:RuleBlurb(entry.id))
		row:SetScript("OnClick", function(_, mouse)
			if mouse == "RightButton" then
				if not officer or viewLocked then
					return
				end
				openRowMenu(not entry.fixed, function()
					showAsk("Rename list", "Rename", entry.name, function(text)
						return SK.Teams:RenameList(text, entry.id)
					end)
				end, function()
					local err = SK.Teams:RemoveList(entry.id)
					if err then
						SK.Print(err)
					end
				end)
				return
			end
			local err = SK.Teams:SelectList(entry.id)
			if err then
				SK.Print(err)
			end
		end)
		row:Show()
	end
	for i = #lists + 1, #listRows do
		listRows[i]:Hide()
	end
	listContent:SetHeight(math.max(40, #lists * 40))
	ruleTitle:SetText(SK.Teams:ListName())
	local rules = SK.Teams:RuleRows()
	ruleEmpty:SetShown(#rules == 0)
	if #rules == 0 then
		local open = SK.Teams:UnclaimedList()
		if open and open.id == SK.Teams:ListId() then
			ruleEmpty:SetText("No rules. This list gets items no other list claims.")
		else
			ruleEmpty:SetText("No rules on more than one list. Rolls will ask which list to use.")
		end
	end
	for i = 1, #rules do
		local rule = rules[i]
		local chip = chipRow(i)
		local col = (i - 1) % 2
		local line = math.floor((i - 1) / 2)
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", 10 + col * 154, -32 - line * 24)
		chip:SetText(rule.label .. "  x")
		chip:SetEnabled(rulesOpen)
		chip:SetScript("OnClick", function(_, mouse)
			if mouse ~= "RightButton" and mouse ~= "LeftButton" then
				return
			end
			if not rulesOpen then
				return
			end
			showContext(false, nil, function()
				commitRule(SK.Teams:DraftClear(rule.kind, rule.key))
			end)
		end)
		chip:Show()
	end
	for i = #rules + 1, #chipRows do
		chipRows[i]:Hide()
	end
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
awayBox:SetScript("OnEnterPressed", function(self)
	SK.Settings:SetAwayMinutes(self:GetText())
	self:ClearFocus()
end)
awayBox:SetScript("OnEditFocusLost", function(self)
	SK.Settings:SetAwayMinutes(self:GetText())
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
mapCheck:SetScript("OnClick", function(self)
	SK.Settings:SetMinimapShown(self:GetChecked())
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
	text = "Clear the selected list? People who are only on this list are removed. Other lists on the team stay.",
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
SK.Events:On("SK_OFFICER", function()
	if frame:IsShown() then
		refresh()
	end
end)
SK.Events:On("SK_SETTINGS", refresh)
SK.Events:On("SK_LIST_CHANGED", function()
	if frame:IsShown() then
		refresh()
	end
end)
frame:SetScript("OnShow", refresh)
frame:SetScript("OnHide", function()
	hideMenu()
	hideContext()
	hideAsk()
	hideNewList()
	StaticPopup_Hide("SKF_CLEAR_LIST")
	StaticPopup_Hide("SKF_CLEAR_HISTORY")
end)
