SK = SK or {}
SK.Teams = SK.Teams or {}

local booted = false
local seq = 0

local function bank()
	if type(SKDB.bank) ~= "table" then
		SKDB.bank = { team = nil, list = nil, teamOrder = {}, teams = {} }
	end
	SKDB.bank.teams = SKDB.bank.teams or {}
	SKDB.bank.teamOrder = SKDB.bank.teamOrder or {}
	return SKDB.bank
end

local function newId(prefix)
	seq = seq + 1
	local who = UnitName and UnitName("player") or "local"
	who = string.gsub(tostring(who), "[^%w]", "")
	if who == "" then
		who = "local"
	end
	return prefix .. who .. tostring(time()) .. tostring(seq) .. tostring(math.random(10000, 99999))
end

local function cleanName(text)
	text = SK.Trim(text or "")
	text = string.gsub(text, "[,;|#]", " ")
	text = string.gsub(text, "%s+", " ")
	return SK.Trim(text)
end

local function blankRules()
	return { items = {}, slots = {} }
end

local function copyRules(rules)
	local out = blankRules()
	if type(rules) ~= "table" then
		return out
	end
	if type(rules.items) == "table" then
		for key, value in pairs(rules.items) do
			if value then
				out.items[tostring(key)] = true
			end
		end
	end
	if type(rules.slots) == "table" then
		for key, value in pairs(rules.slots) do
			if value then
				out.slots[tostring(key)] = true
			end
		end
	end
	return out
end

local function wipeArray(list)
	for i = #list, 1, -1 do
		list[i] = nil
	end
end

local function keysOf(map)
	local out = {}
	for key in pairs(map) do
		table.insert(out, key)
	end
	return out
end

function SK.Teams:Team()
	local db = bank()
	return db.teams[db.team]
end

function SK.Teams:ActiveList()
	local team = self:Team()
	local db = bank()
	if not team then
		return nil
	end
	return team.lists[db.list]
end

function SK.Teams:TeamId()
	local team = self:Team()
	return team and team.id or nil
end

function SK.Teams:TeamName()
	local team = self:Team()
	return team and team.name or "Team"
end

function SK.Teams:ListId()
	local list = self:ActiveList()
	return list and list.id or nil
end

function SK.Teams:ListName()
	local list = self:ActiveList()
	return list and list.name or "List"
end

function SK.Teams:Catalog()
	self:Ensure()
	local db = bank()
	local out = {}
	for i = 1, #db.teamOrder do
		local team = db.teams[db.teamOrder[i]]
		if team then
			table.insert(out, { id = team.id, name = team.name })
		end
	end
	return out
end

function SK.Teams:Lists()
	self:Ensure()
	local team = self:Team()
	local out = {}
	if not team then
		return out
	end
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list then
			table.insert(out, { id = list.id, name = list.name, fixed = list.fixed and true or false })
		end
	end
	return out
end

function SK.Teams:People()
	local team = self:Team()
	local out = {}
	if not team or type(team.people) ~= "table" then
		return out
	end
	for _, person in pairs(team.people) do
		table.insert(out, person)
	end
	table.sort(out, function(a, b)
		return (a.name or "") < (b.name or "")
	end)
	return out
end

function SK.Teams:Person(name)
	if not name or name == "" then
		return nil
	end
	self:Ensure()
	self:Flush()
	local team = self:Team()
	if not team then
		return nil
	end
	return team.people[string.lower(name)]
end

local function makeList(id, name, fixed)
	return {
		id = id,
		name = name,
		fixed = fixed and true or false,
		members = {},
		pos = {},
		rules = blankRules(),
	}
end

local function makeTeam(id, name, listId)
	local list = makeList(listId, "Main", true)
	return {
		id = id,
		name = name,
		people = {},
		listOrder = { listId },
		lists = { [listId] = list },
	}
end

