local frame = SK.UI:CreateWindow("list", "List")
frame:SetSize(740, 588)
local listRoot = CreateFrame("Frame", nil, frame.body)
listRoot:SetPoint("TOPLEFT", 0, -28)
listRoot:SetPoint("BOTTOMRIGHT", 0, 0)
local body = listRoot

local teamBar = CreateFrame("Button", nil, frame.body, "UIPanelButtonTemplate")
teamBar:SetSize(180, 22)
teamBar:SetPoint("TOPLEFT", 4, 2)
teamBar:SetText("Team")
teamBar:SetScript("OnClick", function(self)
	if SK.Session:IsLocked() then
		return
	end
	local teams = SK.Teams:Catalog()
	local rows = {}
	for i = 1, #teams do
		local entry = teams[i]
		table.insert(rows, {
			label = entry.name,
			fn = function()
				local err = SK.Teams:SelectTeam(entry.id)
				if err then
					SK.Print(err)
				end
			end,
		})
	end
	if #rows > 0 then
		SK.UI:Pick(self, rows)
	end
end)

local listPick = CreateFrame("Button", nil, frame.body, "UIPanelButtonTemplate")
listPick:SetSize(160, 22)
listPick:SetPoint("TOPRIGHT", -4, 2)
listPick:SetText("Main")
listPick:SetScript("OnClick", function(self)
	local rows = {}
	local lists = SK.Teams:Lists()
	for i = 1, #lists do
		local entry = lists[i]
		table.insert(rows, {
			label = entry.name,
			fn = function()
				local err = SK.Teams:SelectList(entry.id)
				if err then
					SK.Print(err)
				end
			end,
		})
	end
	SK.UI:Pick(self, rows)
end)

local you = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
you:SetPoint("TOPLEFT", 4, -2)
you:SetPoint("TOPRIGHT", -4, -2)
you:SetJustifyH("LEFT")

local summary = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
summary:SetPoint("TOPLEFT", you, "BOTTOMLEFT", 0, -2)
summary:SetPoint("TOPRIGHT", you, "BOTTOMRIGHT", 0, -2)
summary:SetJustifyH("LEFT")

local scroll = CreateFrame("ScrollFrame", nil, body)
scroll:SetPoint("TOPLEFT", 0, -36)
scroll:SetPoint("BOTTOMRIGHT", -8, 56)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(430, 20)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
	local height = content:GetHeight()
	local view = self:GetHeight()
	local maxScroll = math.max(0, height - view)
	local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 18))
	self:SetVerticalScroll(nextValue)
end)

local buttons = {}
local message = ""
local refresh

local notice = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
notice:SetTextColor(1, 0.3, 0.3)
notice:SetPoint("BOTTOMLEFT", 4, 30)
notice:SetPoint("BOTTOMRIGHT", -4, 30)
notice:SetJustifyH("LEFT")
notice:SetHeight(16)

local function classColor(class)
	local file = SK.CLASS_FILE[class]
	local colors = RAID_CLASS_COLORS
	local color = file and colors and colors[file]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local function rowButton(index)
	local button = buttons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, content)
	button:SetSize(680, 18)
	button:SetPoint("TOPLEFT", 0, -((index - 1) * 18))
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.pos = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.pos:SetPoint("LEFT", 4, 0)
	button.pos:SetWidth(36)
	button.pos:SetJustifyH("RIGHT")
	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.name:SetPoint("LEFT", 64, 0)
	button.name:SetWidth(200)
	button.name:SetJustifyH("LEFT")
	button.class = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.class:SetPoint("LEFT", 272, 0)
	button.class:SetWidth(140)
	button.class:SetJustifyH("LEFT")
	button.status = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.status:SetPoint("LEFT", 420, 0)
	button.status:SetWidth(240)
	button.status:SetJustifyH("LEFT")
	buttons[index] = button
	return button
end

local controls = CreateFrame("Frame", nil, body)
controls:SetPoint("BOTTOMLEFT", 0, 0)
controls:SetPoint("BOTTOMRIGHT", 0, 0)
controls:SetHeight(28)

local function makeButton(text, width, x, y)
	local button = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("BOTTOMLEFT", x, y)
	button:SetText(text)
	return button
end

local endBtn = makeButton("End raid", 80, 0, 0)
local unlockBtn = makeButton("Unlock raid", 110, 88, 0)
unlockBtn:Hide()

