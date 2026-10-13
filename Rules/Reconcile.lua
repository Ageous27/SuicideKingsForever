SK = SK or {}
SK.Rules = SK.Rules or {}
SK.Rules.Reconcile = SK.Rules.Reconcile or {}

SK.Rules.Reconcile.STATUSES = { "Present", "Bench", "Absent", "No-call/no-show", "Pug/fill" }
SK.Rules.Reconcile.ROLLS = { "Bid, MS, OS", "MS, OS", "Cannot Roll" }

function SK.Rules.Reconcile.Defaults(status)
	if status == "Bench" then
		return "Cannot Roll", false, "Allow raise"
	end
	if status == "Absent" then
		return "Cannot Roll", true, "Hold"
	end
	if status == "No-call/no-show" then
		return "Cannot Roll", true, "No-call drop"
	end
	if status == "Pug/fill" then
		return "MS, OS", true, "Pug/fill"
	end
	return "Bid, MS, OS", false, "Allow raise"
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
	local pending = {}
	for i = 1, #rows do
		local row = rows[i]
		if not row.pug and row.status == "No-call/no-show" and row.position then
			table.insert(pending, row)
		end
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
			notes[key] = "No-call drop"
		else
			notes[key] = "No-call stays last"
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
	if seeding and row and not row.pug and not row.position then
		return { "MS", "OS", "Pass" }
	end
	return { "Bid", "MS", "OS", "Pass" }
end
