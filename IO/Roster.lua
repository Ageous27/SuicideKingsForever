SK = SK or {}
SK.Roster = SK.Roster or {}

local function className(displayName, classFile)
	local named = SK.ClassName(displayName)
	if named then
		return named
	end
	if classFile then
		for label, file in pairs(SK.CLASS_FILE) do
			if file == classFile then
				return label
			end
		end
	end
	return "Warrior"
end

local function add(out, name, displayName, classFile)
	name = SK.ShortName(name)
	if name == "" then
		return
	end
	out[string.lower(name)] = {
		name = name,
		class = className(displayName, classFile),
	}
end

function SK.Roster:Resolve(name)
	name = SK.Trim(name)
	if name == "" then
		return nil, nil, nil
	end
	local members = self:Members()
	local exact = members[string.lower(name)]
	if exact then
		return exact.name, exact.class, nil
	end
	if string.find(name, " ", 1, true) then
		return nil, nil, nil
	end
	local first = string.lower(string.match(name, "^(%S+)") or name)
	local hits = {}
	for _, member in pairs(members) do
		local memberFirst = string.lower(string.match(member.name, "^(%S+)") or member.name)
		if memberFirst == first then
			table.insert(hits, member)
		end
	end
	if #hits == 1 then
		return hits[1].name, hits[1].class, nil
	end
	if #hits > 1 then
		return nil, nil, "many"
	end
	return nil, nil, nil
end

function SK.Roster:Members()
	local out = {}
	if IsInRaid and IsInRaid() and GetRaidRosterInfo and GetNumGroupMembers then
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, displayName, classFile = GetRaidRosterInfo(i)
			add(out, name, displayName, classFile)
		end
		return out
	end
	if IsInGroup and IsInGroup() and GetNumGroupMembers then
		local displayName, classFile = UnitClass("player")
		add(out, UnitName("player"), displayName, classFile)
		for i = 1, GetNumGroupMembers() - 1 do
			local unit = "party" .. i
			displayName, classFile = UnitClass(unit)
			add(out, UnitName(unit), displayName, classFile)
		end
	end
	return out
end

local function check()
	if SK.Session and SK.Session.CheckJoins then
		SK.Session:CheckJoins()
	end
end

SK.Events:Register("GROUP_ROSTER_UPDATE", function()
	if SK.Debug then
		SK.Debug:Line("Roster", "update", IsInGroup and IsInGroup() and "grouped" or "solo")
	end
	check()
end)
SK.Events:On("SK_READY", check)
