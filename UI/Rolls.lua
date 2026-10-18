local frame = SK.UI:CreateWindow("rolls", "Rolls")
frame:SetSize(720, 500)
local body = frame.body

local BOX = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function sectionBox(parent)
	local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetBackdrop(BOX)
	box:SetBackdropColor(0, 0, 0, 0.45)
	box:SetBackdropBorderColor(0.75, 0.62, 0.28, 0.9)
	return box
end

local function scrollArea(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(200, 20)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
		local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 16))
		self:SetVerticalScroll(nextValue)
	end)
	return scroll, content
end

local left = CreateFrame("Frame", nil, body)
left:SetPoint("TOPLEFT", 0, 0)
left:SetPoint("BOTTOMLEFT", 0, 78)
left:SetWidth(250)

local waitingBox = sectionBox(left)
waitingBox:SetPoint("TOPLEFT", 0, 0)
waitingBox:SetPoint("TOPRIGHT", 0, 0)
waitingBox:SetHeight(188)
if waitingBox.SetClipsChildren then
	waitingBox:SetClipsChildren(true)
end
local waitingTitle = waitingBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
waitingTitle:SetPoint("TOPLEFT", 10, -8)
waitingTitle:SetText("Waiting")
local waitingScroll, waitingContent = scrollArea(waitingBox)
waitingScroll:SetPoint("TOPLEFT", 8, -28)
waitingScroll:SetPoint("BOTTOMRIGHT", -10, 8)

local addRow = CreateFrame("Frame", nil, left)
addRow:SetHeight(26)
addRow:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)
addRow:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)

local addBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
addBtn:SetSize(64, 22)
addBtn:SetPoint("RIGHT", addRow, "RIGHT", 0, 0)
addBtn:SetText("Add")

local linkBox = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
linkBox:SetHeight(20)
linkBox:SetPoint("LEFT", addRow, "LEFT", 8, 0)
linkBox:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
linkBox:SetAutoFocus(false)
linkBox:SetMaxLetters(400)
local linkHint = linkBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
linkHint:SetPoint("LEFT", 4, 0)
linkHint:SetText("Paste item link")
linkBox:SetScript("OnTextChanged", function(self)
	if self:GetText() == "" then
		linkHint:Show()
	else
		linkHint:Hide()
	end
end)

local tradeBox = sectionBox(left)
tradeBox:SetPoint("TOPLEFT", waitingBox, "BOTTOMLEFT", 0, -8)
tradeBox:SetPoint("BOTTOMRIGHT", addRow, "TOPRIGHT", 0, 8)
if tradeBox.SetClipsChildren then
	tradeBox:SetClipsChildren(true)
end
local tradeTitle = tradeBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tradeTitle:SetPoint("TOPLEFT", 10, -8)
tradeTitle:SetText("Needs Trade")
local tradeScroll, tradeContent = scrollArea(tradeBox)
tradeScroll:SetPoint("TOPLEFT", 8, -28)
tradeScroll:SetPoint("BOTTOMRIGHT", -10, 8)

local right = CreateFrame("Frame", nil, body)
right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
right:SetPoint("BOTTOMRIGHT", 0, 78)

local icon = right:CreateTexture(nil, "ARTWORK")
icon:SetSize(36, 36)
icon:SetPoint("TOPLEFT", 0, 0)
icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

local liveName = right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
liveName:SetPoint("LEFT", icon, "RIGHT", 8, 6)
liveName:SetPoint("RIGHT", right, "RIGHT", -90, 0)
liveName:SetJustifyH("LEFT")
liveName:SetText("No live item")

local liveHit = CreateFrame("Button", nil, right)
liveHit:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
liveHit:SetPoint("RIGHT", right, "RIGHT", -96, 0)
liveHit:SetHeight(36)
liveHit:RegisterForClicks("LeftButtonUp")

local timerText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
timerText:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -8)
timerText:SetText("")

