local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local frame = CreateFrame("Frame", "SKFRaiderPopup", UIParent, "BackdropTemplate")
frame:SetSize(420, 210)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
local function popupPoint()
	local saved = SKDB and SKDB.layout and SKDB.layout.popup
	if type(saved) == "table" and saved.point then
		return saved.point, saved.rel or "CENTER", saved.x or 0, saved.y or 0
	end
	return "CENTER", "CENTER", 0, 0
end

local function applyPopupLayout()
	local point, rel, x, y = popupPoint()
	frame:SetUserPlaced(false)
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, rel, x, y)
end

local function rememberPopupLayout()
	if type(SKDB) ~= "table" then
		return
	end
	local point, _, rel, x, y = frame:GetPoint(1)
	if not point then
		return
	end
	SKDB.layout = SKDB.layout or {}
	SKDB.layout.popup = {
		point = point,
		rel = rel or "CENTER",
		x = x or 0,
		y = y or 0,
	}
	applyPopupLayout()
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	rememberPopupLayout()
end)
frame:SetBackdrop(BACKDROP)
applyPopupLayout()
frame:Hide()
tinsert(UISpecialFrames, frame:GetName())

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local itemText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
itemText:SetPoint("TOP", 0, -28)
itemText:SetWidth(340)
itemText:SetJustifyH("CENTER")
itemText:SetText("Item")

local whoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
whoText:SetPoint("TOP", itemText, "BOTTOM", 0, -6)
whoText:SetWidth(340)
whoText:SetJustifyH("CENTER")

local barBack = frame:CreateTexture(nil, "BACKGROUND")
barBack:SetColorTexture(0.15, 0.12, 0.05, 0.9)
barBack:SetPoint("TOP", whoText, "BOTTOM", 0, -12)
barBack:SetSize(280, 18)

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetPoint("TOPLEFT", barBack, "TOPLEFT", 1, -1)
bar:SetPoint("BOTTOMRIGHT", barBack, "BOTTOMRIGHT", -1, 1)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(1, 0.82, 0)
bar:SetMinMaxValues(0, 15)
bar:SetValue(15)

local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barText:SetPoint("CENTER", barBack, "CENTER", 0, 0)
barText:SetText("15s")

local footnote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footnote:SetPoint("BOTTOM", 0, 16)
footnote:SetText("You can change this until the timer ends.")

local buttons = {}
local order = { "Bid", "MS", "OS", "Pass" }
local current = nil

local function sendChoice(choice)
	local roll
	if choice == "MS" or choice == "OS" then
		roll = math.random(1, 100)
	end
	local name = SK.ShortName(UnitName("player"))
	if SK.Session:IsOfficer() then
		SK.Session:Respond(name, choice, roll, "popup")
	else
		SK.Sync:SendResponse(choice, roll)
	end
	current = choice
	footnote:SetText("Your choice: " .. choice .. (roll and (" " .. roll) or "") .. ". You can change this until the timer ends.")
end

for i = 1, #order do
	local choice = order[i]
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(72, 24)
	button:SetText(choice)
	button:SetScript("OnClick", function()
		sendChoice(choice)
	end)
	buttons[choice] = button
end

local function personLine(name)
	local row = SK.List:Find(SK.ShortName(name))
	if not row then
		return name
	end
	if row.pug then
		return row.name .. ", " .. row.class .. ", pug / fill"
	end
	if not row.position then
		return row.name .. ", " .. row.class .. ", unseeded"
	end
	return row.name .. ", " .. row.class .. ", position " .. row.position
end

local function refresh(reason)
	if SK.Gargul and SK.Gargul:UseGargul() then
		frame:Hide()
		return
	end
	local live = SK.Session:Live()
	local name = UnitName("player")
	local open = live and (live.state == "open" or live.state == "rolloff") and time() <= (live.endsAt or 0)
	local allowed = open and SK.Session:ChoicesFor(name) or {}
	local had = frame.hadChoices and true or false
	local gained = reason == "list" and not had
	local show = open and #allowed > 0 and (reason == "start" or reason == "rolloff" or frame:IsShown() or gained)
	frame.hadChoices = open and #allowed > 0 and true or false
	if not show then
		if frame:IsShown() and not open then
			frame:Hide()
		end
		return
	end
	itemText:SetText(SK.Item.Display(live))
	whoText:SetText(personLine(name))
	local duration = live.duration or 15
	if duration < 1 then
		duration = 15
	end
	local remain = math.max(0, (live.endsAt or 0) - time())
	bar:SetMinMaxValues(0, duration)
	bar:SetValue(math.min(duration, remain))
	barText:SetText(math.ceil(remain) .. "s")
	local shown = {}
	for i = 1, #allowed do
		shown[allowed[i]] = true
	end
	local x = 46
	for i = 1, #order do
		local choice = order[i]
		local button = buttons[choice]
		if shown[choice] then
			button:ClearAllPoints()
			button:SetPoint("BOTTOMLEFT", x, 40)
			button:Show()
			local font = button:GetFontString()
			if font then
				if current == choice then
					font:SetTextColor(1, 0.82, 0)
				else
					font:SetTextColor(1, 1, 1)
				end
			end
			x = x + 80
		else
			button:Hide()
		end
	end
	if not frame:IsShown() then
		applyPopupLayout()
		frame:Show()
	end
end

SK.Events:On("SK_READY", applyPopupLayout)
SK.Events:On("SK_SESSION", refresh)
SK.Events:On("SK_LIST_CHANGED", function()
	refresh("list")
end)
frame:SetScript("OnUpdate", function()
	if not frame:IsShown() then
		return
	end
	local live = SK.Session:Live()
	if not live or time() > (live.endsAt or 0) then
		frame:Hide()
		current = nil
		footnote:SetText("You can change this until the timer ends.")
		return
	end
	local duration = live.duration or 15
	local remain = math.max(0, (live.endsAt or 0) - time())
	bar:SetMinMaxValues(0, math.max(1, duration))
	bar:SetValue(math.min(duration, remain))
	barText:SetText(math.ceil(remain) .. "s")
	itemText:SetText(SK.Item.Display(live))
end)