local function migrate()
	local db = bank()
	local teamId = newId("t")
	local listId = newId("l")
	local team = makeTeam(teamId, "Main", listId)
	local list = team.lists[listId]
	local rows = SKDB.list or {}
	for i = 1, #rows do
		local row = rows[i]
		if row.name and row.name ~= "" then
			local key = string.lower(row.name)
			team.people[key] = {
				name = row.name,
				class = row.class,
				status = row.status,
				rolls = row.rolls,
				hold = row.hold and true or false,
				pug = row.pug and true or false,
			}
			if not row.pug then
				list.members[key] = true
				if row.position then
					list.pos[key] = row.position
				end
			end
		end
	end
	db.teams[teamId] = team
	db.teamOrder = { teamId }
	db.team = teamId
	db.list = listId
end

function SK.Teams:Materialize()
	local db = bank()
	local team = db.teams[db.team]
	local list = team and team.lists[db.list]
	if type(SKDB.list) ~= "table" then
		SKDB.list = {}
	end
	wipeArray(SKDB.list)
	if not team or not list then
		return
	end
	local openRows = {}
	local placed = {}
	local pugs = {}
	for key, person in pairs(team.people) do
		if person.pug then
			table.insert(pugs, {
				name = person.name,
				class = person.class,
				position = nil,
				status = person.status or "Pug/fill",
				rolls = person.rolls,
				hold = person.hold and true or false,
				pug = true,
			})
		elseif list.members[key] then
			local row = {
				name = person.name,
				class = person.class,
				position = list.pos[key],
				status = person.status,
				rolls = person.rolls,
				hold = person.hold and true or false,
				pug = false,
			}
			if row.position then
				table.insert(placed, row)
			else
				table.insert(openRows, row)
			end
		end
	end
	table.sort(openRows, function(a, b)
		return a.name < b.name
	end)
	table.sort(placed, function(a, b)
		return a.position < b.position
	end)
	table.sort(pugs, function(a, b)
		return a.name < b.name
	end)
	for i = 1, #openRows do
		table.insert(SKDB.list, openRows[i])
	end
	for i = 1, #placed do
		table.insert(SKDB.list, placed[i])
	end
	for i = 1, #pugs do
		table.insert(SKDB.list, pugs[i])
	end
end

function SK.Teams:Ensure()
	local db = bank()
	if #db.teamOrder == 0 then
		migrate()
	end
	if not db.team or not db.teams[db.team] then
		db.team = db.teamOrder[1]
	end
	local team = db.teams[db.team]
	if team and (not db.list or not team.lists[db.list]) then
		db.list = team.listOrder[1]
	end
	if not booted then
		booted = true
		self:Materialize()
	end
	return db
end

local function onAny(team, key)
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list and list.members[key] then
			return true
		end
	end
	return false
end

function SK.Teams:Flush()
	self:Ensure()
	local db = bank()
	local team = db.teams[db.team]
	local list = team and team.lists[db.list]
	if not team or not list then
		return
	end
	team.people = team.people or {}
	list.members = list.members or {}
	list.pos = list.pos or {}
	local seen = {}
	local rows = SKDB.list or {}
	for i = 1, #rows do
		local row = rows[i]
		if row.name and row.name ~= "" then
			local key = string.lower(row.name)
			seen[key] = true
			local person = team.people[key] or {}
			person.name = row.name
			person.class = row.class
			person.status = row.status
			person.rolls = row.rolls
			person.hold = row.hold and true or false
			person.pug = row.pug and true or false
			team.people[key] = person
			if row.pug then
				local ids = keysOf(team.lists)
				for n = 1, #ids do
					local other = team.lists[ids[n]]
					if other then
						other.members[key] = nil
						other.pos[key] = nil
					end
				end
			else
				list.members[key] = true
				if row.position then
					list.pos[key] = row.position
				else
					list.pos[key] = nil
				end
			end
		end
	end
	local members = keysOf(list.members)
	for i = 1, #members do
		local key = members[i]
		if not seen[key] then
			list.members[key] = nil
			list.pos[key] = nil
		end
	end
	local people = keysOf(team.people)
	for i = 1, #people do
		local key = people[i]
		local person = team.people[key]
		if person and person.pug and not seen[key] then
			team.people[key] = nil
		elseif person and not person.pug and not onAny(team, key) then
			team.people[key] = nil
		end
	end
end

