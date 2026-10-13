SK = SK or {}
SK.Events = SK.Events or {}

local frame = CreateFrame("Frame")
SK.Events.frame = frame
SK.Events.handlers = {}

function SK.Events:Register(event, fn)
	self.handlers[event] = self.handlers[event] or {}
	table.insert(self.handlers[event], fn)
	frame:RegisterEvent(event)
end

function SK.Events:On(event, fn)
	self.handlers[event] = self.handlers[event] or {}
	table.insert(self.handlers[event], fn)
end

function SK.Events:Fire(event, ...)
	local list = self.handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok and SK.Debug then
			SK.Debug:Line("Events", event, tostring(err))
		end
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == "SuicideKingsForever" then
		SK.Saved:Init()
	end
	SK.Events:Fire(event, ...)
end)

frame:RegisterEvent("ADDON_LOADED")
