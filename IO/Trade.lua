SK = SK or {}
SK.Trade = SK.Trade or {}

local placing = nil
local bothAccepted = false
local busy = false

local function itemString(text)
	if type(text) ~= "string" then
		return nil
	end
	return string.match(text, "item:[%d:%-]+")
end

local function itemID(text)
	local str = itemString(text)
	if not str then
		return nil
	end
	return tonumber(string.match(str, "item:(%d+)"))
end

local function entryID(entry)
	if entry.itemID then
		return entry.itemID
	end
	return itemID(entry.raw or entry.link or entry.name or "")
end

local function entryString(entry)
	return itemString(entry.raw or entry.link or entry.name or "")
end

local function sameName(a, b)
	a = SK.ShortName(a)
	b = SK.ShortName(b)
	if a == "" or b == "" then
		return false
	end
	return string.lower(a) == string.lower(b)
end

local function note(text)
	if SK.Session and SK.Session.SetNote then
		SK.Session:SetNote(text)
	end
	if SK.Debug then
		SK.Debug:Line("Trade", "note", text or "")
	end
end

local function masterLootMethod()
	if IsMasterLooter and IsMasterLooter() then
		return true
	end
	if C_PartyInfo and C_PartyInfo.GetLootMethod and Enum and Enum.LootMethod then
		local ok, method = pcall(C_PartyInfo.GetLootMethod)
		if ok and method == Enum.LootMethod.Masterlooter then
			return true
		end
		if ok then
			return false
		end
	end
	if GetLootMethod then
		return GetLootMethod() == "master"
	end
	return false
end

local function numSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	end
	if GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function slotLink(bag, slot)
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	end
	if GetContainerItemLink then
		return GetContainerItemLink(bag, slot)
	end
end

