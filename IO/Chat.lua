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

local announcedBid = {}

local function noteBid(name)
	name = string.lower(SK.ShortName(name or ""))
	if name == "" then
		return
	end
	announcedBid[name] = time()
end

local function bidNoted(name)
	local at = announcedBid[string.lower(SK.ShortName(name or ""))]
	return at and (time() - at) <= 5
end

function SK.Chat:AnnounceBid(name, position)
	name = SK.ShortName(name)
	if name == "" then
		return
	end
	noteBid(name)
	self:Say(name .. " Bids position " .. tostring(position))
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
	local where = string.match(text, "Bids position%s+(%S+)") or string.match(text, "bids position%s+(%S+)")
	if where then
		noteBid(sender)
		if string.lower(where) ~= "unseeded" then
			SK.Session:Respond(sender, "Bid", nil, "chat")
		end
		return
	end
	if bidMessage(text) then
		SK.Session:Respond(sender, "Bid", nil, "chat")
	end
end

local pendingRoll = nil
local rollWatch = CreateFrame("Frame")
rollWatch:Hide()

local function plainRollText(text)
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "|H.-|h(.-)|h", "%1")
	text = string.gsub(text, "|T.-|t", "")
	text = string.gsub(text, "%[(.-)%]", "%1")
	return SK.Trim(text)
end

local function parseRoll(text)
	if type(text) ~= "string" then
		return nil
	end
	text = plainRollText(text)
	local name, roll, low, high = string.match(text, "^(.-) rolls? a? ?(%d+) %((%d+).(%d+)%)")
	if not roll then
		return nil
	end
	name = SK.Trim(name or "")
	name = string.gsub(name, "^[%s%p]+", "")
	name = string.gsub(name, "[%s%p]+$", "")
	roll = tonumber(roll)
	low = tonumber(low)
	high = tonumber(high)
	if name == "" or not roll or not low or not high then
		return nil
	end
	return name, roll, low, high
end

local function isSelf(name)
	name = string.lower(SK.Trim(name or ""))
	if name == "you" or name == "your" or string.find(name, "%f[%a]you%f[%A]") then
		return true
	end
	local mine = string.lower(SK.ShortName(UnitName("player") or ""))
	if mine == "" then
		return false
	end
	return name == mine or string.lower(SK.ShortName(name)) == mine
end

local function scanChatRoll(afterIndex)
	local chat = DEFAULT_CHAT_FRAME
	if not chat or not chat.GetNumMessages or not chat.GetMessageInfo then
		return nil
	end
	local count = chat:GetNumMessages()
	if type(count) ~= "number" or count < 1 then
		return nil
	end
	afterIndex = afterIndex or 0
	local stop = count - 12
	if stop < afterIndex + 1 then
		stop = afterIndex + 1
	end
	if stop < 1 then
		stop = 1
	end
	for i = count, stop, -1 do
		if i > afterIndex then
			local ok, text = pcall(chat.GetMessageInfo, chat, i)
			local name, roll, low, high
			if ok then
				name, roll, low, high = parseRoll(text)
			end
			if name then
				return name, roll, low, high
			end
		end
	end
	return nil
end

local rollChoice

local function recordRoll(name, roll, low, high)
	local mine = isSelf(name)
	if mine then
		name = UnitName("player")
	end
	if mine and pendingRoll and high == pendingRoll.high and time() - (pendingRoll.at or 0) <= 5 then
		local choice = pendingRoll.choice
		pendingRoll = nil
		rollWatch:Hide()
		if SK.Session:IsOfficer() then
			SK.Session:Respond(name, choice, roll, "roll")
		elseif SK.Sync and SK.Sync.SendResponse then
			SK.Sync:SendResponse(choice, roll)
		end
		if SK.Events then
			SK.Events:Fire("SK_OWN_ROLL", choice, roll)
		end
		return
	end
	if not SK.Session:IsOfficer() or mine then
		return
	end
	local choice = rollChoice(low, high)
	if bidNoted(name) and high == 100 then
		choice = "Bid"
	end
	if not choice then
		return
	end
	SK.Session:Respond(name, choice, roll, "roll")
end

function SK.Chat:RollFor(choice)
	local high = choice == "OS" and 99 or 100
	local seen = 0
	local chat = DEFAULT_CHAT_FRAME
	if chat and chat.GetNumMessages then
		seen = chat:GetNumMessages() or 0
	end
	pendingRoll = { choice = choice, high = high, at = time(), seen = seen }
	rollWatch.tries = 0
	rollWatch:Show()
	if RandomRoll then
		RandomRoll(1, high)
		return
	end
	local box = chat and chat.editBox
	if box and ChatEdit_SendText then
		box:SetText("/roll " .. high)
		ChatEdit_SendText(box, 1)
	end
end

rollChoice = function(low, high)
	local choice = SK.Gargul and SK.Gargul:ChoiceForRange(low, high) or nil
	if not choice and low == 1 and high == 100 then
		choice = "MS"
	elseif not choice and low == 1 and high == 99 then
		choice = "OS"
	end
	return choice
end

local function onSystem(text)
	local secret = type(issecretvalue) == "function" and issecretvalue(text)
	if not secret then
		local ok, name, roll, low, high = pcall(parseRoll, text)
		if ok and name then
			recordRoll(name, roll, low, high)
			return
		end
	end
	if not pendingRoll then
		return
	end
	local name, roll, low, high = scanChatRoll(pendingRoll.seen)
	if name and isSelf(name) and high == pendingRoll.high then
		recordRoll(name, roll, low, high)
	end
end

rollWatch:SetScript("OnUpdate", function(self)
	self.tries = (self.tries or 0) + 1
	if not pendingRoll or self.tries > 20 then
		self:Hide()
		return
	end
	local name, roll, low, high = scanChatRoll(pendingRoll.seen)
	if name and isSelf(name) and high == pendingRoll.high then
		recordRoll(name, roll, low, high)
	end
end)

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

if ChatFrame_AddMessageEventFilter then
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
		onSystem(text)
		return false
	end)
end