local setupHold = {}
local setupError = ""
local setupTeam = nil

local setup = CreateFrame("Frame", nil, frame.body)
setup:SetPoint("TOPLEFT", 0, 0)
setup:SetPoint("BOTTOMRIGHT", 0, 0)
setup:SetFrameLevel((listRoot:GetFrameLevel() or 1) + 5)
setup:Hide()

local setupIntro = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
setupIntro:SetPoint("TOPLEFT", 4, 0)
setupIntro:SetPoint("TOPRIGHT", -4, 0)
setupIntro:SetJustifyH("LEFT")
setupIntro:SetText("Name this raid team, then paste the roster.")

local teamStep = setup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
teamStep:SetPoint("TOPLEFT", 4, -24)
teamStep:SetText("Raid team")

local teamEdit = CreateFrame("EditBox", nil, setup, "InputBoxTemplate")
teamEdit:SetSize(220, 20)
teamEdit:SetPoint("TOPLEFT", 12, -48)
teamEdit:SetAutoFocus(false)
teamEdit:SetMaxLetters(32)
teamEdit:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end)
teamEdit:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

local renameBtn = CreateFrame("Button", nil, setup, "UIPanelButtonTemplate")
renameBtn:SetSize(80, 22)
renameBtn:SetPoint("LEFT", teamEdit, "RIGHT", 12, 0)
renameBtn:SetText("Rename")

local newTeamBtn = CreateFrame("Button", nil, setup, "UIPanelButtonTemplate")
newTeamBtn:SetSize(90, 22)
newTeamBtn:SetPoint("LEFT", renameBtn, "RIGHT", 8, 0)
newTeamBtn:SetText("New team")

local switchBtn = CreateFrame("Button", nil, setup, "UIPanelButtonTemplate")
switchBtn:SetSize(110, 22)
switchBtn:SetPoint("LEFT", newTeamBtn, "RIGHT", 8, 0)
switchBtn:SetText("Switch team")
switchBtn:Hide()

local rosterStep = setup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rosterStep:SetPoint("TOPLEFT", 4, -84)
rosterStep:SetText("Roster")

local rosterHelp = setup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
rosterHelp:SetPoint("TOPLEFT", 4, -106)
rosterHelp:SetPoint("TOPRIGHT", -4, -106)
rosterHelp:SetJustifyH("LEFT")
rosterHelp:SetWordWrap(true)
rosterHelp:SetHeight(28)
rosterHelp:SetText("Paste one name per line. Position and class are optional. A first name fills in the last name and class from the raid. Tabs or commas both work. This lands on the first list.")

local pasteBack = CreateFrame("Frame", nil, setup, "BackdropTemplate")
pasteBack:SetPoint("TOPLEFT", 4, -136)
pasteBack:SetPoint("TOPRIGHT", -4, -136)
pasteBack:SetHeight(150)
pasteBack:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
pasteBack:SetBackdropColor(0, 0, 0, 0.85)
if pasteBack.SetClipsChildren then
	pasteBack:SetClipsChildren(true)
end

local pasteScroll = CreateFrame("ScrollFrame", nil, pasteBack)
pasteScroll:SetPoint("TOPLEFT", 8, -8)
pasteScroll:SetPoint("BOTTOMRIGHT", -8, 8)
if pasteScroll.SetClipsChildren then
	pasteScroll:SetClipsChildren(true)
end
pasteScroll:EnableMouse(false)
pasteScroll:EnableMouseWheel(true)

local paste = CreateFrame("EditBox", nil, pasteScroll)
paste:SetMultiLine(true)
paste:SetAutoFocus(false)
paste:EnableMouse(true)
paste:SetFontObject(GameFontHighlight)
paste:SetTextInsets(4, 4, 2, 2)
paste:SetWidth(660)
paste:SetHeight(140)
paste:SetMaxLetters(8000)
pasteScroll:SetScrollChild(paste)
paste:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

local caret = paste:CreateTexture(nil, "OVERLAY")
caret:SetSize(2, 14)
caret:SetColorTexture(1, 0.95, 0.7, 1)
caret:Hide()
local caretBlink = 0

