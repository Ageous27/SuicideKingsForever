SK = SK or {}

SK.TITLE = "Suicide Kings Forever"
SK.VERSION = "0.3.6"
SK.PREFIX = "SKF1"

SK.CLASSES = {
	"Warrior",
	"Paladin",
	"Hunter",
	"Rogue",
	"Priest",
	"Mage",
	"Warlock",
	"Druid",
	"Shaman",
}

SK.CLASS_FILE = {
	Warrior = "WARRIOR",
	Paladin = "PALADIN",
	Hunter = "HUNTER",
	Rogue = "ROGUE",
	Priest = "PRIEST",
	Mage = "MAGE",
	Warlock = "WARLOCK",
	Druid = "DRUID",
	Shaman = "SHAMAN",
}

function SK.Trim(text)
	if not text then
		return ""
	end
	return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

function SK.ClassName(text)
	local key = string.lower(SK.Trim(text))
	if key == "" then
		return nil
	end
	for i = 1, #SK.CLASSES do
		if string.lower(SK.CLASSES[i]) == key then
			return SK.CLASSES[i]
		end
	end
	return nil
end

function SK.ShortName(name)
	if type(issecretvalue) == "function" and issecretvalue(name) then
		return ""
	end
	if type(name) ~= "string" then
		return ""
	end
	return string.match(name, "^([^%-]+)") or name
end

function SK.Print(text)
	print("|cffd4af37SKF|r " .. tostring(text))
end
