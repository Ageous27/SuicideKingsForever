local frame = SK.UI:CreateWindow("import", "Import")
local body = frame.body

local help = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
help:SetPoint("TOPLEFT", 4, 0)
help:SetPoint("TOPRIGHT", -4, 0)
help:SetJustifyH("LEFT")
help:SetWordWrap(true)
help:SetHeight(32)
help:SetText("Paste Position, Name, Class. Tabs or commas both work. Export makes a Discord code block. Merge with blank positions adds new names at the bottom. Replace with no positions starts seeding.")

local editBack = CreateFrame("Frame", nil, body, "BackdropTemplate")
editBack:SetPoint("TOPLEFT", 4, -36)
editBack:SetPoint("TOPRIGHT", -4, -36)
editBack:SetHeight(168)
editBack:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
editBack:SetBackdropColor(0, 0, 0, 0.85)
if editBack.SetClipsChildren then
	editBack:SetClipsChildren(true)
end

local scroll = CreateFrame("ScrollFrame", nil, editBack)
scroll:SetPoint("TOPLEFT", 8, -8)
scroll:SetPoint("BOTTOMRIGHT", -24, 8)
if scroll.SetClipsChildren then
	scroll:SetClipsChildren(true)
end

local bar = CreateFrame("Slider", "SKFImportScrollBar", editBack, "UIPanelScrollBarTemplate")
bar:SetPoint("TOPRIGHT", -2, -22)
bar:SetPoint("BOTTOMRIGHT", -2, 20)
local settingScroll = false
local suppressCursor = 0

bar:SetScript("OnValueChanged", function(_, value)
	if settingScroll then
		return
	end
	suppressCursor = 2
	scroll:SetVerticalScroll(value or 0)
end)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:Hide()

local edit = CreateFrame("EditBox", nil, scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetFontObject(ChatFontNormal)
edit:SetMaxLetters(8000)
edit:SetWidth(400)
edit:SetHeight(400)
scroll:SetScrollChild(edit)
edit:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)
scroll:SetScript("OnMouseDown", function()
	edit:SetFocus()
end)

local measure = editBack:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
measure:Hide()

local lineStep = 14

local function viewHeight()
	local view = scroll:GetHeight()
	if not view or view < 20 then
		view = (editBack:GetHeight() or 168) - 16
	end
	return view
end

local function setScroll(offset)
	local maxScroll = math.max(0, (edit:GetHeight() or 0) - viewHeight())
	if offset < 0 then
		offset = 0
	elseif offset > maxScroll then
		offset = maxScroll
	end
	settingScroll = true
	local barMax = math.max(maxScroll, 1)
	local _, curMax = bar:GetMinMaxValues()
	if math.abs((curMax or 0) - barMax) > 0.5 then
		bar:SetMinMaxValues(0, barMax)
	end
	if math.abs((bar:GetValue() or 0) - offset) > 0.5 then
		bar:SetValue(offset)
	end
	scroll:SetVerticalScroll(offset)
	settingScroll = false
	if maxScroll <= 1 then
		bar:Hide()
	else
		bar:Show()
	end
end

if bar.ScrollUpButton then
	bar.ScrollUpButton:SetScript("OnClick", function()
		suppressCursor = 3
		setScroll(scroll:GetVerticalScroll() - lineStep * 3)
	end)
end
if bar.ScrollDownButton then
	bar.ScrollDownButton:SetScript("OnClick", function()
		suppressCursor = 3
		setScroll(scroll:GetVerticalScroll() + lineStep * 3)
	end)
end

local function contentSize()
	local width = scroll:GetWidth()
	if not width or width < 20 then
		width = (editBack:GetWidth() or 420) - 28
	end
	local text = edit:GetText() or ""
	local _, fontSize = edit:GetFont()
	local spacing = 0
	if edit.GetSpacing then
		spacing = edit:GetSpacing() or 0
	end
	measure:SetFontObject(edit:GetFontObject() or ChatFontNormal)
	measure:SetText("Ag")
	local glyph = measure:GetStringHeight() or 0
	lineStep = math.max(14, (fontSize or 14) + spacing, glyph) + 3
	if text == "" then
		return width, lineStep + 8
	end
	local lines = 0
	local start = 1
	local len = string.len(text)
	while start <= len do
		local nl = string.find(text, "\n", start, true)
		local line
		if nl then
			line = string.sub(text, start, nl - 1)
			start = nl + 1
		else
			line = string.sub(text, start)
			start = len + 1
		end
		line = string.gsub(line, "\r", "")
		measure:SetText(line == "" and " " or line)
		local pixelWidth = measure:GetStringWidth() or 0
		local wraps = 1
		if width > 20 and pixelWidth > width then
			wraps = math.ceil(pixelWidth / width)
		end
		lines = lines + wraps
	end
	if string.sub(text, -1) == "\n" then
		lines = lines + 1
	end
	return width, math.max(1, lines) * lineStep + lineStep