function SK.Teams:Rename(oldName, newName)
	self:Ensure()
	local team = self:Team()
	if not team or not oldName or not newName then
		return nil
	end
	local oldKey = string.lower(oldName)
	local newKey = string.lower(newName)
	local person = team.people[oldKey]
	if not person or oldKey == newKey then
		return nil
	end
	if team.people[newKey] then
		return nil
	end
	person.name = newName
	team.people[newKey] = person
	team.people[oldKey] = nil
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list then
			if list.members[oldKey] then
				list.members[newKey] = true
				list.members[oldKey] = nil
			end
			if list.pos[oldKey] then
				list.pos[newKey] = list.pos[oldKey]
				list.pos[oldKey] = nil
			end
		end
	end
	return newKey
end

function SK.Teams:FillFromRaid()
	local filled = {}
	if not SK.Roster or not SK.Roster.Resolve then
		return filled
	end
	self:Ensure()
	local team = self:Team()
	if not team then
		return filled
	end
	local pending = {}
	for _, person in pairs(team.people) do
		if person.name and person.name ~= "" then
			table.insert(pending, person.name)
		end
	end
	for i = 1, #pending do
		local person = team.people[string.lower(pending[i])]
		if person then
			local full, class, err = SK.Roster:Resolve(person.name)
			if not err and full then
				local key = string.lower(person.name)
				if class and class ~= "" and (not person.class or person.class == "") then
					person.class = class
					filled[key] = true
				end
				if string.lower(full) ~= string.lower(person.name) then
					local renamed = self:Rename(person.name, full)
					if renamed then
						filled[key] = nil
						filled[renamed] = true
					end
				end
			end
		end
	end
	return filled
end

function SK.Teams:Stamp(event)
	if type(event) ~= "table" then
		return event
	end
	local team = self:Team()
	local list = self:ActiveList()
	if team then
		event.teamId = team.id
		event.teamName = team.name
	end
	if list then
		event.listId = list.id
		event.listName = list.name
	end
	return event
end

function SK.Teams:PositionLine(name)
	self:Ensure()
	local team = self:Team()
	if not team or not name or name == "" then
		return "not on the core list"
	end
	local key = string.lower(name)
	local person = team.people[key]
	if not person or person.pug then
		return "not on the core list"
	end
	local bits = {}
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list and list.members[key] then
			if list.pos[key] then
				table.insert(bits, list.name .. " " .. tostring(list.pos[key]))
			else
				table.insert(bits, list.name .. " unseeded")
			end
		elseif list then
			table.insert(bits, list.name .. " not listed")
		end
	end
	if #bits == 0 then
		return "not on the core list"
	end
	return table.concat(bits, ", ")
end

function SK.Teams:IsSeeding(listId)
	self:Ensure()
	local db = bank()
	if not listId or listId == db.list then
		self:Flush()
		listId = db.list
	end
	local team = db.teams[db.team]
	local list = team and team.lists[listId]
	if not list then
		return false
	end
	for key in pairs(list.members) do
		if not list.pos[key] then
			return true
		end
	end
	return false
end

function SK.Teams:Row(listId, name)
	if not name or name == "" then
		return nil
	end
	self:Ensure()
	local db = bank()
	if not listId or listId == db.list then
		return SK.List:Find(name)
	end
	local team = db.teams[db.team]
	local list = team and team.lists[listId]
	if not team or not list then
		return nil
	end
	local key = string.lower(name)
	local person = team.people[key]
	if not person then
		return nil
	end
	if person.pug then
		return {
			name = person.name,
			class = person.class,
			position = nil,
			status = person.status,
			rolls = person.rolls,
			hold = person.hold and true or false,
			pug = true,
		}
	end
	if not list.members[key] then
		return nil
	end
	return {
		name = person.name,
		class = person.class,
		position = list.pos[key],
		status = person.status,
		rolls = person.rolls,
		hold = person.hold and true or false,
		pug = false,
	}
end

function SK.Teams:WithList(listId, fn)
	self:Ensure()
	local db = bank()
	local team = db.teams[db.team]
	if not listId or not team or not team.lists[listId] then
		return fn()
	end
	local prev = db.list
	local switched = prev ~= listId
	if switched then
		self:Flush()
		db.list = listId
		self:Materialize()
		if SK.List then
			SK.List:RebuildIndex()
		end
	end
	local a, b, c = fn()
	if switched then
		self:Flush()
		db.list = prev
		self:Materialize()
		if SK.List then
			SK.List:RebuildIndex()
		end
		if SK.Session then
			SK.Session:RefreshSeeding()
		end
		if SK.Events then
			SK.Events:Fire("SK_LIST_CHANGED", "view")
		end
	end
	return a, b, c
