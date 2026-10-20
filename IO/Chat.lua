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

function SK.Chat:SayRaid(text)
	if not text or text == "" then
		return
	end
	if not IsInRaid or not IsInRaid() or not SendChatMessage then
		return
	end
	if #text > 250 then
		text = string.sub(text, 1, 250)
	end
	SendChatMessage(text, "RAID")
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

function SK.Chat:AnnounceBid(name, position)
	name = SK.ShortName(name)
	if name == "" then
		return
	end
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
		SK.Session:Respond(sender, "Bid", nil, "chat")
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
	if not SK.Session:IsOfficer() then
		return
	end
	if mine and pendingRoll and time() - (pendingRoll.at or 0) <= 5 then
		return
	end
	local choice = rollChoice(low, high)
	if not choice then
		return
	end
	SK.Session:Respond(name, choice, roll, "roll")
end

function SK.Chat:RollFor(choice)
	local high = 100
	if choice == "OS" then
		high = 99
	end
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

local function skQuery(text)
	text = string.lower(SK.Trim(text or ""))
	text = string.gsub(text, "[%.%!%?]+$", "")
	if text == "sk all" then
		return "all"
	end
	if text == "sk" then
		return "one"
	end
	return nil
end

local function answersSk()
	if UnitIsGroupLeader and UnitIsGroupLeader("player") then
		return true
	end
	return SK.Session and SK.Session.IsMasterLooter and SK.Session:IsMasterLooter() or false
end

local function positionWord(position)
	if position then
		return tostring(position)
	end
	return "unseeded"
end

local function listRows(list, people)
	local openRows = {}
	local placed = {}
	for key, on in pairs(list.members or {}) do
		local person = on and people[key] or nil
		if person and not person.pug then
			local position = tonumber(list.pos and list.pos[key])
			local row = { name = person.name, position = position }
			if position then
				table.insert(placed, row)
			else
				table.insert(openRows, row)
			end
		end
	end
	table.sort(openRows, function(a, b)
		return (a.name or "") < (b.name or "")
	end)
	table.sort(placed, function(a, b)
		if a.position == b.position then
			return (a.name or "") < (b.name or "")
		end
		return a.position < b.position
	end)
	for i = 1, #placed do
		table.insert(openRows, placed[i])
	end
	return openRows
end

local function fullListText()
	local team = SK.Teams and SK.Teams:Team()
	if not team or type(team.listOrder) ~= "table" then
		return "The list is empty."
	end
	local parts = {}
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list then
			local rows = listRows(list, team.people or {})
			if #team.listOrder > 1 then
				table.insert(parts, (list.name or "List") .. ":")
			end
			if #rows == 0 then
				table.insert(parts, "empty")
			end
			for n = 1, #rows do
				table.insert(parts, positionWord(rows[n].position) .. " " .. rows[n].name)
			end
		end
	end
	if #parts == 0 then
		return "The list is empty."
	end
	return table.concat(parts, "\n")
end

local function onePositionText(name)
	local team = SK.Teams and SK.Teams:Team()
	local person = team and team.people and team.people[string.lower(name)] or nil
	if not person or person.pug or not team then
		return name .. " is not on the list."
	end
	local hits = {}
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list and list.members and list.members[string.lower(name)] then
			table.insert(hits, {
				list = list.name or "List",
				position = list.pos and list.pos[string.lower(name)] or nil,
			})
		end
	end
	if #hits == 0 then
		return person.name .. " is not on the list."
	end
	if #hits == 1 and #team.listOrder == 1 then
		return positionWord(hits[1].position) .. " " .. person.name
	end
	local bits = {}
	for i = 1, #hits do
		table.insert(bits, hits[i].list .. " " .. positionWord(hits[i].position))
	end
	return person.name .. ": " .. table.concat(bits, ", ")
end

local function whisperChunks(name, text)
	local rest = text or ""
	while rest ~= "" do
		local newline = string.find(rest, "\n", 1, true)
		local piece
		if newline then
			piece = string.sub(rest, 1, newline - 1)
			rest = string.sub(rest, newline + 1)
		else
			piece = rest
			rest = ""
		end
		piece = SK.Trim(piece)
		while piece ~= "" do
			if #piece <= 240 then
				SK.Chat:Whisper(name, piece)
				piece = ""
			else
				local cut = 240
				for i = 240, 1, -1 do
					local ch = string.sub(piece, i, i)
					if ch == "," or ch == " " or ch == "." then
						cut = i
						break
					end
				end
				SK.Chat:Whisper(name, SK.Trim(string.sub(piece, 1, cut)))
				piece = SK.Trim(string.sub(piece, cut + 1))
			end
		end
	end
end

function SK.Chat:AnswerSk(sender, text)
	if type(issecretvalue) == "function" and issecretvalue(text) then
		return false
	end
	if type(text) ~= "string" then
		return false
	end
	local kind = skQuery(text)
	if not kind or not answersSk() then
		return false
	end
	local who = SK.ShortName(sender)
	if who == "" then
		return false
	end
	if kind == "all" then
		whisperChunks(who, fullListText())
	else
		SK.Chat:Whisper(who, onePositionText(who))
	end
	return true
end

local function onWhisper(text, sender)
	if SK.Chat:AnswerSk(sender, text) then
		return
	end
	onTalk(text, sender)
end

SK.Events:Register("CHAT_MSG_RAID", onTalk)
SK.Events:Register("CHAT_MSG_RAID_LEADER", onTalk)
SK.Events:Register("CHAT_MSG_RAID_WARNING", onTalk)
SK.Events:Register("CHAT_MSG_PARTY", onTalk)
SK.Events:Register("CHAT_MSG_PARTY_LEADER", onTalk)
SK.Events:Register("CHAT_MSG_INSTANCE_CHAT", onTalk)
SK.Events:Register("CHAT_MSG_WHISPER", onWhisper)
SK.Events:Register("CHAT_MSG_SYSTEM", function(text)
	onSystem(text)
end)

if ChatFrame_AddMessageEventFilter then
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
		onSystem(text)
		return false
	end)
end
