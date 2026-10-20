SK = SK or {}
SK.History = SK.History or {}

SK.History.counter = 0

function SK.History:NewId()
	self.counter = self.counter + 1
	local name = UnitName("player") or "local"
	return string.format("%s-%d-%d", name, time(), self.counter)
end

function SK.History:Append(event)
	local db = SK.Saved:History()
	if event.id and db.ids[event.id] then
		return false
	end
	if not event.id then
		event.id = self:NewId()
	end
	if not event.time then
		event.time = time()
	end
	db.ids[event.id] = true
	table.insert(db.events, event)
	if SK.Debug then
		SK.Debug:Line("History", event.type or "event", event.id)
	end
	if SK.Events then
		SK.Events:Fire("SK_HISTORY", event)
	end
	return true
end

function SK.History:Events()
	return SK.Saved:History().events
end

function SK.History:Outcome(event)
	local action = event.action or ""
	if action == "Bid" then
		local where = event.bidPosition
		if where == nil or where == "" then
			if event.positionBefore then
				where = tostring(event.positionBefore)
			else
				where = "unseeded"
			end
		end
		local line = "Bid position " .. tostring(where)
		if tostring(where) == "unseeded" and event.roll then
			line = line .. " roll " .. tostring(event.roll)
		end
		return line
	end
	if action == "MS" or action == "OS" then
		if event.roll then
			return action .. " roll " .. tostring(event.roll)
		end
		return action
	end
	if action == "Disenchant" then
		return "Disenchant"
	end
	return action
end

local function cell(value)
	value = tostring(value or "")
	value = string.gsub(value, "[\t\r\n]", " ")
	return value
end

function SK.History:ExportDiscord()
	local lines = { "```", "id\ttime\ttype\taction\tname\tdetail\titem\troll\tpositionBefore\tpositionAfter\tofficer\tdelivered\tteamId\tteamName\tlistId\tlistName\tbidPosition" }
	local events = self:Events()
	for i = 1, #events do
		local event = events[i]
		table.insert(lines, table.concat({
			cell(event.id),
			cell(event.time),
			cell(event.type),
			cell(event.action),
			cell(event.name),
			cell(event.detail),
			cell(event.item),
			cell(event.roll),
			cell(event.positionBefore),
			cell(event.positionAfter),
			cell(event.officer),
			event.delivered and "1" or "0",
			cell(event.teamId),
			cell(event.teamName),
			cell(event.listId),
			cell(event.listName),
			cell(event.bidPosition),
		}, "\t"))
	end
	table.insert(lines, "```")
	return table.concat(lines, "\n")
end

local function splitFields(line)
	local sep = "\t"
	if string.find(line, "\t", 1, true) then
		sep = "\t"
	elseif string.find(line, ";", 1, true) then
		sep = ";"
	elseif string.find(line, "|", 1, true) then
		sep = "|"
	end
	local out = {}
	local rest = line
	while true do
		local at = string.find(rest, sep, 1, true)
		if not at then
			table.insert(out, rest)
			break
		end
		table.insert(out, string.sub(rest, 1, at - 1))
		rest = string.sub(rest, at + 1)
	end
	return out
end

function SK.History:Parse(text)
	local events = {}
	local errors = {}
	local lineNo = 0
	text = string.gsub(tostring(text or ""), "```%S*", "")
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		lineNo = lineNo + 1
		local trimmed = SK.Trim(line)
		if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
			local fields = splitFields(trimmed)
			local id = fields[1]
			local when = fields[2]
			local header = string.lower(id or "") == "id" and string.lower(when or "") == "time"
			if header then
				id = nil
			elseif #fields < 12 then
				table.insert(errors, "Line " .. lineNo .. " needs the history columns.")
			elseif not id or id == "" then
				table.insert(errors, "Line " .. lineNo .. " has no id.")
			else
				table.insert(events, {
					id = id,
					time = tonumber(when),
					type = fields[3],
					action = fields[4],
					name = fields[5],
					detail = fields[6],
					item = fields[7] ~= "" and fields[7] or nil,
					roll = tonumber(fields[8]),
					positionBefore = tonumber(fields[9]),
					positionAfter = tonumber(fields[10]),
					officer = fields[11],
					delivered = fields[12] == "1",
					teamId = fields[13] ~= "" and fields[13] or nil,
					teamName = fields[14] ~= "" and fields[14] or nil,
					listId = fields[15] ~= "" and fields[15] or nil,
					listName = fields[16] ~= "" and fields[16] or nil,
					bidPosition = fields[17] ~= "" and fields[17] or nil,
				})
			end
		end
	end
	if #events == 0 and #errors == 0 then
		table.insert(errors, "Paste a history code block.")
	end
	return events, errors
end

function SK.History:Merge(events)
	local db = SK.Saved:History()
	db.ids = db.ids or {}
	local added = 0
	local skipped = 0
	for i = 1, #events do
		local event = events[i]
		if event.id and db.ids[event.id] then
			skipped = skipped + 1
		elseif event.id and event.id ~= "" then
			if not event.time then
				event.time = time()
			end
			db.ids[event.id] = true
			table.insert(db.events, event)
			added = added + 1
		end
	end
	table.sort(db.events, function(a, b)
		return (a.time or 0) < (b.time or 0)
	end)
	if SK.Events then
		SK.Events:Fire("SK_HISTORY")
	end
	return added, skipped
end

function SK.History:Clear()
	local db = SK.Saved:History()
	for i = #db.events, 1, -1 do
		db.events[i] = nil
	end
	db.ids = {}
	if SK.Events then
		SK.Events:Fire("SK_HISTORY")
	end
	return nil
end

function SK.History:MarkDelivered(id, silent)
	if not id or id == "" then
		return false
	end
	local events = SK.Saved:History().events
	for i = 1, #events do
		if events[i].id == id then
			events[i].delivered = true
			if not silent and SK.Events then
				SK.Events:Fire("SK_DELIVERED", id)
			end
			return true
		end
	end
	return false
end
