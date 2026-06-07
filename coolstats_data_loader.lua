local ADDON_NAME = ...

coolstats = coolstats or {}

local REALM_DATA_ADDONS = {
	onyxia = "coolstats_Data_Onyxia",
	icecrown = "coolstats_Data_Icecrown",
	lordaeron = "coolstats_Data_Lordaeron",
}

local REALM_PHASE_IDS = {
	onyxia = "ulduar",
	icecrown = "icc",
	lordaeron = "icc",
}

local function NormalizeRealmName(realm)
	return string.lower(string.gsub(tostring(realm or ""), "[^%a%d]", ""))
end

local function GetCurrentRealmName()
	if GetRealmName then
		return GetRealmName() or ""
	end
	return ""
end

local function GetCurrentRealmKey()
	return NormalizeRealmName(GetCurrentRealmName())
end

local function GetDataRealmKey(data)
	return NormalizeRealmName(data and data.realm)
end

local function DataMatchesCurrentRealm(data, realmKey)
	if not data or type(data.players) ~= "table" then
		return false
	end

	local dataRealmKey = GetDataRealmKey(data)
	if dataRealmKey == realmKey then
		return true
	end

	-- Older bundled datasets used this placeholder and were Onyxia-only.
	return dataRealmKey == "realm" and realmKey == "onyxia"
end

local function SetRealmDataStatus(loaded, reason, addonName)
	coolstats.realmDataStatus = {
		loaded = loaded == true,
		reason = reason,
		addonName = addonName,
		realm = GetCurrentRealmName(),
		realmKey = GetCurrentRealmKey(),
		dataRealm = coolstatsUwUData and coolstatsUwUData.realm or nil,
	}
end

function coolstats.GetCurrentRealmName()
	return GetCurrentRealmName()
end

function coolstats.GetCurrentRealmKey()
	return GetCurrentRealmKey()
end

function coolstats.GetRealmDataAddonName(realm)
	return REALM_DATA_ADDONS[NormalizeRealmName(realm or GetCurrentRealmName())]
end

function coolstats.GetExpectedRealmPhaseId(realm)
	return REALM_PHASE_IDS[NormalizeRealmName(realm or GetCurrentRealmName())]
end

function coolstats.GetRealmDataStatus()
	return coolstats.realmDataStatus
end

function coolstats.EnsureRealmDataLoaded()
	local realmKey = GetCurrentRealmKey()
	local addonName = REALM_DATA_ADDONS[realmKey]

	if DataMatchesCurrentRealm(coolstatsUwUData, realmKey) then
		SetRealmDataStatus(true, "loaded", addonName)
		return true
	end

	-- Never expose a bundled dataset from a different realm.
	coolstatsUwUData = nil

	if not addonName then
		SetRealmDataStatus(false, "unsupported-realm", nil)
		return false, "unsupported-realm"
	end

	if IsAddOnLoaded and IsAddOnLoaded(addonName) then
		SetRealmDataStatus(false, "realm-data-mismatch", addonName)
		return false, "realm-data-mismatch"
	end

	if not LoadAddOn then
		SetRealmDataStatus(false, "load-addon-unavailable", addonName)
		return false, "load-addon-unavailable"
	end

	local loaded, reason = LoadAddOn(addonName)
	if loaded and DataMatchesCurrentRealm(coolstatsUwUData, realmKey) then
		SetRealmDataStatus(true, "loaded", addonName)
		return true
	end

	coolstatsUwUData = nil
	SetRealmDataStatus(false, reason or "realm-data-missing", addonName)
	return false, reason or "realm-data-missing"
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, loadedAddonName)
	if loadedAddonName == ADDON_NAME then
		coolstats.EnsureRealmDataLoaded()
	end
end)
