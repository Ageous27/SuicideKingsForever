SK = SK or {}
SK.Saved = SK.Saved or {}

local DEFAULTS = {
	list = {},
	settings = {
		bidDrop = "last",
		timer = 15,
		countdown = 5,
		disenchanter = "",
		autoAdd = true,
		autoQuality = 2,
		opacity = 0.95,
		benchMode = "raise",
		benchSteps = 1,
		absentMode = "hold",
		absentSteps = 1,
		nocallMode = "demote",
		nocallSteps = 1,
		awayMinutes = 10,
		minimapShown = true,
	},
	history = {
		events = {},
		ids = {},
	},
	session = {
		seeding = false,
		waiting = {},
		needsTrade = {},
	},
	layout = {},
}

local function fill(dst, src)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dst[key]) ~= "table" then
				dst[key] = {}
			end
			fill(dst[key], value)
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
end

function SK.Saved:Init()
	if type(SKDB) ~= "table" then
		SKDB = {}
	end
	fill(SKDB, DEFAULTS)
	if SK.Teams then
		SK.Teams:Ensure()
	end
	if SK.List then
		SK.List:RebuildIndex()
	end
	if SK.Session then
		SK.Session:RefreshSeeding()
	end
	if SK.Debug then
		SK.Debug:AttachSaved()
		SK.Debug:Line("Saved", "loaded", tostring(#SKDB.list) .. " rows")
	end
	if SK.Events then
		SK.Events:Fire("SK_READY")
	end
end

function SK.Saved:List()
	return SKDB.list
end

function SK.Saved:Settings()
	return SKDB.settings
end

function SK.Saved:History()
	return SKDB.history
end

function SK.Saved:Session()
	return SKDB.session
end
