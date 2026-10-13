local frame = SK.UI:CreateWindow("list", "List")
frame:SetSize(740, 560)
local listRoot = CreateFrame("Frame", nil, frame.body)
listRoot:SetAllPoints()
local body = listRoot

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

function refresh()
	local reconcileMode = SK.Session:IsOfficer() and not SK.Session:IsLocked()
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
		you:SetText("You are not on the list.")
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
		summary:SetText("The list is empty. Import a CSV.")
	end

	local officer = SK.Session:IsOfficer()
	local locked = SK.Session:IsLocked()
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
frame:SetScript("OnShow", refresh)
frame:SetScript("OnHide", function()
	if SK.UI.HideReconcile then
		SK.UI.HideReconcile()
	end
end)
