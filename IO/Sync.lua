SK = SK or {}
SK.Sync = SK.Sync or {}

local PREFIX = SK.PREFIX
local inbox = {}

local function channel()
	if not IsInGroup or not IsInGroup() then
		return nil
	end
	if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInRaid() then
		return "INSTANCE_CHAT"
	end
	if IsInRaid() then
		return "RAID"
	end
	return "PARTY"
end

local function send(text)
	local dest = channel()
	if not dest or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
		return
	end
	C_ChatInfo.SendAddonMessage(PREFIX, text, dest)
end

local function shortName(name)
	if not name then
		return ""
	end
	return string.match(name, "^([^%-]+)") or name
end

local ROLL_TOKEN = {
	["Bid, MS, OS"] = "b",
	["MS, OS"] = "m",
	["Cannot Roll"] = "n",
}
local ROLL_NAME = {
	b = "Bid, MS, OS",
	m = "MS, OS",
	n = "Cannot Roll",
}

local function encode(row)
	local position = row.position and tostring(row.position) or ""
	local status = row.status or ""
	local pug = row.pug and "1" or "0"
	local rolls = ROLL_TOKEN[row.rolls or ""] or ""
	local hold = row.hold and "1" or "0"
	return table.concat({ row.name, row.class, position, status, pug, rolls, hold }, ",")
end

local function decode(piece)
	local name, class, position, status, pug, rolls, hold = string.match(piece, "^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)$")
	if not name then
		name, class, position, status, pug = string.match(piece, "^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)$")
	end
	if not name or name == "" then
		return nil
	end
	local pos = tonumber(position)
	return {
		name = name,
		class = class,
		position = pos,
		status = status ~= "" and status or nil,
		pug = pug == "1",
		rolls = ROLL_NAME[rolls or ""],
		hold = hold == "1",
	}
end