end

local wantedWidth = 400
local wantedHeight = 168

local function applyBoxSize()
	if wantedWidth > 20 then
		edit:SetWidth(wantedWidth)
	end
	edit:SetHeight(wantedHeight)
	if scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
end

local function fitEdit()
	local width, textHeight = contentSize()
	wantedWidth = width
	wantedHeight = math.max(viewHeight(), textHeight)
	applyBoxSize()
	setScroll(scroll:GetVerticalScroll())
end

scroll:SetScript("OnUpdate", function()
	if suppressCursor > 0 then
		suppressCursor = suppressCursor - 1
	end
	local height = edit:GetHeight() or 0
	local width = edit:GetWidth() or 0
	if math.abs(height - wantedHeight) > 2 or math.abs(width - wantedWidth) > 2 then
		local keep = scroll:GetVerticalScroll()
		applyBoxSize()
		setScroll(keep)
	end
end)

local function onWheel(_, delta)
	suppressCursor = 3
	setScroll(scroll:GetVerticalScroll() - delta * lineStep)
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", onWheel)
edit:EnableMouseWheel(true)
edit:SetScript("OnMouseWheel", onWheel)
editBack:EnableMouseWheel(true)
editBack:SetScript("OnMouseWheel", onWheel)
edit:SetScript("OnCursorChanged", function(self, _, y, _, cursorHeight)
	if suppressCursor > 0 then
		return
	end
	local pos = self:GetCursorPosition() or 0
	if pos == self.skCursor then
		return
	end
	self.skCursor = pos
	local view = viewHeight()
	local cursor = -(y or 0)
	local offset = scroll:GetVerticalScroll()
	local height = cursorHeight or lineStep
	if cursor < offset then
		setScroll(cursor)
	elseif cursor + height > offset + view then
		setScroll(cursor + height - view)
	end
end)

local previewFrame = CreateFrame("Frame", nil, body)
previewFrame:SetPoint("TOPLEFT", editBack, "BOTTOMLEFT", 0, -8)
previewFrame:SetPoint("TOPRIGHT", editBack, "BOTTOMRIGHT", 0, -8)
previewFrame:SetHeight(150)
if previewFrame.SetClipsChildren then
	previewFrame:SetClipsChildren(true)
end

local previewLines = {}
for i = 1, 9 do
	local line = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line:SetPoint("TOPLEFT", 4, -((i - 1) * 16))
	line:SetPoint("RIGHT", -4, 0)
	line:SetJustifyH("LEFT")
	line:SetHeight(16)
	line:SetText("")
	previewLines[i] = line
end

local status = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetTextColor(1, 0.3, 0.3)
status:SetPoint("BOTTOMLEFT", 4, 32)
status:SetPoint("BOTTOMRIGHT", -4, 32)
status:SetJustifyH("LEFT")
status:SetHeight(32)

local replaceBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
replaceBtn:SetSize(100, 22)
replaceBtn:SetPoint("BOTTOMLEFT", 0, 0)
replaceBtn:SetText("Replace")

local mergeBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
mergeBtn:SetSize(100, 22)
mergeBtn:SetPoint("LEFT", replaceBtn, "RIGHT", 8, 0)
mergeBtn:SetText("Merge")

local exportBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
exportBtn:SetSize(100, 22)
exportBtn:SetPoint("LEFT", mergeBtn, "RIGHT", 8, 0)
exportBtn:SetText("Export")

local packed
local ready = false

local footer = CreateFrame("Frame", nil, frame)
footer:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
footer:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
footer:SetHeight(60)
footer:EnableMouse(true)

local function raiseFooter()
	local level = (edit:GetFrameLevel() or 1) + 30
	footer:SetFrameLevel(level)
	previewFrame:SetFrameLevel(level)
	replaceBtn:SetFrameLevel(level + 1)
	mergeBtn:SetFrameLevel(level + 1)
	exportBtn:SetFrameLevel(level + 1)
end

status:SetParent(footer)
status:ClearAllPoints()
status:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 4, 28)
status:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -4, 28)
replaceBtn:SetParent(footer)
replaceBtn:ClearAllPoints()
replaceBtn:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 0, 0)
mergeBtn:SetParent(footer)
mergeBtn:ClearAllPoints()
mergeBtn:SetPoint("LEFT", replaceBtn, "RIGHT", 8, 0)
exportBtn:SetParent(footer)
exportBtn:ClearAllPoints()
exportBtn:SetPoint("LEFT", mergeBtn, "RIGHT", 8, 0)
raiseFooter()

