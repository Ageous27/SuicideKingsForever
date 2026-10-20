local ICON = "Interface\\AddOns\\SuicideKingsForever\\Textures\\Minimap"

local button = CreateFrame("Button", "SKFMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
if button.SetPushedTextOffset then
	button:SetPushedTextOffset(0, 0)
end

-- The crown is the button art. Ellesmere looks for button.icon and, on click,
-- lifts its black plate (a child frame) above that art. The plate stays there.
button:SetNormalTexture(ICON)
button:SetPushedTexture(ICON)
local icon = button:GetNormalTexture()
local pushed = button:GetPushedTexture()
if icon then
	icon:SetTexCoord(0, 1, 0, 1)
	icon:SetVertexColor(1, 1, 1)
	button.icon = icon
end
if pushed then
	pushed:SetTexCoord(0, 1, 0, 1)
	pushed:SetVertexColor(1, 1, 1)
end

local function brighten(self)
	local art = self.icon or self:GetNormalTexture()
	if art then
		art:SetVertexColor(1, 1, 1)
		art:SetAlpha(1)
		if art.SetDesaturated then
			art:SetDesaturated(false)
		end
	end
	local pushedTex = self:GetPushedTexture()
	if pushedTex then
		pushedTex:SetVertexColor(1, 1, 1)
		pushedTex:SetAlpha(1)
	end
end

-- Ellesmere's click hook raises every child, including the black plate, over the crown.
-- Put those children behind the button again once the click has already opened the window.
local function parkCovers(self)
	local level = self:GetFrameLevel() or 1
	local strata = self:GetFrameStrata() or "MEDIUM"
	local children = { self:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		child:SetFrameStrata(strata)
		if level > 1 then
			child:SetFrameLevel(level - 1)
		end
	end
	if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
		self:SetButtonState("NORMAL")
	end
	brighten(self)
end

local parkTicks = 0
local parker = CreateFrame("Frame")
parker:Hide()
parker:SetScript("OnUpdate", function(self)
	parkTicks = parkTicks + 1
	if parkTicks >= 2 then
		parkCovers(button)
	end
	if parkTicks >= 6 then
		parkTicks = 0
		self:Hide()
	end
end)

local function parkSoon()
	parkTicks = 0
	parker:Show()
end

local menu = CreateFrame("Frame", "SKFMinimapMenu", UIParent, "BackdropTemplate")
menu:SetFrameStrata("TOOLTIP")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:Hide()
menu:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
menu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
menu:SetBackdropBorderColor(0.75, 0.62, 0.28, 1)
menu.buttons = {}

local function onMinimap()
	return button:GetParent() == Minimap
end

local function place(angle)
	if not onMinimap() then
		return
	end
	angle = tonumber(angle) or 225
	angle = angle % 360
	local rad = math.rad(angle)
	local radius = (Minimap:GetWidth() / 2) + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
	button.angle = angle
end

local function savedAngle()
	if type(SKDB) == "table" and type(SKDB.minimapAngle) == "number" then
		return SKDB.minimapAngle
	end
	return 225
end

local function wantsButton()
	if type(SKDB) ~= "table" or type(SKDB.settings) ~= "table" then
		return true
	end
	return SKDB.settings.minimapShown ~= false
end

local function applyVisibility()
	if not wantsButton() then
		menu.arming = false
		menu:Hide()
		button:Hide()
		return
	end
	button:Show()
	place(savedAngle())
end

local function cursorAngle()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not scale or scale == 0 then
		scale = 1
	end
	cx = cx / scale
	cy = cy / scale
	local mx, my = Minimap:GetCenter()
	return math.deg(math.atan2(cy - my, cx - mx))
end

local function menuItem(index)
	local row = menu.buttons[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, menu)
	row:SetHeight(20)
	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.text:SetPoint("LEFT", 8, 0)
	row.text:SetPoint("RIGHT", -8, 0)
	row.text:SetJustifyH("LEFT")
	row.hi = row:CreateTexture(nil, "BACKGROUND")
	row.hi:SetAllPoints()
	if row.hi.SetColorTexture then
		row.hi:SetColorTexture(1, 0.82, 0, 0.16)
	end
	row.hi:Hide()
	row:SetScript("OnEnter", function(self)
		self.hi:Show()
		self.text:SetTextColor(1, 0.82, 0)
	end)
	row:SetScript("OnLeave", function(self)
		self.hi:Hide()
		self.text:SetTextColor(1, 1, 1)
	end)
	menu.buttons[index] = row
	return row
end

local function hideMenu()
	menu.arming = false
	menu:Hide()
end

local function showMenu()
	local entries = SK.UI.entries or {}
	local shown = {}
	for i = 1, #entries do
		local entry = entries[i]
		if SK.UI.windows[entry.id] then
			table.insert(shown, entry)
		end
	end
	local width = 108
	for i = 1, #shown do
		local entry = shown[i]
		local row = menuItem(i)
		row:SetWidth(width)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
		row.text:SetText(entry.label)
		row.text:SetTextColor(1, 1, 1)
		row.hi:Hide()
		row:SetScript("OnClick", function()
			hideMenu()
			if entry.officer and not (SK.Session and SK.Session:IsOfficer()) then
				local title = SK.UI.titles[entry.id] or entry.label
				SK.Print(title .. " stays with the officer.")
				return
			end
			for id, frame in pairs(SK.UI.windows) do
				if id ~= entry.id and frame:IsShown() then
					frame:Hide()
				end
			end
			if SK.UI.menu and SK.UI.menu:IsShown() then
				SK.UI.menu:Hide()
			end
			SK.UI:Open(entry.id)
		end)
		row:Show()
	end
	for i = #shown + 1, #menu.buttons do
		menu.buttons[i]:Hide()
	end
	menu:SetSize(width + 8, 8 + #shown * 22)
	menu.arming = true
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", button, "TOPLEFT", -4, 0)
	menu:Show()
end

menu:SetScript("OnUpdate", function(self)
	if not self:IsShown() then
		return
	end
	local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if down then
		if not self.arming and not self:IsMouseOver() and not button:IsMouseOver() then
			hideMenu()
		end
	else
		self.arming = false
	end
end)

button:SetScript("OnClick", function(self, which)
	if self.dragged then
		self.dragged = false
		parkSoon()
		return
	end
	if which == "RightButton" then
		if IsAltKeyDown() then
			hideMenu()
			local link
			if GetCursorInfo then
				local kind, _, cursorLink = GetCursorInfo()
				if kind == "item" and type(cursorLink) == "string" then
					link = cursorLink
				end
			end
			if link and SK.Session and SK.Session.Queue then
				SK.Session:Queue(link)
				if ClearCursor then
					ClearCursor()
				end
			end
			if SK.UI and SK.UI.Open then
				SK.UI:Open("rolls")
			end
			parkSoon()
			return
		end
		if menu:IsShown() then
			hideMenu()
		else
			showMenu()
		end
		parkSoon()
		return
	end
	hideMenu()
	SK.UI:Toggle("list")
	parkSoon()
end)

button:SetScript("OnDragStart", function(self)
	if IsShiftKeyDown() or not onMinimap() then
		return
	end
	hideMenu()
	self.dragged = true
	self:SetScript("OnUpdate", function()
		if not onMinimap() then
			return
		end
		local angle = cursorAngle()
		place(angle)
		if type(SKDB) == "table" then
			SKDB.minimapAngle = angle
		end
	end)
end)

button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	parkSoon()
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Suicide Kings Forever")
	GameTooltip:AddLine("Left-click: List", 1, 1, 1)
	GameTooltip:AddLine("Right-click: windows", 1, 1, 1)
	GameTooltip:AddLine("Alt-Right click: Add Item", 1, 1, 1)
	GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
	brighten(self)
	GameTooltip:Hide()
end)

SK.Minimap = SK.Minimap or {}

function SK.Minimap:Apply()
	applyVisibility()
end

SK.Events:On("SK_READY", applyVisibility)

applyVisibility()