end

local function publish(reason)
	if SK.List then
		SK.List:RebuildIndex()
		SK.List:ClearPosBase()
	end
	if SK.Session then
		SK.Session:RefreshSeeding()
	end
	if SK.Events then
		SK.Events:Fire("SK_LIST_CHANGED", reason or "team")
	end
end

function SK.Teams:SelectList(id)
	self:Ensure()
	local db = bank()
	local team = db.teams[db.team]
	if not team or not team.lists[id] then
		return "That list is not on this team."
	end
	if db.list == id then
		return nil
	end
	self:Flush()
	db.list = id
	self:Materialize()
	publish("view")
	return nil
end

local function structureLock()
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	if SK.Session:IsLocked() then
		return "The raid is locked."
	end
	if SK.Session:Live() then
		return "An item is live."
	end
	return nil
end

function SK.Teams:SelectTeam(id)
	local err = structureLock()
	if err then
		return err
	end
	self:Ensure()
	local db = bank()
	if not db.teams[id] then
		return "That team is gone."
	end
	if db.team == id then
		return nil
	end
	self:Flush()
	db.team = id
	local team = db.teams[id]
	db.list = team.listOrder[1]
	self:Materialize()
	publish("team")
	return nil
end

function SK.Teams:AddTeam(name)
	local err = structureLock()
	if err then
		return err
	end
	name = cleanName(name)
	if name == "" then
		return "Enter a team name."
	end
	self:Flush()
	local db = bank()
	local teamId = newId("t")
	local listId = newId("l")
	db.teams[teamId] = makeTeam(teamId, name, listId)
	table.insert(db.teamOrder, teamId)
	db.team = teamId
	db.list = listId
	self:Materialize()
	publish("team")
	return nil
end

function SK.Teams:RenameTeam(name, id)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	name = cleanName(name)
	if name == "" then
		return "Enter a team name."
	end
	self:Ensure()
	local team = id and bank().teams[id] or self:Team()
	if not team then
		return "That team is gone."
	end
	team.name = name
	publish("team")
	return nil
end

function SK.Teams:RemoveTeam(id)
	local err = structureLock()
	if err then
		return err
	end
	self:Ensure()
	local db = bank()
	if #db.teamOrder <= 1 then
		return "The last team stays."
	end
	if not db.teams[id] then
		return "That team is gone."
	end
	self:Flush()
	db.teams[id] = nil
	for i = #db.teamOrder, 1, -1 do
		if db.teamOrder[i] == id then
			table.remove(db.teamOrder, i)
		end
	end
	if db.team == id then
		db.team = db.teamOrder[1]
		db.list = db.teams[db.team].listOrder[1]
		self:Materialize()
		publish("team")
	end
	return nil
end

function SK.Teams:AddList(name, copyFrom)
	local err = structureLock()
	if err then
		return err
	end
	name = cleanName(name)
	if name == "" then
		return "Enter a list name."
	end
	self:Flush()
	local team = self:Team()
	if not team then
		return "That team is gone."
	end
	local source = copyFrom and team.lists[copyFrom] or nil
	local id = newId("l")
	local list = makeList(id, name, false)
	for key, person in pairs(team.people) do
		if not person.pug then
			list.members[key] = true
			if source and source.members[key] and source.pos[key] then
				list.pos[key] = source.pos[key]
			end
		end
	end
	team.lists[id] = list
	table.insert(team.listOrder, id)
	bank().list = id
	self:Materialize()
	publish("list")
	return nil
end

function SK.Teams:RenameList(name, id)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	name = cleanName(name)
	if name == "" then
		return "Enter a list name."
	end
	self:Ensure()
	local team = self:Team()
	local list = team and (id and team.lists[id] or self:ActiveList())
	if not list then
		return "That list is gone."
	end
	list.name = name
	publish("list")
	return nil
end

