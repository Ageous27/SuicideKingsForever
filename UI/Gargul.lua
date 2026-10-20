local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local frame = CreateFrame("Frame", "SKFGargulChoice", UIParent, "BackdropTemplate")
frame:SetSize(460, 180)
frame:SetFrameStrata("TOOLTIP")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop(BACKDROP)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:Hide()

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Master looter")

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOPLEFT", 24, -48)
text:SetPoint("TOPRIGHT", -24, -48)
text:SetJustifyH("CENTER")
text:SetText("Gargul and Suicide Kings Forever are both installed. Which one should run loot?")

local gargulBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
gargulBtn:SetSize(120, 24)
gargulBtn:SetPoint("BOTTOMLEFT", 70, 24)
gargulBtn:SetText("Gargul")

local skfBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
skfBtn:SetSize(120, 24)
skfBtn:SetPoint("BOTTOMRIGHT", -70, 24)
skfBtn:SetText("SKF")

gargulBtn:SetScript("OnClick", function()
	SK.Gargul:Choose("gargul")
end)
skfBtn:SetScript("OnClick", function()
	SK.Gargul:Choose("skf")
end)

function SK.UI.ShowGargulChoice()
	if frame:IsShown() then
		return
	end
	frame:Show()
	frame:Raise()
end

function SK.UI.HideGargulChoice()
	frame:Hide()
end