local function placeCaret(self, x, y, h)
	local height = (h and h > 4) and h or 14
	caret:ClearAllPoints()
	caret:SetPoint("TOPLEFT", self, "TOPLEFT", x or 4, y or -2)
	caret:SetHeight(height)
	caret:Show()
	caretBlink = 0
	local top = -(y or 0)
	local view = pasteScroll:GetHeight()
	if not view or view < 20 then
		view = 130
	end
	local scroll = pasteScroll:GetVerticalScroll()
	local bottom = top + height
	if top < scroll then
		pasteScroll:SetVerticalScroll(top)
	elseif bottom > scroll + view then
		pasteScroll:SetVerticalScroll(math.max(0, bottom - view))
	end
end

paste:SetScript("OnCursorChanged", function(self, x, y, _, h)
	placeCaret(self, x, y, h)
end)
paste:SetScript("OnEditFocusGained", function(self)
	pasteBack:SetBackdropBorderColor(1, 0.82, 0, 1)
	caret:Show()
	caretBlink = 0
end)
paste:SetScript("OnEditFocusLost", function()
	pasteBack:SetBackdropBorderColor(0.75, 0.62, 0.28, 1)
	caret:Hide()
end)
paste:SetScript("OnUpdate", function(self, elapsed)
	if not self:HasFocus() then
		caret:Hide()
		return
	end
	caretBlink = caretBlink + (elapsed or 0)
	if caretBlink > 0.5 then
		caretBlink = 0
		if caret:IsShown() then
			caret:Hide()
		else
			caret:Show()
		end
	end
end)
paste:SetScript("OnTextChanged", function(self)
	local text = self:GetText() or ""
	local lines = 1
	for _ in string.gmatch(text, "\n") do
		lines = lines + 1
	end
	self:SetHeight(math.max(140, lines * 14 + 14))
end)
pasteScroll:SetScript("OnMouseWheel", function(self, delta)
	local maxScroll = math.max(0, paste:GetHeight() - self:GetHeight())
	local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 18))
	self:SetVerticalScroll(nextValue)
end)
pasteBack:SetScript("OnMouseDown", function()
	paste:SetFocus()
end)
pasteBack:SetBackdropBorderColor(0.75, 0.62, 0.28, 1)

local importBtn = CreateFrame("Button", nil, setup, "UIPanelButtonTemplate")
importBtn:SetSize(180, 22)
importBtn:SetPoint("TOPLEFT", 4, -294)
importBtn:SetText("Import onto Main")

local setupStatus = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
setupStatus:SetPoint("LEFT", importBtn, "RIGHT", 12, 0)
setupStatus:SetPoint("RIGHT", setup, "RIGHT", -4, 0)
setupStatus:SetJustifyH("LEFT")
setupStatus:SetHeight(32)
setupStatus:SetWordWrap(true)

local listStep = setup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listStep:SetPoint("TOPLEFT", 4, -330)
listStep:SetText("More lists")

local listHelp = setup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
listHelp:SetPoint("TOPLEFT", 4, -348)
listHelp:SetPoint("TOPRIGHT", -4, -348)
listHelp:SetJustifyH("LEFT")
listHelp:SetJustifyV("TOP")
listHelp:SetWordWrap(true)
listHelp:SetHeight(28)
listHelp:SetText("Import the roster first. A new list then starts with those names and blank positions. A list with no rules gets items no other list claims. Slot rules are in Settings.")

local listLine = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
listLine:SetPoint("TOPLEFT", 4, -378)
listLine:SetPoint("TOPRIGHT", -4, -378)
listLine:SetJustifyH("LEFT")
listLine:SetText("Current List: Main")

local listEdit = CreateFrame("EditBox", nil, setup, "InputBoxTemplate")
listEdit:SetSize(220, 20)
listEdit:SetPoint("TOPLEFT", 12, -400)
listEdit:SetAutoFocus(false)
listEdit:SetMaxLetters(32)
listEdit:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

local addListBtn = CreateFrame("Button", nil, setup, "UIPanelButtonTemplate")
addListBtn:SetSize(90, 22)
addListBtn:SetPoint("LEFT", listEdit, "RIGHT", 12, 0)
addListBtn:SetText("Add list")

local continueBtn = CreateFrame("Button", nil, setup, "UIPanelButtonTemplate")
continueBtn:SetSize(120, 22)
continueBtn:SetPoint("TOPLEFT", 4, -434)
continueBtn:SetText("Continue")
continueBtn:Hide()