function SK.Teams:RemoveList(id)
	local err = structureLock()
	if err then
		return err
	end
	self:Ensure()
	local team = self:Team()
	local list = team and team.lists[id]
	if not list then
		return "That list is gone."
	end
	if list.fixed then
		return "The first list stays."
	end
	self:Flush()
	team.lists[id] = nil
	for i = #team.listOrder, 1, -1 do
		if team.listOrder[i] == id then
			table.remove(team.listOrder, i)
		end
	end
	local people = keysOf(team.people)
	for i = 1, #people do
		local key = people[i]
		local person = team.people[key]
		if person and not person.pug and not onAny(team, key) then
			team.people[key] = nil
		end
	end
	if bank().list == id then
		bank().list = team.listOrder[1]
	end
	self:Materialize()
	publish("list")
	return nil
end

local function hasRules(list)
	local rules = list and list.rules
	if not rules then
		return false
	end
	if type(rules.items) == "table" and next(rules.items) then
		return true
	end
	if type(rules.slots) == "table" and next(rules.slots) then
		return true
	end
	return false
end

function SK.Teams:UnclaimedList()
	self:Ensure()
	local team = self:Team()
	if not team then
		return nil
	end
	local found = nil
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list and not hasRules(list) then
			if found then
				return nil
			end
			found = list
		end
	end
	return found
end

function SK.Teams:Match(itemID, slot)
	self:Ensure()
	local team = self:Team()
	if not team then
		return nil
	end
	local id = itemID and tostring(itemID) or nil
	if id and id ~= "" then
		for i = 1, #team.listOrder do
			local list = team.lists[team.listOrder[i]]
			if list and list.rules and list.rules.items and list.rules.items[id] then
				return list
			end
		end
	end
	if slot and slot ~= "" then
		for i = 1, #team.listOrder do
			local list = team.lists[team.listOrder[i]]
			if list and list.rules and list.rules.slots and list.rules.slots[slot] then
				return list
			end
		end
	end
	return self:UnclaimedList()
end

function SK.Teams:Assign(item)
	if not item then
		return
	end
	local lists = self:Lists()
	if #lists == 1 then
		item.listId = lists[1].id
		item.listName = lists[1].name
		return
	end
	if item.listPick then
		return
	end
	local slot = nil
	if SK.Item and SK.Item.Slot then
		slot = SK.Item.Slot(item.itemID)
	end
	item.slot = slot
	local list = self:Match(item.itemID, slot)
	if list then
		item.listId = list.id
		item.listName = list.name
	else
		item.listId = nil
		item.listName = nil
	end
end

local function taken(kind, key, exceptId)
	local team = SK.Teams:Team()
	if not team then
		return nil
	end
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list and list.id ~= exceptId then
			local rules = list.rules
			local draft = list.draft
			if rules and rules[kind] and rules[kind][key] then
				return list.name .. " already uses that."
			end
			if draft and draft[kind] and draft[kind][key] then
				return list.name .. " already uses that."
			end
		end
	end
	return nil
end

function SK.Teams:Draft(listId)
	local team = self:Team()
	local list = team and team.lists[listId or bank().list]
	if not list then
		return nil
	end
	if not list.draft then
		list.draft = copyRules(list.rules)
	end
	return list.draft
end

function SK.Teams:RuleBlurb(listId)
	self:Ensure()
	local team = self:Team()
	local list = team and team.lists[listId]
	if not list then
		return ""
	end
	local rules = list.draft or list.rules or blankRules()
	local slots = {}
	for key in pairs(rules.slots or {}) do
		table.insert(slots, key)
	end
	table.sort(slots)
	local items = {}
	for key in pairs(rules.items or {}) do
		table.insert(items, "Item " .. key)
	end
	table.sort(items)
	if #slots == 0 and #items == 0 then
		local open = self:UnclaimedList()
		if open and open.id == list.id then
			return "Everything else"
		end
		return "No rules"
	end
	for i = 1, #items do
		table.insert(slots, items[i])
	end
	return table.concat(slots, ", ")
end

