SK = SK or {}
SK.List = SK.List or {}

local function clear(list)
	for i = #list, 1, -1 do
		list[i] = nil
	end
end

local function touch(action, name, detail)
	SK.List:RebuildIndex()
	SK.Session:RefreshSeeding()
	SK.History:Append({
		type = "edit",
		action = action,
		name = name,
		detail = detail,
		officer = UnitName("player"),
	})
	SK.Events:Fire("SK_LIST_CHANGED", action)
end

function SK.List:RebuildIndex()
	self.index = {}
	local list = SK.Saved:List()
	for i = 1, #list do
		self.index[string.lower(list[i].name)] = i
	end
end

function SK.List:Find(name)
	if not name or not self.index then
		return nil
	end
	local index = self.index[string.lower(name)]
	if not index then
		return nil
	end
	return SK.Saved:List()[index], index
end

function SK.List:Core()
	local out = {}
	local list = SK.Saved:List()
	for i = 1, #list do
		if not list[i].pug then
			table.insert(out, list[i])
		end
	end
	return out
end

function SK.List:Pugs()
	local out = {}
	local list = SK.Saved:List()
	for i = 1, #list do
		if list[i].pug then
			table.insert(out, list[i])
		end
	end
	return out
end

function SK.List.StatusText(row)
	if not row then
		return "—"
	end
	if row.pug then
		return "Pug/fill"
	end
	if row.status and row.status ~= "" then
		if row.hold then
			return row.status .. " · Hold"
		end
		return row.status .. " · Raise"
	end
	if not row.position then
		return "Unseeded"
	end
	return "—"
end

function SK.List:Repack()
	local openRows = {}
	local placed = {}
	local pugs = {}
	local list = SK.Saved:List()
	for i = 1, #list do
		local row = list[i]
		if row.pug then
			table.insert(pugs, row)
		elseif row.position then
			table.insert(placed, row)
		else
			table.insert(openRows, row)
		end
	end
	table.sort(placed, function(a, b)
		return a.position < b.position
	end)
	local startAt = #openRows + 1
	clear(list)
	for i = 1, #openRows do
		openRows[i].position = nil
		table.insert(list, openRows[i])
	end
	for i = 1, #placed do
		placed[i].position = startAt + i - 1
		table.insert(list, placed[i])
	end
	for i = 1, #pugs do
		pugs[i].position = nil
		table.insert(list, pugs[i])
	end
end

function SK.List:SortInPlace()
	local openRows = {}
	local placed = {}
	local pugs = {}
	local list = SK.Saved:List()
	for i = 1, #list do
		local row = list[i]
		if row.pug then
			table.insert(pugs, row)
		elseif row.position then
			table.insert(placed, row)
		else
			table.insert(openRows, row)
		end
	end
	table.sort(placed, function(a, b)
		return a.position < b.position
	end)
	clear(list)
	for i = 1, #openRows do
		table.insert(list, openRows[i])
	end
	for i = 1, #placed do
		table.insert(list, placed[i])
	end
	for i = 1, #pugs do
		table.insert(list, pugs[i])
	end
end

function SK.List:SetDraft(name, patch)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	local row = self:Find(name)
	if not row then
		return "That name is not on the list."
	end
	if patch.status == "--" and not row.pug then
		row.status = nil
		row.rolls = nil
		row.hold = false
	elseif patch.status and not row.pug then
		row.status = patch.status
		local rolls, hold = SK.Rules.Reconcile.Defaults(patch.status)
		row.rolls = rolls
		row.hold = hold
	end
	if patch.rolls then
		row.rolls = patch.rolls
	end
	if patch.hold ~= nil and not row.pug then
		row.hold = patch.hold and true or false
	end
	self:RebuildIndex()
	SK.Events:Fire("SK_LIST_CHANGED", "draft")
	return nil
end

function SK.List:WriteCore(rows, action, detail)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	local pugs = self:Pugs()
	local list = SK.Saved:List()
	clear(list)
	for i = 1, #rows do
		table.insert(list, rows[i])
	end
	for i = 1, #pugs do
		table.insert(list, pugs[i])
	end
	SK.Saved:Session().posBase = nil
	touch(action, nil, detail)
	return nil
end

function SK.List:ReplaceCore(rows)
	return self:WriteCore(rows, "import", "replace")
end

