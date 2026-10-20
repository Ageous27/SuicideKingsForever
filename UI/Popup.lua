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
	local ok = pcall(frame.SetPoint, frame, point, UIParent, rel or "CENTER", x or 0, y or 0)
	if not ok then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
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
footnote:SetText("Pick once. This window closes after your choice.")

local buttons = {}
local order = { "Bid", "MS", "OS", "Pass" }
local current = nil
local picked = nil

local function lockButtons()
	for i = 1, #order do
		local button = buttons[order[i]]
		if button then
			button:Disable()
		end
	end
end

local function unlockButtons()
	for i = 1, #order do
		local button = buttons[order[i]]
		if button then
			button:Enable()
		end
	end
end

local function closeAfterChoice()
	frame.dismissed = frame.token
	frame:Hide()
end

local function sendChoice(choice)
	if picked then
		return
	end
	picked = choice
	current = choice
	lockButtons()
	closeAfterChoice()
	if choice == "MS" or choice == "OS" then
		if SK.Chat and SK.Chat.RollFor then
			SK.Chat:RollFor(choice)
		end
		return
	end
	local name = SK.ShortName(UnitName("player"))
	if choice == "Bid" then
		local live = SK.Session:Live()
		local row
		if live and live.listId and SK.Teams and SK.Teams.Row then
			row = SK.Teams:Row(live.listId, name)
		else
			row = SK.List:Find(name)
		end
		local unseeded = row and not row.pug and not row.position
		local where = unseeded and "unseeded" or (row and row.position)
		if where and SK.Chat and SK.Chat.AnnounceBid then
			SK.Chat:AnnounceBid(row and row.name or name, where)
		end
		if unseeded and SK.Chat and SK.Chat.RollFor then
			SK.Chat:RollFor("Bid")
			return
		end
	end
	if SK.Session:IsOfficer() then
		SK.Session:Respond(name, choice, nil, "popup")
	elseif SK.Sync and SK.Sync.SendResponse then
		SK.Sync:SendResponse(choice, nil)
	end
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
	name = SK.ShortName(name or "")
	if name == "" then
		name = "You"
	end
	local row = SK.List:Find(name)
	if not row then
		return name
	end
	if row.pug then
		return row.name .. ", " .. (row.class or "") .. ", pug / fill"
	end
	if not row.position then
		return row.name .. ", " .. (row.class or "") .. ", unseeded"
	end
	return row.name .. ", " .. (row.class or "") .. ", position " .. row.position
end

local function liveToken(live)
	if not live then
		return nil
	end
	return table.concat({
		live.nonce or "",
		live.state or "",
		tostring(live.endsAt or 0),
		live.listId or "",
		live.raw or live.link or live.name or "",
	}, "\031")
end

close:HookScript("OnClick", function()
	frame.dismissed = frame.token
end)

local function refresh(reason)
	if SK.Gargul and SK.Gargul:UseGargul() then
		frame:Hide()
		return
	end
	local live = SK.Session:Live()
	local name = UnitName("player")
	local open = live and (live.state == "open" or live.state == "rolloff") and time() <= (live.endsAt or 0)
	local allowed = open and SK.Session:ChoicesFor(name) or {}
	local token = liveToken(live)
	local officerStarting = reason == "start" and SK.Session:IsOfficer()
	local show = open and token ~= frame.dismissed and (#allowed > 0 or officerStarting)
	frame.hadChoices = open and #allowed > 0 and true or false
	if not show then
		if frame:IsShown() and not open then
			frame:Hide()
		end
		return
	end
	if not frame:IsShown() or frame.token ~= token then
		picked = nil
		current = nil
		unlockButtons()
		if #allowed == 0 then
			footnote:SetText("You are not eligible to roll on this list.")
		else
			footnote:SetText("Pick once. This window closes after your choice.")
		end
	end
	frame.token = token
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	if not frame:IsShown() then
		applyPopupLayout()
		frame:Show()
	end
	frame:Raise()
	itemText:SetText(SK.Item.Display(live) or "Item")
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
end

SK.UI = SK.UI or {}
function SK.UI.ShowRollPopup(reason)
	refresh(reason or "start")
end

SK.Events:On("SK_READY", applyPopupLayout)
SK.Events:On("SK_OWN_ROLL", function(choice, roll)
	if current == choice and roll then
		footnote:SetText("Your choice: " .. choice .. " " .. roll)
	end
end)
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
		picked = nil
		footnote:SetText("Pick once. This window closes after your choice.")
		return
	end
	local duration = live.duration or 15
	local remain = math.max(0, (live.endsAt or 0) - time())
	bar:SetMinMaxValues(0, math.max(1, duration))
	bar:SetValue(math.min(duration, remain))
	barText:SetText(math.ceil(remain) .. "s")
	itemText:SetText(SK.Item.Display(live))
end)
