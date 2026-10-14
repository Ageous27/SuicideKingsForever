local frame = SK.UI.windows.list
local panel = CreateFrame("Frame", nil, frame.body)
panel:SetPoint("TOPLEFT", 0, -28)
panel:SetPoint("BOTTOMRIGHT", 0, 0)
panel:Hide()

local NAME_X, NAME_W = 4, 118
local CUR_X, CUR_W = 126, 78
local NEW_X, NEW_W = 208, 58
local STATUS_X, STATUS_W = 274, 136
local SHIFT_X, SHIFT_W = 416, 62
local ROLLS_X, ROLLS_W = 484, 112
local ROW_H = 24

local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
summary:SetPoint("TOPLEFT", 4, 0)
summary:SetPoint("TOPRIGHT", -4, 0)
summary:SetJustifyH("LEFT")
summary:SetText("Set status before the first item. Lock saves the raid.")

local notice = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
notice:SetTextColor(1, 0.82, 0)
notice:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -4)
notice:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -4)
notice:SetJustifyH("LEFT")
notice:SetHeight(28)
notice:SetWordWrap(true)

local function columnHead(text, x, width, justify, lines)
	local label = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	label:SetPoint("TOPLEFT", x, -48)
	label:SetWidth(width)
	label:SetJustifyH(justify)
	label:SetText(text)
	if not lines then
		return
	end
	label:SetTextColor(1, 0.82, 0)
	local hit = CreateFrame("Frame", nil, panel)
	hit:SetPoint("TOPLEFT", x, -46)
	hit:SetSize(width, 18)
	hit:EnableMouse(true)
	hit:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 0.82, 0)
		for i = 1, #lines do
			GameTooltip:AddLine(lines[i], 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	hit:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

columnHead("Name", NAME_X, NAME_W, "LEFT")
columnHead("Current Pos", CUR_X, CUR_W, "RIGHT")
columnHead("New Pos", NEW_X, NEW_W, "RIGHT")
columnHead("Status", STATUS_X, STATUS_W, "CENTER", {
	"Present: in the raid. Shift starts at Raise. Rolls are Bid, MS, and OS.",
	"Bench, Absent, and No-call/no-show: they cannot roll. Hold, Raise, or a demote comes from Settings.",
	"Pug/fill: guest for this raid, bottom of every list. Rolls are MS and OS. Shift is Hold.",
	"Blank: lock sets Present if they are in the raid, and Absent if they are missing.",
})
columnHead("Shift", SHIFT_X, SHIFT_W, "CENTER", {
	"Raise: a winner can pass this person.",
	"Hold: a winner does not pass this person. Their position number stays.",
	"Setting a status puts this back to that status default.",
})
columnHead("Rolls", ROLLS_X, ROLLS_W, "CENTER", {
	"Bid, MS, OS: bid or roll. A bid beats every roll. MS beats OS.",
	"MS, OS: main spec or off spec. No bid.",
	"Cannot Roll: no bid and no roll.",
	"Setting a status puts this back to that status default.",
})

local scroll = CreateFrame("ScrollFrame", nil, panel)
scroll:SetPoint("TOPLEFT", 0, -66)
scroll:SetPoint("BOTTOMRIGHT", -8, 36)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(700, 20)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)

local rows = {}
local message = ""
local menu
local paint
local selected

local CORE_CHOICES = { "--", "Present", "Bench", "Absent", "No-call/no-show", "Pug/fill" }
local GUEST_CHOICES = { "--", "Pug/fill", "Present", "Bench", "Absent", "No-call/no-show" }
local SHIFT_CHOICES = { "Raise", "Hold" }

local function paintRow(button, highlight, picked)
	if picked then
		button.bg:SetColorTexture(1, 0.82, 0, 0.28)
	elseif highlight then
		button.bg:SetColorTexture(0.62, 0.38, 0.05, 0.55)
	elseif button.stripe then
		button.bg:SetColorTexture(1, 1, 1, 0.04)
	else
		button.bg:SetColorTexture(0, 0, 0, 0)
	end
end

local function hideMenu()
	if menu then
		menu:Hide()
	end
end

local function ensureMenu()
	if menu then
		return menu
	end
	menu = CreateFrame("Frame", "SKFReconcileStatus", UIParent, "BackdropTemplate")
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
				local overMenu = self:IsMouseOver()
				local overAnchor = self.anchor and self.anchor:IsMouseOver()
				if not overMenu and not overAnchor then
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

