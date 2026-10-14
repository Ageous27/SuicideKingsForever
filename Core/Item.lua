SK = SK or {}
SK.Item = SK.Item or {}

local requested = {}

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

local function request(id)
	if not id or requested[id] then
		return
	end
	requested[id] = true
	if C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(id)
	end
end

function SK.Item.Describe(text)
	local raw = text or ""
	local id = itemID(raw)
	local str = itemString(raw)
	local bracket = string.match(raw, "%[(.-)%]")
	local name, link, icon, quality
	if id and C_Item and C_Item.GetItemNameByID then
		name = C_Item.GetItemNameByID(id)
	end
	if id and C_Item and C_Item.GetItemIconByID then
		icon = C_Item.GetItemIconByID(id)
	end
	if id and not icon and GetItemIcon then
		icon = GetItemIcon(id)
	end
	if id and C_Item and C_Item.GetItemQualityByID then
		quality = C_Item.GetItemQualityByID(id)
	end
	local query = str or id
	if query and (not name or not link) then
		local infoName, infoLink, infoQuality, _, _, _, _, _, _, infoIcon
		if C_Item and C_Item.GetItemInfo then
			infoName, infoLink, infoQuality, _, _, _, _, _, _, infoIcon = C_Item.GetItemInfo(query)
		end
		if not infoName and GetItemInfo then
			infoName, infoLink, infoQuality, _, _, _, _, _, _, infoIcon = GetItemInfo(query)
		end
		name = name or infoName
		link = link or infoLink
		icon = icon or infoIcon
		quality = quality or infoQuality
	end
	name = name or bracket
	if not link and name and str then
		local hex = "ffffffff"
		if GetItemQualityColor and quality then
			local _, _, _, color = GetItemQualityColor(quality)
			if type(color) == "string" and color ~= "" then
				hex = color
			end
		end
		link = "|c" .. hex .. "|H" .. str .. "|h[" .. name .. "]|h|r"
	end
	if string.find(raw, "|Hitem", 1, true) and string.find(raw, "%[") then
		link = raw
	end
	if id and not name then
		request(id)
	end
	return {
		itemID = id,
		name = name,
		link = link,
		icon = icon,
		quality = quality,
		slot = SK.Item.Slot(id),
	}
end

SK.Item.SLOTS = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger", "Trinket", "Weapon", "Off Hand", "Ranged",
}

local EQUIP = {
	INVTYPE_HEAD = "Head",
	INVTYPE_NECK = "Neck",
	INVTYPE_SHOULDER = "Shoulder",
	INVTYPE_CLOAK = "Back",
	INVTYPE_CHEST = "Chest",
	INVTYPE_ROBE = "Chest",
	INVTYPE_WRIST = "Wrist",
	INVTYPE_HAND = "Hands",
	INVTYPE_WAIST = "Waist",
	INVTYPE_LEGS = "Legs",
	INVTYPE_FEET = "Feet",
	INVTYPE_FINGER = "Finger",
	INVTYPE_TRINKET = "Trinket",
	INVTYPE_WEAPON = "Weapon",
	INVTYPE_WEAPONMAINHAND = "Weapon",
	INVTYPE_2HWEAPON = "Weapon",
	INVTYPE_SHIELD = "Off Hand",
	INVTYPE_WEAPONOFFHAND = "Off Hand",
	INVTYPE_HOLDABLE = "Off Hand",
	INVTYPE_RANGED = "Ranged",
	INVTYPE_RANGEDRIGHT = "Ranged",
	INVTYPE_THROWN = "Ranged",
	INVTYPE_RELIC = "Ranged",
}

function SK.Item.Slot(id)
	if not id then
		return nil
	end
	local equip
	if C_Item and C_Item.GetItemInfo then
		local _, _, _, _, _, _, _, _, loc = C_Item.GetItemInfo(id)
		equip = loc
	end
	if (not equip or equip == "") and GetItemInfo then
		local _, _, _, _, _, _, _, _, loc = GetItemInfo(id)
		equip = loc
	end
	if (not equip or equip == "") and C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(id)
	end
	return EQUIP[equip]
end

local function rawItemName(name)
	return type(name) == "string" and string.sub(name, 1, 5) == "item:"
end

function SK.Item.Display(entry)
	if not entry then
		return "Item"
	end
	if entry.name and entry.name ~= "" and not rawItemName(entry.name) then
		return entry.name
	end
	local info = SK.Item.Describe(entry.raw or entry.link or entry.name or "")
	if info.name then
		entry.name = info.name
		entry.link = info.link or entry.link
		entry.icon = info.icon or entry.icon
		entry.itemID = info.itemID or entry.itemID
		return info.name
	end
	return "Loading item..."
end

local function hyperlink(text)
	return type(text) == "string" and string.find(text, "|Hitem", 1, true) and string.find(text, "[", 1, true)
end

function SK.Item.ChatLink(entry)
	if not entry then
		return "item"
	end
	local name = SK.Item.Display(entry)
	if hyperlink(entry.link) then
		return entry.link
	end
	local info = SK.Item.Describe(entry.raw or entry.link or "")
	if not hyperlink(info.link) and entry.itemID and name and name ~= "" and name ~= "Loading item..." then
		info = SK.Item.Describe("item:" .. tostring(entry.itemID))
	end
	if info.name and (not entry.name or entry.name == "" or rawItemName(entry.name) or entry.name == "Loading item...") then
		entry.name = info.name
	end
	if info.icon then
		entry.icon = info.icon
	end
	if info.itemID then
		entry.itemID = info.itemID
	end
	if hyperlink(info.link) then
		entry.link = info.link
		return info.link
	end
	return name
end

local function fillEntry(entry)
	if not entry then
		return false
	end
	local before = entry.name
	local info = SK.Item.Describe(entry.raw or entry.link or entry.name or "")
	if info.name and (not before or before == "" or rawItemName(before) or before == "Loading item...") then
		entry.name = info.name
	end
	if info.link and (not entry.link or not string.find(entry.link, "|Hitem", 1, true)) then
		entry.link = info.link
	end
	if info.icon then
		entry.icon = info.icon
	end
	if info.itemID then
		entry.itemID = info.itemID
	end
	return entry.name ~= before
end

function SK.Item.RefreshSession()
	if not SK.Saved then
		return
	end
	local session = SK.Saved:Session()
	if type(session) ~= "table" then
		return
	end
	local updated = false
	local function walk(list)
		if not list then
			return
		end
		for i = 1, #list do
			if fillEntry(list[i]) then
				updated = true
			end
		end
	end
	walk(session.waiting)
	walk(session.needsTrade)
	if fillEntry(session.live) then
		updated = true
	end
	if updated and SK.Events then
		SK.Events:Fire("SK_SESSION", "item")
	end
end

SK.Events:Register("GET_ITEM_INFO_RECEIVED", function(itemID, success)
	if success == false then
		return
	end
	requested[itemID] = nil
	SK.Item.RefreshSession()
end)
