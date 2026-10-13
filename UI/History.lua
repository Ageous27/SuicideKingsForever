local frame = SK.UI:CreateWindow("history", "History")
frame:SetSize(640, 560)
local body = frame.body
local scroll = CreateFrame("ScrollFrame", nil, body)
scroll:SetPoint("TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", 0, 168)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(430, 20)
scroll:SetScrollChild(content)
local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("TOPLEFT", 4, -4)
label:SetWidth(600)
label:SetJustifyH("LEFT")
label:SetJustifyV("TOP")

local function refresh()
	local events = SK.History:Events()
	if #events == 0 then
		label:SetText("No events yet. List edits are recorded here.")
		content:SetHeight(40)
		return
	end
	local lines = {}
	local startAt = math.max(1, #events - 40)
	for i = #events, startAt, -1 do
		local event = events[i]
		local when = date("%H:%M:%S", event.time or time())
		local detail = event.detail or ""
		local name = event.name or ""
		local delivered = ""
		if event.type == "loot" and event.delivered then
			delivered = "  delivered"
		end
		table.insert(lines, string.format("%s  %s  %s  %s  %s%s", when, event.type or "", event.action or "", name, detail, delivered))
	end
	label:SetText(table.concat(lines, "\n"))
	content:SetHeight(math.max(40, #lines * 14 + 8))
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
