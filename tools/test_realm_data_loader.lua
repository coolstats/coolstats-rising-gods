local loaderPath = assert(arg[1], "usage: lua test_realm_data_loader.lua <coolstats_data_loader.lua>")

local currentRealm = "Rising-Gods"
local loadedAddons = {}
local loadCalls = {}
local realmData = {
	coolstats_Data_RisingGods = {
		realm = "Rising-Gods",
		phaseId = "icc",
		players = { risinggods = true },
	},
}

function GetRealmName()
	return currentRealm
end

function GetAddOnMetadata(addonName, field)
	if addonName == "coolstats_Data_RisingGods" and field == "X-coolstats-Phase" then
		return "icc"
	end
end

function IsAddOnLoaded(addonName)
	return loadedAddons[addonName] == true
end

function LoadAddOn(addonName)
	loadCalls[#loadCalls + 1] = addonName
	local data = realmData[addonName]
	if not data then
		return nil, "MISSING"
	end
	loadedAddons[addonName] = true
	coolstatsUwUData = data
	return true
end

local loaderFrame
function CreateFrame()
	loaderFrame = {
		RegisterEvent = function() end,
		SetScript = function(self, script, handler)
			if script == "OnEvent" then
				self.OnEvent = handler
			end
		end,
	}
	return loaderFrame
end

coolstats = {}
local loaderChunk = assert(loadfile(loaderPath))
loaderChunk("coolstats")

loaderFrame.OnEvent(loaderFrame, "PLAYER_ENTERING_WORLD")
assert(coolstatsUwUData and coolstatsUwUData.realm == "Rising-Gods", "Rising Gods data was not activated")
assert(coolstatsUwUData.phaseId == "icc", "Rising Gods did not activate ICC")
assert(coolstats.realmDataStatus and coolstats.realmDataStatus.loaded, "Rising Gods status was not loaded")

currentRealm = "Rising Gods"
loaderFrame.OnEvent(loaderFrame, "PLAYER_ENTERING_WORLD")
assert(coolstatsUwUData and coolstatsUwUData.realm == "Rising-Gods", "spaced realm alias was not normalized")
assert(#loadCalls == 1, "remembered Rising Gods data was loaded more than once")

print("realm_aliases=Rising-Gods>Rising Gods")
print("realm_load_calls=" .. tostring(#loadCalls))