local function showPreview()
	status:SetTextColor(1, 0.3, 0.3)
	local rows, errors = SK.Rules.Placement.ParseCSV(edit:GetText())
	packed = nil
	ready = false
	local function setPreview(lines)
		for i = 1, #previewLines do
			previewLines[i]:SetText(lines[i] or "")
		end
	end
	if #errors > 0 then
		status:SetText(table.concat(errors, " "))
		setPreview({})
		replaceBtn:SetEnabled(false)
		mergeBtn:SetEnabled(false)
		return
	end
	local normalized, err = SK.Rules.Placement.Normalize(rows)
	if not normalized then
		status:SetText(err)
		setPreview({})
		replaceBtn:SetEnabled(false)
		mergeBtn:SetEnabled(false)
		return
	end
	local merged, mergeErr = SK.List:PlanMerge(rows)
	local lines = {}
	local unseeded = 0
	local incomingOpen = true
	for i = 1, #normalized do
		if not normalized[i].position then
			unseeded = unseeded + 1
		end
	end
	for i = 1, #rows do
		if rows[i].position then
			incomingOpen = false
		end
	end
	local mode = "Numbered list."
	if incomingOpen then
		mode = "No positions."
	elseif unseeded > 0 then
		mode = "Seeding."
	end
	lines[1] = string.format("%d names. %d unseeded. %s", #normalized, unseeded, mode)
	local shown = math.min(#normalized, 7)
	for i = 1, shown do
		local row = normalized[i]
		local pos = row.position and tostring(row.position) or "—"
		lines[#lines + 1] = string.format("%s  %s  %s", pos, row.name, row.class)
	end
	if #normalized > shown then
		lines[#lines + 1] = "and " .. (#normalized - shown) .. " more"
	end
	setPreview(lines)
	packed = normalized
	ready = true
	replaceBtn:SetEnabled(true)
	mergeBtn:SetEnabled(merged ~= nil)
	if mergeErr then
		status:SetTextColor(1, 0.3, 0.3)
		status:SetText(mergeErr)
	elseif incomingOpen then
		status:SetTextColor(1, 0.82, 0)
		status:SetText("Replace starts seeding. Merge adds new names at the bottom.")
	else
		status:SetText("")
	end
end

local function returnToList()
	edit:ClearFocus()
	frame:Hide()
	SK.UI:Open("list")
end

local replacing = false

StaticPopupDialogs["SKF_REPLACE_LIST"] = {
	text = "Are you sure you want to replace the entire list?",
	button1 = "Replace",
	button2 = "Cancel",
	OnAccept = function()
		if not ready or not packed then
			return
		end
		local err = SK.List:ReplaceCore(packed)
		if err then
			status:SetTextColor(1, 0.3, 0.3)
			status:SetText(err)
			return
		end
		replacing = true
		returnToList()
		replacing = false
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

edit:SetScript("OnTextChanged", function()
	fitEdit()
	showPreview()
end)
replaceBtn:SetScript("OnClick", function()
	if not ready or not packed then
		showPreview()
	end
	if not ready or not packed then
		status:SetTextColor(1, 0.3, 0.3)
		if status:GetText() == "" then
			status:SetText("Paste a list first.")
		end
		return
	end
	StaticPopup_Show("SKF_REPLACE_LIST")
end)
mergeBtn:SetScript("OnClick", function()
	status:SetTextColor(1, 0.3, 0.3)
	local rows, errors = SK.Rules.Placement.ParseCSV(edit:GetText())
	if #errors > 0 then
		status:SetText(table.concat(errors, " "))
		return
	end
	local err = SK.List:MergeCore(rows)
	if err then
		status:SetText(err)
		return
	end
	returnToList()
end)
exportBtn:SetScript("OnClick", function()
	edit:SetText(SK.List:ExportDiscord())
	edit:SetFocus()
	edit:HighlightText()
	status:SetTextColor(1, 0.82, 0)
	status:SetText("Export is selected. Ctrl+C copies the Discord code block.")
end)

frame:SetScript("OnShow", function()
	if not SK.Session:IsOfficer() then
		frame:Hide()
		SK.Print("Import stays with the officer.")
		return
	end
	fitEdit()
	showPreview()
	raiseFooter()
end)
frame:SetScript("OnHide", function()
	if not replacing then
		StaticPopup_Hide("SKF_REPLACE_LIST")
	end
end)