local function choose(rowFrame, kind, choice)
	hideMenu()
	if kind == "shift" then
		local person = rowFrame.person
		if person then
			message = SK.List:SetDraft(person.name, { hold = choice == "Hold" }) or ""
		end
	elseif kind == "rolls" then
		local person = rowFrame.person
		if person then
			message = SK.List:SetDraft(person.name, { rolls = choice }) or ""
		end
	elseif rowFrame.guest then
		if choice == "--" then
			return
		end
		local info = rowFrame.info
		if choice == "Pug/fill" then
			message = SK.List:AddPug(info.name, info.class) or ""
		else
			message = SK.List:AddCore(info.name, info.class, choice) or ""
		end
	else
		local person = rowFrame.person
		message = SK.List:SetDraft(person.name, { status = choice }) or ""
	end
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end

local function openMenu(anchor, rowFrame, kind)
	local popup = ensureMenu()
	if popup:IsShown() and popup.anchor == anchor then
		popup:Hide()
		return
	end
	local choices = CORE_CHOICES
	if kind == "shift" then
		choices = SHIFT_CHOICES
	elseif kind == "rolls" then
		choices = SK.Rules.Reconcile.ROLLS
	elseif rowFrame.guest then
		choices = GUEST_CHOICES
	end
	local width = anchor:GetWidth()
	if not width or width < 70 then
		width = STATUS_W
	end
	for i = 1, #choices do
		local button = popup.buttons[i]
		if not button then
			button = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
			popup.buttons[i] = button
		end
		button:SetSize(width, 20)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 22)
		local choice = choices[i]
		button:SetText(choice)
		button:SetScript("OnClick", function()
			choose(rowFrame, kind, choice)
		end)
		button:Show()
	end
	for i = #choices + 1, #popup.buttons do
		popup.buttons[i]:Hide()
	end
	popup:SetSize(width + 16, 16 + #choices * 22)
	popup.anchor = anchor
	popup.down = true
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	popup:Show()
end

local showRemoveMenu

local function rowButton(index)
	local button = rows[index]
	if button then
		return button
	end
	button = CreateFrame("Frame", nil, content)
	button:SetSize(ROLLS_X + ROLLS_W + 8, ROW_H)
	button:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_H))
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.stripe = index % 2 == 0
	button:EnableMouse(true)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton ~= "LeftButton" or not self.person then
			return
		end
		selected = self.person.name
		paint()
	end)
	button.nameHit = CreateFrame("Button", nil, button)
	button.nameHit:SetPoint("LEFT", NAME_X, 0)
	button.nameHit:SetSize(NAME_W, ROW_H)
	button.nameHit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button.nameHit:SetScript("OnClick", function(self, mouseButton)
		local row = self:GetParent()
		if not row.person then
			return
		end
		if mouseButton == "RightButton" then
			showRemoveMenu(row.person.name)
			return
		end
		selected = row.person.name
		paint()
	end)
	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.name:SetPoint("LEFT", NAME_X, 0)
	button.name:SetWidth(NAME_W)
	button.name:SetJustifyH("LEFT")
	button.current = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.current:SetPoint("LEFT", CUR_X, 0)
	button.current:SetWidth(CUR_W)
	button.current:SetJustifyH("RIGHT")
	button.newpos = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.newpos:SetPoint("LEFT", NEW_X, 0)
	button.newpos:SetWidth(NEW_W)
	button.newpos:SetJustifyH("RIGHT")
	button.status = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
	button.status:SetSize(STATUS_W, 20)
	button.status:SetPoint("LEFT", STATUS_X, 0)
	button.status:SetScript("OnClick", function(self)
		local row = self:GetParent()
		if row.pugRow then
			return
		end
		openMenu(self, row, "status")
	end)
	button.shift = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
	button.shift:SetSize(SHIFT_W, 20)
	button.shift:SetPoint("LEFT", SHIFT_X, 0)
	button.shift:SetScript("OnClick", function(self)
		local row = self:GetParent()
		if row.pugRow or not row.person then
			return
		end
		openMenu(self, row, "shift")
	end)
	button.rolls = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
	button.rolls:SetSize(ROLLS_W, 20)
	button.rolls:SetPoint("LEFT", ROLLS_X, 0)
	button.rolls:SetScript("OnClick", function(self)
		local row = self:GetParent()
		if not row.person then
			return
		end
		openMenu(self, row, "rolls")
	end)
	rows[index] = button
	return button
