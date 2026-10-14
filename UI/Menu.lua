SK = SK or {}
SK.UI = SK.UI or {}

SK.UI.windows = {}
SK.UI.titles = {}
SK.UI.entries = {
	{ id = "list", label = "List", officer = false },
	{ id = "import", label = "Import", officer = true },
	{ id = "rolls", label = "Rolls", officer = true },
	{ id = "history", label = "History", officer = false },
	{ id = "settings", label = "Settings", officer = false },
}

local GROUP = {
	list = "main",
	import = "main",
	history = "main",
	settings = "main",
	rolls = "rolls",
}

local function layoutPoint(id)
	local group = GROUP[id]
	if not group then
		return "CENTER", "CENTER", 0, 0
	end
	local saved = SKDB and SKDB.layout and SKDB.layout[group]
	if type(saved) == "table" and saved.point then
		return saved.point, saved.rel or "CENTER", saved.x or 0, saved.y or 0
	end
	return "CENTER", "CENTER", 0, 0
end

function SK.UI:ResetLayout()
	if type(SKDB) == "table" then
		SKDB.layout = {}
	end
	for _, window in pairs(self.windows) do
		window:SetUserPlaced(false)
		self:ApplyLayout(window)
	end
	local function center(name)
		local window = _G[name]
		if not window then
			return
		end
		window:SetUserPlaced(false)
		window:ClearAllPoints()
		window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	center("SKFRaiderPopup")
	center("SKFLateJoin")
	center("SKFGargulChoice")
end

function SK.UI:Opacity()
	local alpha = 1
	if type(SKDB) == "table" and type(SKDB.settings) == "table" then
		alpha = tonumber(SKDB.settings.opacity) or 1
	end
	if alpha < 0 then
		alpha = 0
	elseif alpha > 1 then
		alpha = 1
	end
	return alpha
end

function SK.UI:Paint(frame)
	if not frame or not frame.GetRegions then
		return
	end
	if not frame.skfShade then
		local shade = frame:CreateTexture(nil, "BACKGROUND")
		shade:SetDrawLayer("BACKGROUND", 7)
		shade:SetColorTexture(0.07, 0.07, 0.07, 1)
		shade:SetAllPoints()
		frame.skfShade = shade
	end
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local region = regions[i]
		if region ~= frame.skfShade and region.GetDrawLayer and region.SetAlpha and region:GetDrawLayer() == "BACKGROUND" then
			region:SetAlpha(0)
		end
	end
	frame.skfShade:SetAlpha(self:Opacity())
end

function SK.UI:ApplyOpacity()
	for _, frame in pairs(self.windows) do
		self:Paint(frame)
	end
	self:Paint(self.menu)
	self:Paint(_G.SKFRaiderPopup)
	self:Paint(_G.SKFLateJoin)
	self:Paint(_G.SKFGargulChoice)
end

function SK.UI:ApplyLayout(frame)
	if not frame then
		return
	end
	local point, rel, x, y = layoutPoint(frame.id)
	frame:SetUserPlaced(false)
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, rel, x, y)
end

function SK.UI:RememberLayout(frame)
	local group = GROUP[frame.id]
	if not group or type(SKDB) ~= "table" then
		return
	end
	local point, _, rel, x, y = frame:GetPoint(1)
	if not point then
		return
	end
	SKDB.layout = SKDB.layout or {}
	SKDB.layout[group] = {
		point = point,
		rel = rel or "CENTER",
		x = x or 0,
		y = y or 0,
	}
	frame:SetUserPlaced(false)
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, rel or "CENTER", x or 0, y or 0)
	for id, other in pairs(self.windows) do
		if other ~= frame and GROUP[id] == group then
			other:SetUserPlaced(false)
			other:ClearAllPoints()
			other:SetPoint(point, UIParent, rel or "CENTER", x or 0, y or 0)
		end
	end
end

local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

function SK.UI:CreateWindow(id, title)
	local frame = CreateFrame("Frame", "SKF" .. id, UIParent, "BackdropTemplate")
	frame:SetSize(480, 520)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SK.UI:RememberLayout(self)
	end)
	frame:SetBackdrop(BACKDROP)
	frame:Hide()
	frame.id = id

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -14)
	heading:SetText(SK.TITLE)

	local page = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	page:SetPoint("TOPLEFT", 16, -36)
	page:SetText(title)
	frame.page = page

	local drop = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	drop:SetSize(120, 22)
	drop:SetPoint("TOPRIGHT", -32, -12)
	drop:SetText(title)
	frame.menuButton = drop
	drop:SetScript("OnClick", function()
		SK.UI:ToggleMenu(frame)
	end)

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", 14, -58)
	body:SetPoint("BOTTOMRIGHT", -14, 14)
	frame.body = body

	self.windows[id] = frame
	self.titles[id] = title
	self:ApplyLayout(frame)
	self:Paint(frame)
	tinsert(UISpecialFrames, frame:GetName())
	return frame
end

function SK.UI:Open(id)
	local frame = self.windows[id]
	if not frame then
		return
	end
	self:ApplyLayout(frame)
	frame:Show()
end

function SK.UI:Toggle(id)
	local frame = self.windows[id]
	if not frame then
		return
	end
	if frame:IsShown() then
		frame:Hide()
	else
		self:ApplyLayout(frame)
		frame:Show()
	end
end

SK.Events:On("SK_READY", function()
	for _, frame in pairs(SK.UI.windows) do
		SK.UI:ApplyLayout(frame)
	end
	SK.UI:ApplyOpacity()
end)

