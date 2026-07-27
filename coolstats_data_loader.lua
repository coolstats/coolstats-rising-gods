local ADDON_NAME = ...

coolstats = coolstats or {}

local REALM_DATA_ADDONS = {
	risinggods = "coolstats_Data_RisingGods",
}

local REALM_PHASE_IDS = {
	risinggods = "icc",
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

local function CountPlayers(players)
	if type(players) ~= "table" then
		return 0
	end
	local count = 0
	for _ in pairs(players) do
		count = count + 1
	end
	return count
end

local function GetRawPlayerLoadLimit()
	local db = coolstatsDB
	local tooltip = type(db) == "table" and db.tooltip or nil
	if type(tooltip) ~= "table" then
		return nil
	end
	return tonumber(tooltip.uwuPlayerLoadLimit)
end

local function GetDefaultPlayerChunkCount(totalPlayers)
	totalPlayers = math.floor((tonumber(totalPlayers) or 0) + 0.5)
	if totalPlayers <= 0 then
		return 1
	end
	local chunkCount = math.ceil(totalPlayers / 3000)
	if totalPlayers >= 6000 and chunkCount < 6 then
		chunkCount = 6
	end
	if chunkCount > 16 then
		chunkCount = 16
	end
	if chunkCount < 1 then
		chunkCount = 1
	end
	return chunkCount
end

local function BuildEvenLoadSteps(totalPlayers, chunkCount)
	totalPlayers = math.floor((tonumber(totalPlayers) or 0) + 0.5)
	chunkCount = math.floor((tonumber(chunkCount) or 0) + 0.5)
	if totalPlayers <= 0 then
		return { 0 }
	end
	if chunkCount <= 0 then
		chunkCount = GetDefaultPlayerChunkCount(totalPlayers)
	end
	local steps = { 0 }
	local chunkSize = math.ceil(totalPlayers / chunkCount)
	for index = 1, chunkCount do
		local value = math.min(totalPlayers, index * chunkSize)
		if value > steps[#steps] then
			steps[#steps + 1] = value
		end
	end
	if steps[#steps] ~= totalPlayers then
		steps[#steps + 1] = totalPlayers
	end
	return steps
end

local function GetDataPlayerLoadSteps(data)
	if type(data) == "table" and type(data.playerLoadSteps) == "table" then
		return data.playerLoadSteps
	end
	local totalPlayers = data and data.totalPlayers or nil
	local chunkCount = data and data.playerChunkCount or nil
	return BuildEvenLoadSteps(totalPlayers, chunkCount)
end

local function SnapPlayerLoadLimit(raw, totalPlayers, loadSteps)
	if raw == nil then
		return nil
	end
	local limit = math.floor((tonumber(raw) or 0) + 0.5)
	if limit <= 0 then
		return 0
	end
	totalPlayers = math.floor((tonumber(totalPlayers) or 0) + 0.5)
	if totalPlayers > 0 and limit >= totalPlayers then
		return nil
	end
	if type(loadSteps) == "table" then
		for index = 2, #loadSteps do
			local stepValue = math.floor((tonumber(loadSteps[index]) or 0) + 0.5)
			if stepValue > 0 and limit <= stepValue then
				if totalPlayers > 0 and stepValue >= totalPlayers then
					return nil
				end
				return stepValue
			end
		end
	end
	return limit
end

function coolstats.GetUwUDataPlayerLoadLimit(totalPlayers, loadSteps)
	local raw = GetRawPlayerLoadLimit()
	return SnapPlayerLoadLimit(raw, totalPlayers, loadSteps)
end

function coolstats.ShouldBuildUwUDataPlayerAllowList(data)
	local totalPlayers = data and data.totalPlayers or nil
	local limit = coolstats.GetUwUDataPlayerLoadLimit(totalPlayers, GetDataPlayerLoadSteps(data))
	return limit ~= nil and limit > 0
end

function coolstats.ShouldSkipUwUDataChunk(data, chunkStartIndex)
	if type(data) ~= "table" then
		return false
	end
	local limit = coolstats.GetUwUDataPlayerLoadLimit(data.totalPlayers, GetDataPlayerLoadSteps(data))
	data.loadLimit = limit
	data.loadedPlayers = nil
	if limit == nil then
		return false
	end
	return (tonumber(chunkStartIndex) or 1) > limit
end

function coolstats.BuildUwUDataPlayerAllowList(data, playerLoadOrder)
	if type(data) ~= "table" then
		return nil
	end
	local totalPlayers = tonumber(data.totalPlayers)
	if not totalPlayers or totalPlayers < 0 then
		totalPlayers = type(playerLoadOrder) == "table" and #playerLoadOrder or 0
		data.totalPlayers = totalPlayers
	end
	local limit = coolstats.GetUwUDataPlayerLoadLimit(totalPlayers, GetDataPlayerLoadSteps(data))
	data.loadLimit = limit
	data.loadedPlayers = nil
	data.playerLoadAllowed = nil
	if limit == nil then
		return nil
	end
	if type(playerLoadOrder) ~= "table" then
		return nil
	end
	local allowed = {}
	if limit > 0 then
		for index = 1, math.min(limit, #playerLoadOrder) do
			local key = playerLoadOrder[index]
			if key then
				allowed[key] = true
			end
		end
	end
	data.playerLoadAllowed = allowed
	return allowed
end

function coolstats.InsertUwUDataChunk(data, chunk)
	if type(data) ~= "table" or type(data.players) ~= "table" or type(chunk) ~= "table" then
		return
	end
	local allowed = data.playerLoadAllowed
	if allowed then
		for key, player in pairs(chunk) do
			if allowed[key] then
				data.players[key] = player
			end
		end
	elseif data.loadLimit ~= 0 then
		for key, player in pairs(chunk) do
			data.players[key] = player
		end
	end
end

function coolstats.FinalizeUwUDataLoad(data)
	if type(data) ~= "table" then
		return
	end
	data.loadedPlayers = CountPlayers(data.players)
	data.playerLoadAllowed = nil
end

local function SetRealmDataStatus(loaded, reason, addonName)
	local data = coolstatsUwUData
	coolstats.realmDataStatus = {
		loaded = loaded == true,
		reason = reason,
		addonName = addonName,
		realm = GetCurrentRealmName(),
		realmKey = GetCurrentRealmKey(),
		dataRealm = data and data.realm or nil,
		totalPlayers = data and data.totalPlayers or nil,
		loadedPlayers = data and (data.loadedPlayers or CountPlayers(data.players)) or nil,
		playerLoadLimit = data and data.loadLimit or nil,
	}
end

coolstats.realmDataByRealm = coolstats.realmDataByRealm or {}

local function RememberRealmData(data)
	local realmKey = GetDataRealmKey(data)
	if realmKey ~= "" and data and type(data.players) == "table" then
		coolstats.FinalizeUwUDataLoad(data)
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

local function GetRealmDataForKey(realmKey)
	local data = coolstats.realmDataByRealm and coolstats.realmDataByRealm[realmKey]
	if data then
		return data
	end
	if coolstatsUwUData and GetDataRealmKey(coolstatsUwUData) == realmKey then
		return coolstatsUwUData
	end
	return nil
end

function coolstats.GetRealmDataTotalPlayerCount(realm)
	local realmKey = NormalizeRealmName(realm or GetCurrentRealmName())
	local data = GetRealmDataForKey(realmKey)
	if data and tonumber(data.totalPlayers) then
		return math.max(0, math.floor(tonumber(data.totalPlayers) + 0.5))
	end
	local addonName = REALM_DATA_ADDONS[realmKey]
	if addonName and GetAddOnMetadata then
		local metadataCount = tonumber(GetAddOnMetadata(addonName, "X-coolstats-PlayerCount"))
		if metadataCount then
			return math.max(0, math.floor(metadataCount + 0.5))
		end
	end
	if data and type(data.players) == "table" then
		return CountPlayers(data.players)
	end
	if coolstatsUwUData and GetDataRealmKey(coolstatsUwUData) == realmKey and type(coolstatsUwUData.players) == "table" then
		return CountPlayers(coolstatsUwUData.players)
	end
	return nil
end

function coolstats.GetRealmDataLoadedPlayerCount(realm)
	local realmKey = NormalizeRealmName(realm or GetCurrentRealmName())
	local data = GetRealmDataForKey(realmKey)
	if data and tonumber(data.loadedPlayers) then
		return math.max(0, math.floor(tonumber(data.loadedPlayers) + 0.5))
	end
	if data and type(data.players) == "table" then
		return CountPlayers(data.players)
	end
	return nil
end

function coolstats.GetRealmDataPlayerLoadSteps(realm)
	local realmKey = NormalizeRealmName(realm or GetCurrentRealmName())
	local data = GetRealmDataForKey(realmKey)
	if data and type(data.playerLoadSteps) == "table" then
		return data.playerLoadSteps
	end
	local total = coolstats.GetRealmDataTotalPlayerCount(realm)
	local addonName = REALM_DATA_ADDONS[realmKey]
	local chunkCount
	if addonName and GetAddOnMetadata then
		chunkCount = tonumber(GetAddOnMetadata(addonName, "X-coolstats-PlayerChunks"))
	end
	if data and tonumber(data.playerChunkCount) then
		chunkCount = tonumber(data.playerChunkCount)
	end
	return BuildEvenLoadSteps(total, chunkCount)
end

function coolstats.GetRealmDataEffectivePlayerLoadLimit(realm)
	local total = coolstats.GetRealmDataTotalPlayerCount(realm)
	return SnapPlayerLoadLimit(GetRawPlayerLoadLimit(), total, coolstats.GetRealmDataPlayerLoadSteps(realm))
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
		coolstats.FinalizeUwUDataLoad(coolstatsUwUData)
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
		coolstats.FinalizeUwUDataLoad(coolstatsUwUData)
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
		coolstats.FinalizeUwUDataLoad(coolstatsUwUData)
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