end

local function hideFrom(index)
	for i = index, #rows do
		rows[i]:Hide()
	end
end

local function fullyUnseeded(list)
	local count = 0
	for i = 1, #list do
		if not list[i].pug then
			count = count + 1
			if list[i].position then
				return false
			end
		end
	end
	return count > 0
end

local insertOpen = false
local addOpen = false

local function editButton(text, width, x)
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("BOTTOMLEFT", x, 28)
	button:SetText(text)
	return button
end

local upBtn = editButton("Move up", 76, 0)
local downBtn = editButton("Move down", 86, 80)
local bottomBtn = editButton("Move bottom", 100, 170)
local insertBtn = editButton("Insert", 64, 274)
local addBtn = editButton("Add", 56, 342)

local removeMenu = CreateFrame("Frame", "SKFReconcileRemove", UIParent, "BackdropTemplate")
removeMenu:SetFrameStrata("TOOLTIP")
removeMenu:SetSize(120, 28)
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
removeMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
removeMenu:SetBackdropBorderColor(0.75, 0.62, 0.28, 1)
local removeItem = CreateFrame("Button", nil, removeMenu)
removeItem:SetPoint("TOPLEFT", 4, -4)
removeItem:SetPoint("BOTTOMRIGHT", -4, 4)
removeItem.text = removeItem:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
removeItem.text:SetPoint("LEFT", 8, 0)
removeItem.text:SetPoint("RIGHT", -6, 0)
removeItem.text:SetJustifyH("LEFT")
removeItem.text:SetText("Remove")
removeItem.text:SetTextColor(1, 0.45, 0.4)
removeItem.hi = removeItem:CreateTexture(nil, "BACKGROUND")
removeItem.hi:SetAllPoints()
if removeItem.hi.SetColorTexture then
	removeItem.hi:SetColorTexture(1, 0.82, 0, 0.16)
end
removeItem.hi:Hide()
removeItem:SetScript("OnEnter", function(self)
	self.hi:Show()
	self.text:SetTextColor(1, 0.82, 0)
end)
removeItem:SetScript("OnLeave", function(self)
	self.hi:Hide()
	self.text:SetTextColor(1, 0.45, 0.4)
end)

local function hideRemoveMenu()
	removeMenu.pending = nil
	removeMenu.arming = false
	removeMenu:Hide()
end

function showRemoveMenu(name)
	if not name or name == "" then
		return
	end
	removeMenu.pending = name
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	removeMenu:ClearAllPoints()
	removeMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 2, y / scale)
	removeMenu.arming = true
	removeMenu:Show()
end

removeMenu:SetScript("OnUpdate", function(self)
	if not self:IsShown() or not self.arming then
		return
	end
	if not IsMouseButtonDown("RightButton") then
		self.arming = false
	end
end)
removeMenu:SetScript("OnHide", function(self)
	self.arming = false
end)
removeItem:SetScript("OnClick", function()
	local name = removeMenu.pending
	hideRemoveMenu()
	if not name then
		return
	end
	message = SK.List:Remove(name) or ""
	if message == "" and selected == name then
		selected = nil
	end
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end)
local removeWatcher = CreateFrame("Frame", nil, UIParent)
removeWatcher:SetScript("OnUpdate", function()
	if not removeMenu:IsShown() or removeMenu.arming then
		return
	end
	local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if down and not removeMenu:IsMouseOver() then
		hideRemoveMenu()
	end
end)

local form = CreateFrame("Frame", nil, panel)
form:SetPoint("BOTTOMLEFT", 0, 54)
form:SetPoint("BOTTOMRIGHT", 0, 54)
form:SetHeight(50)
form:Hide()

local nameBox = CreateFrame("EditBox", nil, form, "InputBoxTemplate")
nameBox:SetSize(140, 20)
nameBox:SetPoint("BOTTOMLEFT", 8, 8)
nameBox:SetAutoFocus(false)
nameBox:SetMaxLetters(24)