function SK.Teams:RuleRows()
	self:Ensure()
	local list = self:ActiveList()
	local rules = list and (list.draft or list.rules) or blankRules()
	local rows = {}
	for key in pairs(rules.items or {}) do
		table.insert(rows, { kind = "items", key = key, label = "Item " .. key })
	end
	for key in pairs(rules.slots or {}) do
		table.insert(rows, { kind = "slots", key = key, label = key })
	end
	table.sort(rows, function(a, b)
		return a.label < b.label
	end)
	return rows, list and list.draft ~= nil
end

function SK.Teams:DraftAddItem(itemId)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	local id = tonumber(itemId) or tonumber(string.match(tostring(itemId or ""), "item:(%d+)"))
	if not id then
		return "Enter an item id."
	end
	id = tostring(id)
	self:Ensure()
	local list = self:ActiveList()
	if not list then
		return "That list is gone."
	end
	local err = taken("items", id, list.id)
	if err then
		return err
	end
	local draft = self:Draft(list.id)
	draft.items[id] = true
	return nil
end

function SK.Teams:DraftAddSlot(slot)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	slot = SK.Trim(slot or "")
	if slot == "" then
		return "Pick a slot."
	end
	self:Ensure()
	local list = self:ActiveList()
	if not list then
		return "That list is gone."
	end
	local err = taken("slots", slot, list.id)
	if err then
		return err
	end
	local draft = self:Draft(list.id)
	draft.slots[slot] = true
	return nil
end

function SK.Teams:DraftClear(kind, key)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	self:Ensure()
	local list = self:ActiveList()
	if not list then
		return "That list is gone."
	end
	local draft = self:Draft(list.id)
	if draft[kind] then
		draft[kind][key] = nil
	end
	return nil
end

function SK.Teams:Save()
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	self:Ensure()
	local team = self:Team()
	if not team then
		return "That team is gone."
	end
	local seenItems = {}
	local seenSlots = {}
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		local rules = list.draft or list.rules or blankRules()
		for key in pairs(rules.items or {}) do
			if seenItems[key] then
				return "Two lists cannot both use item " .. key .. "."
			end
			seenItems[key] = true
		end
		for key in pairs(rules.slots or {}) do
			if seenSlots[key] then
				return "Two lists cannot both use " .. key .. "."
			end
			seenSlots[key] = true
		end
	end
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		if list.draft then
			list.rules = list.draft
			list.draft = nil
		end
		list.rules = list.rules or blankRules()
	end
	if SK.Events then
		SK.Events:Fire("SK_LIST_CHANGED", "rules")
	end
	return nil
end

function SK.Teams:AddItemRule(listId, itemId)
	if not SK.Session:IsOfficer() then
		return "Officer only"
	end
	local id = tonumber(itemId)
	if not id then
		return "That item has no id yet."
	end
	id = tostring(id)
	self:Ensure()
	local team = self:Team()
	local list = team and team.lists[listId]
	if not list then
		return "That list is gone."
	end
	local err = taken("items", id, listId)
	if err then
		return err
	end
	list.rules = list.rules or blankRules()
	list.rules.items[id] = true
	if list.draft then
		list.draft.items[id] = true
	end
	if SK.Events then
		SK.Events:Fire("SK_LIST_CHANGED", "rules")
	end
	return nil
end

function SK.Teams:DropNoCallAll()
	self:Flush()
	local db = bank()
	local team = db.teams[db.team]
	if not team then
		return {}
	end
	local viewNotes = {}
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		local rows = {}
		for key, person in pairs(team.people) do
			if not person.pug and list.members[key] then
				table.insert(rows, {
					name = person.name,
					pug = false,
					position = list.pos[key],
					status = person.status,
				})
			end
		end
		local notes = SK.Rules.Reconcile.DropNoCalls(rows)
		for n = 1, #rows do
			local key = string.lower(rows[n].name)
			if rows[n].position then
				list.pos[key] = rows[n].position
			else
				list.pos[key] = nil
			end
		end
		if list.id == db.list then
			viewNotes = notes
		end
	end
	self:Materialize()
	return viewNotes
end

local function pieceSafe(text)
	text = tostring(text or "")
	text = string.gsub(text, "[,;|#]", " ")
	return text
end

