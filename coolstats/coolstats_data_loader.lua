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

local function GetRaidLayerOptions(realmKey, phaseId, create)
	local db = coolstatsDB
	if type(db) ~= "table" then
		return nil
	end
	db.tooltip = db.tooltip or {}
	local tooltip = db.tooltip
	if type(tooltip.uwuRaidLayers) ~= "table" then
		if not create then
			return nil
		end
		tooltip.uwuRaidLayers = {}
	end
	realmKey = NormalizeRealmName(realmKey)
	phaseId = NormalizeRealmName(phaseId)
	if realmKey == "" or phaseId == "" then
		return nil
	end
	if type(tooltip.uwuRaidLayers[realmKey]) ~= "table" then
		if not create then
			return nil
		end
		tooltip.uwuRaidLayers[realmKey] = {}
	end
	if type(tooltip.uwuRaidLayers[realmKey][phaseId]) ~= "table" then
		if not create then
			return nil
		end
		tooltip.uwuRaidLayers[realmKey][phaseId] = {}
	end
	return tooltip.uwuRaidLayers[realmKey][phaseId]
end

function coolstats.IsUwURaidLayerEnabled(realm, phaseId, raidKey)
	raidKey = tostring(raidKey or "")
	if raidKey == "" then
		return true
	end
	local realmKey = NormalizeRealmName(realm or GetCurrentRealmName())
	phaseId = NormalizeRealmName(phaseId or coolstats.GetExpectedRealmPhaseId(realmKey))
	local options = GetRaidLayerOptions(realmKey, phaseId, false)
	if type(options) ~= "table" then
		return true
	end
	return options[raidKey] ~= false
end

function coolstats.SetUwURaidLayerEnabled(realm, phaseId, raidKey, enabled)
	raidKey = tostring(raidKey or "")
	if raidKey == "" then
		return
	end
	local realmKey = NormalizeRealmName(realm or GetCurrentRealmName())
	phaseId = NormalizeRealmName(phaseId or coolstats.GetExpectedRealmPhaseId(realmKey))
	local options = GetRaidLayerOptions(realmKey, phaseId, true)
	if type(options) ~= "table" then
		return
	end
	options[raidKey] = enabled ~= false
	if coolstats.ClearUwUTooltipCache then
		coolstats.ClearUwUTooltipCache()
	end
	if coolstats.InvalidateCachedPlayerBrowserIndex then
		coolstats.InvalidateCachedPlayerBrowserIndex()
	end
end

local function IsUwUDataRaidLayerEnabled(data, raidKey)
	if type(data) ~= "table" then
		return true
	end
	return coolstats.IsUwURaidLayerEnabled(data.realm, data.phaseId, raidKey)
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

function coolstats.ShouldSkipUwUDataRaidLayer(data, raidKey, chunkStartIndex)
	if type(data) ~= "table" then
		return false
	end
	if not IsUwUDataRaidLayerEnabled(data, raidKey) then
		return true
	end
	return coolstats.ShouldSkipUwUDataChunk(data, chunkStartIndex)
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

function coolstats.MarkUwUDataRaidLayerLoaded(data, raidKey)
	if type(data) ~= "table" then
		return
	end
	raidKey = tostring(raidKey or "")
	if raidKey == "" then
		return
	end
	data.loadedRaidLayers = data.loadedRaidLayers or {}
	data.loadedRaidLayers[raidKey] = true
end

local function HasUwUDataShards(data)
	if type(data) ~= "table" then
		return false
	end
	return type(data.playerShardAddons) == "table" or type(data.playerShardAddonPrefix) == "string"
end

local function GetUwUDataShardAddonName(data, index)
	if type(data) ~= "table" then
		return nil
	end
	local addons = data.playerShardAddons
	if type(addons) == "table" and addons[index] then
		return addons[index]
	end
	local prefix = data.playerShardAddonPrefix
	if type(prefix) == "string" and prefix ~= "" then
		return prefix .. string.format("%02d", index)
	end
	return nil
end

local function GetUwUDataRaidLayerShardAddonName(layer, index)
	if type(layer) ~= "table" then
		return nil
	end
	local addons = layer.shardAddons
	if type(addons) == "table" and addons[index] then
		return addons[index]
	end
	local prefix = layer.shardAddonPrefix
	if type(prefix) == "string" and prefix ~= "" then
		return prefix .. string.format("%02d", index)
	end
	return nil
end

function coolstats.GetUwUDataRaidLayerChoices(data)
	data = data or coolstatsUwUData
	local choices = {}
	if type(data) ~= "table" or type(data.raidLayers) ~= "table" then
		return choices
	end
	for index = 1, #data.raidLayers do
		local layer = data.raidLayers[index]
		if type(layer) == "table" and layer.key and layer.name then
			choices[#choices + 1] = {
				key = tostring(layer.key),
				name = tostring(layer.name),
				enabled = IsUwUDataRaidLayerEnabled(data, layer.key),
				loaded = data.loadedRaidLayers and data.loadedRaidLayers[layer.key] == true,
				bossIndexes = layer.bossIndexes,
			}
		end
	end
	return choices
end

local function GetUwUDataRaidLayerByBossIndex(data)
	if type(data) ~= "table" or type(data.raidLayers) ~= "table" then
		return nil
	end
	if data.raidLayerByBossIndex then
		return data.raidLayerByBossIndex
	end
	local map = {}
	for layerIndex = 1, #data.raidLayers do
		local layer = data.raidLayers[layerIndex]
		local bossIndexes = type(layer) == "table" and layer.bossIndexes or nil
		if type(bossIndexes) == "table" then
			for index = 1, #bossIndexes do
				local bossIndex = tonumber(bossIndexes[index])
				if bossIndex then
					map[bossIndex] = layer
				end
			end
		end
	end
	data.raidLayerByBossIndex = map
	return map