function SK.List:ExportDiscord()
	local lines = { "```", "Position\tName\tClass" }
	local core = self:Core()
	for i = 1, #core do
		local row = core[i]
		local position = row.position and tostring(row.position) or ""
		table.insert(lines, position .. "\t" .. (row.name or "") .. "\t" .. (row.class or ""))
	end
	table.insert(lines, "```")
	return table.concat(lines, "\n")
end

function SK.List:Clear()
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	local list = SK.Saved:List()
	for i = #list, 1, -1 do
		list[i] = nil
	end
	SK.Saved:Session().posBase = nil
	touch("clear", nil, "list")
	return nil
end

function SK.List:PlanMerge(incoming)
	local core = {}
	local byName = {}
	local current = self:Core()
	local anyPlaced = false
	for i = 1, #current do
		local copy = {
			name = current[i].name,
			class = current[i].class,
			position = current[i].position,
			status = current[i].status,
			rolls = current[i].rolls,
			hold = current[i].hold,
			pug = false,
		}
		if copy.position then
			anyPlaced = true
		end
		table.insert(core, copy)
		byName[string.lower(copy.name)] = copy
	end
	local nextPos = 0
	if anyPlaced then
		for i = 1, #core do
			if core[i].position and core[i].position > nextPos then
				nextPos = core[i].position
			end
		end
	end
	for i = 1, #incoming do
		local row = incoming[i]
		local existing = byName[string.lower(row.name)]
		if existing then
			existing.class = row.class
			if row.position then
				existing.position = row.position
			end
		else
			local position = row.position
			if not position and anyPlaced then
				nextPos = nextPos + 1
				position = nextPos
			end
			table.insert(core, {
				name = row.name,
				class = row.class,
				position = position,
				status = nil,
				pug = false,
			})
			byName[string.lower(row.name)] = core[#core]
		end
	end
	return SK.Rules.Placement.Normalize(core)
end

function SK.List:MergeCore(incoming)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	local packed, err = self:PlanMerge(incoming)
	if not packed then
		return err
	end
	return self:WriteCore(packed, "import", "merge")
end

function SK.List:ApplySnapshot(rows)
	local list = SK.Saved:List()
	clear(list)
	for i = 1, #rows do
		table.insert(list, rows[i])
	end
	self:RebuildIndex()
	SK.Session:RefreshSeeding()
	SK.Events:Fire("SK_LIST_CHANGED", "snapshot")
end

function SK.List:Move(name, dir)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	local row, index = self:Find(name)
	if not row or row.pug then
		return "Select a core name"
	end
	local list = SK.Saved:List()
	local other = list[index + dir]
	if not other or other.pug then
		return nil
	end
	if (row.position == nil) ~= (other.position == nil) then
		return "Unseeded names stay above placed names"
	end
	list[index], list[index + dir] = other, row
	if row.position and other.position then
		row.position, other.position = other.position, row.position
	end
	touch("swap", row.name, other.name)
	return nil
end

function SK.List:MoveBottom(name)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	local row, index = self:Find(name)
	if not row or row.pug then
		return "Select a core name"
	end
	local list = SK.Saved:List()
	if row.position then
		local maxPos = row.position
		for i = 1, #list do
			local other = list[i]
			if other.position and not other.pug and other.position > maxPos then
				maxPos = other.position
			end
		end
		if row.position == maxPos then
			return nil
		end
		local old = row.position
		for i = 1, #list do
			local other = list[i]
			if other ~= row and other.position and not other.pug and other.position > old then
				other.position = other.position - 1
			end
		end
		row.position = maxPos
		self:SortInPlace()
	else
		local dest = #list + 1
		for i = 1, #list do
			if list[i].pug or list[i].position then
				dest = i
				break
			end
		end
		if index == dest - 1 then
			return nil
		end
		table.remove(list, index)
		if index < dest then
			dest = dest - 1
		end
		table.insert(list, dest, row)
	end
	touch("movebottom", row.name)
	return nil
end

function SK.List:EnsurePosBase()
	local session = SK.Saved:Session()
	if type(session.posBase) == "table" then
		return session.posBase
	end
	local base = {}
	local list = SK.Saved:List()
	for i = 1, #list do
		local person = list[i]
		if not person.pug then
			base[string.lower(person.name)] = person.position or 0
		end
	end
	session.posBase = base
	return base
end

function SK.List:ClearPosBase()
	SK.Saved:Session().posBase = nil
end

function SK.List:Insert(name, class)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	name = SK.Trim(name)
	if name == "" then
		return "Enter a name."
	end
	if self:Find(name) then
		return "That name is already on the list."
	end
	local className = SK.ClassName(class)
	if not className then
		return "Unknown class."
	end
	local list = SK.Saved:List()
	local row = { name = name, class = className, position = nil, status = nil, pug = false }
	local seeding = SK.Session:IsSeeding()
	if not seeding then
		local coreCount = #self:Core()
		row.position = coreCount + 1
		local at = #list + 1
		for i = 1, #list do
			if list[i].pug then
				at = i
				break
			end
		end
		table.insert(list, at, row)
		self:Repack()
	else
		local at = #list + 1
		for i = 1, #list do
			if list[i].pug or list[i].position then
				at = i
				break
			end
		end
		table.insert(list, at, row)
	end
	touch("insert", name, className)
	return nil
end

function SK.List:AddCore(name, class, status)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	name = SK.Trim(name)
	if name == "" then
		return "Enter a name."
	end
	if self:Find(name) then
		return "That name is already on the list."
	end
	local className = SK.ClassName(class) or "Warrior"
	local rolls, hold = SK.Rules.Reconcile.Defaults(status)
	local list = SK.Saved:List()
	local row = {
		name = name,
		class = className,
		position = nil,
		status = status,
		pug = false,
		rolls = rolls,
		hold = hold,
	}
	if SK.Session:IsSeeding() then
		local at = #list + 1
		for i = 1, #list do
			if list[i].pug or list[i].position then
				at = i
				break
			end
		end
		table.insert(list, at, row)
	else
		row.position = #self:Core() + 1
		local at = #list + 1
		for i = 1, #list do
			if list[i].pug then
				at = i
				break
			end
		end
		table.insert(list, at, row)
		self:Repack()
	end
	touch("insert", name, className)
	return nil
end

function SK.List:AddPug(name, class)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	name = SK.Trim(name)
	if name == "" then
		return "Enter a name."
	end
	if self:Find(name) then
		return "That name is already on the list."
	end
	local className = SK.ClassName(class)
	if not className then
		return "Unknown class."
	end
	table.insert(SK.Saved:List(), {
		name = name,
		class = className,
		position = nil,
		status = "Pug/fill",
		pug = true,
		rolls = "MS, OS",
		hold = false,
	})
	touch("addpug", name, className)
	return nil
end

function SK.List:AddPugQuiet(name, class)
	if self:Find(name) then
		return false
	end
	local className = SK.ClassName(class) or "Warrior"
	table.insert(SK.Saved:List(), {
		name = name,
		class = className,
		position = nil,
		status = "Pug/fill",
		pug = true,
		rolls = "MS, OS",
		hold = false,
	})
	return true
end

function SK.List:Remove(name)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	local row, index = self:Find(name)
	if not row then
		return "Select a name."
	end
	table.remove(SK.Saved:List(), index)
	local kind = row.pug and "pug" or "core"
	if not row.pug then
		self:Repack()
	end
	touch("remove", row.name, kind)
	return nil
end

function SK.List:EndRaid()
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	local list = SK.Saved:List()
	local kept = {}
	local dropped = {}
	for i = 1, #list do
		if list[i].pug then
			table.insert(dropped, list[i].name)
		else
			table.insert(kept, list[i])
		end
	end
	clear(list)
	for i = 1, #kept do
		table.insert(list, kept[i])
	end
	if SK.Session.Unlock then
		SK.Session:Unlock()
	end
	touch("endraid", nil, table.concat(dropped, ", "))
	return nil
end

function SK.List:AwardMove(winner, method, bidders, drop, seedingWin)
	local row = self:Find(winner)
	if not row then
		return nil, nil
	end
	local before = row.position
	if seedingWin and not row.pug and not row.position then
		row.position = 100000
		self:Repack()
	elseif method == "Bid" and row.position and not row.pug then
		local placed = {}
		local list = SK.Saved:List()
		for i = 1, #list do
			if list[i].position and not list[i].pug then
				table.insert(placed, list[i])
			end
		end
		table.sort(placed, function(a, b)
			return a.position < b.position
		end)
		SK.Rules.Placement.BidDrop(placed, winner, bidders or {}, drop)
		self:SortInPlace()
	end
	self:RebuildIndex()
	SK.Session:RefreshSeeding()
	local afterRow = self:Find(winner)
	local after = afterRow and afterRow.position or nil
	SK.Events:Fire("SK_LIST_CHANGED", "award")
	return before, after
end
