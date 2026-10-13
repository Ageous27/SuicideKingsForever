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

function SK.Rules.Placement.ParseCSV(text)
	local rows = {}
	local errors = {}
	local lineNo = 0
	for line in string.gmatch(unwrapCodeBlock(text) .. "\n", "(.-)\n") do
		lineNo = lineNo + 1
		line = SK.Trim(line)
		if line ~= "" and string.sub(line, 1, 1) ~= "#" then
			local pos, name, class
			if string.find(line, "\t", 1, true) then
				pos, name, class = string.match(line, "^([^\t]*)\t([^\t]*)\t(.*)$")
			else
				pos, name, class = string.match(line, "^([^,]*),([^,]*),(.*)$")
			end
			pos = SK.Trim(pos)
			name = SK.Trim(name)
			class = SK.Trim(class)
			local isHeader = string.lower(pos) == "position" and string.lower(name) == "name"
			if not isHeader and name ~= "" then
				local className = SK.ClassName(class)
				local position
				pos = SK.Trim(pos)
				if name == "" then
					table.insert(errors, "Line " .. lineNo .. " has no name.")
				elseif not className then
					table.insert(errors, "Line " .. lineNo .. " has an unknown class.")
				elseif pos ~= "" then
					position = tonumber(pos)
					if not position or position < 1 or position ~= math.floor(position) then
						table.insert(errors, "Line " .. lineNo .. " has a bad position.")
					else
						table.insert(rows, { name = name, class = className, position = position })
					end
				else
					table.insert(rows, { name = name, class = className, position = nil })
				end
			elseif not isHeader then
				table.insert(errors, "Line " .. lineNo .. " needs Position,Name,Class.")
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