SK.Events:On("SK_SETTINGS", function()
	SK.UI:ApplyOpacity()
end)

function SK.UI:ToggleMenu(owner)
	local menu = self.menu
	if menu and menu:IsShown() and menu.owner == owner then
		menu:Hide()
		return
	end
	if not menu then
		menu = CreateFrame("Frame", "SKFMenu", UIParent, "BackdropTemplate")
		menu:SetFrameStrata("DIALOG")
		menu:SetBackdrop(BACKDROP)
		menu.buttons = {}
		self.menu = menu
		self:Paint(menu)
	end
	local shown = {}
	local officer = SK.Session:IsOfficer()
	for i = 1, #self.entries do
		local entry = self.entries[i]
		if self.windows[entry.id] and (officer or not entry.officer) then
			table.insert(shown, entry)
		end
	end
	for i = 1, #shown do
		local button = menu.buttons[i]
		if not button then
			button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
			button:SetSize(110, 22)
			button:SetPoint("TOP", 0, -10 - (i - 1) * 24)
			menu.buttons[i] = button
		end
		local entry = shown[i]
		button:SetText(entry.label)
		button:SetScript("OnClick", function()
			menu:Hide()
			if owner then
				owner:Hide()
			end
			SK.UI:Open(entry.id)
		end)
		button:Show()
	end
	for i = #shown + 1, #menu.buttons do
		menu.buttons[i]:Hide()
	end
	menu:SetSize(130, 16 + #shown * 24)
	menu.owner = owner
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -28, -36)
	menu:Show()
end

SLASH_SKF1 = "/sk"
SLASH_SKF2 = "/skf"
SLASH_SKF3 = "/suicidekings"
SlashCmdList.SKF = function(msg)
	msg = string.lower(SK.Trim(msg))
	if msg == "debug" then
		SK.Debug.on = not SK.Debug.on
		SK.Print("debug " .. (SK.Debug.on and "on" or "off") .. ". " .. SK.Debug:Status())
		if SK.Debug.on then
			SK.Debug:Dump()
		end
		return
	end
	if msg == "rolls" then
		if not SK.Session:IsOfficer() then
			SK.Print("Rolls stays with the officer.")
			return
		end
		SK.UI:Toggle("rolls")
		return
	end
	local page = {
		list = "list",
		import = "import",
		reconcile = "list",
		history = "history",
		settings = "settings",
	}
	local id = page[msg] or "list"
	local entryOfficer = {
		import = true,
	}
	if entryOfficer[id] and not SK.Session:IsOfficer() then
		SK.Print(SK.UI.titles[id] .. " stays with the officer.")
		return
	end
	SK.UI:Toggle(id)
end

local pick

function SK.UI:Pick(anchor, rows, maxLines)
	if not pick then
		pick = CreateFrame("Frame", "SKFPick", UIParent, "BackdropTemplate")
		pick:SetFrameStrata("DIALOG")
		pick:SetClampedToScreen(true)
		pick:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 },
		})
		pick.buttons = {}
		local scroll = CreateFrame("ScrollFrame", nil, pick)
		scroll:SetPoint("TOPLEFT", 8, -8)
		scroll:SetPoint("BOTTOMRIGHT", -8, 8)
		scroll:EnableMouseWheel(true)
		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(20, 20)
		scroll:SetScrollChild(content)
		pick.scrollFrame = scroll
		pick.content = content
		pick:SetScript("OnUpdate", function(self)
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
		pick:Hide()
	end
	if pick:IsShown() and pick.anchor == anchor then
		pick:Hide()
		return
	end
	local width = math.max(anchor:GetWidth() or 160, 180)
	local function onWheel(_, delta)
		local scrollFrame = pick.scrollFrame
		local maxScroll = math.max(0, pick.content:GetHeight() - scrollFrame:GetHeight())
		local nextValue = scrollFrame:GetVerticalScroll() - delta * 22
		if nextValue < 0 then
			nextValue = 0
		elseif nextValue > maxScroll then
			nextValue = maxScroll
		end
		scrollFrame:SetVerticalScroll(nextValue)
	end
	for i = 1, #rows do
		local button = pick.buttons[i]
		if not button then
			button = CreateFrame("Button", nil, pick.content, "UIPanelButtonTemplate")
			pick.buttons[i] = button
		end
		button:SetSize(width, 20)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
		button:SetText(rows[i].label)
		local fn = rows[i].fn
		button:SetScript("OnClick", function()
			pick:Hide()
			if fn then
				fn()
			end
		end)
		button:EnableMouseWheel(true)
		button:SetScript("OnMouseWheel", onWheel)
		button:Show()
	end
	for i = #rows + 1, #pick.buttons do
		pick.buttons[i]:Hide()
	end
	local cap = maxLines or math.floor(264 / 22)
	if cap < 1 then
		cap = 1
	end
	local visible = #rows
	if visible > cap then
		visible = cap
	end
	if visible < 1 then
		visible = 1
	end
	pick.content:SetSize(width, math.max(22, #rows * 22))
	pick:SetSize(width + 16, 16 + visible * 22)
	pick.scrollFrame:SetVerticalScroll(0)
	pick.scrollFrame:SetScript("OnMouseWheel", onWheel)
	pick.anchor = anchor
	pick.down = true
	pick:ClearAllPoints()
	pick:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	pick:EnableMouseWheel(true)
	pick:SetScript("OnMouseWheel", onWheel)
	pick:Show()
end