local classBox = CreateFrame("EditBox", nil, form, "InputBoxTemplate")
classBox:SetSize(110, 20)
classBox:SetPoint("LEFT", nameBox, "RIGHT", 12, 0)
classBox:SetAutoFocus(false)
classBox:SetMaxLetters(16)

local formLabel = form:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
formLabel:SetPoint("BOTTOMLEFT", nameBox, "TOPLEFT", -4, 4)

local pugCheck = CreateFrame("CheckButton", nil, form)
pugCheck:SetSize(24, 24)
pugCheck:SetPoint("LEFT", classBox, "RIGHT", 8, 0)
pugCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
pugCheck:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
pugCheck:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
pugCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

local pugLabel = form:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pugLabel:SetPoint("LEFT", pugCheck, "RIGHT", 0, 0)
pugLabel:SetText("Pug / fill")

local commit = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
commit:SetSize(90, 22)
commit:SetPoint("LEFT", pugCheck, "RIGHT", 78, 0)
commit:SetText("Add name")

local cancelForm = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
cancelForm:SetSize(70, 22)
cancelForm:SetPoint("LEFT", commit, "RIGHT", 6, 0)
cancelForm:SetText("Cancel")

local function placeScroll(formOpen)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", 0, -66)
	scroll:SetPoint("BOTTOMRIGHT", -8, formOpen and 110 or 56)
end

local function hideForm()
	insertOpen = false
	addOpen = false
	form:Hide()
	nameBox:ClearFocus()
	classBox:ClearFocus()
	placeScroll(false)
end

local function updateAddButton()
	if addOpen then
		commit:SetText(pugCheck:GetChecked() and "Add pug" or "Add core")
	end
end

local function showForm(kind)
	insertOpen = kind == "insert"
	addOpen = kind == "add"
	hideRemoveMenu()
	if insertOpen then
		formLabel:SetText("Core name and class")
		commit:SetText("Add name")
		pugCheck:Hide()
		pugLabel:Hide()
	else
		formLabel:SetText("Name and class")
		pugCheck:SetChecked(false)
		pugCheck:Show()
		pugLabel:Show()
		updateAddButton()
	end
	nameBox:SetText("")
	classBox:SetText("")
	form:Show()
	placeScroll(true)
	nameBox:SetFocus()
end

pugCheck:SetScript("OnClick", updateAddButton)
hideForm()

local lockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
lockBtn:SetSize(140, 22)
lockBtn:SetPoint("BOTTOMLEFT", 0, 0)
lockBtn:SetText("Lock raid")