function SK.Sync:Broadcast()
	if not SK.Session:IsOfficer() then
		return
	end
	if not channel() then
		return
	end
	local chunks = {}
	local buf = ""
	local function push(piece)
		if buf ~= "" and (#buf + #piece + 1) > 160 then
			table.insert(chunks, buf)
			buf = piece
		elseif buf == "" then
			buf = piece
		else
			buf = buf .. ";" .. piece
		end
	end
	local list = SK.Saved:List()
	for i = 1, #list do
		push(encode(list[i]))
	end
	if buf ~= "" or #chunks == 0 then
		table.insert(chunks, buf)
	end
	self.token = (self.token or 0) + 1
	local token = tostring(self.token)
	local seeding = SK.Session:IsSeeding() and "1" or "0"
	local locked = SK.Session:IsLocked() and "1" or "0"
	for i = 1, #chunks do
		send(string.format("L,%s,%d,%d,%s,%s,%s", token, i, #chunks, seeding, locked, chunks[i]))
	end
	SK.Debug:Line("Sync", "broadcast", #list .. " rows in " .. #chunks .. " chunks")
end

function SK.Sync:Request()
	if self.pending then
		return
	end
	self.pending = true
	local function go()
		self.pending = false
		if SK.Session:IsOfficer() then
			self:Broadcast()
		else
			send("Q")
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(1, go)
	else
		go()
	end
end

local function apply(bucket)
	local rows = {}
	for i = 1, bucket.n do
		local payload = bucket.parts[i]
		if not payload then
			return
		end
		if payload ~= "" then
			for piece in string.gmatch(payload, "([^;]+)") do
				local row = decode(piece)
				if row then
					table.insert(rows, row)
				end
			end
		end
	end
	SK.List:ApplySnapshot(rows)
	if SK.Session and SK.Session.ApplyLock then
		SK.Session:ApplyLock(bucket.locked)
	end
	SK.Debug:Line("Sync", "snapshot", #rows .. " rows")
end

local function onAddon(prefix, text, _, sender)
	if prefix ~= PREFIX or type(text) ~= "string" then
		return
	end
	sender = shortName(sender)
	local me = shortName(UnitName("player"))
	if string.sub(text, 1, 2) == "H|" then
		if sender ~= me then
			local id, eventType, action, name, detail, roll, beforePos, afterPos = string.match(text, "^H|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
			local delivered = string.match(text, "^H|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|([01])$")
			if id and id ~= "" then
				SK.History:Append({
					id = id,
					type = eventType,
					action = action,
					name = name,
					detail = detail,
					roll = tonumber(roll),
					positionBefore = tonumber(beforePos),
					positionAfter = tonumber(afterPos),
					officer = sender,
					delivered = delivered == "1",
				})
			end
		end
		return
	end
	local kind = string.match(text, "^([^,]+)")
	if kind == "D" then
		if sender ~= me then
			local id = string.match(text, "^D,(.+)$")
			if id and id ~= "" then
				SK.History:MarkDelivered(id)
			end
		end
		return
	end
	if kind == "Q" then
		if sender ~= me and SK.Session:IsOfficer() then
			SK.Sync:Broadcast()
			SK.Sync:BroadcastSettings()
			if SK.Gargul then
				SK.Gargul:Broadcast()
			end
		end
		return
	end
	if kind == "M" then
		if sender ~= me and not SK.Session:IsOfficer() and SK.Gargul then
			local engine = string.match(text, "^M,(%a+)$")
			SK.Gargul:ApplyRemote(engine)
		end
		return
	end
	if kind == "G" then
		if sender ~= me and not SK.Session:IsOfficer() then
			local drop, timer, countdown, disenchanter, autoAdd, autoQuality = string.match(text, "^G,([^,]+),([^,]+),([^,]+),([^,]*),([01]),(%d+)$")
			if not drop then
				drop, timer, countdown = string.match(text, "^G,([^,]+),([^,]+),([^,]+)$")
			end
			if drop then
				SK.Settings:ApplyRemote(drop, timer, countdown, disenchanter, autoAdd, autoQuality)
			end
		end
		return
	end
	if kind == "V" then
		if sender ~= me and not SK.Session:IsOfficer() then
			local state, endsAt, tier, names, link = string.match(text, "^V,([^,]+),([^,]*),([^,]*),([^,]*),(.*)$")
			if state == "clear" then
				SK.Session:ApplyRemote("clear")
			elseif state then
				SK.Session:ApplyRemote(state, endsAt, tier, names, link)
			end
		end
		return
	end
	if kind == "J" then
		if sender ~= me and not SK.Session:IsOfficer() then
			local waiting, name = string.match(text, "^J,([01]),(.+)$")
			if name and name ~= "" then
				SK.Session:SetBlocked(name, waiting == "1")
			end
		end
		return
	end
	if kind == "R" then
		if sender ~= me and SK.Session:IsOfficer() then
			local choice, roll = string.match(text, "^R,([^,]+),([^,]*)$")
			if choice then
				SK.Session:Respond(sender, choice, tonumber(roll), "popup")
			end
		end
		return
	end
	if kind ~= "L" or sender == me or SK.Session:IsOfficer() then
		return
	end
	local token, index, count, _, locked, payload = string.match(text, "^L,([^,]+),(%d+),(%d+),([01]),([01]),(.*)$")
	if not token then
		return
	end
	index = tonumber(index)
	count = tonumber(count)
	local bucket = inbox[token]
	if not bucket then
		bucket = { n = count, parts = {}, locked = locked == "1" }
		inbox[token] = bucket
	end
	bucket.parts[index] = payload or ""
	local got = 0
	for i = 1, bucket.n do
		if bucket.parts[i] ~= nil then
			got = got + 1
		end
	end
	if got == bucket.n then
		apply(bucket)
		inbox[token] = nil
	end
end

SK.Events:Register("CHAT_MSG_ADDON", onAddon)

SK.Events:Register("PLAYER_LOGIN", function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	end
	SK.Sync:Request()
end)

SK.Events:On("SK_LIST_CHANGED", function(source)
	if source == "snapshot" then
		return
	end
	SK.Sync:Broadcast()
end)

function SK.Sync:BroadcastLootEngine(engine)
	if not SK.Session:IsOfficer() or not channel() then
		return
	end
	if engine ~= "skf" and engine ~= "gargul" then
		return
	end
	send("M," .. engine)
end

function SK.Sync:BroadcastSettings()
	if not SK.Session:IsOfficer() or not channel() then
		return
	end
	local settings = SK.Settings:Get()
	send(string.format(
		"G,%s,%s,%s,%s,%s,%s",
		settings.bidDrop or "last",
		tostring(settings.timer or 15),
		tostring(settings.countdown or 5),
		settings.disenchanter or "",
		settings.autoAdd and "1" or "0",
		tostring(settings.autoQuality or 2)
	))
end

function SK.Sync:BroadcastSession(reason)
	if not SK.Session:IsOfficer() or not channel() then
		return
	end
	local live = SK.Session:Live()
	if (reason == "start" or reason == "rolloff" or reason == "item") and live then
		local tier = ""
		local names = ""
		if live.rolloff and live.rolloff.names then
			tier = live.rolloff.tier or ""
			local list = {}
			for key in pairs(live.rolloff.names) do
				table.insert(list, key)
			end
			names = table.concat(list, ";")
		end
		local payload = string.format("V,%s,%s,%s,%s,%s", live.state or "open", tostring(live.endsAt or 0), tier, names, live.link or live.name or "")
		if #payload > 240 then
			payload = string.format("V,%s,%s,%s,%s,%s", live.state or "open", tostring(live.endsAt or 0), tier, names, live.name or "item")
		end
		send(payload)
		return
	end
	send("V,clear,,,,,")
end

function SK.Sync:SendResponse(choice, roll)
	if not channel() then
		return
	end
	send(string.format("R,%s,%s", choice or "", roll and tostring(roll) or ""))
end

function SK.Sync:BroadcastHistory(event)
	if not SK.Session:IsOfficer() or not channel() or not event then
		return
	end
	local function clean(value)
		value = tostring(value or "")
		value = string.gsub(value, "|", "/")
		return value
	end
	send(table.concat({
		"H",
		clean(event.id),
		clean(event.type),
		clean(event.action),
		clean(event.name),
		clean(event.detail),
		clean(event.roll),
		clean(event.positionBefore),
		clean(event.positionAfter),
		event.delivered and "1" or "0",
	}, "|"))
end

function SK.Sync:BroadcastJoin(name, waiting)
	if not name or name == "" or not SK.Session:IsOfficer() or not channel() then
		return
	end
	send("J," .. (waiting and "1" or "0") .. "," .. name)
end

function SK.Sync:BroadcastDelivered(id)
	if not id or id == "" or not SK.Session:IsOfficer() or not channel() then
		return
	end
	send("D," .. id)
end

SK.Events:On("SK_SETTINGS", function()
	if SK.Session:IsOfficer() then
		SK.Sync:BroadcastSettings()
	end
end)

SK.Events:On("SK_SESSION", function(reason)
	if reason == "start" or reason == "rolloff" or reason == "item" or reason == "close" or reason == "award" or reason == "cancel" or reason == "disenchant" then
		SK.Sync:BroadcastSession(reason)
	end
end)

SK.Events:On("SK_DELIVERED", function(id)
	if SK.Session:IsOfficer() then
		SK.Sync:BroadcastDelivered(id)
	end
end)

SK.Events:On("SK_HISTORY", function(event)
	if event and (event.type == "loot" or event.type == "reconcile" or event.type == "latejoin") and SK.Session:IsOfficer() then
		SK.Sync:BroadcastHistory(event)
	end
end)

SK.Events:Register("GROUP_ROSTER_UPDATE", function()
	SK.Sync:Request()
end)
