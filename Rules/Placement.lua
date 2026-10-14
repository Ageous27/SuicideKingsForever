SK = SK or {}
SK.Rules = SK.Rules or {}
SK.Rules.Placement = SK.Rules.Placement or {}

local function unwrapCodeBlock(text)
	local kept = {}
	for line in string.gmatch(tostring(text or "") .. "\n", "(.-)\n") do
		local trimmed = SK.Trim(line)
		if trimmed ~= "```" and not string.match(trimmed, "^```%w*$") then
			table.insert(kept, line)
		end
	end
	return table.concat(kept, "\n")
end

local function splitLine(line)
	local sep = ","
	if string.find(line, "\t", 1, true) then
		sep = "\t"
	end
	local fields = {}
	local start = 1
	local len = string.len(line)
	while start <= len do
		local found = string.find(line, sep, start, true)
		if not found then
			table.insert(fields, SK.Trim(string.sub(line, start)))
			break
		end
		table.insert(fields, SK.Trim(string.sub(line, start, found - 1)))
		start = found + 1
		if start > len then
			table.insert(fields, "")
		end
	end
	return fields, sep
end

local function headerLine(fields)
	local first = string.lower(fields[1] or "")
	local second = string.lower(fields[2] or "")
	if #fields == 1 then
		return first == "name" or first == "position" or first == "class"
	end
	if first == "position" and second == "name" then
		return true
	end
	if first == "name" and second == "class" then
		return true
	end
	return false
end

local function finishRow(rows, errors, lineNo, pos, name, class)
	name = SK.Trim(name)
	class = SK.Trim(class)
	pos = SK.Trim(pos)
	if name == "" then
		table.insert(errors, "Line " .. lineNo .. " needs a name.")
		return
	end
	local className = nil
	if class ~= "" then
		className = SK.ClassName(class)
		if not className then
			table.insert(errors, "Line " .. lineNo .. " has an unknown class.")
			return
		end
	end
	local position = nil
	if pos ~= "" then
		position = tonumber(pos)
		if not position or position < 1 or position ~= math.floor(position) then
			table.insert(errors, "Line " .. lineNo .. " has a bad position.")
			return
		end
	end
	if SK.Roster and SK.Roster.Resolve then
		local full, raidClass, err = SK.Roster:Resolve(name)
		if err then
			table.insert(errors, "Line " .. lineNo .. " matches more than one raider.")
			return
		end
		if full then
			name = full
		end
		if not className and raidClass then
			className = raidClass
		end
	end
	table.insert(rows, { name = name, class = className or "", position = position })
end

function SK.Rules.Placement.ParseCSV(text)
	local rows = {}
	local errors = {}
	local lineNo = 0
	for line in string.gmatch(unwrapCodeBlock(text) .. "\n", "(.-)\n") do
		lineNo = lineNo + 1
		line = SK.Trim(line)
		if line ~= "" and string.sub(line, 1, 1) ~= "#" then
			local fields, sep = splitLine(line)
			if not headerLine(fields) then
				local pos, name, class = "", "", ""
				if #fields >= 3 then
					pos = fields[1]
					name = fields[2]
					class = table.concat(fields, sep, 3)
				elseif #fields == 2 then
					local position = tonumber(fields[1])
					if position and position >= 1 and position == math.floor(position) then
						pos = fields[1]
						name = fields[2]
					elseif SK.ClassName(fields[2]) then
						name = fields[1]
						class = fields[2]
					elseif fields[1] == "" then
						name = fields[2]
					else
						name = SK.Trim(fields[1] .. " " .. fields[2])
					end
				else
					name = fields[1] or ""
				end
				finishRow(rows, errors, lineNo, pos, name, class)
			end
		end
	end
	if #rows == 0 and #errors == 0 then
		table.insert(errors, "Paste at least one name.")
	end
	return rows, errors
end

function SK.Rules.Placement.Normalize(rows)
	local placed = {}
	local openRows = {}
	local seen = {}
	for i = 1, #rows do
		local row = rows[i]
		local key = string.lower(row.name)
		if seen[key] then
			return nil, "Duplicate name: " .. row.name
		end
		seen[key] = true
		if row.position then
			table.insert(placed, row)
		else
			table.insert(openRows, row)
		end
	end
	table.sort(placed, function(a, b)
		return a.position < b.position
	end)
	local used = {}
	for i = 1, #placed do
		local position = placed[i].position
		if used[position] then
			return nil, "Duplicate position " .. position
		end
		used[position] = true
		if i > 1 and position ~= placed[i - 1].position + 1 then
			return nil, "Gap between positions " .. placed[i - 1].position .. " and " .. position
		end
	end
	local startAt = #openRows + 1
	local out = {}
	for i = 1, #openRows do
		table.insert(out, {
			name = openRows[i].name,
			class = openRows[i].class,
			position = nil,
			status = openRows[i].status,
			rolls = openRows[i].rolls,
			hold = openRows[i].hold,
			pug = false,
		})
	end
	for i = 1, #placed do
		table.insert(out, {
			name = placed[i].name,
			class = placed[i].class,
			position = startAt + i - 1,
			status = placed[i].status,
			rolls = placed[i].rolls,
			hold = placed[i].hold,
			pug = false,
		})
	end
	return out
end

function SK.Rules.Placement.BidDrop(placed, winner, bidders, mode)
	local winnerKey = string.lower(winner)
	local ordered = {}
	for i = 1, #placed do
		table.insert(ordered, placed[i])
	end
	table.sort(ordered, function(a, b)
		return (a.position or 0) < (b.position or 0)
	end)
	local winnerRow
	local rest = {}
	for i = 1, #ordered do
		if string.lower(ordered[i].name) == winnerKey then
			winnerRow = ordered[i]
		else
			table.insert(rest, ordered[i])
		end
	end
	if not winnerRow or not winnerRow.position then
		return placed
	end
	local hole = winnerRow.position
	for i = 1, #rest do
		local row = rest[i]
		if row.position and row.position > hole then
			if row.hold then
				break
			end
			local old = row.position
			row.position = hole
			hole = old
		end
	end
	local function maxPos()
		local maxValue = 0
		for i = 1, #rest do
			if (rest[i].position or 0) > maxValue then
				maxValue = rest[i].position
			end
		end
		return maxValue
	end
	local dest
	if mode == "below" then
		local lowestPos = -1
		for i = 1, #bidders do
			local bidder = string.lower(bidders[i])
			if bidder ~= winnerKey then
				for j = 1, #rest do
					if string.lower(rest[j].name) == bidder and (rest[j].position or 0) > lowestPos then
						lowestPos = rest[j].position or 0
					end
				end
			end
		end
		if lowestPos > 0 then
			dest = lowestPos + 1
			local blocked = false
			local last = #rest
			for i = 1, #rest do
				if rest[i].position and rest[i].position >= dest then
					if rest[i].hold and rest[i].position == dest then
						blocked = true
					end
					if rest[i].hold then
						last = i - 1
						break
					end
				end
			end
			if blocked then
				dest = nil
			else
				for i = last, 1, -1 do
					local row = rest[i]
					if row.position and row.position >= dest and not row.hold then
						row.position = row.position + 1
					end
				end
			end
		end
	end
	if not dest then
		dest = maxPos() + 1
	end
	winnerRow.position = dest
	table.insert(rest, winnerRow)
	return rest
end
