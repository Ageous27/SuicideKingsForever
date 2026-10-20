SK = SK or {}
SK.Rules = SK.Rules or {}
SK.Rules.Reconcile = SK.Rules.Reconcile or {}

SK.Rules.Reconcile.STATUSES = { "Present", "Bench", "Absent", "No-call/no-show", "Pug/fill" }
SK.Rules.Reconcile.ROLLS = { "Bid, MS, OS", "MS, OS", "Cannot Roll" }

function SK.Rules.Reconcile.Defaults(status)
	if status == "Bench" or status == "Absent" or status == "No-call/no-show" then
		local mode = "hold"
		if status == "Bench" then
			mode = "raise"
		elseif status == "No-call/no-show" then
			mode = "demote"
		end
		if SK.Settings and SK.Settings.StatusRule then
			local configured = SK.Settings:StatusRule(status)
			if configured then
				mode = configured
			end
		end
		return "Cannot Roll", mode ~= "raise"
	end
	if status == "Pug/fill" then
		return "MS, OS", true, "Pug/fill"
	end
	return "Bid, MS, OS", false, "Allow raise"
end

local function demoteSteps(status)
	if status ~= "Bench" and status ~= "Absent" and status ~= "No-call/no-show" then
		return 0
	end
	if SK.Settings and SK.Settings.StatusRule then
		local mode, steps = SK.Settings:StatusRule(status)
		if mode == "demote" then
			return steps
		end
		return 0
	end
	if status == "No-call/no-show" then
		return 1
	end
	return 0
end

function SK.Rules.Reconcile.Next(list, current)
	for i = 1, #list do
		if list[i] == current then
			if i == #list then
				return list[1]
			end
			return list[i + 1]
		end
	end
	return list[1]
end

function SK.Rules.Reconcile.DropNoCalls(rows)
	local notes = {}
	local moved = {}
	local remaining = {}
	local maxSteps = 0
	for i = 1, #rows do
		local row = rows[i]
		local steps = 0
		if not row.pug and row.position then
			steps = demoteSteps(row.status)
		end
		if steps > 0 then
			remaining[row] = steps
			if steps > maxSteps then
				maxSteps = steps
			end
		end
	end
	for _ = 1, maxSteps do
		local pending = {}
		for i = 1, #rows do
			if remaining[rows[i]] and remaining[rows[i]] > 0 then
				table.insert(pending, rows[i])
			end
		end
		if #pending == 0 then
			break
		end
		table.sort(pending, function(a, b)
			return a.position > b.position
		end)
		for i = 1, #pending do
			local row = pending[i]
			local nxt
			local nxtPos
			for j = 1, #rows do
				local other = rows[j]
				if other ~= row and other.position and other.position > row.position then
					if not nxtPos or other.position < nxtPos then
						nxt = other
						nxtPos = other.position
					end
				end
			end
			local key = string.lower(row.name)
			if nxt then
				row.position, nxt.position = nxt.position, row.position
				moved[key] = (moved[key] or 0) + 1
				notes[key] = "Down " .. moved[key]
				remaining[row] = remaining[row] - 1
			else
				if not moved[key] then
					notes[key] = "Stays last"
				end
				remaining[row] = 0
			end
		end
	end
	return notes
end

function SK.Rules.Reconcile.Rule(row, notes)
	if row.pug or row.status == "Pug/fill" then
		return "Pug/fill"
	end
	local noted = notes and notes[string.lower(row.name)]
	if noted then
		return noted
	end
	if row.hold then
		return "Hold"
	end
	return "Allow raise"
end

function SK.Rules.Reconcile.Choices(rolls, row, seeding)
	if rolls == "Cannot Roll" then
		return {}
	end
	if rolls ~= "Bid, MS, OS" then
		return { "MS", "OS", "Pass" }
	end
	return { "Bid", "MS", "OS", "Pass" }
end