local ask = CreateFrame("Frame", "SKFSetupAsk", UIParent, "BackdropTemplate")
ask:SetSize(320, 128)
ask:SetFrameStrata("DIALOG")
ask:SetClampedToScreen(true)
ask:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
ask:Hide()
ask:SetPoint("CENTER")
ask.title = ask:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ask.title:SetPoint("TOP", 0, -16)
ask.title:SetText("New team")
ask.edit = CreateFrame("EditBox", nil, ask, "InputBoxTemplate")
ask.edit:SetSize(200, 20)
ask.edit:SetPoint("TOP", 0, -48)
ask.edit:SetAutoFocus(false)
ask.edit:SetMaxLetters(32)
ask.cancel = CreateFrame("Button", nil, ask, "UIPanelButtonTemplate")
ask.cancel:SetSize(90, 22)
ask.cancel:SetPoint("BOTTOMLEFT", 40, 16)
ask.cancel:SetText("Cancel")
ask.create = CreateFrame("Button", nil, ask, "UIPanelButtonTemplate")
ask.create:SetSize(90, 22)
ask.create:SetPoint("BOTTOMRIGHT", -40, 16)
ask.create:SetText("Create")

local function hideAsk()
	ask:Hide()
	ask.edit:ClearFocus()
end

local function teamHasCore()
	if not SK.Teams then
		return false
	end
	local people = SK.Teams:People()
	for i = 1, #people do
		if not people[i].pug then
			return true
		end
	end
	return false
end

local function fixedList()
	local lists = SK.Teams:Lists()
	for i = 1, #lists do
		if lists[i].fixed then
			return lists[i]
		end
	end
	return lists[1]
end

