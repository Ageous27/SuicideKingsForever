local frame = SK.UI:CreateWindow("history", "History")
frame:SetSize(640, 560)
local body = frame.body
local scroll = CreateFrame("ScrollFrame", nil, body)
scroll:SetPoint("TOPLEFT", 0, -26)
scroll:SetPoint("BOTTOMRIGHT", 0, 168)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(600, 20)
scroll:SetScrollChild(content)
scroll:EnableMouse(true)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
	local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
	local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 18))
	self:SetVerticalScroll(nextValue)
end)
local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("TOPLEFT", 4, -4)
label:SetWidth(600)
label:SetJustifyH("LEFT")
label:SetJustifyV("TOP")

local showEvery = false
local dayFilter = nil
local refresh
local scopeBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
scopeBtn:SetSize(140, 22)
scopeBtn:SetPoint("TOPLEFT", 0, 2)
scopeBtn:SetText("This team")
scopeBtn:SetScript("OnClick", function(self)
	showEvery = not showEvery
	self:SetText(showEvery and "Every team" or "This team")
	refresh(true)
end)

local dayBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
dayBtn:SetSize(140, 22)
dayBtn:SetPoint("LEFT", scopeBtn, "RIGHT", 8, 0)
dayBtn:SetText("All")

local function dayKey(event)
	return date("%Y-%m-%d", event.time or time())
end

local function onTeam(event)
	if showEvery or not event.teamId or event.teamId == "" then
		return true
	end
	if not SK.Teams then
		return true
	end
	return event.teamId == SK.Teams:TeamId()
end

local function wanted(event)
	if not onTeam(event) then
		return false
	end
	if dayFilter and dayKey(event) ~= dayFilter then
		return false
	end
	return true
end

dayBtn:SetScript("OnClick", function(self)
	local events = SK.History:Events()
	local seen = {}
	local days = {}
	for i = 1, #events do
		if onTeam(events[i]) then
			local key = dayKey(events[i])
			if not seen[key] then
				seen[key] = true
				table.insert(days, key)
			end
		end
	end
	table.sort(days, function(a, b)
		return a > b
	end)
	local rows = {
		{
			label = "All",
			fn = function()
				dayFilter = nil
				dayBtn:SetText("All")
				refresh(true)
			end,
		},
	}
	for i = 1, #days do
		local key = days[i]
		table.insert(rows, {
			label = key,
			fn = function()
				dayFilter = key
				dayBtn:SetText(key)
				refresh(true)
			end,
		})
	end
	SK.UI:Pick(self, rows, 10)
end)

function refresh(resetScroll)
	local events = SK.History:Events()
	local shown = {}
	for i = 1, #events do
		if wanted(events[i]) then
			table.insert(shown, events[i])
		end
	end
	if #shown == 0 then
		if dayFilter then
			label:SetText("No events on " .. dayFilter .. ".")
		else
			label:SetText("No events yet. List edits are recorded here.")
		end
		content:SetHeight(40)
		scroll:SetVerticalScroll(0)
		return
	end
	local lines = {}
	for i = #shown, 1, -1 do
		local event = shown[i]
		local when = date("%Y-%m-%d %H:%M:%S", event.time or time())
		local detail = event.detail or ""
		local name = event.name or ""
		local delivered = ""
		if event.type == "loot" and event.delivered then
			delivered = "  delivered"
		end
		local where = ""
		if event.listName and event.listName ~= "" then
			where = "  " .. (event.teamName or "") .. " / " .. event.listName
		end
		table.insert(lines, string.format("%s  %s  %s  %s  %s%s%s", when, event.type or "", event.action or "", name, detail, where, delivered))
	end
	label:SetText(table.concat(lines, "\n"))
	local textHeight = label:GetStringHeight() or 0
	if textHeight < 1 then
		textHeight = #lines * 14
	end
	content:SetHeight(math.max(40, textHeight + 8))
	local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
	if resetScroll == true then
		scroll:SetVerticalScroll(0)
	elseif scroll:GetVerticalScroll() > maxScroll then
		scroll:SetVerticalScroll(maxScroll)
	end
end

local note = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("BOTTOMLEFT", 4, 148)
note:SetPoint("BOTTOMRIGHT", -4, 148)
note:SetJustifyH("LEFT")
note:SetText("Export selects a Discord code block. Merge adds missing events and deletes nothing.")

local editBack = CreateFrame("Frame", nil, body, "BackdropTemplate")
editBack:SetPoint("BOTTOMLEFT", 0, 28)
editBack:SetPoint("BOTTOMRIGHT", 0, 28)
editBack:SetHeight(116)
editBack:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
editBack:SetBackdropColor(0, 0, 0, 0.85)

local editScroll = CreateFrame("ScrollFrame", nil, editBack)
editScroll:SetPoint("TOPLEFT", 6, -6)
editScroll:SetPoint("BOTTOMRIGHT", -6, 6)
local edit = CreateFrame("EditBox", nil, editScroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetFontObject(ChatFontNormal)
edit:SetMaxLetters(200000)
edit:SetWidth(580)
edit:SetHeight(200)
editScroll:SetScrollChild(edit)
edit:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)
edit:SetScript("OnTextChanged", function(self)
	local text = self:GetText() or ""
	local _, breaks = string.gsub(text, "\n", "\n")
	self:SetHeight(math.max(96, (breaks + 2) * 16))
end)
editScroll:EnableMouseWheel(true)
editScroll:SetScript("OnMouseWheel", function(self, delta)
	local maxScroll = math.max(0, (edit:GetHeight() or 0) - self:GetHeight())
	local nextValue = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 16))
	self:SetVerticalScroll(nextValue)
end)

local exportBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
exportBtn:SetSize(100, 22)
exportBtn:SetPoint("BOTTOMLEFT", 0, 0)
exportBtn:SetText("Export")

local mergeBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
mergeBtn:SetSize(140, 22)
mergeBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
mergeBtn:SetText("Import / Merge")

exportBtn:SetScript("OnClick", function()
	edit:SetText(SK.History:ExportDiscord())
	edit:SetFocus()
	edit:HighlightText()
	note:SetText("Export is selected. Ctrl+C copies the Discord code block.")
end)
mergeBtn:SetScript("OnClick", function()
	local events, errors = SK.History:Parse(edit:GetText())
	if #errors > 0 then
		note:SetText(table.concat(errors, " "))
		return
	end
	local added, skipped = SK.History:Merge(events)
	note:SetText("Added " .. tostring(added) .. ". " .. tostring(skipped) .. " were already saved.")
	edit:ClearFocus()
end)

SK.Events:On("SK_READY", refresh)
SK.Events:On("SK_HISTORY", refresh)
SK.Events:On("SK_DELIVERED", refresh)
frame:SetScript("OnShow", refresh)
