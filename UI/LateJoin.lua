local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local frame = CreateFrame("Frame", "SKFLateJoin", UIParent, "BackdropTemplate")
frame:SetSize(440, 200)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop(BACKDROP)
frame:Hide()
tinsert(UISpecialFrames, frame:GetName())

local function savedPoint()
	local saved = SKDB and SKDB.layout and SKDB.layout.latejoin
	if type(saved) == "table" and saved.point then
		return saved.point, saved.rel or "CENTER", saved.x or 0, saved.y or 0
	end
	return "CENTER", "CENTER", 0, 0
end

local function applyPoint()
	local point, rel, x, y = savedPoint()
	frame:SetUserPlaced(false)
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, rel, x, y)
end

local function rememberPoint()
	if type(SKDB) ~= "table" then
		return
	end
	local point, _, rel, x, y = frame:GetPoint(1)
	if not point then
		return
	end
	SKDB.layout = SKDB.layout or {}
	SKDB.layout.latejoin = {
		point = point,
		rel = rel or "CENTER",
		x = x or 0,
		y = y or 0,
	}
	applyPoint()
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	rememberPoint()
end)
applyPoint()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Late join")

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOPLEFT", 24, -48)
text:SetPoint("TOPRIGHT", -24, -48)
text:SetJustifyH("CENTER")
text:SetJustifyV("TOP")

local yesBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
yesBtn:SetSize(90, 24)
yesBtn:SetPoint("BOTTOMLEFT", 80, 24)
yesBtn:SetText("Yes")

local noBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
noBtn:SetSize(90, 24)
noBtn:SetPoint("BOTTOMRIGHT", -80, 24)
noBtn:SetText("No")

local function current()
	local queue = SK.Saved:Session().pendingJoins
	if type(queue) ~= "table" then
		return nil
	end
	return queue[1]
end

local function positionText(entry)
	if not entry.onList then
		return "not on the core list"
	end
	if not entry.position then
		return "unseeded"
	end
	return "stored position " .. tostring(entry.position)
end

local function refresh()
	if not SK.Session:IsOfficer() then
		frame:Hide()
		return
	end
	local entry = current()
	if not entry then
		frame:Hide()
		return
	end
	local when = date("%H:%M:%S", entry.joinedAt or time())
	local waiting = #(SK.Saved:Session().pendingJoins or {})
	local extra = ""
	if waiting > 1 then
		extra = "\n" .. tostring(waiting - 1) .. " more waiting."
	end
	text:SetText(entry.name .. " joined at " .. when .. ".\n" .. positionText(entry) .. ".\nAllow them to bid and roll?" .. extra)
	if not frame:IsShown() then
		applyPoint()
		frame:Show()
	end
end

yesBtn:SetScript("OnClick", function()
	SK.Session:AnswerJoin(true)
end)
noBtn:SetScript("OnClick", function()
	SK.Session:AnswerJoin(false)
end)

SK.Events:On("SK_JOIN", refresh)
SK.Events:On("SK_READY", refresh)