local header = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
header:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -10)
header:SetPoint("RIGHT", right, "RIGHT", -4, 0)
header:SetJustifyH("LEFT")
header:SetText("#   Name            Response   Roll   Pos   Result")

local liveBox = sectionBox(right)
liveBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -4)
liveBox:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
local liveScroll, liveContent = scrollArea(liveBox)
liveScroll:SetPoint("TOPLEFT", 6, -6)
liveScroll:SetPoint("BOTTOMRIGHT", -8, 6)

local note = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("BOTTOMLEFT", 4, 28)
note:SetPoint("BOTTOMRIGHT", -4, 28)
note:SetJustifyH("LEFT")
note:SetText("/sk or /skf opens this window. Alt-click an item, or shift-click one into the add box. Right-click a row, then click Remove.")

local function makeButton(text, width, x)
	local button = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("BOTTOMLEFT", x, 0)
	button:SetText(text)
	return button
end

local startBtn = makeButton("Start", 80, 0)
local endBtn = makeButton("End", 70, 88)
local awardBtn = makeButton("Award", 90, 166)
local deBtn = makeButton("Disenchant", 110, 264)
local cancelBtn = makeButton("Cancel", 80, 382)

local waitingButtons = {}
local tradeButtons = {}
local liveButtons = {}
local message = ""
local pendingRemove = nil

local function classColor(class)
	local file = SK.CLASS_FILE[class]
	local colors = RAID_CLASS_COLORS
	local color = file and colors and colors[file]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local function paint(button, selected)
	if not button.bg.SetColorTexture then
		return
	end
	if selected then
		button.bg:SetColorTexture(1, 0.82, 0, 0.18)
	elseif button.stripe then
		button.bg:SetColorTexture(1, 1, 1, 0.04)
	else
		button.bg:SetColorTexture(0, 0, 0, 0)
	end
end

local function showItemTip(owner, entry)
	local link = SK.Item.ChatLink(entry)
	if type(link) ~= "string" or not string.find(link, "item:", 1, true) then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
		GameTooltip:Show()
	else
		GameTooltip:Hide()
	end
end

local function hideItemTip()
	GameTooltip:Hide()
end

local function insertShownLink(link)
	if type(link) ~= "string" or not string.find(link, "|Hitem", 1, true) then
		return false
	end
	if not (IsModifiedClick and IsModifiedClick("CHATLINK")) then
		return false
	end
	local edit = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if edit and edit.Insert then
		edit:Insert(link)
		return true
	end
	return false
end

liveHit:SetScript("OnEnter", function(self)
	if self.entry then
		showItemTip(self, self.entry)
	end
end)
liveHit:SetScript("OnLeave", hideItemTip)
liveHit:SetScript("OnClick", function(self)
	if not self.entry then
		return
	end
	local link = SK.Item.ChatLink(self.entry)
	if insertShownLink(link) then
		return
	end
	local itemString = type(link) == "string" and string.match(link, "item:[%d:%-]+")
	if itemString and SetItemRef then
		SetItemRef(itemString, link, "LeftButton")
	end
end)

local function lineButton(store, parent, index, width)
	local button = store[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 18)
	button:SetPoint("TOPLEFT", 0, -((index - 1) * 18))
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.stripe = index % 2 == 0
	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.label:SetPoint("LEFT", 6, 0)
	button.label:SetPoint("RIGHT", -6, 0)
	button.label:SetJustifyH("LEFT")
	button.label:SetWordWrap(false)
	button.label:SetTextColor(1, 1, 1)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnEnter", function(self)
		if self.entry then
			showItemTip(self, self.entry)
		end
	end)
	button:SetScript("OnLeave", hideItemTip)
	store[index] = button
	return button
end

