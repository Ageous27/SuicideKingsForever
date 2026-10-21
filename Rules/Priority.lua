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
		return { "Bid", "MS", "OS", "Pass" }
	end
	return { "Bid", "MS", "OS", "Pass" }
end

function SK.Rules.Priority.Allows(choices, choice)
	return allows(choices, choice)
end

local function byPosition(a, b)
	return (a.position or 9999) < (b.position or 9999)
end

local function byBid(a, b)
	if a.unseeded ~= b.unseeded then
		return a.unseeded and true or false
	end
	if a.unseeded and b.unseeded then
		return (a.roll or 0) > (b.roll or 0)
	end
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

function SK.Rules.Priority.Decide(responses, seeding, rolloff, contest)
	local bids = {}
	local ms = {}
	local os = {}
	local passes = {}
	local unseededBids = {}
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
			elseif choice == "Bid" and (row.position or row.unseeded) then
				table.insert(bids, row)
				if row.unseeded then
					table.insert(unseededBids, row)
				end
			elseif choice == "MS" or choice == "Roll" then
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
	table.sort(bids, byBid)
	table.sort(ms, byRoll)
	table.sort(os, byRoll)
	local showBids, showMs, showOs, showPasses, showDuplicates = bids, ms, os, passes, duplicates

	local winner
	local tie
	local ordered = {}
	local contestHandled = false
	if contest and contest.active and not (rolloff and rolloff.side) then
		local function plusCount(person)
			local map = contest.plus
			if type(map) ~= "table" then
				return 0
			end
			return map[string.lower(person.name or "")] or 0
		end
		local pugMs = {}
		local coreMs = {}
		local coreOs = {}
		local coreBids = {}
		local coreUnseededBids = {}
		local coreUnseededMs = {}
		local coreUnseededOs = {}
		for i = 1, #ms do
			if ms[i].pug then
				table.insert(pugMs, ms[i])
			else
				table.insert(coreMs, ms[i])
				if ms[i].unseeded then
					table.insert(coreUnseededMs, ms[i])
				end
			end
		end
		for i = 1, #os do
			if not os[i].pug then
				table.insert(coreOs, os[i])
				if os[i].unseeded then
					table.insert(coreUnseededOs, os[i])
				end
			end
		end
		for i = 1, #bids do
			if not bids[i].pug then
				table.insert(coreBids, bids[i])
				if bids[i].unseeded then
					table.insert(coreUnseededBids, bids[i])
				end
			end
		end
		if #pugMs > 0 then
			contestHandled = true
			local plus0 = false
			for i = 1, #pugMs do
				if plusCount(pugMs[i]) < 1 then
					plus0 = true
				end
			end
			local blocked = plus0 or #coreBids > 0 or #coreMs > 0
			local eligible = {}
			for i = 1, #coreMs do
				if coreMs[i].roll then
					table.insert(eligible, coreMs[i])
				end
			end
			for i = 1, #coreBids do
				if coreBids[i].roll then
					table.insert(eligible, coreBids[i])
				end
			end
			for i = 1, #pugMs do
				if pugMs[i].roll and (plusCount(pugMs[i]) < 1 or not blocked) then
					table.insert(eligible, pugMs[i])
				end
			end
			local pugWon = false
			if #eligible > 0 then
				local top = eligible[1].roll or 0
				for i = 2, #eligible do
					local roll = eligible[i].roll or 0
					if roll > top then
						top = roll
					end
				end
				local tied = {}
				local pugTied = false
				local coreTied = false
				for i = 1, #eligible do
					if (eligible[i].roll or 0) == top then
						table.insert(tied, eligible[i])
						if tied[#tied].pug then
							pugTied = true
						else
							coreTied = true
						end
					end
				end
				if pugTied and coreTied then
					tie = { tier = "MS", names = tied, side = true }
					pugWon = true
				elseif pugTied then
					winner, tie = pickRolls(tied)
					if tie then
						tie = { tier = "MS", names = tie }
					end
					pugWon = true
				end
			end
			if not pugWon then
				bids = coreBids
				ms = coreMs
				os = coreOs
				unseededBids = coreUnseededBids
				unseededMs = coreUnseededMs
				unseededOs = coreUnseededOs
			end
		end
	end
	if contestHandled and (winner or tie) then
		winner = winner
	elseif seeding and not rolloff and (#unseededBids + #unseededMs + #unseededOs) > 0 then
		local pool = unseededMs
		local tier = "MS"
		if #unseededBids > 0 then
			pool = unseededBids
			tier = "Bid"
		elseif #unseededOs > 0 and #unseededMs == 0 then
			pool = unseededOs
			tier = "OS"
		end
		winner, tie = pickRolls(pool)
		if tie then
			tie = { tier = tier, names = tie }
		end
	elseif #bids > 0 then
		local topRoll = bids[1].roll or 0
		local tiedBids = nil
		if bids[1].unseeded and not bids[1].position then
			tiedBids = {}
			for i = 1, #bids do
				local row = bids[i]
				if row.unseeded and not row.position and (row.roll or 0) == topRoll then
					table.insert(tiedBids, row)
				end
			end
			if #tiedBids < 2 then
				tiedBids = nil
			end
		end
		if tiedBids then
			tie = { tier = "Bid", names = tiedBids }
		else
			winner = bids[1]
		end
	elseif #ms > 0 then
		winner, tie = pickRolls(ms)
		if tie then
			tie = { tier = "MS", names = tie }
		end
	elseif #os > 0 then
		winner, tie = pickRolls(os)
		if tie then
			tie = { tier = "OS", names = tie }
		end
	end
	appendAll(ordered, showBids)
	appendAll(ordered, showMs)
	appendAll(ordered, showOs)
	appendAll(ordered, showPasses)
	appendAll(ordered, showDuplicates)
	return { ordered = ordered, winner = winner, tie = tie }
end