function SK.Teams:Pieces()
	self:Flush()
	local team = self:Team()
	local pieces = {}
	if not team then
		return pieces
	end
	local locked = SK.Session and SK.Session:IsLocked() and "1" or "0"
	table.insert(pieces, "#T," .. pieceSafe(team.id) .. "," .. pieceSafe(team.name) .. "," .. locked)
	for i = 1, #team.listOrder do
		local list = team.lists[team.listOrder[i]]
		table.insert(pieces, "#L," .. pieceSafe(list.id) .. "," .. pieceSafe(list.name) .. "," .. (list.fixed and "1" or "0"))
		local rules = list.rules or blankRules()
		for itemId in pairs(rules.items or {}) do
			table.insert(pieces, "#I," .. pieceSafe(itemId))
		end
		local slots = {}
		for slot in pairs(rules.slots or {}) do
			table.insert(slots, slot)
		end
		table.sort(slots)
		for n = 1, #slots do
			table.insert(pieces, "#S," .. pieceSafe(slots[n]))
		end
		for key, person in pairs(team.people) do
			local include = person.pug or list.members[key]
			if include then
				local position = (not person.pug) and list.pos[key] or nil
				local row = {
					name = person.name,
					class = person.class,
					position = position,
					status = person.status,
					pug = person.pug,
					rolls = person.rolls,
					hold = person.hold,
				}
				table.insert(pieces, "#P," .. SK.Sync.EncodeRow(row))
			end
		end
	end
	return pieces
end

function SK.Teams:ApplyPieces(parts, lockedFallback)
	local teamId, teamName, locked
	local people = {}
	local lists = {}
	local order = {}
	local current = nil
	for i = 1, #parts do
		local piece = parts[i]
		if string.sub(piece, 1, 3) == "#T," then
			local id, name, flag = string.match(piece, "^#T,([^,]*),([^,]*),([01])$")
			if not id then
				id, name = string.match(piece, "^#T,([^,]*),([^,]*)$")
			end
			teamId = id
			teamName = name
			if flag == "1" then
				locked = true
			elseif flag == "0" then
				locked = false
			end
		elseif string.sub(piece, 1, 3) == "#L," then
			local id, name, flag = string.match(piece, "^#L,([^,]*),([^,]*),([01])$")
			if id and id ~= "" then
				current = makeList(id, name ~= "" and name or "List", flag == "1")
				lists[id] = current
				table.insert(order, id)
			end
		elseif current and string.sub(piece, 1, 3) == "#I," then
			local itemId = string.match(piece, "^#I,(.+)$")
			if itemId and itemId ~= "" then
				current.rules.items[itemId] = true
			end
		elseif current and string.sub(piece, 1, 3) == "#S," then
			local slot = string.match(piece, "^#S,(.+)$")
			if slot and slot ~= "" then
				current.rules.slots[slot] = true
			end
		elseif current and string.sub(piece, 1, 3) == "#P," then
			local row = SK.Sync.DecodeRow(string.sub(piece, 4))
			if row then
				local key = string.lower(row.name)
				people[key] = {
					name = row.name,
					class = row.class,
					status = row.status,
					rolls = row.rolls,
					hold = row.hold and true or false,
					pug = row.pug and true or false,
				}
				if not row.pug then
					current.members[key] = true
					if row.position then
						current.pos[key] = row.position
					end
				end
			end
		end
	end
	if not teamId or teamId == "" or #order == 0 then
		return
	end
	local db = bank()
	local known = false
	for i = 1, #db.teamOrder do
		if db.teamOrder[i] == teamId then
			known = true
			break
		end
	end
	if not known then
		table.insert(db.teamOrder, teamId)
	end
	db.teams[teamId] = {
		id = teamId,
		name = teamName ~= "" and teamName or "Team",
		people = people,
		listOrder = order,
		lists = lists,
	}
	db.team = teamId
	if not lists[db.list] then
		db.list = order[1]
	end
	self:Materialize()
	if SK.List then
		SK.List:RebuildIndex()
	end
	if SK.Session then
		SK.Session:RefreshSeeding()
		if locked == nil then
			locked = lockedFallback
		end
		if locked ~= nil and SK.Session.ApplyLock then
			SK.Session:ApplyLock(locked)
		end
	end
	if SK.Events then
		SK.Events:Fire("SK_LIST_CHANGED", "snapshot")
	end
end