local function responseButton(index)
	local button = liveButtons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, liveContent)
	button:SetSize(420, 18)
	button:SetPoint("TOPLEFT", 0, -((index - 1) * 18))
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.stripe = index % 2 == 0
	local function col(x, w)
		local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", x, 0)
		text:SetWidth(w)
		text:SetJustifyH("LEFT")
		return text
	end
	button.num = col(4, 22)
	button.name = col(28, 110)
	button.response = col(142, 70)
	button.roll = col(214, 36)
	button.pos = col(252, 36)
	button.result = col(290, 120)
	liveButtons[index] = button
	return button
end

local function hideFrom(store, index)
	for i = index, #store do
		store[i]:Hide()
	end
end

local function resultText(row, winner)
	if row.choice == "Pass" then
		return "Pass"
	end
	if not winner then
		return ""
	end
	if row.name == winner.name then
		if row.choice == "Bid" then
			return "Best bid"
		end
		return "Wins"
	end
	if winner.choice == "Bid" and row.choice == "Bid" then
		return "Outbid"
	end
	if winner.choice == "Bid" then
		return "Bid beats " .. row.choice
	end
	if winner.choice == "MS" and row.choice == "OS" then
		return "Lower tier"
	end
	if row.choice == winner.choice then
		return "Lower roll"
	end
	return ""
end

local refresh

local function queueLink()
	local err = SK.Session:Queue(linkBox:GetText())
	if err then
		message = err
		refresh()
	else
		message = ""
		linkBox:SetText("")
		linkBox:ClearFocus()
	end
end

addBtn:SetScript("OnClick", queueLink)
linkBox:SetScript("OnEnterPressed", function(self)
	queueLink()
	self:ClearFocus()
end)

local removeMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
removeMenu:SetFrameStrata("TOOLTIP")
removeMenu:SetSize(84, 24)
removeMenu:SetClampedToScreen(true)
removeMenu:EnableMouse(true)
removeMenu:Hide()
removeMenu:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
removeMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
removeMenu:SetBackdropBorderColor(0.75, 0.62, 0.28, 1)

local menuButtons = {}

local function menuButton(index)
	local button = menuButtons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, removeMenu)
	button:SetHeight(20)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetPoint("LEFT", 8, 0)
	button.text:SetPoint("RIGHT", -6, 0)
	button.text:SetJustifyH("LEFT")
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
		self.text:SetTextColor(self.baseR or 1, self.baseG or 1, self.baseB or 1)
	end)
	menuButtons[index] = button
	return button
end

local function hideRemoveMenu()
	pendingRemove = nil
	removeMenu.arming = false
	removeMenu:Hide()
end

local function showRemoveMenu(kind, item)
	pendingRemove = { kind = kind, id = item.id }
	local entries = {}
	if kind == "waiting" and SK.Teams then
		local lists = SK.Teams:Lists()
		if #lists > 1 then
			for i = 1, #lists do
				local entry = lists[i]
				table.insert(entries, {
					label = entry.name,
					selected = item.listId == entry.id,
					fn = function()
						item.listId = entry.id
						item.listName = entry.name
						item.listPick = true
						refresh()
					end,
				})
			end
		end
	end
	table.insert(entries, {
		label = "Remove",
		remove = true,
		fn = function()
			local err
			if kind == "trade" then
				err = SK.Session:RemoveNeedsTrade(item.id)
			else
				err = SK.Session:RemoveWaiting(item.id)
			end
			if err then
				message = err
				refresh()
			end
		end,
	})
	local width = 120
	for i = 1, #entries do
		local button = menuButton(i)
		local label = entries[i].label
		if #label > 18 then
			width = 180
		end
		button:SetWidth(width)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
		button.text:SetText(label)
		if entries[i].remove then
			button.baseR, button.baseG, button.baseB = 1, 0.45, 0.4
		elseif entries[i].selected then
			button.baseR, button.baseG, button.baseB = 1, 0.82, 0
		else
			button.baseR, button.baseG, button.baseB = 1, 1, 1
		end
		button.text:SetTextColor(button.baseR, button.baseG, button.baseB)
		button.hi:Hide()
		local fn = entries[i].fn
		button:SetScript("OnClick", function()
			hideRemoveMenu()
			if fn then
				fn()
			end
		end)
		button:Show()
	end
	for i = #entries + 1, #menuButtons do
		menuButtons[i]:Hide()
	end
	removeMenu:SetSize(width + 8, 8 + #entries * 22)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	removeMenu:ClearAllPoints()
	removeMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 2, y / scale)
	removeMenu.arming = true
	removeMenu:Show()