end

function coolstats.IsUwUBossIndexEnabled(data, bossIndex)
	if type(data) ~= "table" or type(data.raidLayers) ~= "table" then
		return true
	end
	local map = GetUwUDataRaidLayerByBossIndex(data)
	local layer = map and map[tonumber(bossIndex)]
	if not layer or not layer.key then
		return true
	end
	return IsUwUDataRaidLayerEnabled(data, layer.key)
end

function coolstats.GetUwUDataDesiredShardCount(data)
	if type(data) ~= "table" then
		return 0
	end
	local chunkCount = math.floor((tonumber(data.playerChunkCount) or 0) + 0.5)
	local steps = GetDataPlayerLoadSteps(data)
	if chunkCount <= 0 and type(steps) == "table" then
		chunkCount = math.max(0, #steps - 1)
	end
	if chunkCount <= 0 then
		return 0
	end

	local limit = coolstats.GetUwUDataPlayerLoadLimit(data.totalPlayers, steps)
	data.loadLimit = limit
	data.loadedPlayers = nil
	if limit == 0 then
		return 0
	end
	if limit == nil or type(steps) ~= "table" then
		return chunkCount
	end

	local desired = 0
	for index = 1, chunkCount do
		local chunkStartIndex = math.floor((tonumber(steps[index]) or 0) + 0.5) + 1
		if chunkStartIndex <= limit then
			desired = index
		end
	end
	return desired
end

local function LoadUwUDataRaidLayers(data, desiredShardCount)
	if type(data) ~= "table" or type(data.raidLayers) ~= "table" then
		return true
	end
	if not LoadAddOn then
		return false, "load-addon-unavailable"
	end
	desiredShardCount = math.floor((tonumber(desiredShardCount) or 0) + 0.5)
	if desiredShardCount <= 0 then
		return true
	end
	data.loadedRaidLayerShards = data.loadedRaidLayerShards or {}
	data.loadedRaidLayers = data.loadedRaidLayers or {}
	for layerIndex = 1, #data.raidLayers do
		local layer = data.raidLayers[layerIndex]
		local raidKey = layer and layer.key
		if raidKey and IsUwUDataRaidLayerEnabled(data, raidKey) then
			local loaded = tonumber(data.loadedRaidLayerShards[raidKey]) or 0
			for shardIndex = loaded + 1, desiredShardCount do
				local shardAddonName = GetUwUDataRaidLayerShardAddonName(layer, shardIndex)
				if not shardAddonName then
					return false, "realm-data-raid-layer-missing"
				end
				if not IsAddOnLoaded or not IsAddOnLoaded(shardAddonName) then
					local ok, reason = LoadAddOn(shardAddonName)
					if not ok then
						return false, reason or "realm-data-raid-layer-missing", shardAddonName
					end
				end
				data.loadedRaidLayerShards[raidKey] = shardIndex
			end
			data.loadedRaidLayers[raidKey] = true
		end
	end
	return true
end

function coolstats.LoadUwUDataShards(data)
	if not HasUwUDataShards(data) then
		return true
	end
	if type(data.players) ~= "table" then
		data.players = {}
	end
	if not LoadAddOn then
		return false, "load-addon-unavailable"
	end

	local desired = coolstats.GetUwUDataDesiredShardCount(data)
	local loaded = tonumber(data.loadedShardCount) or 0
	for index = loaded + 1, desired do
		local shardAddonName = GetUwUDataShardAddonName(data, index)
		if not shardAddonName then
			return false, "realm-data-shard-missing"
		end
		if not IsAddOnLoaded or not IsAddOnLoaded(shardAddonName) then
			local ok, reason = LoadAddOn(shardAddonName)
			if not ok then
				return false, reason or "realm-data-shard-missing", shardAddonName
			end
		end
		data.loadedShardCount = index
	end
	data.loadedShardTarget = desired
	local raidLoaded, raidReason, raidAddonName = LoadUwUDataRaidLayers(data, desired)
	if not raidLoaded then
		return false, raidReason or "realm-data-raid-layer-missing", raidAddonName
	end
	return true
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
		loadedShardCount = data and data.loadedShardCount or nil,
		loadedShardTarget = data and data.loadedShardTarget or nil,
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

local function ActivateRealmData(data, realmKey, addonName, statusReason)
	if not DataMatchesCurrentRealm(data, realmKey) then
		return false, "realm-data-mismatch"
	end
	coolstatsUwUData = data
	local loaded, reason, shardAddonName = coolstats.LoadUwUDataShards(data)
	if not loaded then
		SetRealmDataStatus(false, reason or "realm-data-shard-missing", shardAddonName or addonName)
		return false, reason or "realm-data-shard-missing"
	end
	coolstats.FinalizeUwUDataLoad(data)
	RememberRealmData(data)
	SetRealmDataStatus(true, statusReason or "loaded", addonName)
	return true
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
		return ActivateRealmData(coolstatsUwUData, realmKey, addonName, "loaded")
	end

	RememberRealmData(coolstatsUwUData)
	coolstatsUwUData = nil

	if not addonName then
		SetRealmDataStatus(false, "unsupported-realm", nil)
		return false, "unsupported-realm"
	end

	local rememberedData = coolstats.realmDataByRealm[realmKey]
	if DataMatchesCurrentRealm(rememberedData, realmKey) then
		return ActivateRealmData(rememberedData, realmKey, addonName, "restored")
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
		return ActivateRealmData(coolstatsUwUData, realmKey, addonName, "loaded")
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
