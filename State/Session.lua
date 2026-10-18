SK = SK or {}
SK.Session = SK.Session or {}

local function samePlayer(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	return SK.ShortName(name) == SK.ShortName(UnitName("player"))
end

local function methodIsMaster(method)
	if method == "master" or method == "masterlooter" then
		return true
	end
	if Enum and Enum.LootMethod and method == Enum.LootMethod.Masterlooter then
		return true
	end
	return type(method) == "number" and method == 2
end

local function playerIsListedMaster(partyId, raidId)
	if type(raidId) == "number" and raidId > 0 and GetRaidRosterInfo then
		return samePlayer(GetRaidRosterInfo(raidId))
	end
	if type(partyId) == "number" then
		if partyId == 0 then
			return true
		end
		if partyId > 0 and UnitIsUnit then
			return UnitIsUnit("player", "party" .. partyId) and true or false
		end
	end
	if type(partyId) == "string" and partyId ~= "" then
		if UnitExists and UnitExists(partyId) then
			return UnitIsUnit("player", partyId) and true or false
		end
		return samePlayer(partyId)
	end
	if type(raidId) == "string" and raidId ~= "" and UnitExists and UnitExists(raidId) then
		return UnitIsUnit("player", raidId) and true or false
	end
	return nil
end

local function masterLooterIsPlayer()
	if C_PartyInfo and C_PartyInfo.GetLootMethod then
		local ok, method, partyId, raidId = pcall(C_PartyInfo.GetLootMethod)
		if ok and methodIsMaster(method) then
			local listed = playerIsListedMaster(partyId, raidId)
			if listed ~= nil then
				return listed
			end
		end
	end
	if GetLootMethod then
		local method, partyIndex, raidIndex = GetLootMethod()
		if method == "master" then
			if type(raidIndex) == "number" and raidIndex > 0 and GetRaidRosterInfo then
				return samePlayer(GetRaidRosterInfo(raidIndex))
			end
			if partyIndex == 0 then
				return true
			end
			if type(partyIndex) == "number" and partyIndex > 0 and UnitIsUnit then
				return UnitIsUnit("player", "party" .. partyIndex) and true or false
			end
			return false
		end
	end
	return nil
end

function SK.Session:IsMasterLooter()
	return masterLooterIsPlayer() == true
end

function SK.Session:IsOfficer()
	if not IsInGroup or not IsInGroup() then
		return true
	end
	local isMaster = masterLooterIsPlayer()
	if isMaster ~= nil then
		return isMaster
	end
	return UnitIsGroupLeader("player") and true or false
end

function SK.Session:IsSeeding()
	local session = SK.Saved:Session()
	return session.seeding and true or false
end

function SK.Session:IsLocked()
	return SK.Saved:Session().locked and true or false
end

function SK.Session:LockedTeam()
	local teamId = SK.Saved:Session().lockedTeam
	if type(teamId) == "string" and teamId ~= "" then
		return teamId
	end
	return nil
end

function SK.Session:Unlock()
	local session = SK.Saved:Session()
	session.locked = false
	session.lockedTeam = nil
	session.pendingJoins = {}
	session.blocked = {}
	session.joinAnswers = {}
	session.raidAtLock = nil
end

function SK.Session:UnlockRaid()
	if not self:IsOfficer() then
		return "Officer only"
	end
	if not self:IsLocked() then
		return "The raid is not locked."
	end
	if SK.Sync and SK.Sync.BroadcastTeam then
		SK.Sync:BroadcastTeam("0")
	end
	self:Unlock()
	SK.Events:Fire("SK_LIST_CHANGED", "unlock")
	return nil
end

function SK.Session:SetBlocked(name, waiting)
	local key = string.lower(SK.ShortName(name))
	if key == "" then
		return
	end
	local session = SK.Saved:Session()
	session.blocked = session.blocked or {}
	if waiting then
		session.blocked[key] = true
	else
		session.blocked[key] = nil
	end
	SK.Events:Fire("SK_LIST_CHANGED", "join")
end

function SK.Session:ApplyLock(locked)
	if self:IsOfficer() then
		return
	end
	local session = SK.Saved:Session()
	session.locked = locked and true or false
	if not session.locked then
		session.blocked = {}
		session.pendingJoins = {}
	end
end

function SK.Session:RefreshSeeding()
	local seeding = false
	local core = SK.List:Core()
	for i = 1, #core do
		if not core[i].position then
			seeding = true
			break
		end
	end
	SK.Saved:Session().seeding = seeding
	return seeding
end

local function db()
	return SK.Saved:Session()
end

local function changed(reason)
	SK.Events:Fire("SK_SESSION", reason or "change")
end

local function say(text)
	SK.Events:Fire("SK_ANNOUNCE", text)
end

function SK.Session:Live()
	return db().live
end

function SK.Session:Waiting()
	return db().waiting
end

function SK.Session:NeedsTrade()
	return db().needsTrade
end

function SK.Session:Selected()
	local id = db().selected
	if not id then
		return nil
	end
	local waiting = db().waiting
	for i = 1, #waiting do
		if waiting[i].id == id then
			return waiting[i]
		end
	end
	return nil
end

function SK.Session:Note()
	return db().note or ""
end

function SK.Session:SetNote(text)
	db().note = text or ""
	changed("note")
end

function SK.Session:MarkDelivered(id)
	local trades = db().needsTrade
	local found
	for i = 1, #trades do
		if trades[i].id == id then
			found = table.remove(trades, i)
			break
		end
	end
	if not found then
		return false
	end
	if found.historyId and SK.History and SK.History.MarkDelivered then
		SK.History:MarkDelivered(found.historyId)
	end
	db().note = SK.Item.Display(found) .. " delivered to " .. (found.winner or "") .. "."
	changed("deliver")
	return true
end

local function shownItem(item)
	if SK.Item and SK.Item.ChatLink then
		return SK.Item.ChatLink(item)
	end
	return item.name or item.link or "item"
end

function SK.Session:Queue(link)
	if not self:IsOfficer() then
		return "Officer only"
	end
	link = SK.Trim(link)
	if link == "" then
		return "Paste an item link."
	end
	local info = SK.Item.Describe(link)
	local waiting = db().waiting
	local id = "i" .. tostring(time()) .. tostring(#waiting + 1)
	local entry = {
		id = id,
		raw = link,
		link = info.link or link,
		name = info.name or "Loading item...",
		icon = info.icon,
		itemID = info.itemID,
	}
	if SK.Teams then
		SK.Teams:Assign(entry)
	end
	table.insert(waiting, entry)
	db().selected = id
	db().note = (info.name or "Item") .. " added to Waiting."
	changed("queue")
	return nil
end

function SK.Session:RemoveWaiting(id)
	if not self:IsOfficer() then
		return "Officer only"
	end
	local waiting = db().waiting
	for i = 1, #waiting do
		if waiting[i].id == id then
			local name = SK.Item.Display(waiting[i])
			table.remove(waiting, i)
			if db().selected == id then
				local nextItem = waiting[i] or waiting[i - 1]
				db().selected = nextItem and nextItem.id or nil
			end
			db().note = name .. " removed from Waiting."
			changed("queue")
			return nil
		end
	end
	return "That item is not waiting."
end

function SK.Session:RemoveNeedsTrade(id)
	if not self:IsOfficer() then
		return "Officer only"
	end
	local trades = db().needsTrade
	for i = 1, #trades do
		if trades[i].id == id then
			local name = SK.Item.Display(trades[i])
			table.remove(trades, i)
			db().note = name .. " removed from Needs Trade."
			changed("trade")
			return nil
		end
	end
	return "That item is not in Needs Trade."
end

function SK.Session:Select(id)
	db().selected = id
	changed("select")
end

local function responseIndex(live, name)
	local key = string.lower(name)
	for i = 1, #live.responses do
		if string.lower(live.responses[i].name) == key then
			return i
		end
	end
	return nil
end

function SK.Session:Decision()
	local live = self:Live()
	if not live then
		return nil
	end
	return SK.Rules.Priority.Decide(live.responses, live.seeding, live.state == "rolloff" and live.rolloff or nil)
end

function SK.Session:ChoicesFor(name)
	local live = self:Live()
	local row
	if live and live.listId and SK.Teams then
		row = SK.Teams:Row(live.listId, SK.ShortName(name))
	else
		row = SK.List:Find(SK.ShortName(name))
	end
	local seeding = self:IsSeeding()
	if live and live.seeding ~= nil then
		seeding = live.seeding
	end
	local blocked = SK.Saved:Session().blocked
	local key = string.lower(SK.ShortName(name))
	if blocked and blocked[key] then
		return {}
	end
	local choices = SK.Rules.Priority.Choices(row, seeding, self:IsLocked())
	if live and live.state == "rolloff" and live.rolloff then
		local key = string.lower(SK.ShortName(name))
		if not live.rolloff.names[key] then
			return {}
		end
		return { live.rolloff.tier, "Pass" }
	end
	return choices
end

function SK.Session:Respond(name, choice, roll, source)
	local live = self:Live()
	if not live or (live.state ~= "open" and live.state ~= "rolloff") then
		return
	end
	if time() > (live.endsAt or 0) then
		return
	end
	name = SK.ShortName(name)
	if name == "" then
		return
	end
	local choices = self:ChoicesFor(name)
	if not SK.Rules.Priority.Allows(choices, choice) then
		if SK.Debug then
			SK.Debug:Line("Session", "ignore", name .. " " .. tostring(choice))
		end
		return
	end
	if choice == "MS" or choice == "OS" then
		roll = tonumber(roll)
		if not roll or roll < 1 or roll > 100 then
			return
		end
		roll = math.floor(roll)
	else
		roll = nil
	end
	local row
	if live.listId and SK.Teams then
		row = SK.Teams:Row(live.listId, name)
	else
		row = SK.List:Find(name)
	end
	local record = {
		name = row and row.name or name,
		choice = choice,
		roll = roll,
		position = row and row.position or nil,
		pug = row and row.pug or false,
		unseeded = row and (not row.pug) and (not row.position) or false,
		source = source or "popup",
	}
	local index = responseIndex(live, record.name)
	if index then
		live.responses[index] = record
	else
		table.insert(live.responses, record)
	end
	changed("response")
end

function SK.Session:SetOverride(name)
	local live = self:Live()
	if not live or live.state == "open" or live.state == "rolloff" then
		return
	end
	live.override = name
	changed("override")
end

local function removeWaiting(id)
	local waiting = db().waiting
	for i = 1, #waiting do
		if waiting[i].id == id then
			table.remove(waiting, i)
			return
		end
	end
end

local function findWaiting(id)
	local waiting = db().waiting
	for i = 1, #waiting do
		if waiting[i].id == id then
			return waiting[i], i
		end
	end
	return nil
end

function SK.Session:Start()
	if not self:IsOfficer() then
		return "Officer only"
	end
	if SK.Gargul and SK.Gargul:UseGargul() then
		return "Loot is running in Gargul."
	end
	if self:Live() then
		return "An item is already live."
	end
	local item = self:Selected()
	if not item then
		return "Select a Waiting item."
	end
	if SK.Teams then
		SK.Teams:Assign(item)
		if not item.listId then
			return "Pick a list for this item."
		end
	end
	local settings = SK.Settings:Get()
	local duration = settings.timer or 15
	local countdown = settings.countdown or 5
	db().live = {
		id = item.id,
		link = item.link,
		name = item.name,
		icon = item.icon,
		itemID = item.itemID,
		raw = item.raw or item.link,
		started = time(),
		duration = duration,
		countdownFrom = countdown,
		endsAt = time() + duration,
		state = "open",
		responses = {},
		rolloff = nil,
		said = {},
		seeding = (item.listId and SK.Teams and SK.Teams:IsSeeding(item.listId)) or self:IsSeeding(),
		override = nil,
		rolloffTries = 0,
		listId = item.listId,
		listName = item.listName,
		listPick = item.listPick,
		teamId = SK.Teams and SK.Teams:TeamId() or nil,
		teamName = SK.Teams and SK.Teams:TeamName() or nil,
	}
	removeWaiting(item.id)
	db().selected = nil
	local listLabel = item.listName or "list"
	db().note = SK.Item.Display(item) .. " is live on " .. listLabel .. ". " .. duration .. " seconds."
	say(shownItem(item) .. " — " .. listLabel .. " — bid, or MS /roll 100, or OS /roll 99. " .. duration .. " seconds.")
	changed("start")
	return nil
end

local function winnerRecord(live, decision)
	if live.override then
		local key = string.lower(live.override)
		for i = 1, #live.responses do
			local row = live.responses[i]
			if string.lower(row.name) == key and row.choice ~= "Pass" then
				return row
			end
		end
	end
	return decision and decision.winner or nil
end

function SK.Session:Chosen()
	local live = self:Live()
	if not live then
		return nil
	end
	local decision = self:Decision()
	return winnerRecord(live, decision), decision
end

local function beginRolloff(live, tie)
	live.rolloffTries = (live.rolloffTries or 0) + 1
	if live.rolloffTries > 3 then
		live.state = "closed"
		live.rolloff = { tier = tie.tier, names = live.rolloff and live.rolloff.names or {} }
		db().note = "Still tied. Pick an override, then Award."
		say("Roll-off still tied. Officer will pick the winner.")
		changed("close")
		return
	end
	local names = {}
	local label = {}
	for i = 1, #tie.names do
		local person = tie.names[i]
		names[string.lower(person.name)] = true
		table.insert(label, person.name)
		local index = responseIndex(live, person.name)
		if index then
			table.remove(live.responses, index)
		end
	end
	live.rolloff = { tier = tie.tier, names = names }
	live.state = "rolloff"
	live.override = nil
	live.said = {}
	live.endsAt = time() + (live.duration or 15)
	db().note = "Roll-off: " .. table.concat(label, ", ") .. ". " .. tie.tier .. " only."
	say("Roll-off " .. tie.tier .. ": " .. table.concat(label, ", ") .. ". " .. (live.duration or 15) .. " seconds.")
	changed("rolloff")
end

function SK.Session:CloseTimer()
	local live = self:Live()
	if not live or (live.state ~= "open" and live.state ~= "rolloff") then
		return
	end
	local decision = SK.Rules.Priority.Decide(live.responses, live.seeding, live.state == "rolloff" and live.rolloff or nil)
	if decision.tie then
		beginRolloff(live, decision.tie)
		return
	end
	live.state = "closed"
	local winner = decision.winner
	if winner then
		local roll = winner.roll and tostring(winner.roll) or ""
		db().note = winner.name .. " wins by " .. winner.choice .. (roll ~= "" and (" " .. roll) or "") .. ". Award, disenchant, or cancel."
		say("Winner: " .. winner.name .. ", " .. winner.choice .. (roll ~= "" and (", roll " .. roll) or "") .. ".")
	else
		db().note = live.name .. " is closed. No response. Disenchant or cancel."
		say(live.name .. " closed with no winner.")
	end
	changed("close")
end

function SK.Session:EndEarly()
	if not self:IsOfficer() then
		return "Officer only"
	end
	local live = self:Live()
	if not live or (live.state ~= "open" and live.state ~= "rolloff") then
		return "The timer is already closed."
	end
	live.endsAt = time()
	self:CloseTimer()
	return nil
end

local enteredAt = 0

local function inGroup()
	if IsInRaid and IsInRaid() then
		return true
	end
	if IsInGroup and IsInGroup() then
		return true
	end
	return false
end

local function inInstance()
	if not GetInstanceInfo then
		return false
	end
	local ok, _, kind = pcall(GetInstanceInfo)
	if not ok then
		return false
	end
	return kind == "raid" or kind == "party"
end

local function raidIsOpen(session)
	if session.locked or (session.raidId and session.raidId ~= "") then
		return true
	end
	if not SK.Saved or not SK.Saved.List then
		return false
	end
	local list = SK.Saved:List()
	for i = 1, #list do
		if list[i].pug then
			return true
		end
	end
	return false
end

function SK.Session:CheckAway()
	if type(SKDB) ~= "table" or type(SKDB.session) ~= "table" then
		return
	end
	local now = time()
	if enteredAt == 0 then
		enteredAt = now
	end
	local session = SKDB.session
	local grouped = inGroup()
	local inside = inInstance()
	if grouped or inside then
		session.awaySince = nil
		if self:IsOfficer() then
			session.raidSawGroup = true
			session.raidOfficer = UnitName("player")
		end
		return
	end
	if not session.raidSawGroup or not session.raidOfficer then
		return
	end
	if session.raidOfficer ~= UnitName("player") then
		return
	end
	if not raidIsOpen(session) then
		session.awaySince = nil
		return
	end
	if not session.awaySince then
		session.awaySince = now
		return
	end
	if now - enteredAt < 15 then
		return
	end
	local awaySeconds = 600
	if SK.Settings and SK.Settings.AwaySeconds then
		awaySeconds = SK.Settings:AwaySeconds()
	end
	if now - session.awaySince < awaySeconds then
		return
	end
	session.awaySince = nil
	if not SK.List or not SK.List.EndRaid then
		return
	end
	local err = SK.List:EndRaid()
	if not err and SK.Print then
		SK.Print("Raid ended.")
	end
end

function SK.Session:Tick()
	if type(SKDB) ~= "table" or type(SKDB.session) ~= "table" then
		return
	end
	if not self:IsOfficer() then
		return
	end
	local live = self:Live()
	if not live or (live.state ~= "open" and live.state ~= "rolloff") then
		return
	end
	local remain = math.ceil((live.endsAt or 0) - time())
	if remain <= 0 then
		if time() - (live.endsAt or 0) > 3 then
			live.state = "closed"
			db().note = (live.name or "Item") .. " timer ended."
			changed("close")
			return
		end
		self:CloseTimer()
		return
	end
	local from = live.countdownFrom or 5
	if remain <= from then
		live.said = live.said or {}
		local key = tostring(remain)
		if not live.said[key] then
			live.said[key] = true
			say(tostring(remain))
		end
	end
end

local function bidders(live)
	local names = {}
	for i = 1, #live.responses do
		if live.responses[i].choice == "Bid" then
			table.insert(names, live.responses[i].name)
		end
	end
	return names
end

function SK.Session:Award()
	if not self:IsOfficer() then
		return "Officer only"
	end
	local live = self:Live()
	if not live or live.state == "open" or live.state == "rolloff" then
		return "Wait for the timer to close."
	end
	local winner = self:Chosen()
	if not winner then
		return "No winner."
	end
	local before, after
	local seedingWin = live.seeding and winner.unseeded and not winner.pug
	local function moveWinner()
		return SK.List:AwardMove(winner.name, winner.choice, bidders(live), SK.Settings:Get().bidDrop, seedingWin)
	end
	if seedingWin or winner.choice == "Bid" then
		if SK.Teams and live.listId then
			before, after = SK.Teams:WithList(live.listId, moveWinner)
		else
			before, after = moveWinner()
		end
	else
		local row = (SK.Teams and live.listId) and SK.Teams:Row(live.listId, winner.name) or SK.List:Find(winner.name)
		before = row and row.position or nil
		after = before
	end
	local event = {
		type = "loot",
		action = winner.choice,
		name = winner.name,
		detail = SK.Item.Display(live),
		item = live.link,
		roll = winner.roll,
		positionBefore = before,
		positionAfter = after,
		officer = UnitName("player"),
		delivered = false,
		teamId = live.teamId,
		teamName = live.teamName,
		listId = live.listId,
		listName = live.listName,
	}
	local given = SK.Trade and SK.Trade.GiveMasterLoot and SK.Trade:GiveMasterLoot(live, winner.name)
	if given then
		event.delivered = true
	end
	SK.History:Append(event)
	if given then
		say(winner.name .. " awarded " .. shownItem(live) .. ".")
		db().note = SK.Item.Display(live) .. " given to " .. winner.name .. " by master loot."
	else
		table.insert(db().needsTrade, {
			id = live.id,
			link = live.link,
			name = live.name,
			winner = winner.name,
			method = winner.choice,
			roll = winner.roll,
			icon = live.icon,
			itemID = live.itemID,
			raw = live.raw,
			historyId = event.id,
		})
		say(winner.name .. " awarded " .. shownItem(live) .. ". Open trade.")
		if SK.Chat and SK.Chat.Whisper then
			SK.Chat:Whisper(winner.name, "You won " .. shownItem(live) .. ". Open trade.")
		end
		db().note = SK.Item.Display(live) .. " awarded to " .. winner.name .. ". It is in Needs Trade."
	end
	db().live = nil
	changed("award")
	return nil
end

function SK.Session:Disenchant()
	if not self:IsOfficer() then
		return "Officer only"
	end
	local live = self:Live()
	if not live or live.state == "open" or live.state == "rolloff" then
		return "Wait for the timer to close."
	end
	local enchanter = SK.Settings and SK.Settings.Get and SK.Settings:Get().disenchanter or ""
	enchanter = SK.ShortName(enchanter)
	if enchanter == "" then
		return "Assign a disenchanter in Settings."
	end
	local event = {
		type = "loot",
		action = "Disenchant",
		name = enchanter,
		detail = SK.Item.Display(live),
		item = live.link,
		officer = UnitName("player"),
		delivered = false,
		teamId = live.teamId,
		teamName = live.teamName,
		listId = live.listId,
		listName = live.listName,
	}
	SK.History:Append(event)
	table.insert(db().needsTrade, {
		id = live.id,
		link = live.link,
		name = live.name,
		winner = enchanter,
		method = "Disenchant",
		icon = live.icon,
		itemID = live.itemID,
		raw = live.raw,
		historyId = event.id,
	})
	say(enchanter .. " disenchants " .. shownItem(live) .. ". Open trade.")
	local me = string.lower(SK.ShortName(UnitName("player")))
	if string.lower(enchanter) ~= me and SK.Chat and SK.Chat.Whisper then
		SK.Chat:Whisper(enchanter, "Disenchant " .. shownItem(live) .. ". Open trade.")
	end
	db().note = SK.Item.Display(live) .. " is in Needs Trade for " .. enchanter .. ". The list does not move."
	db().live = nil
	changed("disenchant")
	return nil
end

function SK.Session:Cancel()
	if not self:IsOfficer() then
		return "Officer only"
	end
	local live = self:Live()
	if not live then
		return "No live item."
	end
	if live.state == "open" or live.state == "rolloff" then
		return "Wait for the timer to close."
	end
	table.insert(db().waiting, 1, {
		id = live.id,
		link = live.link,
		name = live.name,
		icon = live.icon,
		itemID = live.itemID,
		raw = live.raw,
		listId = live.listId,
		listName = live.listName,
		listPick = true,
	})
	db().selected = live.id
	db().note = SK.Item.Display(live) .. " is back on Waiting."
	db().live = nil
	changed("cancel")
	return nil
end

function SK.Session:ApplyRemote(state, endsAt, tier, names, link)
	if self:IsOfficer() then
		return
	end
	if state == "clear" or not link or link == "" then
		db().live = nil
		changed("remote")
		return
	end
	local map = {}
	if names and names ~= "" then
		for piece in string.gmatch(names, "[^;]+") do
			map[string.lower(piece)] = true
		end
	end
	local info = SK.Item.Describe(link)
	local listId, listName, teamId, realLink = string.match(link, "^([^\031]*)\031([^\031]*)\031([^\031]*)\031(.*)$")
	if realLink then
		link = realLink
		info = SK.Item.Describe(link)
	end
	local ends = tonumber(endsAt) or 0
	db().live = {
		link = info.link or link,
		name = info.name or "Loading item...",
		icon = info.icon,
		itemID = info.itemID,
		raw = link,
		endsAt = ends,
		duration = math.max(1, ends - time()),
		state = state or "open",
		responses = {},
		seeding = (listId and listId ~= "" and SK.Teams and SK.Teams:IsSeeding(listId)) or self:IsSeeding(),
		rolloff = (tier and tier ~= "") and { tier = tier, names = map } or nil,
		listId = listId ~= "" and listId or nil,
		listName = listName ~= "" and listName or nil,
		teamId = teamId ~= "" and teamId or nil,
		teamName = SK.Teams and SK.Teams:TeamName() or nil,
	}
	changed("remote")
end

function SK.Session:LockRaid()
	if not self:IsOfficer() then
		return "Officer only"
	end
	if self:IsLocked() then
		return "The raid is already locked."
	end
	local grouped = IsInGroup and IsInGroup()
	local raid = SK.Roster and SK.Roster.Members and SK.Roster:Members() or {}
	local filled = {}
	if SK.Teams then
		SK.Teams:Flush()
		filled = SK.Teams:FillFromRaid()
	end
	local list = SK.Teams and SK.Teams:People() or SK.Saved:List()
	for i = 1, #list do
		local row = list[i]
		if row.pug then
			row.status = "Pug/fill"
			if not row.rolls or row.rolls == "" then
				row.rolls = "MS, OS"
			end
		elseif not row.status or row.status == "" or (filled[string.lower(row.name)] and row.status == "Absent") then
			local key = string.lower(row.name)
			if not grouped or raid[key] then
				row.status = "Present"
			else
				row.status = "Absent"
			end
			local rolls, hold = SK.Rules.Reconcile.Defaults(row.status)
			row.rolls = rolls
			row.hold = hold
		elseif not row.rolls or row.rolls == "" then
			local rolls, hold = SK.Rules.Reconcile.Defaults(row.status)
			row.rolls = rolls
			if row.hold == nil then
				row.hold = hold
			end
		end
	end
	local notes
	if SK.Teams then
		SK.Teams:Materialize()
		notes = SK.Teams:DropNoCallAll()
	else
		notes = SK.Rules.Reconcile.DropNoCalls(list)
	end
	list = SK.Saved:List()
	local session = SK.Saved:Session()
	session.locked = true
	session.lockedTeam = SK.Teams and SK.Teams:TeamId() or nil
	if not session.raidId or session.raidId == "" then
		session.raidId = tostring(time())
	end
	session.raidOfficer = UnitName("player")
	session.raidAtLock = {}
	for key in pairs(raid) do
		session.raidAtLock[key] = true
	end
	session.pendingJoins = {}
	session.joinAnswers = {}
	session.blocked = {}
	for i = 1, #list do
		local row = list[i]
		local rule = SK.Rules.Reconcile.Rule(row, notes)
		local where = SK.Teams and SK.Teams:PositionLine(row.name) or ""
		local event = {
			type = "reconcile",
			action = row.status or "",
			name = row.name,
			detail = (row.rolls or "") .. " / " .. rule .. " / raid " .. session.raidId .. " / " .. where,
			positionBefore = row.position,
			officer = UnitName("player"),
		}
		if SK.Teams then
			SK.Teams:Stamp(event)
		end
		SK.History:Append(event)
	end
	SK.List:SortInPlace()
	SK.List:ClearPosBase()
	SK.List:RebuildIndex()
	SK.Events:Fire("SK_LIST_CHANGED", "reconcile")
	if SK.Debug then
		SK.Debug:Line("Reconcile", "lock", session.raidId)
	end
	return nil
end

function SK.Session:CheckJoins()
	if not SKDB or not SKDB.session then
		return
	end
	if not self:IsOfficer() or not self:IsLocked() then
		return
	end
	if not SK.Roster or not SK.Roster.Members then
		return
	end
	local session = SK.Saved:Session()
	local raid = SK.Roster:Members()
	local atLock = session.raidAtLock or {}
	session.pendingJoins = session.pendingJoins or {}
	session.joinAnswers = session.joinAnswers or {}
	session.blocked = session.blocked or {}
	local queued = {}
	for i = 1, #session.pendingJoins do
		queued[string.lower(session.pendingJoins[i].name)] = true
	end
	local added = false
	for key, info in pairs(raid) do
		local person = SK.Teams and SK.Teams:Person(info.name) or nil
		local row = SK.List:Find(info.name)
		local onCore = person and not person.pug or (not person and row and not row.pug)
		local alreadyPug = (person and person.pug) or (row and row.pug)
		if not atLock[key] and not session.joinAnswers[key] and not queued[key] and not alreadyPug then
			table.insert(session.pendingJoins, {
				name = (person and person.name) or (row and row.name) or info.name,
				class = info.class,
				position = row and not row.pug and row.position or nil,
				onList = onCore and true or false,
				joinedAt = time(),
			})
			session.blocked[key] = true
			if SK.Sync and SK.Sync.BroadcastJoin then
				SK.Sync:BroadcastJoin(row and row.name or info.name, true)
			end
			added = true
		end
	end
	if added then
		SK.Events:Fire("SK_JOIN")
	end
end

function SK.Session:AnswerJoin(allow)
	if not self:IsOfficer() then
		return
	end
	local session = SK.Saved:Session()
	local queue = session.pendingJoins or {}
	local entry = table.remove(queue, 1)
	if not entry then
		return
	end
	session.pendingJoins = queue
	session.joinAnswers = session.joinAnswers or {}
	session.joinAnswers[string.lower(entry.name)] = true
	session.blocked = session.blocked or {}
	session.blocked[string.lower(entry.name)] = nil
	local result = "still ineligible"
	if allow and entry.onList then
		local person = SK.Teams and SK.Teams:Person(entry.name) or nil
		local row = person or SK.List:Find(entry.name)
		if row and not row.pug then
			row.status = "Present"
			row.hold = false
			row.rolls = "Bid, MS, OS"
			if SK.Teams then
				SK.Teams:Materialize()
			end
			result = "Present"
		end
	elseif allow and not entry.onList then
		SK.List:AddPugQuiet(entry.name, entry.class)
		result = "pug/fill"
	end
	local when = date("%H:%M:%S", entry.joinedAt or time())
	local where = SK.Teams and SK.Teams:PositionLine(entry.name) or ""
	local event = {
		type = "latejoin",
		action = allow and "Allowed" or "Denied",
		name = entry.name,
		detail = result .. " / " .. where .. " / joined " .. when .. " / raid " .. (session.raidId or ""),
		positionBefore = entry.position,
		officer = UnitName("player"),
	}
	if SK.Teams then
		SK.Teams:Stamp(event)
	end
	SK.History:Append(event)
	if SK.Sync and SK.Sync.BroadcastJoin then
		SK.Sync:BroadcastJoin(entry.name, false)
	end
	SK.List:RebuildIndex()
	SK.Events:Fire("SK_LIST_CHANGED", "latejoin")
	SK.Events:Fire("SK_JOIN")
end

local autoOpen = false

local function masterLootOn()
	if C_PartyInfo and C_PartyInfo.GetLootMethod and Enum and Enum.LootMethod then
		local ok, method = pcall(C_PartyInfo.GetLootMethod)
		if ok and method == Enum.LootMethod.Masterlooter then
			return true
		end
	end
	if GetLootMethod then
		return GetLootMethod() == "master"
	end
	return false
end

local function lootSlotIsItem(slot)
	if not GetLootSlotLink or not GetLootSlotLink(slot) then
		return false
	end
	if not GetLootSlotType then
		return true
	end
	local kind = GetLootSlotType(slot)
	if LOOT_SLOT_ITEM and kind == LOOT_SLOT_ITEM then
		return true
	end
	return kind == 1
end

function SK.Session:AutoLoot()
	if not self:IsOfficer() or not masterLootOn() then
		return
	end
	if SK.Gargul and SK.Gargul:UseGargul() then
		return
	end
	local settings = SK.Settings:Get()
	if not settings.autoAdd then
		return
	end
	local floor = settings.autoQuality or 2
	local slots = GetNumLootItems and GetNumLootItems() or 0
	local added = 0
	local waiting = db().waiting
	for slot = 1, slots do
		if lootSlotIsItem(slot) then
			local link = GetLootSlotLink(slot)
			local info = SK.Item.Describe(link)
			local quality = info.quality
			if not quality and type(link) == "string" then
				local hex = string.match(link, "|c(%x%x%x%x%x%x%x%x)")
				local fromColor = hex and ({
					ff9d9d9d = 0,
					ffffffff = 1,
					ff1eff00 = 2,
					ff0070dd = 3,
					ffa335ee = 4,
					ffff8000 = 5,
				})[string.lower(hex)]
				quality = fromColor
			end
			if quality and quality >= floor then
				local id = "i" .. tostring(time()) .. tostring(#waiting + 1) .. tostring(slot)
				local entry = {
					id = id,
					raw = link,
					link = info.link or link,
					name = info.name or "Loading item...",
					icon = info.icon,
					itemID = info.itemID,
				}
				if SK.Teams then
					SK.Teams:Assign(entry)
				end
				table.insert(waiting, entry)
				db().selected = id
				added = added + 1
			end
		end
	end
	if added > 0 then
		db().note = added == 1 and "1 item added to Waiting." or (tostring(added) .. " items added to Waiting.")
		changed("queue")
	end
end

SK.Events:Register("LOOT_OPENED", function()
	if autoOpen then
		return
	end
	autoOpen = true
	SK.Session:AutoLoot()
end)
SK.Events:Register("LOOT_CLOSED", function()
	autoOpen = false
end)

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	acc = acc + elapsed
	if acc < 0.25 then
		return
	end
	acc = 0
	if SK.Session.Tick then
		SK.Session:Tick()
	end
	if SK.Session.CheckAway then
		SK.Session:CheckAway()
	end
end)

SK.Events:Register("PLAYER_ENTERING_WORLD", function()
	if enteredAt == 0 then
		enteredAt = time()
	end
end)

local wasOfficer = nil

local function noteOfficer()
	local nowOfficer = SK.Session:IsOfficer()
	local changedRole = wasOfficer ~= nil and wasOfficer ~= nowOfficer
	wasOfficer = nowOfficer
	if not changedRole then
		return
	end
	local session = SK.Saved:Session()
	if nowOfficer then
		session.raidOfficer = UnitName("player")
		session.raidSawGroup = true
		if SK.Session:IsLocked() and SK.Sync and SK.Sync.Broadcast then
			SK.Sync:Broadcast()
		end
	elseif session.raidOfficer and samePlayer(session.raidOfficer) then
		session.raidOfficer = nil
	end
	SK.Events:Fire("SK_OFFICER")
end

SK.Events:Register("GROUP_ROSTER_UPDATE", noteOfficer)
SK.Events:Register("PARTY_LOOT_METHOD_CHANGED", noteOfficer)
SK.Events:On("SK_READY", noteOfficer)
