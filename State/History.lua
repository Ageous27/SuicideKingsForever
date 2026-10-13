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

local function cell(value)
	value = tostring(value or "")
	value = string.gsub(value, "[\t\r\n]", " ")
	return value
end

function SK.History:ExportDiscord()
	local lines = { "```", "id\ttime\ttype\taction\tname\tdetail\titem\troll\tpositionBefore\tpositionAfter\tofficer\tdelivered" }
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
		}, "\t"))
	end
	table.insert(lines, "```")
	return table.concat(lines, "\n")
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
			local id, when, eventType, action, name, detail, item, roll, beforePos, afterPos, officer, delivered = string.match(trimmed, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
			local header = string.lower(id or "") == "id" and string.lower(when or "") == "time"
			if header then
				id = nil
			elseif not id or id == "" then
				table.insert(errors, "Line " .. lineNo .. " has no id.")
			else
				table.insert(events, {
					id = id,
					time = tonumber(when),
					type = eventType,
					action = action,
					name = name,
					detail = detail,
					item = item ~= "" and item or nil,
					roll = tonumber(roll),
					positionBefore = tonumber(beforePos),
					positionAfter = tonumber(afterPos),
					officer = officer,
					delivered = delivered == "1",
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