local function paintSetup(ready)
	local blocked = SK.Session:TeamIsLocked() or SK.Session:Live()
	local teamId = SK.Teams:TeamId()
	if setupTeam ~= teamId then
		setupTeam = teamId
		setupError = ""
		if not teamEdit:HasFocus() then
			teamEdit:SetText(SK.Teams:TeamName())
		end
	elseif not teamEdit:HasFocus() then
		local name = SK.Teams:TeamName()
		if teamEdit:GetText() ~= name then
			teamEdit:SetText(name)
		end
	end
	local teams = SK.Teams:Catalog()
	switchBtn:SetShown(#teams > 1)
	local first = fixedList()
	local firstName = first and first.name or "Main"
	importBtn:SetText("Import onto " .. firstName)
	listLine:SetText("Current List: " .. SK.Teams:ListName())
	addListBtn:SetEnabled(ready and not blocked)
	continueBtn:SetShown(ready)
	importBtn:SetEnabled(not blocked)
	renameBtn:SetEnabled(not SK.Session:TeamIsLocked())
	newTeamBtn:SetEnabled(not SK.Session:Live())
	if ready then
		setupIntro:SetText("Add a list if weapons or trinkets need their own order. Continue when you are done.")
		listHelp:SetText("A new list starts with this roster and blank positions. A list with no rules gets items no other list claims. Slot rules are in Settings.")
	else
		setupIntro:SetText("Name this raid team, then paste the roster.")
		listHelp:SetText("Import the roster first. A new list then starts with those names and blank positions. A list with no rules gets items no other list claims. Slot rules are in Settings.")
	end
	if setupError ~= "" then
		setupStatus:SetTextColor(1, 0.3, 0.3)
		setupStatus:SetText(setupError)
	elseif ready then
		local count = #SK.List:Core()
		setupStatus:SetTextColor(1, 0.82, 0)
		setupStatus:SetText(count .. " names on " .. firstName .. ".")
	elseif blocked and SK.Session:Live() then
		setupStatus:SetTextColor(1, 0.3, 0.3)
		setupStatus:SetText("An item is live.")
	elseif blocked then
		setupStatus:SetTextColor(1, 0.3, 0.3)
		setupStatus:SetText("The raid is locked.")
	else
		setupStatus:SetText("")
	end
end

local function showSetup(ready)
	listRoot:Hide()
	if SK.UI.HideReconcile then
		SK.UI.HideReconcile()
	end
	teamBar:Hide()
	listPick:Hide()
	if frame.page then
		frame.page:SetText("List")
	end
	if frame.menuButton then
		frame.menuButton:SetText("List")
	end
	paintSetup(ready)
	setup:Show()
end

renameBtn:SetScript("OnClick", function()
	local err = SK.Teams:RenameTeam(teamEdit:GetText())
	if err then
		setupError = err
	else
		setupError = ""
		teamEdit:ClearFocus()
	end
	refresh()
end)

newTeamBtn:SetScript("OnClick", function()
	ask.edit:SetText("")
	ask:Show()
	ask.edit:SetFocus()
end)

ask.cancel:SetScript("OnClick", hideAsk)
ask.create:SetScript("OnClick", function()
	local name = ask.edit:GetText()
	hideAsk()
	local err = SK.Teams:AddTeam(name)
	if err then
		setupError = err
	else
		setupError = ""
	end
	refresh()
end)
ask.edit:SetScript("OnEnterPressed", function()
	ask.create:Click()
end)
ask.edit:SetScript("OnEscapePressed", function()
	hideAsk()
end)

switchBtn:SetScript("OnClick", function(self)
	local teams = SK.Teams:Catalog()
	local rows = {}
	for i = 1, #teams do
		local entry = teams[i]
		table.insert(rows, {
			label = entry.name,
			fn = function()
				local err = SK.Teams:SelectTeam(entry.id)
				if err then
					setupError = err
					refresh()
				end
			end,
		})
	end
	SK.UI:Pick(self, rows)
end)

importBtn:SetScript("OnClick", function()
	if SK.Session:TeamIsLocked() then
		setupError = "The raid is locked."
		refresh()
		return
	end
	if SK.Session:Live() then
		setupError = "An item is live."
		refresh()
		return
	end
	local rows, errors = SK.Rules.Placement.ParseCSV(paste:GetText())
	if #errors > 0 then
		setupError = table.concat(errors, " ")
		refresh()
		return
	end
	if #rows == 0 then
		setupError = "Paste a list first."
		refresh()
		return
	end
	local normalized, err = SK.Rules.Placement.Normalize(rows)
	if not normalized then
		setupError = err or "That list could not be read."
		refresh()
		return
	end
	local first = fixedList()
	if first then
		local selErr = SK.Teams:SelectList(first.id)
		if selErr then
			setupError = selErr
			refresh()
			return
		end
	end
	local teamId = SK.Teams:TeamId()
	if teamId then
		setupHold[teamId] = true
	end
	local replaceErr = SK.List:ReplaceCore(normalized)
	if replaceErr then
		if teamId then
			setupHold[teamId] = nil
		end
		setupError = replaceErr
		refresh()
		return
	end
	setupError = ""
	paste:ClearFocus()
	refresh()
end)

addListBtn:SetScript("OnClick", function()
	local err = SK.Teams:AddList(listEdit:GetText())
	if err then
		setupError = err
	else
		setupError = ""
		listEdit:SetText("")
		listEdit:ClearFocus()
	end
	refresh()
end)
listEdit:SetScript("OnEnterPressed", function(self)
	addListBtn:Click()
	self:ClearFocus()
end)

continueBtn:SetScript("OnClick", function()
	local first = fixedList()
	if first then
		SK.Teams:SelectList(first.id)
	end
	local teamId = SK.Teams:TeamId()
	if teamId then
		setupHold[teamId] = nil
	end
	setupError = ""
	paste:ClearFocus()
	teamEdit:ClearFocus()
	listEdit:ClearFocus()
	hideAsk()
	refresh()
end)

local matchingRaid = false

function refresh()
	if not matchingRaid and SK.Session and SK.Session.DetectRaid then
		matchingRaid = true
		SK.Session:DetectRaid()
		matchingRaid = false
	end
	local officer = SK.Session:IsOfficer()
	local teamId = SK.Teams and SK.Teams:TeamId()
	local emptyTeam = not teamHasCore()
	if emptyTeam and teamId then
		setupHold[teamId] = nil
	end
	if officer and teamId and (emptyTeam or setupHold[teamId]) then
		showSetup(setupHold[teamId] and true or false)
		message = ""
		return
	end
	setup:Hide()
	hideAsk()
	teamBar:Show()
	if SK.Teams then
		teamBar:SetText(SK.Teams:TeamName())
		teamBar:SetEnabled(not SK.Session:IsLocked())
		local lists = SK.Teams:Lists()
		if #lists > 1 then
			listPick:SetText(SK.Teams:ListName())
			listPick:Show()
		else
			listPick:Hide()
		end
	end
	local reconcileMode = SK.Session:IsOfficer() and not SK.Session:TeamIsLocked()
	local modeName = reconcileMode and "Reconcile" or "List"
	if frame.page then
		frame.page:SetText(modeName)
	end
	if frame.menuButton then
		frame.menuButton:SetText(modeName)
	end
	if reconcileMode then
		listRoot:Hide()
		if SK.UI.ShowReconcile then
			SK.UI.ShowReconcile(message)
		end
		message = ""
		return
	end
	if SK.UI.HideReconcile then
		SK.UI.HideReconcile()
	end
	listRoot:Show()
	local list = SK.Saved:List()
	local player = UnitName("player")
	local mine = player and SK.List:Find(player)
	if not mine then
		you:SetText("You are not on this list.")
	elseif mine.pug then
		you:SetText("You are " .. mine.name .. ", pug / fill, bottom of the list for this raid.")
	elseif mine.position then
		you:SetText(string.format("You are %s, position %d, %s.", mine.name, mine.position, SK.List.StatusText(mine)))
	else
		you:SetText("You are " .. mine.name .. ", unseeded.")
	end
	local core = SK.List:Core()
	local unseeded = 0
	for i = 1, #core do
		if not core[i].position then
			unseeded = unseeded + 1
		end
	end
	local pugs = SK.List:Pugs()
	local seed = SK.Session:IsSeeding() and " Seeding." or ""
	summary:SetText(string.format("%d core. %d unseeded. %d pug / fill.%s", #core, unseeded, #pugs, seed))

	for i = 1, #list do
		local button = rowButton(i)
		local row = list[i]
		button.rowName = row.name
		button.pos:SetText(row.position and tostring(row.position) or "—")
		button.name:SetText(row.name)
		button.name:SetTextColor(classColor(row.class))
		button.class:SetText(row.class)
		button.status:SetText(SK.List.StatusText(row))
		if i % 2 == 0 then
			button.bg:SetColorTexture(1, 1, 1, 0.04)
		else
			button.bg:SetColorTexture(0, 0, 0, 0)
		end
		button:Show()
	end
	for i = #list + 1, #buttons do
		buttons[i]:Hide()
	end
	local height = math.max(18, #list * 18)
	content:SetHeight(height)
	local maxScroll = math.max(0, height - (scroll:GetHeight() > 0 and scroll:GetHeight() or 1))
	if scroll:GetVerticalScroll() > maxScroll then
		scroll:SetVerticalScroll(maxScroll)
	end
	if #list == 0 then
		if officer then
			summary:SetText("The list is empty. Import a CSV.")
		else
			summary:SetText("The officer has not set up this raid.")
		end
	end


	local locked = SK.Session:TeamIsLocked()
	controls:SetShown(officer)
	scroll:SetPoint("BOTTOMRIGHT", -16, officer and 56 or 8)
	notice:ClearAllPoints()
	notice:SetPoint("BOTTOMLEFT", 4, officer and 30 or 4)
	notice:SetPoint("BOTTOMRIGHT", -4, officer and 30 or 4)
	notice:SetText(message)
	if not officer then
		unlockBtn:Hide()
		return
	end
	endBtn:SetEnabled(#pugs > 0)
	unlockBtn:SetShown(locked)
	unlockBtn:SetEnabled(locked)
end

endBtn:SetScript("OnClick", function()
	message = SK.List:EndRaid() or ""
	refresh()
end)
unlockBtn:SetScript("OnClick", function()
	message = SK.Session:UnlockRaid() or "Raid unlocked."
	refresh()
end)

function SK.UI.RefreshList()
	refresh()
end

function SK.UI.Note(text)
	message = text or ""
end

SK.Events:On("SK_READY", refresh)
SK.Events:On("SK_LIST_CHANGED", refresh)
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
frame:SetScript("OnShow", function()
	if SK.Session and SK.Session.DetectRaid then
		SK.Session:DetectRaid()
	end
	refresh()
end)
frame:SetScript("OnHide", function()
	if SK.UI.HideReconcile then
		SK.UI.HideReconcile()
	end
	hideAsk()
	paste:ClearFocus()
	teamEdit:ClearFocus()
	listEdit:ClearFocus()
end)