local function slotCount(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if type(info) == "table" then
			return info.stackCount or info.count or 1, info.isLocked and true or false
		end
	end
	if GetContainerItemInfo then
		local _, count, locked = GetContainerItemInfo(bag, slot)
		return count or 0, locked and true or false
	end
	return 0, false
end

local function matches(link, entry)
	if type(link) ~= "string" then
		return false
	end
	local wantStr = entryString(entry)
	local gotStr = itemString(link)
	if wantStr and gotStr and wantStr == gotStr then
		return true
	end
	local wantId = entryID(entry)
	local gotId = itemID(link)
	return wantId and gotId and wantId == gotId or false
end

local function findInBags(entry)
	local fallback
	local maxBag = NUM_BAG_SLOTS or 4
	if maxBag < 5 then
		maxBag = 5
	end
	for bag = 0, maxBag do
		local slots = numSlots(bag)
		for slot = 1, slots do
			local link = slotLink(bag, slot)
			local count, locked = slotCount(bag, slot)
			if link and not locked and count > 0 and matches(link, entry) then
				local wantStr = entryString(entry)
				local gotStr = itemString(link)
				if wantStr and gotStr == wantStr then
					return bag, slot, count
				end
				if not fallback then
					fallback = { bag, slot, count }
				end
			end
		end
	end
	if fallback then
		return fallback[1], fallback[2], fallback[3]
	end
end

local function tradeLink(index)
	if GetTradePlayerItemLink then
		return GetTradePlayerItemLink(index)
	end
end

local function emptyTradeSlot()
	for index = 1, 6 do
		local link = tradeLink(index)
		if not link or link == "" then
			return index
		end
	end
end

local function findInTrade(entry)
	for index = 1, 6 do
		local link = tradeLink(index)
		if matches(link, entry) then
			return index
		end
	end
end

local function pickup(bag, slot)
	if C_Container and C_Container.PickupContainerItem then
		C_Container.PickupContainerItem(bag, slot)
	elseif PickupContainerItem then
		PickupContainerItem(bag, slot)
	end
end

local function holding()
	return CursorHasItem and CursorHasItem()
end

local function releaseCursor(bag, slot)
	if not holding() then
		return
	end
	pickup(bag, slot)
	if holding() and ClearCursor then
		ClearCursor()
	end
end

local function placeInTrade(bag, slot, tradeSlot)
	pickup(bag, slot)
	if not holding() then
		return false
	end
	if not ClickTradeButton then
		releaseCursor(bag, slot)
		return false
	end
	ClickTradeButton(tradeSlot)
	if holding() then
		releaseCursor(bag, slot)
		return false
	end
	local link = tradeLink(tradeSlot)
	return link and link ~= ""
end

local function partnerName()
	local name = UnitName and UnitName("npc")
	if type(name) ~= "string" or name == "" then
		if TradeFrameRecipientNameText and TradeFrameRecipientNameText.GetText then
			name = TradeFrameRecipientNameText:GetText()
		end
	end
	return SK.ShortName(name)
end

local function alreadyPlacing(id)
	if not placing then
		return false
	end
	for i = 1, #placing do
		if placing[i].id == id then
			return true
		end
	end
	return false
end

local function onTradeShow()
	if not SK.Session or not SK.Session:IsOfficer() then
		return
	end
	busy = true
	local who = partnerName()
	if who == "" then
		note("Trade target is not available.")
		return
	end
	if CheckInteractDistance and not CheckInteractDistance("npc", 2) then
		note(who .. " is out of range. The award stays in Needs Trade.")
		return
	end
	local pending = SK.Session:NeedsTrade()
	local owed = {}
	for i = 1, #pending do
		if sameName(pending[i].winner, who) then
			table.insert(owed, pending[i])
		end
	end
	if #owed == 0 then
		return
	end
	placing = placing or {}
	local problems = {}
	local placedNames = {}
	for i = 1, #owed do
		local entry = owed[i]
		if not alreadyPlacing(entry.id) then
			local label = SK.Item.Display(entry)
			if findInTrade(entry) then
				table.insert(placing, { id = entry.id, inTrade = true, itemID = entryID(entry) })
				table.insert(placedNames, label)
			else
				local bag, slot, count = findInBags(entry)
				if not bag then
					table.insert(problems, label .. " is not in your bags.")
				else
					local tradeSlot = emptyTradeSlot()
					if not tradeSlot then
						table.insert(problems, "The trade window is full.")
					elseif placeInTrade(bag, slot, tradeSlot) then
						table.insert(placing, {
							id = entry.id,
							bag = bag,
							slot = slot,
							count = count,
							itemID = entryID(entry),
						})
						table.insert(placedNames, label)
					else
						table.insert(problems, "Could not place " .. label .. " in the trade window.")
					end
				end
			end
		end
	end
	if #problems > 0 then
		note(table.concat(problems, " ") .. " The award stays in Needs Trade.")
	elseif #placedNames == 1 then
		note(placedNames[1] .. " is in the trade window.")
	elseif #placedNames > 1 then
		note(#placedNames .. " items are in the trade window.")
	end
end

local function countAt(row)
	if not row.bag then
		return nil
	end
	local link = slotLink(row.bag, row.slot)
	if not link or itemID(link) ~= row.itemID then
		return 0
	end
	local count = slotCount(row.bag, row.slot)
	return count or 0
end

local function stillCarrying(itemID)
	if not itemID then
		return false
	end
	local maxBag = NUM_BAG_SLOTS or 4
	if maxBag < 5 then
		maxBag = 5
	end
	for bag = 0, maxBag do
		local slots = numSlots(bag)
		for slot = 1, slots do
			local link = slotLink(bag, slot)
			if link and itemID(link) == itemID then
				return true
			end
		end
	end
	return false
end

local function finishTrade()
	local rows = placing
	local accepted = bothAccepted
	placing = nil
	bothAccepted = false
	busy = false
	if not rows or #rows == 0 or not SK.Session then
		return
	end
	local function settle()
		for i = 1, #rows do
			local row = rows[i]
			local handedOver = false
			if row.inTrade then
				handedOver = accepted and not stillCarrying(row.itemID)
			else
				local still = countAt(row)
				handedOver = still ~= nil and still < (row.count or 1)
			end
			if handedOver then
				SK.Session:MarkDelivered(row.id)
			end
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.3, settle)
	else
		settle()
	end
end

function SK.Trade:GiveMasterLoot(entry, winner)
	if not masterLootMethod() or not GiveMasterLoot or not GetNumLootItems then
		return false
	end
	local slots = GetNumLootItems() or 0
	if slots < 1 then
		return false
	end
	local wantId = entryID(entry)
	for slot = 1, slots do
		local slotType = GetLootSlotType and GetLootSlotType(slot)
		if slotType and LOOT_SLOT_ITEM and slotType ~= LOOT_SLOT_ITEM and slotType ~= 1 then
			slotType = "skip"
		end
		local link = GetLootSlotLink and GetLootSlotLink(slot)
		if slotType ~= "skip" and link and (not wantId or itemID(link) == wantId) and matches(link, entry) then
			local candidate
			if GetMasterLootCandidate then
				for index = 1, 40 do
					local name = GetMasterLootCandidate(slot, index)
					if not name or name == "" then
						break
					end
					if sameName(name, winner) then
						candidate = index
						break
					end
				end
			end
			local before = link
			local ok = false
			if candidate then
				ok = pcall(GiveMasterLoot, slot, candidate)
			end
			if not ok then
				ok = pcall(GiveMasterLoot, slot, winner)
			end
			if not ok then
				return false
			end
			local after = GetLootSlotLink and GetLootSlotLink(slot)
			if after and after == before then
				return false
			end
			if SK.Debug then
				SK.Debug:Line("Trade", "master", SK.Item.Display(entry) .. " to " .. tostring(winner))
			end
			return true
		end
	end
	return false
end

local function onAccept(playerAccepted, targetAccepted)
	local function flag(value)
		return value == 1 or value == true
	end
	bothAccepted = flag(playerAccepted) and flag(targetAccepted)
end

local function onError(a, b)
	if not busy then
		return
	end
	local message = a
	if type(a) == "number" then
		message = b
	end
	if type(message) ~= "string" then
		return
	end
	if (ERR_TRADE_BAG_FULL and message == ERR_TRADE_BAG_FULL) or (ERR_INV_FULL and message == ERR_INV_FULL) then
		note("Bags are full. The award stays in Needs Trade.")
		return
	end
	local lower = string.lower(message)
	if string.find(lower, "bag", 1, true) and string.find(lower, "full", 1, true) then
		note("Bags are full. The award stays in Needs Trade.")
		return
	end
	if string.find(lower, "too far", 1, true) or string.find(lower, "out of range", 1, true) then
		note("Out of range. The award stays in Needs Trade.")
	end
end

SK.Events:Register("TRADE_SHOW", onTradeShow)
SK.Events:Register("TRADE_ACCEPT_UPDATE", onAccept)
SK.Events:Register("TRADE_CLOSED", finishTrade)
SK.Events:Register("TRADE_REQUEST_CANCEL", function()
	bothAccepted = false
end)
SK.Events:Register("UI_ERROR_MESSAGE", onError)
