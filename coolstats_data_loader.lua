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

	return GetDataRealmKey(data) == realmKey
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

coolstats.realmDataByRealm = coolstats.realmDataByRealm or {}

local function RememberRealmData(data)
	local realmKey = GetDataRealmKey(data)
	if realmKey ~= "" and data and type(data.players) == "table" then
		coolstats.realmDataByRealm[realmKey] = data
	end
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
	local realmKey = NormalizeRealmName(realm or GetCurrentRealmName())
	local addonName = REALM_DATA_ADDONS[realmKey]
	if addonName and GetAddOnMetadata then
		local manifestPhase = NormalizeRealmName(GetAddOnMetadata(addonName, "X-coolstats-Phase"))
		if manifestPhase ~= "" then
			return manifestPhase
		end
	end
	return REALM_PHASE_IDS[realmKey]
end

function coolstats.GetRealmDataStatus()
	return coolstats.realmDataStatus
end

function coolstats.EnsureRealmDataLoaded()
	local realmKey = GetCurrentRealmKey()
	local addonName = REALM_DATA_ADDONS[realmKey]

	-- The core addon never owns logs data. Discard anything another addon
	-- exposed unless it explicitly belongs to the current realm.
	if DataMatchesCurrentRealm(coolstatsUwUData, realmKey) then
		RememberRealmData(coolstatsUwUData)
		SetRealmDataStatus(true, "loaded", addonName)
		return true
	end

	RememberRealmData(coolstatsUwUData)
	coolstatsUwUData = nil

	if not addonName then
		SetRealmDataStatus(false, "unsupported-realm", nil)
		return false, "unsupported-realm"
	end

	local rememberedData = coolstats.realmDataByRealm[realmKey]
	if DataMatchesCurrentRealm(rememberedData, realmKey) then
		coolstatsUwUData = rememberedData
		SetRealmDataStatus(true, "restored", addonName)
		return true
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
		RememberRealmData(coolstatsUwUData)
		SetRealmDataStatus(true, "loaded", addonName)
		return true
	end

	coolstatsUwUData = nil
	SetRealmDataStatus(false, reason or "realm-data-missing", addonName)
	return false, reason or "realm-data-missing"
end

-- Never let stale or eagerly loaded data survive until realm validation.
coolstatsUwUData = nil

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(_, event, loadedAddonName)
	if event == "ADDON_LOADED" and loadedAddonName ~= ADDON_NAME then
		return
	end

	coolstats.EnsureRealmDataLoaded()
end)
