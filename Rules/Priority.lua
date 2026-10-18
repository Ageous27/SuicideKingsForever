SK = SK or {}
SK.Rules = SK.Rules or {}
SK.Rules.Priority = SK.Rules.Priority or {}

local function allows(list, choice)
	for i = 1, #list do
		if list[i] == choice then
			return true
		end
	end
	return false
end

function SK.Rules.Priority.Choices(row, seeding, locked)
	if not row then
		return {}
	end
	if locked and row.rolls then
		return SK.Rules.Reconcile.Choices(row.rolls, row, seeding)
	end
	if row.pug then
		return { "MS", "OS", "Pass" }
	end
	local status = row.status
	if status == "Bench" or status == "Absent" or status == "No-call/no-show" then
		return {}
	end
	if seeding and not row.position then
		return { "MS", "OS", "Pass" }
	end
	return { "Bid", "MS", "OS", "Pass" }
end

function SK.Rules.Priority.Allows(choices, choice)
	return allows(choices, choice)
end

local function byPosition(a, b)
	return (a.position or 9999) < (b.position or 9999)
end

local function byRoll(a, b)
	local ar = a.roll or 0
	local br = b.roll or 0
	if ar ~= br then
		return ar > br
	end
	return (a.position or 9999) < (b.position or 9999)
end

local function pickRolls(list)
	if #list == 0 then
		return nil, nil
	end
	table.sort(list, byRoll)
	local top = list[1].roll or 0
	local tied = {}
	for i = 1, #list do
		if (list[i].roll or 0) == top then
			table.insert(tied, list[i])
		end
	end
	if #tied == 1 then
		return tied[1], nil
	end
	local placed = {}
	for i = 1, #tied do
		if tied[i].position then
			table.insert(placed, tied[i])
		end
	end
	if #placed > 0 then
		table.sort(placed, byPosition)
		return placed[1], nil
	end
	return nil, tied
end

local function appendAll(into, list)
	for i = 1, #list do
		table.insert(into, list[i])
	end
end

function SK.Rules.Priority.Decide(responses, seeding, rolloff)
	local bids = {}
	local ms = {}
	local os = {}
	local passes = {}
	local unseededMs = {}
	local unseededOs = {}
	local duplicates = {}
	local allowed
	local tierOnly
	if rolloff and rolloff.names then
		allowed = rolloff.names
		tierOnly = rolloff.tier
	end
	for i = 1, #(responses or {}) do
		local row = responses[i]
		local key = string.lower(row.name)
		if row.duplicate or row.choice == "Duplicate" then
			if not allowed or allowed[key] then
				table.insert(duplicates, row)
			end
		elseif not allowed or allowed[key] then
			local choice = row.choice
			if tierOnly and choice ~= tierOnly and choice ~= "Pass" then
				choice = nil
			end
			if choice == "Pass" then
				table.insert(passes, row)
			elseif choice == "Bid" and row.position then
				table.insert(bids, row)
			elseif choice == "MS" then
				table.insert(ms, row)
				if row.unseeded then
					table.insert(unseededMs, row)
				end
			elseif choice == "OS" then
				table.insert(os, row)
				if row.unseeded then
					table.insert(unseededOs, row)
				end
			end
		end
	end
	table.sort(bids, byPosition)
	table.sort(ms, byRoll)
	table.sort(os, byRoll)

	local winner
	local tie
	local ordered = {}
	if seeding and not rolloff and (#unseededMs + #unseededOs) > 0 then
		local pool = #unseededMs > 0 and unseededMs or unseededOs
		local tier = #unseededMs > 0 and "MS" or "OS"
		winner, tie = pickRolls(pool)
		if tie then
			tie = { tier = tier, names = tie }
		end
		appendAll(ordered, unseededMs)
		appendAll(ordered, unseededOs)
		appendAll(ordered, bids)
		for i = 1, #ms do
			if not ms[i].unseeded then
				table.insert(ordered, ms[i])
			end
		end
		for i = 1, #os do
			if not os[i].unseeded then
				table.insert(ordered, os[i])
			end
		end
	elseif #bids > 0 then
		winner = bids[1]
		appendAll(ordered, bids)
		appendAll(ordered, ms)
		appendAll(ordered, os)
	elseif #ms > 0 then
		winner, tie = pickRolls(ms)
		if tie then
			tie = { tier = "MS", names = tie }
		end
		appendAll(ordered, bids)
		appendAll(ordered, ms)
		appendAll(ordered, os)
	elseif #os > 0 then
		winner, tie = pickRolls(os)
		if tie then
			tie = { tier = "OS", names = tie }
		end
		appendAll(ordered, bids)
		appendAll(ordered, ms)
		appendAll(ordered, os)
	else
		appendAll(ordered, bids)
		appendAll(ordered, ms)
		appendAll(ordered, os)
	end
	appendAll(ordered, passes)
	appendAll(ordered, duplicates)
	return { ordered = ordered, winner = winner, tie = tie }
end