paint = function()
	if not panel:IsShown() then
		return
	end
	hideMenu()
	local base = SK.List:EnsurePosBase()
	local grouped = IsInGroup and IsInGroup()
	local raid = SK.Roster and SK.Roster:Members() or {}
	local list = SK.Saved:List()
	local seedingList = fullyUnseeded(list)
	local onList = {}
	for i = 1, #list do
		onList[string.lower(list[i].name)] = true
	end
	local line = 1
	for i = 1, #list do
		local row = list[i]
		local button = rowButton(line)
		button.stripe = line % 2 == 0
		button.person = row
		button.guest = false
		button.info = nil
		button.pugRow = row.pug and true or false
		local key = string.lower(row.name)
		local unset = not row.status or row.status == ""
		local missing = grouped and not row.pug and not raid[key] and unset and not seedingList
		paintRow(button, missing, selected == row.name)
		button.name:SetText(row.name)
		local file = SK.CLASS_FILE[row.class]
		local color = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
		if color then
			button.name:SetTextColor(color.r, color.g, color.b)
		else
			button.name:SetTextColor(1, 1, 1)
		end
		local had = base[key]
		local currentText = (had and had > 0) and tostring(had) or "—"
		local newText = row.position and tostring(row.position) or "—"
		button.current:SetText(currentText)
		button.newpos:SetText(newText)
		button.current:SetTextColor(0.75, 0.75, 0.75)
		if not row.pug and currentText ~= newText then
			button.newpos:SetTextColor(1, 0.82, 0)
		else
			button.newpos:SetTextColor(1, 1, 1)
		end
		button.status:Show()
		button.shift:Show()
		button.rolls:Show()
		if row.pug then
			button.status:SetText("Pug/fill")
			button.shift:SetText("—")
		else
			button.shift:SetText(row.hold and "Hold" or "Raise")
			if row.status and row.status ~= "" then
				button.status:SetText(row.status)
			elseif grouped and not raid[key] then
				button.status:SetText("--")
			else
				button.status:SetText("Present")
			end
		end
		button.rolls:SetText(row.rolls or (row.pug and "MS, OS" or "Bid, MS, OS"))
		button.status:SetEnabled(not row.pug)
		button.shift:SetEnabled(not row.pug)
		button.rolls:SetEnabled(true)
		button:Show()
		line = line + 1
	end
	local guests = {}
	for _, info in pairs(raid) do
		if not onList[string.lower(info.name)] then
			table.insert(guests, info)
		end
	end
	table.sort(guests, function(a, b)
		return a.name < b.name
	end)
	for i = 1, #guests do
		local info = guests[i]
		local button = rowButton(line)
		button.stripe = line % 2 == 0
		button.person = nil
		button.guest = true
		button.info = info
		button.pugRow = false
		paintRow(button, true)
		button.name:SetText(info.name)
		local file = SK.CLASS_FILE[info.class]
		local color = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
		if color then
			button.name:SetTextColor(color.r, color.g, color.b)
		else
			button.name:SetTextColor(1, 1, 1)
		end
		button.current:SetText("—")
		button.newpos:SetText("—")
		button.current:SetTextColor(0.75, 0.75, 0.75)
		button.newpos:SetTextColor(1, 1, 1)
		button.status:Show()
		button.status:SetText("--")
		button.status:SetEnabled(true)
		button.shift:Hide()
		button.rolls:Hide()
		button:Show()
		line = line + 1
	end
	hideFrom(line)
	content:SetHeight(math.max(ROW_H, (line - 1) * ROW_H))
	local picked = selected and SK.List:Find(selected)
	upBtn:SetEnabled(picked and not picked.pug)
	downBtn:SetEnabled(picked and not picked.pug)
	bottomBtn:SetEnabled(picked and not picked.pug)
	summary:SetText("Highlighted rows need a status. Lock still fills a blank in-raid name as Present and a blank missing name as Absent.")
	if message ~= "" then
		notice:SetText(message)
	elseif seedingList then
		notice:SetText("This list has no positions, so seeding rules apply. Missing raiders stay unhighlighted until the list has positions.")
	elseif not grouped then
		notice:SetText("You are not in a raid. Lock still saves status, and everyone left blank stays Present.")
	else
		notice:SetText("Highlighted rows are on the list and missing from the raid, or in the raid and not on the list. Choose a status to clear the highlight.")
	end
end

scroll:SetScript("OnMouseWheel", function(self, delta)
	hideMenu()
	local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
	local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * ROW_H))
	self:SetVerticalScroll(nextValue)
end)

upBtn:SetScript("OnClick", function()
	if not selected then
		return
	end
	message = SK.List:Move(selected, -1) or ""
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end)
downBtn:SetScript("OnClick", function()
	if not selected then
		return
	end
	message = SK.List:Move(selected, 1) or ""
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end)
bottomBtn:SetScript("OnClick", function()
	if not selected then
		return
	end
	message = SK.List:MoveBottom(selected) or ""
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end)
insertBtn:SetScript("OnClick", function()
	showForm("insert")
end)
addBtn:SetScript("OnClick", function()
	showForm("add")
end)
cancelForm:SetScript("OnClick", hideForm)
commit:SetScript("OnClick", function()
	local err
	if insertOpen or (addOpen and not pugCheck:GetChecked()) then
		err = SK.List:Insert(nameBox:GetText(), classBox:GetText())
	elseif addOpen then
		err = SK.List:AddPug(nameBox:GetText(), classBox:GetText())
	end
	if err then
		message = err
	else
		message = ""
		selected = SK.Trim(nameBox:GetText())
		hideForm()
	end
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end)
lockBtn:SetScript("OnClick", function()
	local text = SK.Session:LockRaid() or "Raid locked."
	if SK.UI.Note then
		SK.UI.Note(text)
	end
	if SK.UI.RefreshList then
		SK.UI.RefreshList()
	end
end)

function SK.UI.ShowReconcile(note)
	panel:Show()
	if type(note) == "string" and note ~= "" then
		message = note
	end
	paint()
end

function SK.UI.HideReconcile()
	hideMenu()
	hideForm()
	hideRemoveMenu()
	GameTooltip:Hide()
	panel:Hide()
end
