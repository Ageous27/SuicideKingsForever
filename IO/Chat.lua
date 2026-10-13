SK = SK or {}
SK.Chat = SK.Chat or {}

local function sayChannel()
	if IsInRaid and IsInRaid() then
		return "RAID"
	end
	if IsInGroup and IsInGroup() then
		return "PARTY"
	end
	return nil
end

function SK.Chat:Say(text)
	if not text or text == "" then
		return
	end
	if #text > 250 then
		text = string.sub(text, 1, 250)
	end
	local channel = sayChannel()
	if not channel or not SendChatMessage then
		SK.Print(text)
		return
	end
	SendChatMessage(text, channel)
end

function SK.Chat:Whisper(name, text)
	name = SK.ShortName(name)
	if name == "" or not text or text == "" then
		return
	end
	if not sayChannel() or not SendChatMessage then
		SK.Print("To " .. name .. ": " .. text)
		return
	end
	SendChatMessage(text, "WHISPER", nil, name)
end

local function bidMessage(text)
	text = string.lower(SK.Trim(text))
	return text == "bid" or string.sub(text, 1, 4) == "bid " or text == "bid."
end

local function onTalk(text, sender)
	if not SK.Session:IsOfficer() then
		return
	end
	sender = SK.ShortName(sender)
	text = SK.ShortName(text) ~= "" and text or nil
	if type(issecretvalue) == "function" and issecretvalue(text) then
		return
	end
	if type(text) ~= "string" or sender == "" then
		return
	end
	if bidMessage(text) then
		SK.Session:Respond(sender, "Bid", nil, "chat")
	end
end

local function onSystem(text)
	if not SK.Session:IsOfficer() then
		return
	end
	if type(issecretvalue) == "function" and issecretvalue(text) then
		return
	end
	if type(text) ~= "string" then
		return
	end
	local name, roll, low, high = string.match(text, "^(%S+) rolls (%d+) %((%d+)%-(%d+)%)$")
	if not name then
		roll, low, high = string.match(text, "^You roll (%d+) %((%d+)%-(%d+)%)$")
		if roll then
			name = UnitName("player")
		end
	end
	if not name then
		return
	end
	low = tonumber(low)
	high = tonumber(high)
	local choice = SK.Gargul and SK.Gargul:ChoiceForRange(low, high) or nil
	if not choice and low == 1 and high == 100 then
		choice = "MS"
	elseif not choice and low == 1 and high == 99 then
		choice = "OS"
	end
	if not choice then
		return
	end
	SK.Session:Respond(name, choice, tonumber(roll), "roll")
end

SK.Events:On("SK_ANNOUNCE", function(text)
	if SK.Session:IsOfficer() then
		SK.Chat:Say(text)
	end
end)

SK.Events:Register("CHAT_MSG_RAID", onTalk)
SK.Events:Register("CHAT_MSG_RAID_LEADER", onTalk)
SK.Events:Register("CHAT_MSG_RAID_WARNING", onTalk)
SK.Events:Register("CHAT_MSG_PARTY", onTalk)
SK.Events:Register("CHAT_MSG_PARTY_LEADER", onTalk)
SK.Events:Register("CHAT_MSG_INSTANCE_CHAT", onTalk)
SK.Events:Register("CHAT_MSG_WHISPER", onTalk)
SK.Events:Register("CHAT_MSG_SYSTEM", function(text)
	onSystem(text)
end)