end

removeMenu:SetScript("OnUpdate", function(self)
	if not self:IsShown() then
		return
	end
	if self.arming then
		if not IsMouseButtonDown("RightButton") then
			self.arming = false
		end
		return
	end
	if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and not self:IsMouseOver() then
		hideRemoveMenu()
	end
end)

function refresh()
	local officer = SK.Session:IsOfficer()
	addBtn:SetEnabled(officer)
	linkBox:SetEnabled(officer)
	local waiting = SK.Session:Waiting()
	local selected = SK.Saved:Session().selected
	if pendingRemove and removeMenu:IsShown() then
		local stillThere = false
		local rows = pendingRemove.kind == "trade" and SK.Session:NeedsTrade() or waiting
		for i = 1, #rows do
			if rows[i].id == pendingRemove.id then
				stillThere = true
				break
			end
		end
		if not stillThere then
			hideRemoveMenu()
		end
	end
	for i = 1, #waiting do
		local item = waiting[i]
		if SK.Teams then
			SK.Teams:Assign(item)
		end
		local button = lineButton(waitingButtons, waitingContent, i, 220)
		button.entry = item
		local many = SK.Teams and #SK.Teams:Lists() > 1
		local listLabel = many and item.listName or ""
		button.label:ClearAllPoints()
		button.label:SetPoint("LEFT", 6, 0)
		button.label:SetPoint("RIGHT", -6, 0)
		if listLabel and listLabel ~= "" then
			button.label:SetText(SK.Item.ChatLink(item) .. "   " .. listLabel)
		else
			button.label:SetText(SK.Item.ChatLink(item))
		end
		button.label:SetTextColor(1, 1, 1)
		paint(button, item.id == selected)
		button:SetScript("OnClick", function(_, mouse)
			if mouse == "RightButton" then
				if officer then
					showRemoveMenu("waiting", item)
				end
				return
			end
			if insertShownLink(SK.Item.ChatLink(item)) then
				return
			end
			hideRemoveMenu()
			SK.Session:Select(item.id)
		end)
		button:Show()
	end
	hideFrom(waitingButtons, #waiting + 1)
	waitingContent:SetHeight(math.max(18, #waiting * 18))
	waitingTitle:SetText("Waiting")

	local trades = SK.Session:NeedsTrade()
	for i = 1, #trades do
		local item = trades[i]
		local button = lineButton(tradeButtons, tradeContent, i, 220)
		button.entry = item
		button.label:ClearAllPoints()
		button.label:SetPoint("LEFT", 6, 0)
		button.label:SetPoint("RIGHT", -6, 0)
		button.label:SetText(SK.Item.ChatLink(item) .. "    " .. (item.winner or ""))
		button.label:SetTextColor(1, 1, 1)
		paint(button, false)
		button:SetScript("OnClick", function(_, mouse)
			if mouse == "RightButton" then
				if officer then
					showRemoveMenu("trade", item)
				end
				return
			end
			if insertShownLink(SK.Item.ChatLink(item)) then
				return
			end
			hideRemoveMenu()
		end)
		button:Show()
	end
	hideFrom(tradeButtons, #trades + 1)
	tradeContent:SetHeight(math.max(18, #trades * 18))

	local live = SK.Session:Live()
	local collecting = live and (live.state == "open" or live.state == "rolloff")
	local chosen = SK.Session:Chosen()
	if not live then
		icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		liveHit.entry = nil
		liveName:SetTextColor(1, 0.82, 0)
		liveName:SetText("No live item")
		timerText:SetText("")
		hideFrom(liveButtons, 1)
		liveContent:SetHeight(18)
	else
		icon:SetTexture(live.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		liveHit.entry = live
		liveName:SetTextColor(1, 1, 1)
		liveName:SetText(SK.Item.ChatLink(live))
		local ordered = {}
		local decision = select(2, SK.Session:Chosen())
		if decision and decision.ordered then
			ordered = decision.ordered
		end
		for i = 1, #ordered do
			local row = ordered[i]
			local button = responseButton(i)
			local listRow = SK.List:Find(row.name)
			button.num:SetText(tostring(i))
			button.name:SetText(row.name)
			if listRow then
				button.name:SetTextColor(classColor(listRow.class))
			else
				button.name:SetTextColor(1, 1, 1)
			end
			button.response:SetText(row.choice or "")
			button.roll:SetText(row.roll and tostring(row.roll) or "-")
			button.pos:SetText(row.position and tostring(row.position) or "-")
			button.result:SetText(resultText(row, chosen))
			paint(button, chosen and chosen.name == row.name)
			button:SetScript("OnClick", function()
				if not collecting and row.choice ~= "Pass" then
					SK.Session:SetOverride(row.name)
				end
			end)
			button:Show()
		end
		hideFrom(liveButtons, #ordered + 1)
		liveContent:SetWidth(420)
		liveContent:SetHeight(math.max(18, #ordered * 18))
		local many = SK.Teams and #SK.Teams:Lists() > 1
		local listLabel = many and live.listName or ""
		if listLabel == "" then
			listLabel = nil
		end
		if collecting then
			local remain = math.max(0, math.ceil((live.endsAt or 0) - time()))
			if listLabel then
				timerText:SetText(listLabel .. "  " .. remain .. "s")
			else
				timerText:SetText("Timer " .. remain .. "s")
			end
		elseif listLabel then
			timerText:SetText(listLabel .. "  closed")
		else
			timerText:SetText("Timer closed")
		end
	end

	if message ~= "" then
		note:SetText(message)
	else
		local sessionNote = SK.Session:Note()
		if sessionNote ~= "" then
			note:SetText(sessionNote)
		else
			note:SetText("/sk or /skf opens this window. Alt-click an item, or shift-click one into the add box. Right-click a row, then click Remove.")
		end
	end
	local selectedItem = SK.Session:Selected()
	if selectedItem and SK.Teams then
		SK.Teams:Assign(selectedItem)
	end
	local listReady = (not selectedItem) or selectedItem.listId
	startBtn:SetEnabled(officer and not live and selectedItem ~= nil and listReady)
	endBtn:SetEnabled(officer and not not collecting)
	awardBtn:SetEnabled(officer and live and not collecting and chosen ~= nil)
	deBtn:SetEnabled(officer and live and not collecting)
	cancelBtn:SetEnabled(officer and live and not collecting)
end

startBtn:SetScript("OnClick", function()
	message = SK.Session:Start() or ""
	refresh()
end)
endBtn:SetScript("OnClick", function()
	message = SK.Session:EndEarly() or ""
	refresh()
end)
awardBtn:SetScript("OnClick", function()
	message = SK.Session:Award() or ""
	refresh()
end)
deBtn:SetScript("OnClick", function()
	message = SK.Session:Disenchant() or ""
	refresh()
end)
cancelBtn:SetScript("OnClick", function()
	message = SK.Session:Cancel() or ""
	refresh()
end)

local lastLink = ""
local lastWhen = 0

local function takeItem(link)
	if type(link) ~= "string" or not SK.Session:IsOfficer() then
		return
	end
	if SK.Gargul and SK.Gargul:UseGargul() then
		return
	end
	if SK.Gargul and SK.Gargul.asking then
		SK.Gargul:Choose("skf")
	end
	if not string.find(link, "item:", 1, true) then
		return
	end
	local now = GetTime and GetTime() or time()
	if link == lastLink and (now - lastWhen) < 0.4 then
		return
	end
	lastLink = link
	lastWhen = now
	message = SK.Session:Queue(link) or ""
	SK.UI:Open("rolls")
end

local function hideSplit()
	if StackSplitFrame and StackSplitFrame.Hide and StackSplitFrame.IsShown and StackSplitFrame:IsShown() then
		StackSplitFrame:Hide()
	end
end

local function shiftIntoAddBox(link)
	if type(link) ~= "string" or not string.find(link, "item:", 1, true) then
		return false
	end
	if not linkBox:IsShown() or not linkBox:HasFocus() then
		return false
	end
	if not IsShiftKeyDown() and not (IsModifiedClick and IsModifiedClick("CHATLINK")) then
		return false
	end
	local now = GetTime and GetTime() or time()
	if link == lastLink and (now - lastWhen) < 0.4 then
		hideSplit()
		return true
	end
	lastLink = link
	lastWhen = now
	linkBox:SetText(link)
	if linkHint then
		linkHint:Hide()
	end
	hideSplit()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, hideSplit)
	end
	local err = SK.Session:Queue(link)
	if err then
		message = err
		refresh()
	else
		message = ""
		linkBox:SetText("")
	end
	return true
end

local function linkFromButton(self)
	if type(self) ~= "table" then
		return nil
	end
	if type(self.itemLink) == "string" then
		return self.itemLink
	end
	if type(self.link) == "string" then
		return self.link
	end
	local bag = self.bagID
	if not bag and self.GetBagID then
		bag = self:GetBagID()
	end
	if not bag and self.GetParent and self:GetParent() then
		bag = self:GetParent():GetID()
	end
	local slot = self.slotID or (self.GetID and self:GetID())
	if self.GetItemLink then
		local ok, itemLink = pcall(self.GetItemLink, self)
		if ok and type(itemLink) == "string" then
			return itemLink
		end
	end
	if bag and slot and C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if type(info) == "table" and type(info.hyperlink) == "string" then
			return info.hyperlink
		end
	end
	if bag and slot and C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	end
	if bag and slot and GetContainerItemLink then
		return GetContainerItemLink(bag, slot)
	end
	local lootSlot = self.slotIndex or slot
	if self.GetSlotIndex then
		lootSlot = self:GetSlotIndex()
	end
	if lootSlot and GetLootSlotLink then
		local lootLink = GetLootSlotLink(lootSlot)
		if lootLink then
			return lootLink
		end
	end
	return nil
end

local hooked = {}

local function hookClick(object, method)
	if type(hooksecurefunc) ~= "function" or type(object) ~= "table" or type(object[method]) ~= "function" then
		return
	end
	local key = tostring(object) .. method
	if hooked[key] then
		return
	end
	hooked[key] = true
	hooksecurefunc(object, method, function(self)
		if shiftIntoAddBox(linkFromButton(self)) then
			return
		end
		if IsAltKeyDown() then
			takeItem(linkFromButton(self))
		end
	end)
end

local function hookItemClicks()
	if type(hooksecurefunc) ~= "function" then
		return
	end
	if type(SetItemRef) == "function" and not hooked.SetItemRef then
		hooked.SetItemRef = true
		hooksecurefunc("SetItemRef", function(link, _, button)
			if button == "LeftButton" and IsAltKeyDown() then
				takeItem(link)
			end
		end)
	end
	if type(HandleModifiedItemClick) == "function" and not hooked.HandleModifiedItemClick then
		hooked.HandleModifiedItemClick = true
		local originalModified = HandleModifiedItemClick
		HandleModifiedItemClick = function(link, ...)
			if shiftIntoAddBox(link) then
				return true
			end
			if IsAltKeyDown() then
				takeItem(link)
			end
			return originalModified(link, ...)
		end
	end
	if type(ChatEdit_InsertLink) == "function" and not hooked.insertLink then
		hooked.insertLink = true
		local originalInsert = ChatEdit_InsertLink
		ChatEdit_InsertLink = function(text)
			if shiftIntoAddBox(text) then
				return true
			end
			return originalInsert(text)
		end
	end
	if type(StackSplitFrame) == "table" and type(StackSplitFrame.OpenStackSplitFrame) == "function" and not hooked.split then
		hooked.split = true
		local originalSplit = StackSplitFrame.OpenStackSplitFrame
		function StackSplitFrame:OpenStackSplitFrame(maxStack, parent, ...)
			if linkBox:IsShown() and linkBox:HasFocus() and IsShiftKeyDown() then
				shiftIntoAddBox(linkFromButton(parent))
				return
			end
			return originalSplit(self, maxStack, parent, ...)
		end
	end
	hookClick(ContainerFrameItemButtonMixin, "OnModifiedClick")
	hookClick(ContainerFrameItemButtonMixin, "OnClick")
	hookClick(LootFrameElementMixin, "OnClick")
	hookClick(LootFrameItemMixin, "OnClick")
	if type(ContainerFrameItemButton_OnModifiedClick) == "function" and not hooked.bagFunc then
		hooked.bagFunc = true
		hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self)
			if shiftIntoAddBox(linkFromButton(self)) then
				return
			end
			if IsAltKeyDown() then
				takeItem(linkFromButton(self))
			end
		end)
	end
	for bag = 1, 13 do
		for slot = 1, 36 do
			local button = _G["ContainerFrame" .. bag .. "Item" .. slot]
			if button and not button.skfAlt then
				button.skfAlt = true
				button:HookScript("OnClick", function(self)
					if shiftIntoAddBox(linkFromButton(self)) then
						return
					end
					if IsAltKeyDown() then
						takeItem(linkFromButton(self))
					end
				end)
			end
		end
	end
end

SK.Events:Register("PLAYER_LOGIN", hookItemClicks)
SK.Events:Register("ADDON_LOADED", hookItemClicks)
SK.Events:Register("LOOT_OPENED", function()
	hookItemClicks()
	local slots = GetNumLootItems and GetNumLootItems() or 0
	for i = 1, slots do
		local button = _G["LootButton" .. i]
		if button and not button.skfAlt then
			button.skfAlt = true
			button:HookScript("OnClick", function(self)
				local lootLink = self.link or (GetLootSlotLink and GetLootSlotLink(self:GetID() or i))
				if shiftIntoAddBox(lootLink) then
					return
				end
				if IsAltKeyDown() then
					takeItem(lootLink)
				end
			end)
		end
		if GetLootSlotLink then
			local lootLink = GetLootSlotLink(i)
			local element = _G["LootFrameElement" .. i] or _G["LootButton" .. i]
			if element and lootLink and not element.skfAlt then
				element.skfAlt = true
				element:HookScript("OnClick", function()
					local lootLink = GetLootSlotLink(i)
					if shiftIntoAddBox(lootLink) then
						return
					end
					if IsAltKeyDown() then
						takeItem(lootLink)
					end
				end)
			end
		end
	end
end)

SK.Events:On("SK_READY", refresh)
SK.Events:On("SK_SESSION", function()
	message = ""
	refresh()
end)
SK.Events:On("SK_OFFICER", function()
	if frame:IsShown() then
		refresh()
	end
end)
pcall(function()
	SK.Events:Register("GET_ITEM_INFO_RECEIVED", function()
		if frame:IsShown() then
			refresh()
		end
	end)
end)
frame:SetScript("OnHide", hideRemoveMenu)
frame:SetScript("OnShow", function()
	hookItemClicks()
	if SK.Item and SK.Item.RefreshSession then
		SK.Item.RefreshSession()
	end
	refresh()
end)
frame:SetScript("OnUpdate", function()
	if not frame:IsShown() then
		return
	end
	local live = SK.Session:Live()
	if live and (live.state == "open" or live.state == "rolloff") then
		local remain = math.max(0, math.ceil((live.endsAt or 0) - time()))
		timerText:SetText("Timer " .. remain .. "s")
	end
end)
