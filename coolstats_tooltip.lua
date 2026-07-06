local ADDON_NAME = ...

local ADDON_COLOR_R = 1.0
local ADDON_COLOR_G = 0.82
local ADDON_COLOR_B = 0.0

-- The stock client has no reliable API for custom progression phase detection.
local CURRENT_UWU_PHASE_ID = "toc"
local CURRENT_RAID_ID = CURRENT_UWU_PHASE_ID
local SECONDS_PER_DAY = 86400
local RAID_PROGRESS_CACHE_SECONDS = 300
local RAID_PROGRESS_FAILED_CACHE_SECONDS = 1.5
local RAID_PROGRESS_LOW_LEVEL_CACHE_SECONDS = SECONDS_PER_DAY
local RAID_PROGRESS_PRUNE_INTERVAL_SECONDS = 60
local RAID_PROGRESS_REQUEST_TIMEOUT_SECONDS = 4
coolstats.RAID_PROGRESS_REQUEST_THROTTLE = {
	dwell = 0.10,
	interval = 1.0,
	window = 11,
	limit = 5,
}

local RAID_PROGRESS_DATA = {
	ulduar = {
		name = "Ulduar",
		hardLabel = "Ulduar 25H",
		hardTotal = 9,
		milestoneLabel = "A",
		milestoneAchievementIds = { 3037 },
		hardModes = {
			{ name = "FL 4T", ids = { 3057 } },
			{ name = "XT", ids = { 3059 } },
			{ name = "Steelbreaker", ids = { 2944 } },
			{ name = "Hodir", ids = { 3184 } },
			{ name = "Thorim", ids = { 3183 } },
			{ name = "Freya", ids = { 3187 } },
			{ name = "Mimiron", ids = { 3189 } },
			{ name = "Vezax", ids = { 3188 } },
			{ name = "Yogg 0", ids = { 3164 } },
		},
	},
	icc = {
		name = "Icecrown Citadel",
		hardLabel = "ICC 25H",
		hardTotal = 10,
		milestoneLabel = "LOD",
		milestoneAchievementIds = { 4584 },
		hardModes = {
			{ name = "Marrowgar", statisticIds = { 4642 } },
			{ name = "Deathwhisper", statisticIds = { 4656 } },
			{ name = "Saurfang", statisticIds = { 4664 } },
			{ name = "Festergut", statisticIds = { 4667 } },
			{ name = "Rotface", statisticIds = { 4670 } },
			{ name = "Putricide", statisticIds = { 4673 } },
			{ name = "Blood Council", statisticIds = { 4676 } },
			{ name = "Lana'thel", statisticIds = { 4679 } },
			{ name = "Sindragosa", statisticIds = { 4685 } },
			{ name = "Lich King", statisticIds = { 4688 } },
		},
	},
}

local UWU_RAID_PHASES = {
	ulduar = {
		name = "Ulduar",
		defaultCollapsedRaids = {},
	},
	toc = {
		name = "Trial of the Grand Crusader",
		defaultCollapsedRaids = {},
	},
	icc = {
		name = "Icecrown Citadel",
		defaultCollapsedRaids = {},
	},
	rs = {
		name = "Ruby Sanctum",
		defaultCollapsedRaids = {},
	},
}

local UWU_INSPECT_PANEL_WIDTH = 318
local UWU_INSPECT_PANEL_HEIGHT = 460
local UWU_INSPECT_ROW_HEIGHT = 15
local UWU_INSPECT_ROW_COUNT = 40
local UWU_INSPECT_ROW_WIDTH = 292
local UWU_INSPECT_ROW_LEFT = 13
local UWU_INSPECT_TEXT_LEFT = 4
local UWU_INSPECT_TEXT_RIGHT = -8
local UWU_INSPECT_LABEL_WIDTH = 104
local UWU_INSPECT_VALUE_WIDTH = 164
local UWU_INSPECT_BOSS_LABEL_WIDTH = 98
local UWU_INSPECT_PARSE_LEFT = 104
local UWU_INSPECT_PARSE_WIDTH = 44
local UWU_INSPECT_PLAYER_RANK_LEFT = 153
local UWU_INSPECT_RAID_RANK_LEFT = 188
local UWU_INSPECT_RANK_WIDTH = 30
local UWU_INSPECT_DPS_WIDTH = 48
local UWU_INSPECT_SPEC_TAB_SIZE = 32
local UWU_INSPECT_SPEC_TAB_SPACING = 36
local UWU_INSPECT_SPEC_TAB_LEFT = 0
local UWU_INSPECT_SPEC_TAB_TOP = -50
local UWU_INSPECT_SPEC_TAB_BG_LEFT = -3
local UWU_INSPECT_SPEC_TAB_BG_TOP = 11
-- Large SavedVariables chunks can silently fail to load on the 3.3.5 client.
-- Normalized talent snapshots share one catalog per class and only retain
-- per-player rank strings, but keep a conservative cap while v2 rolls out.
coolstats.CACHE_LIMITS = {
	gearPlayers = 500,
	talentPlayers = 500,
	maxAgeSeconds = SECONDS_PER_DAY * 14,
}
local UWU_CACHED_GEAR_PANEL_WIDTH = 274
local UWU_CACHED_GEAR_PANEL_HEIGHT = 430
local UWU_CACHED_GEAR_PANEL_GAP = 5
local UWU_CACHED_GEAR_SLOT_SIZE = 38
local UWU_CACHED_GEAR_CLASS_ICON_SIZE = 62
local UWU_CACHED_GEAR_INFO_LEFT = 53
local UWU_CACHED_GEAR_INFO_WIDTH = 168
local UWU_CACHED_GEAR_INFO_ROW_HEIGHT = 13
local UWU_CLASS_ICON_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local UWU_LEVEL_80_BASE_DEFENSE_SKILL = 400
local UWU_LEVEL_80_HIT_RATING_PER_PERCENT = 32.78998947
local UWU_LEVEL_80_EXPERTISE_RATING_PER_POINT = 8.1974
local UWU_LEVEL_80_ARMOR_PEN_RATING_PER_PERCENT = 13.995727
local UWU_LEVEL_80_DEFENSE_RATING_PER_SKILL = 4.918498039

local UWU_CLASS_FILE_BY_INDEX = {
	[0] = "DEATHKNIGHT",
	[1] = "DRUID",
	[2] = "HUNTER",
	[3] = "MAGE",
	[4] = "PALADIN",
	[5] = "PRIEST",
	[6] = "ROGUE",
	[7] = "SHAMAN",
	[8] = "WARLOCK",
	[9] = "WARRIOR",
}

local UWU_CLASS_INDEX_BY_FILE = {
	DEATHKNIGHT = 0,
	DRUID = 1,
	HUNTER = 2,
	MAGE = 3,
	PALADIN = 4,
	PRIEST = 5,
	ROGUE = 6,
	SHAMAN = 7,
	WARLOCK = 8,
	WARRIOR = 9,
}

local UWU_CACHED_GEAR_SLOTS = {
	{ slot = 1, token = "HeadSlot", label = "Head", x = 14, y = -58 },
	{ slot = 2, token = "NeckSlot", label = "Neck", x = 14, y = -98 },
	{ slot = 3, token = "ShoulderSlot", label = "Shoulder", x = 14, y = -138 },
	{ slot = 15, token = "BackSlot", label = "Back", x = 14, y = -178 },
	{ slot = 5, token = "ChestSlot", label = "Chest", x = 14, y = -218 },
	{ slot = 4, token = "ShirtSlot", label = "Shirt", x = 14, y = -258 },
	{ slot = 19, token = "TabardSlot", label = "Tabard", x = 14, y = -298 },
	{ slot = 9, token = "WristSlot", label = "Wrist", x = 14, y = -338 },
	{ slot = 10, token = "HandsSlot", label = "Hands", x = 226, y = -58 },
	{ slot = 6, token = "WaistSlot", label = "Waist", x = 226, y = -98 },
	{ slot = 7, token = "LegsSlot", label = "Legs", x = 226, y = -138 },
	{ slot = 8, token = "FeetSlot", label = "Feet", x = 226, y = -178 },
	{ slot = 11, token = "Finger0Slot", label = "Finger", x = 226, y = -218 },
	{ slot = 12, token = "Finger1Slot", label = "Finger", x = 226, y = -258 },
	{ slot = 13, token = "Trinket0Slot", label = "Trinket", x = 226, y = -298 },
	{ slot = 14, token = "Trinket1Slot", label = "Trinket", x = 226, y = -338 },
	{ slot = 16, token = "MainHandSlot", label = "Main Hand", x = 78, y = -386 },
	{ slot = 17, token = "SecondaryHandSlot", label = "Off Hand", x = 119, y = -386 },
	{ slot = 18, token = "RangedSlot", label = "Ranged", x = 160, y = -386 },
}

local UWU_CACHED_GEAR_STAT_KEYS = {
	hit = { "ITEM_MOD_HIT_RATING_SHORT" },
	spellHit = { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_SPELL_HIT_RATING_SHORT" },
	expertise = { "ITEM_MOD_EXPERTISE_RATING_SHORT" },
	armorPen = { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
	defense = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
}

local UWU_CACHED_GEAR_ENCHANT_STATS = {
	[1951] = { defense = 16 },
	[1952] = { defense = 20 },
	[1953] = { defense = 22 },
	[2523] = { hit = UWU_LEVEL_80_HIT_RATING_PER_PERCENT * 3 },
	[2583] = { defense = UWU_LEVEL_80_DEFENSE_RATING_PER_SKILL * 7 },
	[2584] = { defense = UWU_LEVEL_80_DEFENSE_RATING_PER_SKILL * 7 },
	[2586] = { hit = UWU_LEVEL_80_HIT_RATING_PER_PERCENT },
	[2588] = { spellHit = UWU_LEVEL_80_HIT_RATING_PER_PERCENT },
	[2648] = { defense = 12 },
	[3027] = { armorPen = 3 },
	[3028] = { armorPen = 5 },
	[3029] = { armorPen = 7 },
	[3030] = { armorPen = 9 },
	[3031] = { armorPen = 10 },
	[3032] = { armorPen = 12 },
	[3033] = { armorPen = 15 },
	[3034] = { armorPen = 20 },
	[3035] = { armorPen = 25 },
	[3036] = { armorPen = 30 },
	[3037] = { armorPen = 35 },
	[3038] = { armorPen = 40 },
	[3039] = { armorPen = 50 },
	[3040] = { armorPen = 75 },
	[3041] = { armorPen = 100 },
	[3042] = { armorPen = 150 },
	[3043] = { armorPen = 200 },
	[3044] = { armorPen = 25 },
	[3051] = { armorPen = 25 },
	[3231] = { expertise = 15 },
	[3234] = { hit = 20, spellHit = 20 },
	[3731] = { hit = 28, spellHit = 28 },
	[3788] = { hit = 25, spellHit = 25 },
	[3811] = { defense = 15 },
	[3826] = { hit = 12, spellHit = 12 },
	[3837] = { defense = 15 },
	[3847] = { defense = UWU_LEVEL_80_DEFENSE_RATING_PER_SKILL * 25 },
	[3883] = { defense = UWU_LEVEL_80_DEFENSE_RATING_PER_SKILL * 13 },
}
local UWU_SPEC_ICON_FALLBACKS = {
	[0] = { [1] = "Interface\\Icons\\Spell_Deathknight_BloodPresence", [2] = "Interface\\Icons\\Spell_Deathknight_FrostPresence", [3] = "Interface\\Icons\\Spell_Deathknight_UnholyPresence" },
	[1] = { [1] = "Interface\\Icons\\Spell_Nature_StarFall", [2] = "Interface\\Icons\\Ability_Racial_BearForm", [3] = "Interface\\Icons\\Spell_Nature_HealingTouch" },
	[2] = { [1] = "Interface\\Icons\\Ability_Hunter_BeastTaming", [2] = "Interface\\Icons\\Ability_Marksmanship", [3] = "Interface\\Icons\\Ability_Hunter_SwiftStrike" },
	[3] = { [1] = "Interface\\Icons\\Spell_Holy_MagicalSentry", [2] = "Interface\\Icons\\Spell_Fire_FireBolt02", [3] = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
	[4] = { [1] = "Interface\\Icons\\Spell_Holy_HolyBolt", [2] = "Interface\\Icons\\Spell_Holy_DevotionAura", [3] = "Interface\\Icons\\Spell_Holy_AuraOfLight" },
	[5] = { [1] = "Interface\\Icons\\Spell_Holy_WordFortitude", [2] = "Interface\\Icons\\Spell_Holy_HolyBolt", [3] = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
	[6] = { [1] = "Interface\\Icons\\Ability_Rogue_Eviscerate", [2] = "Interface\\Icons\\Ability_BackStab", [3] = "Interface\\Icons\\Ability_Stealth" },
	[7] = { [1] = "Interface\\Icons\\Spell_Nature_Lightning", [2] = "Interface\\Icons\\Spell_Nature_LightningShield", [3] = "Interface\\Icons\\Spell_Nature_MagicImmunity" },
	[8] = { [1] = "Interface\\Icons\\Spell_Shadow_DeathCoil", [2] = "Interface\\Icons\\Spell_Shadow_Metamorphosis", [3] = "Interface\\Icons\\Spell_Shadow_RainOfFire" },
	[9] = { [1] = "Interface\\Icons\\Ability_Warrior_SavageBlow", [2] = "Interface\\Icons\\Ability_Warrior_InnerRage", [3] = "Interface\\Icons\\INV_Shield_06" },
}

local UWU_BOSS_RAID_OVERRIDES = {
	["Archavon the Stone Watcher"] = "Vault of Archavon",
	["Emalon the Storm Watcher"] = "Vault of Archavon",
	["Koralon the Flame Watcher"] = "Vault of Archavon",
	["Toravon the Ice Watcher"] = "Vault of Archavon",
	["Northrend Beasts"] = "Trial of the Grand Crusader",
	["Lord Jaraxxus"] = "Trial of the Grand Crusader",
	["Faction Champions"] = "Trial of the Grand Crusader",
	["Twin Val'kyr"] = "Trial of the Grand Crusader",
	["Anub'arak"] = "Trial of the Grand Crusader",
	["Onyxia"] = "Onyxia's Lair",
	["Onyxia the Broodmother"] = "Onyxia's Lair",
	["Lord Marrowgar"] = "Icecrown Citadel",
	["Lady Deathwhisper"] = "Icecrown Citadel",
	["Gunship Battle"] = "Icecrown Citadel",
	["Deathbringer Saurfang"] = "Icecrown Citadel",
	["Festergut"] = "Icecrown Citadel",
	["Rotface"] = "Icecrown Citadel",
	["Professor Putricide"] = "Icecrown Citadel",
	["Blood Prince Council"] = "Icecrown Citadel",
	["Blood-Queen Lana'thel"] = "Icecrown Citadel",
	["Blood Queen Lana'thel"] = "Icecrown Citadel",
	["Valithria Dreamwalker"] = "Icecrown Citadel",
	["Sindragosa"] = "Icecrown Citadel",
	["The Lich King"] = "Icecrown Citadel",
	["Halion"] = "Ruby Sanctum",
}

local UWU_BOSS_SHORT_NAMES = {
	["Ignis the Furnace Master"] = "Ignis",
	["XT-002 Deconstructor"] = "XT-002",
	["Assembly of Iron"] = "Assembly",
	["General Vezax"] = "Vezax",
	["Algalon the Observer"] = "Algalon",
	["Emalon the Storm Watcher"] = "Emalon",
	["Koralon the Flame Watcher"] = "Koralon",
	["Northrend Beasts"] = "Beasts",
	["Faction Champions"] = "Champions",
	["Twin Val'kyr"] = "Twin Val'kyr",
	["Onyxia the Broodmother"] = "Onyxia",
	["Lord Marrowgar"] = "Marrowgar",
	["Lady Deathwhisper"] = "Deathwhisper",
	["Deathbringer Saurfang"] = "Saurfang",
	["Professor Putricide"] = "Putricide",
	["Blood Prince Council"] = "Blood Council",
	["Blood-Queen Lana'thel"] = "Lana'thel",
	["Blood Queen Lana'thel"] = "Lana'thel",
	["Valithria Dreamwalker"] = "Dreamwalker",
	["Toravon the Ice Watcher"] = "Toravon",
}

local UWU_HARD_MODE_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"
local UWU_HARD_MODE_FALLBACK = " (HC)"

local UWU_HARD_MODE_BOSSES = {
	["XT-002 Deconstructor"] = true,
	["Assembly of Iron"] = true,
	["Hodir"] = true,
	["Thorim"] = true,
	["Freya"] = true,
	["Mimiron"] = true,
	["General Vezax"] = true,
	["Yogg-Saron"] = true,
	["Northrend Beasts"] = true,
	["Lord Jaraxxus"] = true,
	["Faction Champions"] = true,
	["Twin Val'kyr"] = true,
	["Anub'arak"] = true,
}

local UWU_LOG_PROGRESS_PHASES = {
	ulduar = {
		hardLabel = "Ulduar 25H Logs",
		milestoneLabel = "A",
		milestoneBoss = "Algalon the Observer",
		hardBosses = {
			"XT-002 Deconstructor",
			"Assembly of Iron",
			"Hodir",
			"Thorim",
			"Freya",
			"Mimiron",
			"General Vezax",
			"Yogg-Saron",
		},
	},
	toc = {
		hardLabel = "TOGC 25H Logs",
		milestoneLabel = "AA",
		milestoneBoss = "Anub'arak",
		hardBosses = {
			"Northrend Beasts",
			"Lord Jaraxxus",
			"Faction Champions",
			"Twin Val'kyr",
			"Anub'arak",
		},
	},
	icc = {
		hardLabel = "ICC 25H Logs",
		milestoneLabel = "LOD",
		milestoneBoss = "The Lich King",
		hardBosses = {
			"Lord Marrowgar",
			"Lady Deathwhisper",
			"Deathbringer Saurfang",
			"Festergut",
			"Rotface",
			"Professor Putricide",
			"Blood Prince Council",
			"Blood-Queen Lana'thel",
			"Sindragosa",
			"The Lich King",
		},
	},
}

coolstats.UWU_BOSS_CHART_ABBREVIATIONS = {
	["Ignis the Furnace Master"] = "IG",
	["Razorscale"] = "RZ",
	["XT-002 Deconstructor"] = "XT",
	["Assembly of Iron"] = "IC",
	["Kologarn"] = "KO",
	["Auriaya"] = "AU",
	["Hodir"] = "HD",
	["Thorim"] = "TH",
	["Freya"] = "FR",
	["Mimiron"] = "MI",
	["General Vezax"] = "VX",
	["Yogg-Saron"] = "YS",
	["Algalon the Observer"] = "AL",
	["Northrend Beasts"] = "NB",
	["Lord Jaraxxus"] = "LJ",
	["Faction Champions"] = "FC",
	["Twin Val'kyr"] = "TV",
	["Anub'arak"] = "AA",
	["Lord Marrowgar"] = "LM",
	["Lady Deathwhisper"] = "LD",
	["Deathbringer Saurfang"] = "DS",
	["Festergut"] = "FG",
	["Rotface"] = "RF",
	["Professor Putricide"] = "PP",
	["Blood Prince Council"] = "BC",
	["Blood-Queen Lana'thel"] = "BQ",
	["Sindragosa"] = "SD",
	["The Lich King"] = "LK",
}

coolstats.UWU_ULDUAR_RAID_BOSSES = {
	["Ignis the Furnace Master"] = true,
	["Razorscale"] = true,
	["XT-002 Deconstructor"] = true,
	["Assembly of Iron"] = true,
	["Kologarn"] = true,
	["Auriaya"] = true,
	["Hodir"] = true,
	["Thorim"] = true,
	["Freya"] = true,
	["Mimiron"] = true,
	["General Vezax"] = true,
	["Yogg-Saron"] = true,
	["Algalon the Observer"] = true,
}

local raidProgressCache = {}
local pendingRaidProgress = nil
coolstats.raidProgressRequestState = {
	queued = nil,
	times = {},
	last = -100,
}
local tooltipAchievementComparisonOwned = false
local lastRaidProgressPruneAt = 0
local tooltipFrame = CreateFrame("Frame")
local inspectUwUPanel = nil
local lookupUwUPanel = nil
local GetUwUPlayerByName
local BuildUwURaidProgress
local RefreshTooltipForKey
local RefreshCurrentTooltip
local CacheRaidProgressFailure
local UpdateInspectUwUPanel
local RenderUwUPanel
local GetInspectUwUUnit
local tooltipRefreshFrame = CreateFrame("Frame")
local tooltipRefreshQueued = false
local lastTooltipAltState = false
local uwuTooltipCache = {}
local uwuBossIndexSource = nil
local uwuBossIndexByName = nil
local lastCachedGearPruneAt = 0
local pendingGearInspectName = nil
local pendingGearInspectGuid = nil

local function GetNowSeconds()
	if time then
		return time()
	end
	return math.floor(GetTime())
end

local function SetFrameSize(frame, width, height)
	if frame.SetSize then
		frame:SetSize(width, height)
	else
		frame:SetWidth(width)
		frame:SetHeight(height)
	end
end

function coolstats.RemoveManagedWindowSpecialFrame(frameName)
	if not frameName or not UISpecialFrames then
		return
	end
	for index = #UISpecialFrames, 1, -1 do
		if UISpecialFrames[index] == frameName then
			table.remove(UISpecialFrames, index)
		end
	end
end

function coolstats.GetTopManagedWindow()
	local stack = coolstats.managedWindowStack or {}
	for index = #stack, 1, -1 do
		local frame = stack[index]
		if frame and frame:IsShown() then
			return frame
		end
		table.remove(stack, index)
	end
	return nil
end

function coolstats.SyncManagedWindowEscapeHandler()
	local handler = coolstats.managedWindowEscapeHandler
	if not handler then
		return
	end
	if coolstats.GetTopManagedWindow() then
		handler:Show()
	elseif handler:IsShown() then
		handler.suppressManagedHide = true
		handler:Hide()
		handler.suppressManagedHide = nil
	end
end

function coolstats.EnsureManagedWindowEscapeHandler()
	if coolstats.managedWindowEscapeHandler then
		return coolstats.managedWindowEscapeHandler
	end
	local handler = CreateFrame("Frame", "coolstatsManagedWindowEscapeHandler", UIParent)
	coolstats.managedWindowEscapeHandler = handler
	handler:Hide()
	handler:SetScript("OnHide", function(self)
		if self.suppressManagedHide then
			return
		end
		local top = coolstats.GetTopManagedWindow()
		if top then
			top:Hide()
		end
		coolstats.SyncManagedWindowEscapeHandler()
	end)
	if UISpecialFrames then
		table.insert(UISpecialFrames, "coolstatsManagedWindowEscapeHandler")
	end
	return handler
end

function coolstats.TouchManagedWindow(frame)
	if not frame or not frame:IsShown() then
		return
	end
	local stack = coolstats.managedWindowStack or {}
	coolstats.managedWindowStack = stack
	for index = #stack, 1, -1 do
		if stack[index] == frame then
			table.remove(stack, index)
		end
	end
	stack[#stack + 1] = frame
	coolstats.managedWindowLevel = (coolstats.managedWindowLevel or 120) + 4
	if coolstats.managedWindowLevel > 800 then
		coolstats.managedWindowLevel = 124
	end
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(coolstats.managedWindowLevel)
	for _, button in ipairs(frame.specButtons or {}) do
		button:SetFrameLevel(frame:GetFrameLevel() + 7)
	end
	if frame.trees and frame.talentButtons then
		coolstats.SyncCachedTalentPanelFrameLevels(frame)
	end
	if frame.cachedGearPanel then
		frame.cachedGearPanel:SetFrameStrata("DIALOG")
		frame.cachedGearPanel:SetFrameLevel(frame:GetFrameLevel() + 1)
	end
	for index, child in ipairs(frame.coolstatsManagedChildren or {}) do
		child:SetFrameStrata("DIALOG")
		child:SetFrameLevel(frame:GetFrameLevel() + index)
		for _, button in ipairs(child.specButtons or {}) do
			button:SetFrameLevel(child:GetFrameLevel() + 7)
		end
	end
	coolstats.EnsureManagedWindowEscapeHandler()
	coolstats.SyncManagedWindowEscapeHandler()
end

function coolstats.RemoveManagedWindow(frame)
	local stack = coolstats.managedWindowStack or {}
	for index = #stack, 1, -1 do
		if stack[index] == frame then
			table.remove(stack, index)
		end
	end
	coolstats.SyncManagedWindowEscapeHandler()
end

function coolstats.RegisterManagedWindow(frame)
	if not frame or frame.coolstatsManagedWindow then
		return
	end
	frame.coolstatsManagedWindow = true
	coolstats.EnsureManagedWindowEscapeHandler()
	coolstats.RemoveManagedWindowSpecialFrame(frame:GetName())
	frame:HookScript("OnShow", function(self)
		coolstats.TouchManagedWindow(self)
	end)
	frame:HookScript("OnHide", function(self)
		coolstats.RemoveManagedWindow(self)
	end)
	frame:HookScript("OnMouseDown", function(self)
		coolstats.TouchManagedWindow(self)
	end)
end

function coolstats.TouchManagedWindowOwner(frame)
	if not frame then
		return
	end
	if frame.coolstatsManagedWindow then
		coolstats.TouchManagedWindow(frame)
	elseif frame.coolstatsManagedWindowOwner then
		coolstats.TouchManagedWindow(frame.coolstatsManagedWindowOwner)
	end
end

local function GetCurrentUwUPhase()
	local phaseId = (coolstats.GetActiveUwUPhaseId and coolstats.GetActiveUwUPhaseId()) or (coolstats.GetExpectedRealmPhaseId and coolstats.GetExpectedRealmPhaseId()) or CURRENT_UWU_PHASE_ID
	return UWU_RAID_PHASES[phaseId] or UWU_RAID_PHASES.ulduar
end

local function NormalizeName(name)
	name = string.lower(tostring(name or ""))
	name = string.gsub(name, "%s+", "")
	return name
end

function coolstats.NormalizeCachedPlayerRealmKey(realm)
	realm = string.lower(tostring(realm or ""))
	return string.gsub(realm, "[^%a%d]", "")
end

function coolstats.GetCurrentCachedPlayerRealmKey()
	local realmKey = coolstats.GetCurrentRealmKey and coolstats.GetCurrentRealmKey()
	realmKey = coolstats.NormalizeCachedPlayerRealmKey(realmKey or (GetRealmName and GetRealmName()) or "")
	if realmKey == "" then
		return "unknown"
	end
	return realmKey
end

function coolstats.GetCachedPlayerSnapshotRealmName(realm)
	if realm and realm ~= "" then
		return realm
	end
	return GetRealmName and GetRealmName() or ""
end

local function GetUnitCacheKey(unit)
	if UnitGUID then
		local guid = UnitGUID(unit)
		if guid then
			return guid
		end
	end

	local name, realm = UnitName(unit)
	if not name then
		return nil
	end
	if not realm or realm == "" then
		realm = GetRealmName and GetRealmName() or ""
	end
	return name .. "-" .. realm
end

local function GetUnitUwUKey(unit)
	local name = UnitName(unit)
	if not name then
		return nil
	end
	return NormalizeName(name)
end

local function IsCachedProgressUsable(progress)
	return progress and progress.expiresAt and progress.expiresAt > GetNowSeconds()
end

local function GetCacheLifetimeForProgress(progress)
	if progress.level and progress.level > 0 and progress.level < 80 then
		return RAID_PROGRESS_LOW_LEVEL_CACHE_SECONDS
	end
	if progress.status == "failed" then
		return RAID_PROGRESS_FAILED_CACHE_SECONDS
	end
	return RAID_PROGRESS_CACHE_SECONDS
end

function coolstats.GetTooltipFeatureOptions()
	if coolstats.GetTooltipOptions then
		return coolstats.GetTooltipOptions()
	end
	coolstatsDB = coolstatsDB or {}
	coolstatsDB.tooltip = coolstatsDB.tooltip or {}
	return coolstatsDB.tooltip
end

function coolstats.MergeCachedPlayerStoreRoots(target, source)
	if type(target) ~= "table" or type(source) ~= "table" or target == source then
		return target
	end
	target.realms = target.realms or {}
	for realmKey, sourceStore in pairs(source.realms or {}) do
		local targetStore = target.realms[realmKey] or { players = {}, order = {} }
		targetStore.players = targetStore.players or {}
		targetStore.order = targetStore.order or {}
		for key, snapshot in pairs(sourceStore.players or {}) do
			local existing = targetStore.players[key]
			if not existing or (tonumber(snapshot and snapshot.seenAt) or 0) >= (tonumber(existing and existing.seenAt) or 0) then
				targetStore.players[key] = snapshot
			end
		end
		local seen = {}
		local mergedOrder = {}
		for _, order in ipairs({ sourceStore.order or {}, targetStore.order or {} }) do
			for _, key in ipairs(order) do
				if key and targetStore.players[key] and not seen[key] then
					seen[key] = true
					mergedOrder[#mergedOrder + 1] = key
				end
			end
		end
		for key in pairs(targetStore.players) do
			if not seen[key] then
				mergedOrder[#mergedOrder + 1] = key
			end
		end
		targetStore.order = mergedOrder
		target.realms[realmKey] = targetStore
	end
	target.realmCacheVersion = math.max(tonumber(target.realmCacheVersion) or 0, tonumber(source.realmCacheVersion) or 0)
	return target
end

function coolstats.GetCacheDatabase()
	if type(coolstatsCacheDB) == "table" then
		return coolstatsCacheDB
	end
	if type(coolstatsDB) == "table" and (
		type(coolstatsDB.cachedInspectGear) == "table"
		or type(coolstatsDB.cachedInspectTalents) == "table"
		or type(coolstatsDB.cachedTalentCatalogs) == "table"
	) then
		return coolstatsDB
	end
	coolstats.runtimeCacheDB = coolstats.runtimeCacheDB or {}
	return coolstats.runtimeCacheDB
end

function coolstats.MigrateSplitCacheDatabase()
	if type(coolstatsCacheDB) ~= "table" or type(coolstatsDB) ~= "table" then
		return coolstats.GetCacheDatabase()
	end
	for _, field in ipairs({ "cachedInspectGear", "cachedInspectTalents" }) do
		local source = coolstatsDB[field]
		if type(source) == "table" then
			if type(coolstatsCacheDB[field]) ~= "table" then
				coolstatsCacheDB[field] = source
			else
				coolstats.MergeCachedPlayerStoreRoots(coolstatsCacheDB[field], source)
			end
			coolstatsDB[field] = nil
		end
	end
	if type(coolstatsDB.cachedTalentCatalogs) == "table" then
		coolstatsCacheDB.cachedTalentCatalogs = coolstatsCacheDB.cachedTalentCatalogs or { version = 2, classes = {} }
		coolstatsCacheDB.cachedTalentCatalogs.classes = coolstatsCacheDB.cachedTalentCatalogs.classes or {}
		for classFile, catalog in pairs(coolstatsDB.cachedTalentCatalogs.classes or {}) do
			if not coolstatsCacheDB.cachedTalentCatalogs.classes[classFile] then
				coolstatsCacheDB.cachedTalentCatalogs.classes[classFile] = catalog
			end
		end
		coolstatsCacheDB.cachedTalentCatalogs.version = math.max(tonumber(coolstatsCacheDB.cachedTalentCatalogs.version) or 0, tonumber(coolstatsDB.cachedTalentCatalogs.version) or 0)
		coolstatsDB.cachedTalentCatalogs = nil
	end
	coolstatsCacheDB.splitCacheVersion = 1
	return coolstatsCacheDB
end

local function EnsureTooltipDatabase()
	coolstatsDB = coolstatsDB or {}
	coolstatsDB.tooltip = coolstatsDB.tooltip or {}
	coolstatsDB.tooltip.raidProgress = nil
	local cacheDB = coolstats.MigrateSplitCacheDatabase()
	cacheDB.cachedInspectGear = cacheDB.cachedInspectGear or {}
	cacheDB.cachedInspectTalents = cacheDB.cachedInspectTalents or {}
	cacheDB.cachedTalentCatalogs = cacheDB.cachedTalentCatalogs or { version = 2, classes = {} }
	cacheDB.cachedTalentCatalogs.classes = cacheDB.cachedTalentCatalogs.classes or {}
	if coolstatsStaticTalentCatalogs and cacheDB.embeddedTalentCatalogVersion ~= 1 then
		for classFile in pairs(coolstatsStaticTalentCatalogs.classes or {}) do
			cacheDB.cachedTalentCatalogs.classes[classFile] = nil
		end
		cacheDB.embeddedTalentCatalogVersion = 1
	end
	coolstatsDB.cachedPlayerBrowserFavorites = coolstatsDB.cachedPlayerBrowserFavorites or {}
end

function coolstats.MigrateLegacyCachedPlayerRealmStore(root)
	root.realms = root.realms or {}
	if root.realmCacheVersion == 1 then
		return
	end

	local legacyPlayers = root.players
	local legacyOrder = root.order
	if type(legacyPlayers) == "table" or type(legacyOrder) == "table" then
		local target = root.realms.onyxia or { players = {}, order = {} }
		target.players = target.players or {}
		target.order = target.order or {}

		for key, snapshot in pairs(legacyPlayers or {}) do
			local existing = target.players[key]
			if not existing or (tonumber(snapshot and snapshot.seenAt) or 0) >= (tonumber(existing.seenAt) or 0) then
				target.players[key] = snapshot
			end
		end

		local seen = {}
		local mergedOrder = {}
		local function AppendOrder(order)
			for _, key in ipairs(order or {}) do
				if key and target.players[key] and not seen[key] then
					seen[key] = true
					mergedOrder[#mergedOrder + 1] = key
				end
			end
		end
		AppendOrder(legacyOrder)
		AppendOrder(target.order)
		for key in pairs(target.players) do
			if not seen[key] then
				mergedOrder[#mergedOrder + 1] = key
			end
		end
		target.order = mergedOrder
		root.realms.onyxia = target
	end

	root.players = nil
	root.order = nil
	root.realmCacheVersion = 1
end

function coolstats.GetCachedPlayerRealmStore(root)
	coolstats.MigrateLegacyCachedPlayerRealmStore(root)
	local realmKey = coolstats.GetCurrentCachedPlayerRealmKey()
	local store = root.realms[realmKey]
	if not store then
		store = { players = {}, order = {} }
		root.realms[realmKey] = store
	end
	store.players = store.players or {}
	store.order = store.order or {}
	return store
end

local function GetCachedGearStore()
	EnsureTooltipDatabase()
	return coolstats.GetCachedPlayerRealmStore(coolstats.GetCacheDatabase().cachedInspectGear)
end

function coolstats.GetCachedTalentStore()
	EnsureTooltipDatabase()
	return coolstats.GetCachedPlayerRealmStore(coolstats.GetCacheDatabase().cachedInspectTalents)
end

function coolstats.CachedTalentGroupMatchesClass(group, classFile)
	if not group or not classFile then
		return true
	end

	local expectedClass = string.lower(string.gsub(tostring(classFile), "[^%a]", ""))
	local sawBackground = false
	for _, tab in ipairs(group.tabs or {}) do
		local background = tab and tab.background
		if background and background ~= "" then
			sawBackground = true
			background = string.lower(string.gsub(tostring(background), "[^%a]", ""))
			if string.sub(background, 1, string.len(expectedClass)) ~= expectedClass then
				return false
			end
		end
	end
	return sawBackground
end

function coolstats.CachedTalentSnapshotMatchesClass(snapshot)
	if not snapshot or snapshot.missing then
		return true
	end

	local classFile = snapshot.classFile or UWU_CLASS_FILE_BY_INDEX[snapshot.classIndex]
	if not classFile then
		return false
	end
	if snapshot.talentVersion == 2 then
		local catalog = coolstats.GetCachedTalentCatalog(classFile)
		return catalog and catalog.classFile == classFile and type(snapshot.rankGroups) == "table" and #snapshot.rankGroups > 0
	end
	if not snapshot.groups or #snapshot.groups == 0 then
		return false
	end
	for _, group in ipairs(snapshot.groups) do
		if not coolstats.CachedTalentGroupMatchesClass(group, classFile) then
			return false
		end
	end
	return true
end

function coolstats.GetCachedTalentValue(talent, key, compactIndex)
	if not talent then
		return nil
	end
	if talent[key] ~= nil then
		return talent[key]
	end
	return talent[compactIndex]
end

function coolstats.GetCachedTalentCatalogStore()
	EnsureTooltipDatabase()
	return coolstats.GetCacheDatabase().cachedTalentCatalogs
end

function coolstats.GetCachedTalentCatalog(classFile)
	if not classFile then
		return nil
	end
	local store = coolstats.GetCachedTalentCatalogStore()
	local catalog = store and store.classes and store.classes[classFile]
	if catalog then
		return catalog
	end
	local staticStore = coolstatsStaticTalentCatalogs
	return staticStore and staticStore.classes and staticStore.classes[classFile] or nil
end

function coolstats.ExtractCachedTalentId(link)
	if not link then
		return nil
	end
	return tonumber(string.match(tostring(link), "talent:(%d+):"))
end

function coolstats.BuildCachedTalentLink(talentId, rank, talentName, fallbackLink)
	talentId = tonumber(talentId)
	if not talentId then
		return fallbackLink
	end
	rank = tonumber(rank) or 0
	return "|cff4e96f7|Htalent:" .. tostring(talentId) .. ":" .. tostring(rank > 0 and rank - 1 or -1) .. "|h[" .. tostring(talentName or "Talent") .. "]|h|r"
end

function coolstats.BuildCachedTalentCatalog(snapshot)
	if not snapshot or snapshot.missing or snapshot.talentVersion == 2 or type(snapshot.groups) ~= "table" then
		return nil
	end
	local classFile = snapshot.classFile or UWU_CLASS_FILE_BY_INDEX[snapshot.classIndex]
	if not classFile then
		return nil
	end
	local sourceGroup
	for _, group in ipairs(snapshot.groups) do
		if coolstats.CachedTalentGroupMatchesClass(group, classFile) then
			sourceGroup = group
			break
		end
	end
	if not sourceGroup or type(sourceGroup.tabs) ~= "table" or #sourceGroup.tabs == 0 then
		return nil
	end
	local catalog = {
		version = 2,
		classFile = classFile,
		tabs = {},
	}
	for tabIndex, tab in ipairs(sourceGroup.tabs) do
		local catalogTab = {
			name = tab.name,
			icon = tab.icon,
			background = tab.background,
			talents = {},
		}
		for talentIndex, talent in ipairs(tab.talents or {}) do
			local talentLink = coolstats.GetCachedTalentValue(talent, "link", 10)
			catalogTab.talents[talentIndex] = {
				coolstats.GetCachedTalentValue(talent, "name", 1),
				coolstats.GetCachedTalentValue(talent, "icon", 2),
				coolstats.GetCachedTalentValue(talent, "tier", 3),
				coolstats.GetCachedTalentValue(talent, "column", 4),
				coolstats.GetCachedTalentValue(talent, "maxRank", 6),
				coolstats.GetCachedTalentValue(talent, "exceptional", 7),
				coolstats.GetCachedTalentValue(talent, "prereqTier", 8),
				coolstats.GetCachedTalentValue(talent, "prereqColumn", 9),
				coolstats.ExtractCachedTalentId(talentLink),
				talentLink,
			}
		end
		catalog.tabs[tabIndex] = catalogTab
	end
	return catalog
end

function coolstats.CachedTalentCatalogMatchesSnapshot(catalog, snapshot)
	if not catalog or not snapshot or type(catalog.tabs) ~= "table" or type(snapshot.groups) ~= "table" then
		return false
	end
	local sourceGroup = snapshot.groups[1]
	if not sourceGroup or type(sourceGroup.tabs) ~= "table" or #sourceGroup.tabs ~= #catalog.tabs then
		return false
	end
	for tabIndex, catalogTab in ipairs(catalog.tabs) do
		local tab = sourceGroup.tabs[tabIndex]
		if not tab or #catalogTab.talents ~= #(tab.talents or {}) then
			return false
		end
		for talentIndex, catalogTalent in ipairs(catalogTab.talents) do
			local talent = tab.talents[talentIndex]
			if not talent
				or tostring(catalogTalent[1] or "") ~= tostring(coolstats.GetCachedTalentValue(talent, "name", 1) or "")
				or tonumber(catalogTalent[3]) ~= tonumber(coolstats.GetCachedTalentValue(talent, "tier", 3))
				or tonumber(catalogTalent[4]) ~= tonumber(coolstats.GetCachedTalentValue(talent, "column", 4))
				or tonumber(catalogTalent[5]) ~= tonumber(coolstats.GetCachedTalentValue(talent, "maxRank", 6))
			then
				return false
			end
		end
	end
	return true
end

function coolstats.EncodeCachedTalentGroupRanks(group, catalog)
	if not group or not catalog then
		return nil
	end
	local ranks = {}
	for tabIndex, catalogTab in ipairs(catalog.tabs or {}) do
		local tab = group.tabs and group.tabs[tabIndex]
		if not tab or #(tab.talents or {}) ~= #(catalogTab.talents or {}) then
			return nil
		end
		for talentIndex = 1, #catalogTab.talents do
			local rank = tonumber(coolstats.GetCachedTalentValue(tab.talents[talentIndex], "rank", 5)) or 0
			rank = math.max(0, math.min(9, math.floor(rank)))
			ranks[#ranks + 1] = tostring(rank)
		end
	end
	return table.concat(ranks)
end

function coolstats.NormalizeCachedTalentSnapshot(snapshot)
	if not snapshot or snapshot.missing or snapshot.talentVersion == 2 or type(snapshot.groups) ~= "table" then
		return snapshot
	end
	local classFile = snapshot.classFile or UWU_CLASS_FILE_BY_INDEX[snapshot.classIndex]
	if not classFile then
		return snapshot
	end
	for _, group in ipairs(snapshot.groups) do
		if not coolstats.CachedTalentGroupMatchesClass(group, classFile) then
			return snapshot
		end
	end
	local catalogStore = coolstats.GetCachedTalentCatalogStore()
	local catalog = coolstats.GetCachedTalentCatalog(classFile)
	if not catalog then
		catalog = coolstats.BuildCachedTalentCatalog(snapshot)
		if not catalog then
			return snapshot
		end
		catalogStore.classes[classFile] = catalog
	end
	if not coolstats.CachedTalentCatalogMatchesSnapshot(catalog, snapshot) then
		return snapshot
	end
	local rankGroups = {}
	for groupIndex, group in ipairs(snapshot.groups) do
		local ranks = coolstats.EncodeCachedTalentGroupRanks(group, catalog)
		if not ranks then
			return snapshot
		end
		rankGroups[groupIndex] = { tonumber(group.group) or groupIndex, ranks }
	end
	snapshot.talentVersion = 2
	snapshot.rankGroups = rankGroups
	snapshot.groups = nil
	snapshot.compactVersion = nil
	return snapshot
end

function coolstats.GetCachedTalentGroups(snapshot)
	if not snapshot then
		return nil
	end
	if snapshot.talentVersion ~= 2 then
		return snapshot.groups
	end
	local classFile = snapshot.classFile or UWU_CLASS_FILE_BY_INDEX[snapshot.classIndex]
	local catalog = coolstats.GetCachedTalentCatalog(classFile)
	if not catalog or type(snapshot.rankGroups) ~= "table" then
		return nil
	end
	local groups = {}
	for groupIndex, rankGroup in ipairs(snapshot.rankGroups) do
		local ranks = rankGroup[2] or ""
		local offset = 1
		local groupPoints = 0
		local tabs = {}
		for tabIndex, catalogTab in ipairs(catalog.tabs or {}) do
			local tabPoints = 0
			local talents = {}
			for talentIndex, catalogTalent in ipairs(catalogTab.talents or {}) do
				local rank = tonumber(string.sub(ranks, offset, offset)) or 0
				offset = offset + 1
				tabPoints = tabPoints + rank
				talents[talentIndex] = {
					catalogTalent[1],
					catalogTalent[2],
					catalogTalent[3],
					catalogTalent[4],
					rank,
					catalogTalent[5],
					catalogTalent[6],
					catalogTalent[7],
					catalogTalent[8],
					coolstats.BuildCachedTalentLink(catalogTalent[9], rank, catalogTalent[1], catalogTalent[10]),
				}
			end
			groupPoints = groupPoints + tabPoints
			tabs[tabIndex] = {
				name = catalogTab.name,
				icon = catalogTab.icon,
				points = tabPoints,
				background = catalogTab.background,
				talents = talents,
			}
		end
		groups[groupIndex] = {
			group = tonumber(rankGroup[1]) or groupIndex,
			active = groupIndex == (tonumber(snapshot.activeGroup) or 1),
			points = groupPoints,
			tabs = tabs,
		}
	end
	return groups
end

function coolstats.CompactCachedTalentSnapshot(snapshot)
	if not snapshot or snapshot.missing or snapshot.talentVersion == 2 or snapshot.compactVersion == 1 then
		return snapshot
	end
	for _, group in ipairs(snapshot.groups or {}) do
		for _, tab in ipairs(group.tabs or {}) do
			for index, talent in ipairs(tab.talents or {}) do
				if talent.name ~= nil then
					tab.talents[index] = {
						talent.name,
						talent.icon,
						talent.tier,
						talent.column,
						talent.rank,
						talent.maxRank,
						talent.exceptional or nil,
						talent.prereqTier,
						talent.prereqColumn,
						talent.link,
					}
				end
			end
		end
	end
	snapshot.compactVersion = 1
	return snapshot
end

local function PruneCachedGearCache(force)
	local now = GetNowSeconds()
	if not force and now - lastCachedGearPruneAt < RAID_PROGRESS_PRUNE_INTERVAL_SECONDS then
		return
	end
	lastCachedGearPruneAt = now

	local store = GetCachedGearStore()
	local players = store.players
	local order = store.order
	for index = #order, 1, -1 do
		local key = order[index]
		local snapshot = key and players[key]
		if not key or not snapshot or now - (tonumber(snapshot.seenAt) or 0) > coolstats.CACHE_LIMITS.maxAgeSeconds then
			if key then
				players[key] = nil
			end
			table.remove(order, index)
		end
	end
	while #order > coolstats.CACHE_LIMITS.gearPlayers do
		local staleKey = table.remove(order)
		if staleKey then
			players[staleKey] = nil
		end
	end
end

local function TouchCachedGearKey(store, key)
	if not store or not key then
		return
	end
	local order = store.order
	for index = #order, 1, -1 do
		if order[index] == key or not store.players[order[index]] then
			table.remove(order, index)
		end
	end
	table.insert(order, 1, key)
	while #order > coolstats.CACHE_LIMITS.gearPlayers do
		local staleKey = table.remove(order)
		if staleKey then
			store.players[staleKey] = nil
		end
	end
end

local function GetCachedGearKeyForName(name)
	local key = NormalizeName(name)
	if key == "" then
		return nil
	end
	return key
end

function coolstats.PruneCachedTalentCache(force)
	local now = GetNowSeconds()
	if not force and now - (coolstats.lastCachedTalentPruneAt or 0) < RAID_PROGRESS_PRUNE_INTERVAL_SECONDS then
		return
	end
	coolstats.lastCachedTalentPruneAt = now

	local store = coolstats.GetCachedTalentStore()
	local players = store.players
	local order = store.order
	for key, snapshot in pairs(players) do
		coolstats.CompactCachedTalentSnapshot(snapshot)
		coolstats.NormalizeCachedTalentSnapshot(snapshot)
		if not snapshot or not coolstats.CachedTalentSnapshotMatchesClass(snapshot) or now - (tonumber(snapshot.seenAt) or 0) > coolstats.CACHE_LIMITS.maxAgeSeconds then
			players[key] = nil
		end
	end
	for index = #order, 1, -1 do
		local key = order[index]
		local snapshot = key and players[key]
		if not key or not snapshot or now - (tonumber(snapshot.seenAt) or 0) > coolstats.CACHE_LIMITS.maxAgeSeconds then
			if key then
				players[key] = nil
			end
			table.remove(order, index)
		end
	end
	while #order > coolstats.CACHE_LIMITS.talentPlayers do
		local staleKey = table.remove(order)
		if staleKey then
			players[staleKey] = nil
		end
	end
end

function coolstats.TouchCachedTalentKey(store, key)
	if not store or not key then
		return
	end
	local order = store.order
	for index = #order, 1, -1 do
		if order[index] == key or not store.players[order[index]] then
			table.remove(order, index)
		end
	end
	table.insert(order, 1, key)
	while #order > coolstats.CACHE_LIMITS.talentPlayers do
		local staleKey = table.remove(order)
		if staleKey then
			store.players[staleKey] = nil
		end
	end
end

local function GetCachedGearSnapshot(name)
	local key = GetCachedGearKeyForName(name)
	local store = key and GetCachedGearStore()
	return store and store.players[key] or nil
end

function coolstats.GetCachedTalentSnapshot(name)
	local key = GetCachedGearKeyForName(name)
	local store = key and coolstats.GetCachedTalentStore()
	local snapshot = store and store.players[key] or nil
	coolstats.CompactCachedTalentSnapshot(snapshot)
	coolstats.NormalizeCachedTalentSnapshot(snapshot)
	if snapshot and not coolstats.CachedTalentSnapshotMatchesClass(snapshot) then
		store.players[key] = nil
		for index = #store.order, 1, -1 do
			if store.order[index] == key then
				table.remove(store.order, index)
			end
		end
		return nil
	end
	return snapshot
end

local function FormatCachedGearDateTime(seenAt)
	seenAt = tonumber(seenAt)
	if not seenAt or seenAt <= 0 then
		return "No cached gear"
	end
	if date then
		return "Cached " .. date("%m/%d %H:%M", seenAt)
	end
	return "Cached " .. tostring(seenAt)
end

local function GetClassFileForSnapshot(snapshot, player)
	if snapshot and snapshot.classFile then
		return snapshot.classFile
	end
	local classIndex = snapshot and snapshot.classIndex or player and player[3]
	return UWU_CLASS_FILE_BY_INDEX[classIndex]
end

local function GetItemIDFromLink(link)
	if not link then
		return nil
	end
	local itemID = string.match(link, "item:(%-?%d+)")
	return itemID and tonumber(itemID) or nil
end

local function GetEnchantIDFromLink(link)
	if not link then
		return nil
	end
	local enchantID = string.match(link, "item:%-?%d+:(%-?%d*)")
	enchantID = enchantID and tonumber(enchantID) or nil
	if enchantID and enchantID > 0 then
		return enchantID
	end
	return nil
end

local function AddItemStatsToSummary(summary, itemStats)
	if not itemStats then
		return
	end
	for summaryKey, statKeys in pairs(UWU_CACHED_GEAR_STAT_KEYS) do
		for index = 1, #statKeys do
			summary[summaryKey] = (summary[summaryKey] or 0) + (tonumber(itemStats[statKeys[index]]) or 0)
		end
	end
end

local function AddEnchantStatsToSummary(summary, enchantID)
	local enchantStats = enchantID and UWU_CACHED_GEAR_ENCHANT_STATS[enchantID]
	if not enchantStats then
		return
	end
	for summaryKey, value in pairs(enchantStats) do
		summary[summaryKey] = (summary[summaryKey] or 0) + (tonumber(value) or 0)
	end
end

local function BuildCachedGearStatSummary(snapshot)
	local summary = {
		hit = 0,
		spellHit = 0,
		expertise = 0,
		armorPen = 0,
		defense = 0,
		gearScore = 0,
		itemLevelTotal = 0,
		itemLevelCount = 0,
	}
	if not snapshot or type(snapshot.slots) ~= "table" then
		return summary
	end

	local slots = snapshot.slots
	local classFile = snapshot.classFile or UWU_CLASS_FILE_BY_INDEX[snapshot.classIndex]
	local titanGrip = 1
	if GetItemInfo and slots[16] and slots[16].link and slots[17] and slots[17].link then
		local _, _, _, _, _, _, _, _, mainEquipLoc = GetItemInfo(slots[16].link)
		if mainEquipLoc == "INVTYPE_2HWEAPON" then
			titanGrip = 0.5
		end
	end
	if GetItemInfo and slots[17] and slots[17].link then
		local _, _, _, _, _, _, _, _, offEquipLoc = GetItemInfo(slots[17].link)
		if offEquipLoc == "INVTYPE_2HWEAPON" then
			titanGrip = 0.5
		end
	end

	local function RefreshCachedItem(item)
		if item and item.link then
			if coolstats and coolstats.GetItemScore then
				local score, displayItemLevel, _, red, green, blue = coolstats.GetItemScore(item.link)
				if score then
					item.score = score
				end
				if displayItemLevel and displayItemLevel > 0 then
					item.itemLevel = displayItemLevel
				end
				item.red = red
				item.green = green
				item.blue = blue
			end
			if GetItemInfo then
				local _, _, quality, itemLevel, _, _, _, _, _, texture = GetItemInfo(item.link)
				if quality then
					item.quality = quality
				end
				if itemLevel and itemLevel > 0 and not item.itemLevel then
					item.itemLevel = itemLevel
				end
				if texture then
					item.texture = texture
				end
			end
			if GetItemStats then
				AddItemStatsToSummary(summary, GetItemStats(item.link))
			end
			AddEnchantStatsToSummary(summary, GetEnchantIDFromLink(item.link))
		end
	end

	for _, item in pairs(slots) do
		RefreshCachedItem(item)
	end

	local function AddScoredSlot(slot, multiplier)
		local item = slots[slot]
		if item and item.score then
			local score = item.score * (multiplier or 1)
			summary.gearScore = summary.gearScore + score
			if item.itemLevel and item.itemLevel > 0 then
				summary.itemLevelTotal = summary.itemLevelTotal + item.itemLevel
				summary.itemLevelCount = summary.itemLevelCount + 1
			end
		end
	end

	if slots[17] then
		AddScoredSlot(17, (classFile == "HUNTER" and 0.3164 or 1) * titanGrip)
	end
	for slot = 1, 18 do
		if slot ~= 4 and slot ~= 17 then
			local multiplier = 1
			if slot == 16 then
				multiplier = titanGrip
				if classFile == "HUNTER" then
					multiplier = multiplier * 0.3164
				end
			elseif slot == 18 and classFile == "HUNTER" then
				multiplier = 5.3224
			end
			AddScoredSlot(slot, multiplier)
		end
	end

	summary.gearScore = math.ceil(summary.gearScore)
	if summary.itemLevelCount > 0 then
		summary.averageItemLevel = summary.itemLevelTotal / summary.itemLevelCount
	end
	snapshot.stats = summary
	return summary
end

local function FormatCachedInteger(value)
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function FormatCachedRatingPercent(rating, ratingPerPercent)
	rating = tonumber(rating) or 0
	if rating <= 0 then
		return "-"
	end
	return FormatCachedInteger(rating) .. " (" .. string.format("%.2f%%", rating / ratingPerPercent) .. ")"
end

local function FormatCachedExpertise(rating)
	rating = tonumber(rating) or 0
	if rating <= 0 then
		return "-"
	end
	local expertise = rating / UWU_LEVEL_80_EXPERTISE_RATING_PER_POINT
	return FormatCachedInteger(expertise) .. " (" .. string.format("%.2f%%", expertise * 0.25) .. ")"
end

local function FormatCachedDefense(rating)
	rating = tonumber(rating) or 0
	local defenseSkill = rating / UWU_LEVEL_80_DEFENSE_RATING_PER_SKILL
	local total = UWU_LEVEL_80_BASE_DEFENSE_SKILL + defenseSkill
	if rating <= 0 then
		return tostring(UWU_LEVEL_80_BASE_DEFENSE_SKILL)
	end
	return FormatCachedInteger(total) .. " (+" .. FormatCachedInteger(defenseSkill) .. ")"
end

function coolstats.GetTalentGroupCount(isInspect)
	if GetNumTalentGroups then
		local ok, count = pcall(GetNumTalentGroups, isInspect, false)
		if ok and tonumber(count) and tonumber(count) > 0 then
			return math.min(2, tonumber(count))
		end
	end
	return 2
end

function coolstats.GetActiveCachedTalentGroup(isInspect)
	if GetActiveTalentGroup then
		local ok, activeGroup = pcall(GetActiveTalentGroup, isInspect, false)
		if ok and tonumber(activeGroup) and tonumber(activeGroup) > 0 then
			return tonumber(activeGroup)
		end
	end
	if isInspect and InspectTalentFrame and InspectTalentFrame.talentGroup then
		return InspectTalentFrame.talentGroup
	end
	return 1
end

function coolstats.GetCachedTalentTabInfo(tabIndex, isInspect, talentGroup)
	if not GetTalentTabInfo then
		return nil
	end
	local ok, name, icon, pointsSpent, background = pcall(GetTalentTabInfo, tabIndex, isInspect, false, talentGroup)
	if ok and name then
		return name, icon, pointsSpent, background
	end
	ok, name, icon, pointsSpent, background = pcall(GetTalentTabInfo, tabIndex, isInspect, false)
	if ok then
		return name, icon, pointsSpent, background
	end
	return nil
end

function coolstats.GetCachedTalentCount(tabIndex, isInspect, talentGroup)
	if not GetNumTalents then
		return 0
	end
	local ok, count = pcall(GetNumTalents, tabIndex, isInspect, false, talentGroup)
	if ok and tonumber(count) then
		return tonumber(count)
	end
	ok, count = pcall(GetNumTalents, tabIndex, isInspect, false)
	if ok and tonumber(count) then
		return tonumber(count)
	end
	return 0
end

function coolstats.GetCachedTalentInfo(tabIndex, talentIndex, isInspect, talentGroup)
	if not GetTalentInfo then
		return nil
	end
	local ok, name, icon, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = pcall(GetTalentInfo, tabIndex, talentIndex, isInspect, false, talentGroup)
	if ok and name then
		return name, icon, tier, column, currentRank, maxRank, isExceptional, meetsPrereq
	end
	ok, name, icon, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = pcall(GetTalentInfo, tabIndex, talentIndex, isInspect, false)
	if ok then
		return name, icon, tier, column, currentRank, maxRank, isExceptional, meetsPrereq
	end
	return nil
end

function coolstats.GetCachedTalentLink(tabIndex, talentIndex, isInspect, talentGroup)
	if not GetTalentLink then
		return nil
	end
	local ok, link = pcall(GetTalentLink, tabIndex, talentIndex, isInspect, false, talentGroup)
	if ok and link then
		return link
	end
	ok, link = pcall(GetTalentLink, tabIndex, talentIndex, isInspect, false)
	if ok then
		return link
	end
	return nil
end

function coolstats.GetCachedTalentPrereq(tabIndex, talentIndex, isInspect, talentGroup)
	if not GetTalentPrereqs then
		return nil
	end
	local ok, tier, column, isLearnable = pcall(GetTalentPrereqs, tabIndex, talentIndex, isInspect, false, talentGroup)
	if ok and tonumber(tier) and tonumber(column) then
		return tonumber(tier), tonumber(column), isLearnable
	end
	ok, tier, column, isLearnable = pcall(GetTalentPrereqs, tabIndex, talentIndex, isInspect, false)
	if ok and tonumber(tier) and tonumber(column) then
		return tonumber(tier), tonumber(column), isLearnable
	end
	return nil
end

function coolstats.CacheInspectTalentsForUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil
	end
	if not GetTalentTabInfo or not GetTalentInfo then
		return nil
	end

	local name, realm = UnitName(unit)
	if not name then
		return nil
	end
	local key = GetCachedGearKeyForName(name)
	if not key then
		return nil
	end

	local _, classFile = UnitClass(unit)
	local player = GetUwUPlayerByName and GetUwUPlayerByName(name)
	local isInspect = not (UnitIsUnit and UnitIsUnit(unit, "player"))
	local activeGroup = coolstats.GetActiveCachedTalentGroup(isInspect)
	local groupCount = coolstats.GetTalentGroupCount(isInspect)
	local groups = {}
	local totalRankedTalents = 0

	for groupIndex = 1, groupCount do
		local tabs = {}
		local totalPoints = 0
		local rankedTalents = 0
		for tabIndex = 1, 3 do
			local tabName, tabIcon, pointsSpent, background = coolstats.GetCachedTalentTabInfo(tabIndex, isInspect, groupIndex)
			if tabName then
				pointsSpent = tonumber(pointsSpent) or 0
				totalPoints = totalPoints + pointsSpent
				local talents = {}
				local talentCount = coolstats.GetCachedTalentCount(tabIndex, isInspect, groupIndex)
				for talentIndex = 1, talentCount do
					local talentName, talentIcon, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = coolstats.GetCachedTalentInfo(tabIndex, talentIndex, isInspect, groupIndex)
					currentRank = tonumber(currentRank) or 0
					maxRank = tonumber(maxRank) or 0
					if talentName then
						local prereqTier, prereqColumn, prereqMet = coolstats.GetCachedTalentPrereq(tabIndex, talentIndex, isInspect, groupIndex)
						local talentLink = coolstats.GetCachedTalentLink(tabIndex, talentIndex, isInspect, groupIndex)
						rankedTalents = rankedTalents + 1
						talents[#talents + 1] = {
							talentName,
							talentIcon,
							tonumber(tier) or 1,
							tonumber(column) or 1,
							currentRank,
							maxRank,
							isExceptional and true or nil,
							prereqTier,
							prereqColumn,
							talentLink,
						}
					end
				end
				tabs[#tabs + 1] = {
					name = tabName,
					icon = tabIcon,
					points = pointsSpent,
					background = background,
					talents = talents,
				}
			end
		end
		if rankedTalents > 0 or totalPoints > 0 then
			local group = {
				group = groupIndex,
				active = groupIndex == activeGroup,
				points = totalPoints,
				tabs = tabs,
			}
			if coolstats.CachedTalentGroupMatchesClass(group, classFile) then
				totalRankedTalents = totalRankedTalents + rankedTalents
				groups[#groups + 1] = group
			end
		end
	end

	if #groups == 0 then
		return nil, false
	end

	local activeGroupIndex = 1
	for groupIndex = 1, #groups do
		groups[groupIndex].active = groups[groupIndex].group == activeGroup
		if groups[groupIndex].active then
			activeGroupIndex = groupIndex
		end
	end

	local store = coolstats.GetCachedTalentStore()
	local snapshot = {
		name = name,
		realm = coolstats.GetCachedPlayerSnapshotRealmName(realm),
		classFile = classFile,
		classIndex = classFile and UWU_CLASS_INDEX_BY_FILE[classFile] or player and player[3],
		level = UnitLevel(unit),
		seenAt = GetNowSeconds(),
		activeGroup = activeGroupIndex,
		groups = groups,
		compactVersion = 1,
	}
	if not coolstats.CachedTalentSnapshotMatchesClass(snapshot) then
		return nil, false
	end
	coolstats.NormalizeCachedTalentSnapshot(snapshot)
	store.players[key] = snapshot
	coolstats.TouchCachedTalentKey(store, key)
	coolstats.PruneCachedTalentCache(false)
	return snapshot, #groups >= groupCount
end

local function CacheInspectGearForUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil
	end

	local name, realm = UnitName(unit)
	if not name then
		return nil
	end
	local key = GetCachedGearKeyForName(name)
	if not key then
		return nil
	end

	local _, classFile = UnitClass(unit)
	local player = GetUwUPlayerByName and GetUwUPlayerByName(name)
	local slots = {}
	local slotCount = 0
	for index = 1, #UWU_CACHED_GEAR_SLOTS do
		local slot = UWU_CACHED_GEAR_SLOTS[index].slot
		local link = GetInventoryItemLink(unit, slot)
		if link then
			slotCount = slotCount + 1
			slots[slot] = {
				link = link,
				itemID = GetItemIDFromLink(link),
				texture = GetInventoryItemTexture(unit, slot),
				quality = GetInventoryItemQuality and GetInventoryItemQuality(unit, slot) or nil,
			}
			if GetItemInfo then
				local _, _, quality, itemLevel, _, _, _, _, _, texture = GetItemInfo(link)
				slots[slot].quality = quality or slots[slot].quality
				slots[slot].itemLevel = itemLevel
				slots[slot].texture = texture or slots[slot].texture
			end
		end
	end

	if slotCount == 0 then
		return nil
	end

	local store = GetCachedGearStore()
	local snapshot = {
		name = name,
		realm = coolstats.GetCachedPlayerSnapshotRealmName(realm),
		classFile = classFile,
		classIndex = classFile and UWU_CLASS_INDEX_BY_FILE[classFile] or player and player[3],
		level = UnitLevel(unit),
		seenAt = GetNowSeconds(),
		slotCount = slotCount,
		slots = slots,
	}
	BuildCachedGearStatSummary(snapshot)
	store.players[key] = snapshot
	TouchCachedGearKey(store, key)
	PruneCachedGearCache(false)
	return snapshot
end

function coolstats.TrackInspectRequest(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end
	local name = UnitName(unit)
	pendingGearInspectName = name and GetCachedGearKeyForName(name) or nil
	pendingGearInspectGuid = UnitGUID and UnitGUID(unit) or nil
	coolstats.pendingTalentInspectName = pendingGearInspectName
	coolstats.pendingTalentInspectGuid = pendingGearInspectGuid
end

local function RequestGearInspectForUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return false
	end
	if not NotifyInspect or not CanInspect or not CanInspect(unit) then
		return false
	end
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		return false
	end

	coolstats.TrackInspectRequest(unit)
	NotifyInspect(unit)
	return true
end

if hooksecurefunc and NotifyInspect and not coolstats.inspectNotifyHooked then
	coolstats.inspectNotifyHooked = true
	hooksecurefunc("NotifyInspect", function(unit)
		coolstats.TrackInspectRequest(unit)
	end)
end

function coolstats.FindInspectReadyUnit(guid, nameKey)
	local function Matches(unit)
		if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
			return false
		end
		if guid and UnitGUID and UnitGUID(unit) ~= guid then
			return false
		end
		if nameKey and GetCachedGearKeyForName(UnitName(unit)) ~= nameKey then
			return false
		end
		return guid ~= nil or nameKey ~= nil
	end

	local inspectUnit = GetInspectUwUUnit and GetInspectUwUUnit()
	if Matches(inspectUnit) then
		return inspectUnit
	end
	for _, unit in ipairs({ "mouseover", "target", "focus", "player" }) do
		if Matches(unit) then
			return unit
		end
	end
	for index = 1, 4 do
		local unit = "party" .. index
		if Matches(unit) then
			return unit
		end
	end
	for index = 1, 40 do
		local unit = "raid" .. index
		if Matches(unit) then
			return unit
		end
	end
	return nil
end

function coolstats.UpdateVisibleCachedPlayerBrowserTalent(snapshot)
	local panel = coolstats.cachedPlayerBrowser
	if not snapshot or not panel or not panel:IsShown() or not panel.browserRows then
		return
	end
	local key = NormalizeName(snapshot.name)
	for _, row in ipairs(panel.browserRows) do
		if row.key == key then
			if not row.hasTalents and panel.browserCounts then
				panel.browserCounts.talents = (panel.browserCounts.talents or 0) + 1
			end
			row.hasTalents = true
			row.talentsSeenAt = snapshot.seenAt
			row.classFile = snapshot.classFile or row.classFile
			row.classIndex = row.classIndex or snapshot.classIndex
			if coolstats.PaintCachedPlayerBrowserRows then
				coolstats.PaintCachedPlayerBrowserRows()
			end
			return
		end
	end
end

function coolstats.CaptureReadyInspectTalents(guid, nameKey)
	local unit = coolstats.FindInspectReadyUnit(guid, nameKey)
	if not unit then
		return nil
	end
	local snapshot = coolstats.CacheInspectTalentsForUnit(unit)
	if snapshot then
		coolstats.UpdateVisibleCachedPlayerBrowserTalent(snapshot)
	end
	if snapshot and coolstats.pendingCachedTalentsOpenName and coolstats.GetCachedTalentSnapshot(coolstats.pendingCachedTalentsOpenName) then
		local pendingName = coolstats.pendingCachedTalentsOpenName
		coolstats.pendingCachedTalentsOpenName = nil
		coolstats.OpenCachedTalentsForName(pendingName)
	end
	coolstats.pendingTalentInspectGuid = nil
	coolstats.pendingTalentInspectName = nil
	return snapshot
end

local function TryCacheLookupGearFromUnit(unit, lookupKey)
	if not unit or not lookupKey or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil, false
	end
	local unitName = UnitName(unit)
	if GetCachedGearKeyForName(unitName) ~= lookupKey then
		return nil, false
	end

	local snapshot = CacheInspectGearForUnit(unit)
	local requested = RequestGearInspectForUnit(unit)
	return snapshot, requested
end

local function CacheGearForLookupName(name)
	local lookupKey = GetCachedGearKeyForName(name)
	if not lookupKey then
		return nil, false
	end

	local inspectUnit = GetInspectUwUUnit and GetInspectUwUUnit()
	local snapshot, requested = TryCacheLookupGearFromUnit(inspectUnit, lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = TryCacheLookupGearFromUnit("target", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = TryCacheLookupGearFromUnit("mouseover", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = TryCacheLookupGearFromUnit("focus", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	for index = 1, 4 do
		snapshot, requested = TryCacheLookupGearFromUnit("party" .. index, lookupKey)
		if snapshot or requested then
			return snapshot, requested
		end
	end
	for index = 1, 40 do
		snapshot, requested = TryCacheLookupGearFromUnit("raid" .. index, lookupKey)
		if snapshot or requested then
			return snapshot, requested
		end
	end

	return nil, false
end

function coolstats.TryCacheLookupTalentsFromUnit(unit, lookupKey)
	if not unit or not lookupKey or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil, false
	end
	local unitName = UnitName(unit)
	if GetCachedGearKeyForName(unitName) ~= lookupKey then
		return nil, false
	end

	if UnitIsUnit and UnitIsUnit(unit, "player") then
		return coolstats.CacheInspectTalentsForUnit(unit), false
	end
	return nil, RequestGearInspectForUnit(unit)
end

function coolstats.CacheTalentsForLookupName(name)
	local lookupKey = GetCachedGearKeyForName(name)
	if not lookupKey then
		return nil, false
	end
	local cached = coolstats.GetCachedTalentSnapshot(name)
	if cached then
		return cached, false
	end

	local inspectUnit = GetInspectUwUUnit and GetInspectUwUUnit()
	local snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit(inspectUnit, lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit("player", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit("target", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit("mouseover", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit("focus", lookupKey)
	if snapshot or requested then
		return snapshot, requested
	end
	for index = 1, 4 do
		snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit("party" .. index, lookupKey)
		if snapshot or requested then
			return snapshot, requested
		end
	end
	for index = 1, 40 do
		snapshot, requested = coolstats.TryCacheLookupTalentsFromUnit("raid" .. index, lookupKey)
		if snapshot or requested then
			return snapshot, requested
		end
	end

	return nil, false
end

local function CachedGearButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.link then
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Cached gear snapshot", 0.62, 0.62, 0.58, true)
	else
		GameTooltip:SetText(self.slotLabel or "Empty Slot", 1, 0.82, 0.16)
		GameTooltip:AddLine("No cached item for this slot.", 0.62, 0.62, 0.58, true)
	end
	GameTooltip:Show()
end

local function CachedGearButton_OnLeave()
	GameTooltip:Hide()
end

local function CachedGearInfo_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(self.tooltipTitle or "Cached Gear", 1, 0.82, 0.16)
	GameTooltip:AddLine("These values are gear-only estimates from cached item links.", 0.78, 0.78, 0.72, true)
	GameTooltip:AddLine("Gems and enchants are not reliably included.", 1.0, 0.45, 0.25, true)
	GameTooltip:Show()
end

local function CachedGearButton_OnClick(self)
	if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
		ChatEdit_InsertLink(self.link)
	end
end

function coolstats.IsAchievementComparisonUIVisible()
	if AchievementFrameComparison and AchievementFrameComparison.IsVisible and AchievementFrameComparison:IsVisible() then
		return true
	end
	if AchievementFrame and AchievementFrame.IsVisible and AchievementFrame:IsVisible() then
		if AchievementFrame.isComparison then
			return true
		end
		if AchievementFrameTab_OnClick and AchievementFrameComparisonTab_OnClick and AchievementFrameTab_OnClick == AchievementFrameComparisonTab_OnClick then
			return true
		end
	end
	return false
end

function coolstats.ClearTooltipAchievementComparison(force)
	if not tooltipAchievementComparisonOwned and not force then
		return
	end
	if coolstats.IsAchievementComparisonUIVisible() then
		tooltipAchievementComparisonOwned = false
		return
	end
	if ClearAchievementComparisonUnit then
		ClearAchievementComparisonUnit()
	end
	tooltipAchievementComparisonOwned = false
end

function coolstats.YieldTooltipAchievementComparisonToUI()
	if pendingRaidProgress then
		local interruptedKey = pendingRaidProgress.key
		pendingRaidProgress = nil
		if CacheRaidProgressFailure then
			CacheRaidProgressFailure(interruptedKey, true, "Achievement UI busy")
		end
	end
	coolstats.raidProgressRequestState.queued = nil
	tooltipAchievementComparisonOwned = false
	tooltipFrame:SetScript("OnUpdate", nil)
end

function coolstats.HookAchievementComparisonUI()
	if not AchievementFrameComparison or AchievementFrameComparison.__coolstatsComparisonGuardHooked then
		return
	end
	AchievementFrameComparison.__coolstatsComparisonGuardHooked = true
	AchievementFrameComparison:HookScript("OnShow", coolstats.YieldTooltipAchievementComparisonToUI)
end

local function ClearRaidProgressCacheForUnit(unit)
	local key = unit and GetUnitCacheKey(unit)
	if not key then
		return
	end
	raidProgressCache[key] = nil
	if pendingRaidProgress and pendingRaidProgress.key == key then
		pendingRaidProgress = nil
		coolstats.ClearTooltipAchievementComparison()
		if not coolstats.raidProgressRequestState.queued then
			tooltipFrame:SetScript("OnUpdate", nil)
		end
	end
	if coolstats.raidProgressRequestState.queued and coolstats.raidProgressRequestState.queued.key == key then
		coolstats.raidProgressRequestState.queued = nil
		if not pendingRaidProgress then
			tooltipFrame:SetScript("OnUpdate", nil)
		end
	end
end

local function PruneRaidProgressCache(force)
	local now = GetNowSeconds()
	if not force and now - lastRaidProgressPruneAt < RAID_PROGRESS_PRUNE_INTERVAL_SECONDS then
		return
	end

	lastRaidProgressPruneAt = now
	for key, progress in pairs(raidProgressCache) do
		local updatedAt = progress.updatedAt or 0
		local maxAge = GetCacheLifetimeForProgress(progress)
		if updatedAt <= 0 or now - updatedAt > maxAge then
			raidProgressCache[key] = nil
		end
	end
end

function coolstats.GetActiveUwUPhaseId()
	local currentRealmKey = coolstats.GetCurrentRealmKey and coolstats.GetCurrentRealmKey()
	local dataRealmKey = string.lower(string.gsub(tostring(coolstatsUwUData and coolstatsUwUData.realm or ""), "[^%a%d]", ""))
	if coolstatsUwUData and coolstatsUwUData.phaseId and (not currentRealmKey or currentRealmKey == "" or dataRealmKey == currentRealmKey) then
		return coolstatsUwUData.phaseId
	end
	return (coolstats.GetExpectedRealmPhaseId and coolstats.GetExpectedRealmPhaseId()) or CURRENT_UWU_PHASE_ID
end

local function GetCurrentRaid()
	local phaseId = coolstats.GetActiveUwUPhaseId() or CURRENT_RAID_ID
	return RAID_PROGRESS_DATA[phaseId]
end

local function IsAchievementComplete(achievementID, source)
	if source == "player" then
		if not GetAchievementInfo then
			return false
		end
		local _, _, _, completed = GetAchievementInfo(achievementID)
		return completed == true
	end

	if not GetAchievementComparisonInfo then
		return false
	end
	return GetAchievementComparisonInfo(achievementID) == true
end

function coolstats.IsRaidStatisticComplete(statisticID, source)
	local value
	if source == "player" then
		value = GetStatistic and GetStatistic(statisticID)
	else
		value = GetComparisonStatistic and GetComparisonStatistic(statisticID)
	end
	return (tonumber(value) or 0) > 0
end

local function CountHardModeProgress(raid, source)
	local count = 0
	for _, hardMode in ipairs(raid.hardModes) do
		local completed = false
		for _, achievementID in ipairs(hardMode.ids or {}) do
			if IsAchievementComplete(achievementID, source) then
				completed = true
				break
			end
		end
		if not completed then
			for _, statisticID in ipairs(hardMode.statisticIds or {}) do
				if coolstats.IsRaidStatisticComplete(statisticID, source) then
					completed = true
					break
				end
			end
		end
		if completed then
			count = count + 1
		end
	end
	return count
end

local function HasAchievementProgress(achievementIDs, source)
	if type(achievementIDs) ~= "table" then
		return false
	end
	for _, achievementID in ipairs(achievementIDs) do
		if IsAchievementComplete(achievementID, source) then
			return true
		end
	end
	return false
end

local function BuildRaidProgress(source, unit)
	local raid = GetCurrentRaid()
	if not raid then
		return nil
	end

	local now = GetNowSeconds()
	return {
		status = "ready",
		hardLabel = raid.hardLabel,
		hardCount = CountHardModeProgress(raid, source),
		hardTotal = raid.hardTotal,
		milestoneLabel = raid.milestoneLabel,
		milestoneComplete = HasAchievementProgress(raid.milestoneAchievementIds, source),
		level = unit and UnitLevel(unit) or nil,
		updatedAt = now,
		expiresAt = now + RAID_PROGRESS_CACHE_SECONDS,
	}
end

local function GetClassColor(unit)
	local _, classFile = UnitClass(unit)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if color then
		return color.r, color.g, color.b
	end
	return 1.0, 1.0, 1.0
end

local function AddClassLine(unit)
	local className = UnitClass(unit)
	if not className then
		return
	end
	local classR, classG, classB = GetClassColor(unit)
	GameTooltip:AddLine(className, classR, classG, classB)
end

local function GetReactionColor(unit)
	local reaction = UnitReaction(unit, "player")
	local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if color then
		return color.r, color.g, color.b
	end
	return 1.0, 1.0, 1.0
end

local function GetTargetText(unit)
	local name, realm = UnitName(unit)
	if not name then
		return nil
	end
	if realm and realm ~= "" then
		name = name .. "-" .. realm
	end

	if UnitIsPlayer(unit) then
		local level = UnitLevel(unit)
		local className = UnitClass(unit)
		if level and level > 0 and className then
			return string.format("%s (%d %s)", name, level, className)
		end
		if className then
			return string.format("%s (%s)", name, className)
		end
	end
	return name
end

local function GetGuildRankText(guildRankName, guildRankIndex)
	if guildRankName and guildRankName ~= "" and string.gsub(guildRankName, "%?", "") ~= "" then
		return guildRankName
	end
	if guildRankIndex == 0 then
		return "Guild Master"
	end
	if guildRankIndex then
		return "Rank " .. guildRankIndex
	end
	return nil
end

local function GetUnitGuildNameText(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or not GetGuildInfo then
		return nil
	end

	local guildName = GetGuildInfo(unit)
	if guildName and guildName ~= "" then
		return "<" .. guildName .. ">"
	end
	return nil
end

local function ApplyGuildRankLine(unit)
	if not GetGuildInfo then
		return
	end

	local guildName, guildRankName, guildRankIndex = GetGuildInfo(unit)
	if not guildName then
		return
	end

	local guildText = guildName
	local guildRankText = GetGuildRankText(guildRankName, guildRankIndex)
	if guildRankText then
		guildText = guildRankText .. " of " .. guildName
	end
	if GameTooltipTextLeft2 then
		GameTooltipTextLeft2:SetText(guildText)
	end
end

local function GetTooltipUnit()
	if GameTooltip.GetUnit then
		local _, unit = GameTooltip:GetUnit()
		if unit and UnitExists(unit) then
			return unit
		end
	end
	if UnitExists("mouseover") then
		return "mouseover"
	end
	return nil
end

RefreshTooltipForKey = function(key)
	local unit = GetTooltipUnit()
	if not unit or GetUnitCacheKey(unit) ~= key or not GameTooltip.SetUnit then
		return
	end
	GameTooltip:ClearLines()
	GameTooltip:SetUnit(unit)
end

local function QueueCurrentTooltipRefresh()
	if tooltipRefreshQueued then
		return
	end
	tooltipRefreshQueued = true
	tooltipRefreshFrame:SetScript("OnUpdate", function(self)
		tooltipRefreshQueued = false
		self:SetScript("OnUpdate", nil)
		if RefreshCurrentTooltip then
			RefreshCurrentTooltip()
		end
	end)
end

function coolstats.PruneRaidProgressRequestTimes(now)
	local state = coolstats.raidProgressRequestState
	local throttle = coolstats.RAID_PROGRESS_REQUEST_THROTTLE
	while state.times[1] and now - state.times[1] >= throttle.window do
		table.remove(state.times, 1)
	end
end

function coolstats.GetRaidProgressRequestDelay(now)
	now = tonumber(now) or GetTime()
	coolstats.PruneRaidProgressRequestTimes(now)
	local state = coolstats.raidProgressRequestState
	local throttle = coolstats.RAID_PROGRESS_REQUEST_THROTTLE
	local delay = math.max(0, (state.last + throttle.interval) - now)
	if #state.times >= throttle.limit then
		delay = math.max(delay, (state.times[1] + throttle.window) - now)
	end
	return delay
end

function coolstats.RecordRaidProgressRequest(now)
	now = tonumber(now) or GetTime()
	coolstats.PruneRaidProgressRequestTimes(now)
	local state = coolstats.raidProgressRequestState
	state.last = now
	table.insert(state.times, now)
end

function coolstats.ResetRaidProgressRequestThrottle()
	local state = coolstats.raidProgressRequestState
	state.times = {}
	state.last = -100
	state.queued = nil
end

function coolstats.QueueRaidProgressRequest(unit, key)
	local state = coolstats.raidProgressRequestState
	if state.queued and state.queued.key == key then
		return
	end
	state.queued = {
		key = key,
		unit = unit,
		queuedAt = GetTime(),
	}
	tooltipFrame:SetScript("OnUpdate", coolstats.RaidProgressFrame_OnUpdate)
end

function coolstats.StartQueuedRaidProgressRequest(request, now)
	local unit = request and request.unit
	local key = request and request.key
	if not unit or not key or not UnitExists(unit) or GetUnitCacheKey(unit) ~= key then
		return false
	end
	if UnitIsVisible and not UnitIsVisible(unit) then
		CacheRaidProgressFailure(key, true, "Move closer")
		return false
	end
	if CanInspect and not CanInspect(unit) then
		CacheRaidProgressFailure(key, true, "Move closer")
		return false
	end
	if coolstats.IsAchievementComparisonUIVisible() then
		CacheRaidProgressFailure(key, true, "Achievement UI busy")
		return false
	end

	coolstats.ClearTooltipAchievementComparison(true)
	local ok = pcall(SetAchievementComparisonUnit, unit)
	if not ok then
		CacheRaidProgressFailure(key, true, "Retry shortly")
		return false
	end

	coolstats.RecordRaidProgressRequest(now)
	tooltipAchievementComparisonOwned = true
	pendingRaidProgress = {
		key = key,
		unit = unit,
		requestedAt = now,
	}
	return true
end

function coolstats.RaidProgressFrame_OnUpdate(self)
	local now = GetTime()
	local state = coolstats.raidProgressRequestState
	if pendingRaidProgress and coolstats.IsAchievementComparisonUIVisible() then
		local interruptedKey = pendingRaidProgress.key
		pendingRaidProgress = nil
		tooltipAchievementComparisonOwned = false
		CacheRaidProgressFailure(interruptedKey, true, "Achievement UI busy")
	end
	if pendingRaidProgress and now - pendingRaidProgress.requestedAt >= RAID_PROGRESS_REQUEST_TIMEOUT_SECONDS then
		local failedKey = pendingRaidProgress.key
		pendingRaidProgress = nil
		coolstats.ClearTooltipAchievementComparison()
		CacheRaidProgressFailure(failedKey, true, "Retry shortly")
		RefreshTooltipForKey(failedKey)
	end

	if not pendingRaidProgress and state.queued then
		local currentUnit = GetTooltipUnit()
		if not currentUnit or GetUnitCacheKey(currentUnit) ~= state.queued.key then
			state.queued = nil
		elseif now - state.queued.queuedAt >= coolstats.RAID_PROGRESS_REQUEST_THROTTLE.dwell
			and coolstats.GetRaidProgressRequestDelay(now) <= 0
		then
			local request = state.queued
			state.queued = nil
			coolstats.StartQueuedRaidProgressRequest(request, now)
		end
	end

	if not pendingRaidProgress and not state.queued then
		self:SetScript("OnUpdate", nil)
	end
end

CacheRaidProgressFailure = function(key, shouldRetry, message)
	local now = GetNowSeconds()
	raidProgressCache[key] = {
		status = "failed",
		retry = shouldRetry == true,
		message = message,
		updatedAt = now,
		expiresAt = now + RAID_PROGRESS_FAILED_CACHE_SECONDS,
	}
end

local function CacheLowLevelProgress(unit, key)
	local now = GetNowSeconds()
	raidProgressCache[key] = {
		status = "skipped",
		level = UnitLevel(unit),
		updatedAt = now,
		expiresAt = now + RAID_PROGRESS_LOW_LEVEL_CACHE_SECONDS,
	}
end

local function RequestRaidProgress(unit, key)
	EnsureTooltipDatabase()
	if not key or IsCachedProgressUsable(raidProgressCache[key]) then
		return
	end
	if pendingRaidProgress and pendingRaidProgress.key == key then
		return
	end
	if coolstats.raidProgressRequestState.queued and coolstats.raidProgressRequestState.queued.key == key then
		return
	end

	local level = UnitLevel(unit)
	if level and level > 0 and level < 80 then
		CacheLowLevelProgress(unit, key)
		return
	end

	if UnitIsUnit and UnitIsUnit(unit, "player") then
		raidProgressCache[key] = BuildRaidProgress("player", unit)
		return
	end

	if not SetAchievementComparisonUnit then
		CacheRaidProgressFailure(key, false, "Unavailable")
		return
	end

	if UnitIsVisible and not UnitIsVisible(unit) then
		CacheRaidProgressFailure(key, true, "Move closer")
		return
	end

	if CanInspect and not CanInspect(unit) then
		CacheRaidProgressFailure(key, true, "Move closer")
		return
	end

	if coolstats.IsAchievementComparisonUIVisible() then
		CacheRaidProgressFailure(key, true, "Achievement UI busy")
		return
	end

	coolstats.QueueRaidProgressRequest(unit, key)
end

local function AddRaidProgressLines(unit)
	EnsureTooltipDatabase()
	PruneRaidProgressCache(false)

	local key = GetUnitCacheKey(unit)
	if not key then
		return false
	end

	local raid = GetCurrentRaid()
	local uwuProgress = BuildUwURaidProgress and BuildUwURaidProgress(unit)
	if uwuProgress and (uwuProgress.hasCurrentLogs or not raid) then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Raid Progress", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
		GameTooltip:AddDoubleLine(uwuProgress.hardLabel, coolstats.FormatRaidProgressText(uwuProgress), 1.0, 1.0, 1.0, 0.0, 1.0, 0.25)
		return true
	end
	if not raid then
		return false
	end

	local progress = raidProgressCache[key]
	if progress and not IsCachedProgressUsable(progress) then
		raidProgressCache[key] = nil
		progress = nil
	end

	if not progress then
		RequestRaidProgress(unit, key)
		progress = raidProgressCache[key]
	end

	if progress and progress.status == "skipped" then
		return false
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Raid Progress", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
	if progress and progress.status == "ready" then
		GameTooltip:AddDoubleLine(progress.hardLabel, coolstats.FormatRaidProgressText(progress), 1.0, 1.0, 1.0, 0.0, 1.0, 0.25)
	elseif progress and progress.status == "failed" then
		GameTooltip:AddDoubleLine(raid.hardLabel, progress.message or (progress.retry and "Retry shortly" or "Unavailable"), 1.0, 1.0, 1.0, 0.6, 0.6, 0.6)
	elseif coolstats.raidProgressRequestState.queued and coolstats.raidProgressRequestState.queued.key == key then
		GameTooltip:AddDoubleLine(raid.hardLabel, "Waiting...", 1.0, 1.0, 1.0, 0.6, 0.6, 0.6)
	else
		GameTooltip:AddDoubleLine(raid.hardLabel, "Loading...", 1.0, 1.0, 1.0, 0.6, 0.6, 0.6)
	end
	return true
end

local function GetUwUScoreColor(scoreCenti)
	scoreCenti = tonumber(scoreCenti or 0) or 0
	if scoreCenti >= 10000 then
		return 0.898, 0.800, 0.502
	elseif scoreCenti >= 9900 then
		return 0.886, 0.408, 0.659
	elseif scoreCenti >= 9500 then
		return 1.000, 0.502, 0.000
	elseif scoreCenti >= 9000 then
		return 1.000, 0.235, 0.000
	elseif scoreCenti >= 7500 then
		return 0.639, 0.208, 0.933
	elseif scoreCenti >= 5000 then
		return 0.000, 0.439, 1.000
	elseif scoreCenti >= 2500 then
		return 0.118, 1.000, 0.000
	end
	return 0.400, 0.400, 0.400
end

GetUwUPlayerByName = function(name)
	local data = coolstatsUwUData
	if not data or not data.players then
		return nil
	end
	return data.players[NormalizeName(name)]
end

local function FormatUwUScore(scoreCenti)
	return string.format("%.2f", (tonumber(scoreCenti or 0) or 0) / 100)
end

local function FormatUwUDps(dps)
	dps = tonumber(dps or 0) or 0
	if dps <= 0 then
		return "-"
	end
	if dps >= 10000 then
		return string.format("%.1fk", dps / 1000)
	end
	return tostring(math.floor(dps + 0.5))
end

local function FormatUwUScoreWithRank(scoreCenti, rank)
	local value = FormatUwUScore(scoreCenti)
	if rank then
		value = value .. " #" .. tostring(rank)
	end
	return value
end

local function GetUwUBossRaidName(bossName)
	local data = coolstatsUwUData
	if data and data.phaseId == "toc" and coolstats.UWU_ULDUAR_RAID_BOSSES[bossName] then
		return "Ulduar"
	end
	return UWU_BOSS_RAID_OVERRIDES[bossName] or (data and data.defaultRaidName) or "Ulduar"
end

-- Keep these helpers on the addon table: this chunk is at the Lua 5.1
-- compiler's 200-local limit on the 3.3.5 client.
function coolstats.IsUwUPlayerRankedForCurrentPhase(player)
	return player and player[11] ~= false
end

function coolstats.GetUwUHistoricalOverall(player)
	local historical = player and player[10]
	if type(historical) ~= "table" or historical[1] == nil then
		return nil, nil
	end
	return historical[1], historical[2]
end

function coolstats.GetUwUHistoricalOverallLabel()
	local data = coolstatsUwUData
	return (data and data.historicalOverallLabel) or "Phase 2 Overall"
end

function coolstats.FormatRaidProgressText(progress)
	local milestoneLabel = tostring(progress and progress.milestoneLabel or "")
	local milestoneText = progress and progress.milestoneComplete and "|cff20ff20" or "|cffff3030"
	milestoneText = milestoneText .. milestoneLabel .. "|r"
	if (tonumber(progress and progress.hardTotal) or 0) > 0 then
		local hardText = string.format("H %d/%d", progress.hardCount or 0, progress.hardTotal)
		return milestoneLabel ~= "" and (hardText .. "  " .. milestoneText) or hardText
	end
	return milestoneLabel ~= "" and milestoneText or ""
end

function coolstats.NormalizePlayerLogLinkName(name)
	name = tostring(name or "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	name = string.gsub(name, "[%c|:]", "")
	return string.sub(name, 1, 48)
end

function coolstats.BuildPlayerLogLink(name)
	name = coolstats.NormalizePlayerLogLinkName(name)
	if name == "" then
		return nil
	end
	return "|cff00c0ff|Hplayer:" .. name .. ":coolstatslogs|h[coolstats: " .. name .. "]|h|r"
end

function coolstats.BuildPlayerLogToken(name)
	name = coolstats.NormalizePlayerLogLinkName(name)
	if name == "" then
		return nil
	end
	return "[coolstats: " .. name .. "]"
end

function coolstats.InsertPlayerLogLink(name)
	local token = coolstats.BuildPlayerLogToken(name)
	if not token then
		return false
	end
	if ChatEdit_InsertLink and ChatEdit_InsertLink(token) then
		return true
	end
	if ChatFrame_OpenChat then
		ChatFrame_OpenChat(token, DEFAULT_CHAT_FRAME)
		return true
	end
	return false
end

function coolstats.GetPlayerNameFromLogLink(link)
	local name = string.match(tostring(link or ""), "^player:([^:]+):coolstatslogs$")
	name = coolstats.NormalizePlayerLogLinkName(name)
	return name ~= "" and name or nil
end

function coolstats.HandlePlayerLogLink(link)
	local name = coolstats.GetPlayerNameFromLogLink(link)
	if not name then
		return false
	end
	if IsModifiedClick and IsModifiedClick("CHATLINK") then
		coolstats.InsertPlayerLogLink(name)
	elseif coolstats.ShowUwULogsPanelForName then
		coolstats.ShowUwULogsPanelForName(name)
	end
	return true
end

function coolstats.InstallPlayerLogLinkHandler()
	if coolstats.playerLogLinkHandlerInstalled or type(SetItemRef) ~= "function" then
		return
	end
	coolstats.playerLogLinkHandlerInstalled = true
	coolstats.originalSetItemRef = SetItemRef
	SetItemRef = function(link, text, button, chatFrame)
		if coolstats.HandlePlayerLogLink(link) then
			return
		end
		return coolstats.originalSetItemRef(link, text, button, chatFrame)
	end
end

coolstats.PLAYER_LOG_CHAT_EVENTS = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_BATTLEGROUND",
	"CHAT_MSG_BATTLEGROUND_LEADER",
	"CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_BN_CONVERSATION",
}

function coolstats.LinkifyPlayerLogTokens(message)
	if type(message) ~= "string" or not string.find(message, "[coolstats:", 1, true) then
		return message
	end
	return (string.gsub(message, "%[coolstats:%s*([^%]]+)%]", function(name)
		return coolstats.BuildPlayerLogLink(name) or ("[coolstats: " .. tostring(name or "") .. "]")
	end))
end

function coolstats.PlayerLogChatFilter(frame, event, message, ...)
	return false, coolstats.LinkifyPlayerLogTokens(message), ...
end

function coolstats.InstallPlayerLogChatFilters()
	if coolstats.playerLogChatFiltersInstalled or not ChatFrame_AddMessageEventFilter then
		return
	end
	coolstats.playerLogChatFiltersInstalled = true
	for _, event in ipairs(coolstats.PLAYER_LOG_CHAT_EVENTS) do
		ChatFrame_AddMessageEventFilter(event, coolstats.PlayerLogChatFilter)
	end
end

local function GetUwUBossDisplayName(bossName)
	return UWU_BOSS_SHORT_NAMES[bossName] or bossName
end

local function GetUwUBossDisplayLabel(bossName)
	local label = GetUwUBossDisplayName(bossName)
	if UWU_HARD_MODE_BOSSES[bossName] then
		return label .. " " .. UWU_HARD_MODE_ICON
	end
	return label
end

local function GetUwUBossScoreCenti(bossData)
	if type(bossData) == "number" then
		return bossData
	end
	if type(bossData) == "table" then
		return bossData[1]
	end
	return nil
end

local function GetUwUBossIndexByName()
	local data = coolstatsUwUData
	if uwuBossIndexByName and uwuBossIndexSource == data then
		return uwuBossIndexByName
	end

	local indexes = {}
	if data and data.bosses then
		for bossIndex = 1, #data.bosses do
			local bossName = data.bosses[bossIndex]
			if bossName then
				indexes[bossName] = bossIndex
			end
		end
	end
	uwuBossIndexSource = data
	uwuBossIndexByName = indexes
	return indexes
end

local function HasUwUBossLog(player, bossIndex)
	if type(player) ~= "table" or not bossIndex then
		return false
	end

	local bestSpecBossData = player[8]
	if type(bestSpecBossData) == "table" and GetUwUBossScoreCenti(bestSpecBossData[bossIndex]) then
		return true
	end

	local bossDataBySpec = player[9]
	if type(bossDataBySpec) == "table" then
		for _, specBossData in pairs(bossDataBySpec) do
			if type(specBossData) == "table" and GetUwUBossScoreCenti(specBossData[bossIndex]) then
				return true
			end
		end
	end
	return false
end

BuildUwURaidProgress = function(unit)
	local phaseId = coolstats.GetActiveUwUPhaseId()
	local progressPhase = UWU_LOG_PROGRESS_PHASES[phaseId or CURRENT_UWU_PHASE_ID]
	if not progressPhase then
		return nil
	end
	local name = unit and UnitName(unit)
	local player = name and GetUwUPlayerByName and GetUwUPlayerByName(name)

	local indexes = GetUwUBossIndexByName()
	local hardCount = 0
	local hardTotal = 0
	for index = 1, #progressPhase.hardBosses do
		local bossIndex = indexes[progressPhase.hardBosses[index]]
		if bossIndex then
			hardTotal = hardTotal + 1
			if HasUwUBossLog(player, bossIndex) then
				hardCount = hardCount + 1
			end
		end
	end

	if hardTotal <= 0 then
		return nil
	end

	return {
		status = "ready",
		hardLabel = progressPhase.hardLabel,
		hardCount = hardCount,
		hardTotal = hardTotal,
		milestoneLabel = progressPhase.milestoneLabel,
		milestoneComplete = HasUwUBossLog(player, indexes[progressPhase.milestoneBoss]),
		level = unit and UnitLevel(unit) or nil,
		updatedAt = GetNowSeconds(),
		expiresAt = GetNowSeconds() + RAID_PROGRESS_CACHE_SECONDS,
		source = "uwu",
		hasCurrentLogs = hardCount > 0,
	}
end

local function GetUwUBossPlayerRank(bossData)
	if type(bossData) == "table" then
		return bossData[2]
	end
	return nil
end

local function GetUwUBossRaidRank(bossData)
	if type(bossData) == "table" then
		return bossData[3]
	end
	return nil
end

local function GetUwUBossDps(bossData)
	if type(bossData) == "table" then
		return bossData[4]
	end
	return nil
end

local function FormatUwUBossTooltipValue(bossData)
	local scoreCenti = GetUwUBossScoreCenti(bossData)
	if not scoreCenti then
		return "-"
	end
	return FormatUwUScore(scoreCenti)
end

local function FormatUwUBossPanelValue(bossData)
	local scoreCenti = GetUwUBossScoreCenti(bossData)
	if not scoreCenti then
		return "-"
	end

	local value = FormatUwUScore(scoreCenti)
	local playerRank = GetUwUBossPlayerRank(bossData)
	if playerRank then
		value = value .. " P" .. tostring(playerRank)
	end

	local raidRank = GetUwUBossRaidRank(bossData)
	if raidRank then
		value = value .. " R" .. tostring(raidRank)
	end

	local dps = GetUwUBossDps(bossData)
	if dps and tonumber(dps) and tonumber(dps) > 0 then
		value = value .. " " .. FormatUwUDps(dps)
	end
	return value
end

local function GetUwUSpecName(player, specIndex)
	local data = coolstatsUwUData
	if not data or not data.specs then
		return nil
	end

	local classIndex = player[3]
	specIndex = specIndex or player[4]
	local classSpecs = data.specs[classIndex]
	return classSpecs and classSpecs[specIndex] or nil
end

local function GetUwUSpecScoreCenti(player, specIndex)
	local specScores = player and player[6]
	if specScores and specIndex then
		return specScores[specIndex]
	end
	return player and player[2] or nil
end

local function GetUwUSpecRank(player, specIndex)
	local specRanks = player and player[7]
	if specRanks and specIndex then
		return specRanks[specIndex]
	end
	return player and player[5] or nil
end

local function GetUwUSpecBossData(player, specIndex)
	if not player then
		return nil
	end
	specIndex = specIndex or player[4]
	local perSpecBossData = player[9]
	local bossData
	if type(perSpecBossData) == "table" and type(perSpecBossData[specIndex]) == "table" then
		bossData = perSpecBossData[specIndex]
	elseif specIndex == player[4] then
		bossData = player[8]
	end
	return bossData
end

local function GetUwUBestBossDataAcrossSpecs(player, bossIndex)
	local bestEntry
	local bestSpecIndex
	local bestScore
	local perSpecBossData = player and player[9]
	if type(perSpecBossData) ~= "table" then
		return nil, nil
	end
	for specIndex, specBossData in pairs(perSpecBossData) do
		local entry = type(specBossData) == "table" and specBossData[bossIndex]
		local score = GetUwUBossScoreCenti(entry)
		if score and (not bestScore or score > bestScore) then
			bestEntry = entry
			bestSpecIndex = specIndex
			bestScore = score
		end
	end
	return bestEntry, bestSpecIndex
end

local function GetUwUSpecIcon(player, specIndex, panel)
	if panel and panel.isInspectPanel and GetTalentTabInfo then
		local talentGroup = InspectTalentFrame and InspectTalentFrame.talentGroup or 1
		local _, icon = GetTalentTabInfo(specIndex, true, false, talentGroup)
		if icon then
			return icon
		end
	end

	local classFallbacks = player and UWU_SPEC_ICON_FALLBACKS[player[3]]
	return classFallbacks and classFallbacks[specIndex] or "Interface\\Icons\\Ability_Marksmanship"
end

local function BuildUwUSpecChoices(player)
	local choices = {}
	local data = coolstatsUwUData
	local classSpecs = data and data.specs and data.specs[player[3]]
	local specScores = player[6]
	if not classSpecs or not specScores then
		return choices
	end

	for specIndex = 1, 3 do
		local scoreCenti = specScores[specIndex]
		if scoreCenti and classSpecs[specIndex] then
			choices[#choices + 1] = {
				specIndex = specIndex,
				scoreCenti = scoreCenti,
				rank = GetUwUSpecRank(player, specIndex),
				name = classSpecs[specIndex],
			}
		end
	end

	table.sort(choices, function(left, right)
		if left.scoreCenti == right.scoreCenti then
			return left.specIndex < right.specIndex
		end
		return left.scoreCenti > right.scoreCenti
	end)
	return choices
end

local function GetUwUBestSpecIndex(player)
	if not player then
		return nil
	end
	local defaultSpecIndex = player[4]
	if GetUwUSpecScoreCenti(player, defaultSpecIndex) then
		return defaultSpecIndex
	end
	local choices = BuildUwUSpecChoices(player)
	return choices[1] and choices[1].specIndex or defaultSpecIndex
end

local function GetInspectPanelSelectedSpecIndex(panel, player)
	local defaultSpecIndex = GetUwUBestSpecIndex(player)
	if not panel or not player then
		return defaultSpecIndex
	end

	local playerKey = tostring(player[1] or "") .. ":" .. tostring(player[3] or "")
	if panel.selectedPlayerKey ~= playerKey then
		panel.selectedPlayerKey = playerKey
		panel.selectedSpecIndex = defaultSpecIndex
	end

	if not GetUwUSpecScoreCenti(player, panel.selectedSpecIndex) then
		panel.selectedSpecIndex = defaultSpecIndex
	end
	return panel.selectedSpecIndex or defaultSpecIndex
end

local function ResetInspectPanelSelectedSpec(panel)
	if not panel then
		return
	end
	panel.selectedPlayerKey = nil
	panel.selectedSpecIndex = nil
end

local function HideInspectPanelSpecButtons(panel)
	if not panel or not panel.specButtons then
		return
	end
	for index = 1, #panel.specButtons do
		panel.specButtons[index]:Hide()
	end
end

local function AddUwUSpecLines(player)
	local data = coolstatsUwUData
	local classSpecs = data and data.specs and data.specs[player[3]]
	local specScores = player[6]
	if not classSpecs or not specScores then
		return
	end

	local specRanks = player[7]
	GameTooltip:AddLine("UwU Specs", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
	for specIndex = 1, 3 do
		local specScore = specScores[specIndex]
		if specScore and classSpecs[specIndex] then
			local specRed, specGreen, specBlue = GetUwUScoreColor(specScore)
			local rank = specRanks and specRanks[specIndex]
			GameTooltip:AddDoubleLine("  " .. classSpecs[specIndex], FormatUwUScoreWithRank(specScore, rank), 0.70, 0.70, 0.70, specRed, specGreen, specBlue)
		end
	end
end

local function AddUwUBossLines(player)
	local data = coolstatsUwUData
	local bossData = player[8]
	if not data or not data.bosses then
		return
	end

	GameTooltip:AddLine("UwU Boss Parses", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
	local currentRaidName = nil
	for bossIndex = 1, #data.bosses do
		local bossName = data.bosses[bossIndex]
		if bossName then
			local raidName = GetUwUBossRaidName(bossName)
			if raidName ~= currentRaidName then
				GameTooltip:AddLine("  " .. raidName, 0.86, 0.72, 0.25)
				currentRaidName = raidName
			end

			local entry = bossData and bossData[bossIndex]
			local historicalSpecIndex
			if coolstats.GetActiveUwUPhaseId() == "toc" and bossName == "Algalon the Observer" then
				entry, historicalSpecIndex = GetUwUBestBossDataAcrossSpecs(player, bossIndex)
			end
			local scoreCenti = GetUwUBossScoreCenti(entry)
			local bossRed, bossGreen, bossBlue = 0.45, 0.45, 0.45
			if scoreCenti then
				bossRed, bossGreen, bossBlue = GetUwUScoreColor(scoreCenti)
			end
			local bossLabel = GetUwUBossDisplayLabel(bossName)
			local historicalSpecName = historicalSpecIndex and GetUwUSpecName(player, historicalSpecIndex)
			if historicalSpecName then
				bossLabel = bossLabel .. " (" .. historicalSpecName .. ")"
			end
			GameTooltip:AddDoubleLine("    " .. bossLabel, FormatUwUBossTooltipValue(entry), 0.70, 0.70, 0.70, bossRed, bossGreen, bossBlue)
		end
	end
end

local function AddCachedUwUTooltipLine(line)
	if not line then
		return
	end
	if line[1] == "line" then
		GameTooltip:AddLine(line[2], line[3], line[4], line[5])
	elseif line[1] == "double" then
		GameTooltip:AddDoubleLine(line[2], line[3], line[4], line[5], line[6], line[7], line[8], line[9])
	end
end

local function BuildUwUTooltipCache(player)
	local scoreCenti = player[2]
	local specName = GetUwUSpecName(player)
	local rank = player[5]
	local currentPhaseRanked = coolstats.IsUwUPlayerRankedForCurrentPhase(player)
	local value = "Not ranked"
	if currentPhaseRanked then
		value = FormatUwUScore(scoreCenti)
		if specName then
			value = value .. " " .. specName
		end
		if rank then
			value = value .. " #" .. tostring(rank)
		end
	end

	local red, green, blue = 0.45, 0.45, 0.45
	if currentPhaseRanked then
		red, green, blue = GetUwUScoreColor(scoreCenti)
	end
	local cache = {
		player = player,
		base = { "double", "UwU Logs Raid Score", value, ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, red, green, blue },
		details = {},
	}
	local historicalScore, historicalRank = coolstats.GetUwUHistoricalOverall(player)
	if historicalScore then
		local historicalRed, historicalGreen, historicalBlue = GetUwUScoreColor(historicalScore)
		cache.historical = {
			"double",
			coolstats.GetUwUHistoricalOverallLabel(),
			FormatUwUScoreWithRank(historicalScore, historicalRank),
			0.70, 0.70, 0.70,
			historicalRed, historicalGreen, historicalBlue,
		}
	end

	local data = coolstatsUwUData
	local classSpecs = data and data.specs and data.specs[player[3]]
	local specScores = player[6]
	if currentPhaseRanked and classSpecs and specScores then
		cache.details[#cache.details + 1] = { "line", "UwU Specs", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B }
		local specRanks = player[7]
		for specIndex = 1, 3 do
			local specScore = specScores[specIndex]
			if specScore and classSpecs[specIndex] then
				local specRed, specGreen, specBlue = GetUwUScoreColor(specScore)
				local specRank = specRanks and specRanks[specIndex]
				cache.details[#cache.details + 1] = { "double", "  " .. classSpecs[specIndex], FormatUwUScoreWithRank(specScore, specRank), 0.70, 0.70, 0.70, specRed, specGreen, specBlue }
			end
		end
	end

	local bossData = player[8]
	if data and data.bosses then
		cache.details[#cache.details + 1] = { "line", "UwU Boss Parses", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B }
		local currentRaidName = nil
		for bossIndex = 1, #data.bosses do
			local bossName = data.bosses[bossIndex]
			if bossName then
				local raidName = GetUwUBossRaidName(bossName)
				if raidName ~= currentRaidName then
					cache.details[#cache.details + 1] = { "line", "  " .. raidName, 0.86, 0.72, 0.25 }
					currentRaidName = raidName
				end

				local entry = bossData and bossData[bossIndex]
				local historicalSpecIndex
				if coolstats.GetActiveUwUPhaseId() == "toc" and bossName == "Algalon the Observer" then
					entry, historicalSpecIndex = GetUwUBestBossDataAcrossSpecs(player, bossIndex)
				end
				local bossRed, bossGreen, bossBlue = 0.45, 0.45, 0.45
				local bossScore = GetUwUBossScoreCenti(entry)
				if bossScore then
					bossRed, bossGreen, bossBlue = GetUwUScoreColor(bossScore)
				end
				local bossLabel = GetUwUBossDisplayLabel(bossName)
				local historicalSpecName = historicalSpecIndex and GetUwUSpecName(player, historicalSpecIndex)
				if historicalSpecName then
					bossLabel = bossLabel .. " (" .. historicalSpecName .. ")"
				end
				cache.details[#cache.details + 1] = { "double", "    " .. bossLabel, FormatUwUBossTooltipValue(entry), 0.70, 0.70, 0.70, bossRed, bossGreen, bossBlue }
			end
		end
	end

	return cache
end

local function GetUwUTooltipCache(player)
	local cacheKey = NormalizeName(player and player[1] or "")
	local cache = uwuTooltipCache[cacheKey]
	if cache and cache.player == player then
		return cache
	end
	cache = BuildUwUTooltipCache(player)
	uwuTooltipCache[cacheKey] = cache
	return cache
end

local function AddUwULogsLines(unit)
	local options = coolstats.GetTooltipFeatureOptions()
	if options.logsSummary == false and options.logsBossDetails == false then
		return false
	end
	local data = coolstatsUwUData
	if not data or not data.players then
		return false
	end

	local name = UnitName(unit)
	local player = name and GetUwUPlayerByName(name)
	if not player then
		local level = UnitLevel(unit)
		if options.logsSummary ~= false and level and level >= 80 then
			GameTooltip:AddDoubleLine("UwU Logs Raid Score", "Not ranked", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, 0.45, 0.45, 0.45)
		end
		return false
	end

	local cache = GetUwUTooltipCache(player)
	if options.logsSummary ~= false then
		AddCachedUwUTooltipLine(cache.base)
		AddCachedUwUTooltipLine(cache.historical)
	end

	if options.logsBossDetails ~= false and IsAltKeyDown and IsAltKeyDown() then
		for index = 1, #cache.details do
			AddCachedUwUTooltipLine(cache.details[index])
		end
	end
	return true
end

GetInspectUwUUnit = function()
	if InspectFrame and InspectFrame.unit and UnitExists(InspectFrame.unit) then
		return InspectFrame.unit
	end
	if UnitExists("target") and InspectFrame and InspectFrame:IsShown() then
		return "target"
	end
	return nil
end

local function IsInspectPanelRaidCollapsedByDefault(raidName)
	local phase = GetCurrentUwUPhase()
	local collapsedRaids = phase and phase.defaultCollapsedRaids
	return collapsedRaids and collapsedRaids[raidName] == true
end

local function IsInspectPanelRaidCollapsed(panel, raidName)
	if not panel or not raidName then
		return false
	end
	panel.collapsedRaids = panel.collapsedRaids or {}
	local collapsed = panel.collapsedRaids[raidName]
	if collapsed == nil then
		return IsInspectPanelRaidCollapsedByDefault(raidName)
	end
	return collapsed == true
end

local function ToggleInspectPanelRaid(panel, raidName)
	if not panel or not raidName then
		return
	end
	panel.collapsedRaids = panel.collapsedRaids or {}
	panel.collapsedRaids[raidName] = not IsInspectPanelRaidCollapsed(panel, raidName)
	if RenderUwUPanel then
		RenderUwUPanel(panel, panel.renderName, panel.renderPlayer, panel.renderSubtitle)
	end
end

local function ResetInspectPanelRow(row)
	row.bg:Hide()
	row.headerLeft:Hide()
	row.headerRight:Hide()
	row.headerText:Hide()
	row.headerToggle:Hide()
	row.label:Hide()
	row.value:Hide()
	row.parse:Hide()
	row.playerRank:Hide()
	row.raidRank:Hide()
	row.dps:Hide()
	row.uwuCollapseRaid = nil
	row.uwuPanel = nil
	row:EnableMouse(false)
end

local function SetInspectPanelRow(row, label, value, labelR, labelG, labelB, valueR, valueG, valueB, shaded)
	ResetInspectPanelRow(row)
	row.label:SetText(label or "")
	row.label:SetTextColor(labelR or 0.86, labelG or 0.86, labelB or 0.78)
	row.label:SetWidth(UWU_INSPECT_LABEL_WIDTH)
	row.label:Show()
	row.value:SetText(value or "")
	row.value:SetTextColor(valueR or 1.0, valueG or 1.0, valueB or 1.0)
	row.value:Show()
	if shaded then
		row.bg:SetVertexColor(0.28, 0.27, 0.25, 0.26)
		row.bg:Show()
	end
	row:Show()
end

local function SetInspectPanelSection(row, title, panel, collapseRaid, collapsed)
	ResetInspectPanelRow(row)
	row.headerLeft:Show()
	row.headerRight:Show()
	row.headerText:SetText(title or "")
	row.headerText:Show()
	if collapseRaid then
		row.uwuCollapseRaid = collapseRaid
		row.uwuPanel = panel
		if collapsed then
			row.headerToggle:SetTexCoord(0, 0.4375, 0, 0.4375)
		else
			row.headerToggle:SetTexCoord(0.5625, 1, 0, 0.4375)
		end
		row.headerToggle:Show()
		row:EnableMouse(true)
	end
	row:Show()
end

local function SetInspectPanelColumnHeader(row)
	ResetInspectPanelRow(row)
	row.bg:SetVertexColor(0.08, 0.08, 0.08, 0.42)
	row.bg:Show()
	row.label:SetText("Boss")
	row.label:SetTextColor(0.86, 0.86, 0.78)
	row.label:SetWidth(UWU_INSPECT_BOSS_LABEL_WIDTH)
	row.label:Show()
	row.parse:SetText("Parse")
	row.parse:SetTextColor(0.86, 0.86, 0.78)
	row.parse:Show()
	row.playerRank:SetText("P#")
	row.playerRank:SetTextColor(0.86, 0.86, 0.78)
	row.playerRank:Show()
	row.raidRank:SetText("R#")
	row.raidRank:SetTextColor(0.86, 0.86, 0.78)
	row.raidRank:Show()
	row.dps:SetText("DPS")
	row.dps:SetTextColor(0.86, 0.86, 0.78)
	row.dps:Show()
	row:Show()
end

local function SetInspectPanelBossRow(row, bossName, bossData, shaded)
	ResetInspectPanelRow(row)
	if shaded then
		row.bg:SetVertexColor(0.28, 0.27, 0.25, 0.26)
		row.bg:Show()
	else
		row.bg:SetVertexColor(0.05, 0.06, 0.07, 0.10)
		row.bg:Show()
	end

	local scoreCenti = GetUwUBossScoreCenti(bossData)
	local red, green, blue = 0.45, 0.45, 0.45
	if scoreCenti then
		red, green, blue = GetUwUScoreColor(scoreCenti)
	end

	row.label:SetText(GetUwUBossDisplayLabel(bossName))
	row.label:SetTextColor(0.86, 0.86, 0.78)
	row.label:SetWidth(UWU_INSPECT_BOSS_LABEL_WIDTH)
	row.label:Show()
	row.parse:SetText(scoreCenti and FormatUwUScore(scoreCenti) or "-")
	row.parse:SetTextColor(red, green, blue)
	row.parse:Show()
	row.playerRank:SetText(tostring(GetUwUBossPlayerRank(bossData) or "-"))
	row.playerRank:SetTextColor(red, green, blue)
	row.playerRank:Show()
	row.raidRank:SetText(tostring(GetUwUBossRaidRank(bossData) or "-"))
	row.raidRank:SetTextColor(red, green, blue)
	row.raidRank:Show()
	row.dps:SetText(FormatUwUDps(GetUwUBossDps(bossData)))
	row.dps:SetTextColor(red, green, blue)
	row.dps:Show()
	row:Show()
end

local function AddInspectPanelLine(state, label, value, valueR, valueG, valueB, labelR, labelG, labelB)
	local row = state.rows[state.index]
	if not row then
		return
	end
	SetInspectPanelRow(row, label, value, labelR, labelG, labelB, valueR, valueG, valueB, state.stripeIndex % 2 == 0)
	state.stripeIndex = state.stripeIndex + 1
	state.index = state.index + 1
end

local function AddInspectPanelSection(state, title, collapseRaid)
	local row = state.rows[state.index]
	if not row then
		return false
	end
	local collapsed = collapseRaid and IsInspectPanelRaidCollapsed(state.panel, collapseRaid)
	SetInspectPanelSection(row, title, state.panel, collapseRaid, collapsed)
	state.index = state.index + 1
	state.stripeIndex = 1
	return collapsed == true
end

local function AddInspectPanelColumns(state)
	local row = state.rows[state.index]
	if not row then
		return
	end
	SetInspectPanelColumnHeader(row)
	state.index = state.index + 1
end

local function AddInspectPanelBoss(state, bossName, bossData)
	local row = state.rows[state.index]
	if not row then
		return
	end
	SetInspectPanelBossRow(row, bossName, bossData, state.stripeIndex % 2 == 0)
	state.stripeIndex = state.stripeIndex + 1
	state.index = state.index + 1
end

local function UpdateInspectPanelSpecButtons(panel, player, selectedSpecIndex)
	if not panel or not panel.specButtons then
		return
	end

	local choices = player and BuildUwUSpecChoices(player) or {}
	if #choices == 0 then
		HideInspectPanelSpecButtons(panel)
		return
	end

	for index = 1, #panel.specButtons do
		local button = panel.specButtons[index]
		local choice = choices[index]
		if choice then
			button.uwuPanel = panel
			button.specIndex = choice.specIndex
			button.specName = choice.name
			button.scoreCenti = choice.scoreCenti
			button.rank = choice.rank
			button.hasBossData = GetUwUSpecBossData(player, choice.specIndex) ~= nil
			local normalTexture = button:GetNormalTexture()
			if normalTexture then
				normalTexture:SetTexture(GetUwUSpecIcon(player, choice.specIndex, panel))
			else
				button:SetNormalTexture(GetUwUSpecIcon(player, choice.specIndex, panel))
			end
			button:SetChecked(choice.specIndex == selectedSpecIndex)
			button:SetAlpha(choice.specIndex == selectedSpecIndex and 1 or 0.72)
			button:Show()
		else
			button.specIndex = nil
			button.uwuPanel = nil
			button:Hide()
		end
	end
end

local function InspectPanelSpecButton_OnClick(self)
	local panel = self.uwuPanel
	if not panel or not self.specIndex then
		return
	end
	coolstats.TouchManagedWindowOwner(panel)
	panel.selectedSpecIndex = self.specIndex
	if PlaySound then
		PlaySound("igCharacterInfoTab")
	end
	if RenderUwUPanel then
		RenderUwUPanel(panel, panel.renderName, panel.renderPlayer, panel.renderSubtitle)
	end
end

local function InspectPanelSpecButton_OnEnter(self)
	if not self.specName then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(self.specName, 1.0, 0.82, 0)
	local red, green, blue = GetUwUScoreColor(self.scoreCenti)
	GameTooltip:AddDoubleLine("Raid Score", FormatUwUScoreWithRank(self.scoreCenti, self.rank), ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, red, green, blue)
	if not self.hasBossData then
		GameTooltip:AddLine("Boss parses not cached for this spec", 0.62, 0.62, 0.58, true)
	end
	GameTooltip:Show()
end

local function InspectPanelSpecButton_OnLeave()
	GameTooltip:Hide()
end

local function CreateCachedGearSlotButton(panel, info)
	local button = CreateFrame("Button", nil, panel)
	SetFrameSize(button, UWU_CACHED_GEAR_SLOT_SIZE, UWU_CACHED_GEAR_SLOT_SIZE)
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", info.x, info.y)
	button.slotID = info.slot
	button.slotLabel = info.label
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnEnter", CachedGearButton_OnEnter)
	button:SetScript("OnLeave", CachedGearButton_OnLeave)
	button:SetScript("OnClick", CachedGearButton_OnClick)

	local border = button:CreateTexture(nil, "BACKGROUND")
	border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	border:SetAllPoints(button)
	button.border = border

	local qualityBorder = button:CreateTexture(nil, "OVERLAY")
	qualityBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	qualityBorder:SetBlendMode("ADD")
	SetFrameSize(qualityBorder, UWU_CACHED_GEAR_SLOT_SIZE + 29, UWU_CACHED_GEAR_SLOT_SIZE + 29)
	qualityBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
	qualityBorder:Hide()
	button.qualityBorder = qualityBorder

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local itemLevel = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	itemLevel:SetPoint("CENTER", button, "CENTER", 0, 0)
	itemLevel:SetWidth(UWU_CACHED_GEAR_SLOT_SIZE - 4)
	itemLevel:SetJustifyH("CENTER")
	itemLevel:SetTextColor(1, 1, 1)
	itemLevel:SetShadowOffset(0, 0)
	button.itemLevelText = itemLevel

	if GetInventorySlotInfo and info.token then
		local _, emptyTexture = GetInventorySlotInfo(info.token)
		button.emptyTexture = emptyTexture
	end

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
	return button
end

local function CreateCachedGearInfoHeader(panel, text, yOffset)
	local row = CreateFrame("Frame", nil, panel)
	SetFrameSize(row, UWU_CACHED_GEAR_INFO_WIDTH, 18)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", UWU_CACHED_GEAR_INFO_LEFT, yOffset)
	row.tooltipTitle = text
	row:EnableMouse(true)
	row:SetScript("OnEnter", CachedGearInfo_OnEnter)
	row:SetScript("OnLeave", CachedGearButton_OnLeave)

	local right = row:CreateTexture(nil, "ARTWORK")
	right:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
	SetFrameSize(right, 37, 18)
	right:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	right:SetTexCoord(0, 0.14453125, 0.296875, 0.578125)

	local left = row:CreateTexture(nil, "ARTWORK")
	left:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
	left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	left:SetTexCoord(0, 1, 0, 0.28125)

	local label = row:CreateFontString(nil, "OVERLAY")
	label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	SetFrameSize(label, UWU_CACHED_GEAR_INFO_WIDTH - 32, 16)
	label:SetPoint("CENTER", row, "CENTER", -4, 0)
	label:SetJustifyH("CENTER")
	if label.SetJustifyV then
		label:SetJustifyV("MIDDLE")
	end
	label:SetText(text)
	label:SetTextColor(1, 0.82, 0)
	label:SetShadowOffset(1, -1)
	label:SetShadowColor(0, 0, 0, 1)
	row.label = label
	return row
end

local function CreateCachedGearInfoRow(panel, yOffset, rowIndex, centered)
	local row = CreateFrame("Frame", nil, panel)
	SetFrameSize(row, UWU_CACHED_GEAR_INFO_WIDTH, UWU_CACHED_GEAR_INFO_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", UWU_CACHED_GEAR_INFO_LEFT, yOffset)
	row.centered = centered == true
	row.tooltipTitle = centered and "Equipment" or "Stats (Implied)"
	row:EnableMouse(true)
	row:SetScript("OnEnter", CachedGearInfo_OnEnter)
	row:SetScript("OnLeave", CachedGearButton_OnLeave)

	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 0)
	bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, 0)
	if ((rowIndex or 0) % 2) == 0 then
		bg:SetVertexColor(0.28, 0.27, 0.25, 0.26)
	else
		bg:SetVertexColor(0.05, 0.06, 0.07, 0.10)
	end
	row.bg = bg

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", row, "LEFT", 3, 0)
	label:SetWidth(58)
	label:SetJustifyH("LEFT")
	label:SetTextColor(ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
	row.label = label

	local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	value:SetPoint("RIGHT", row, "RIGHT", -3, 0)
	value:SetWidth(104)
	value:SetJustifyH("RIGHT")
	value:SetTextColor(1, 1, 1)
	row.value = value
	if row.centered then
		row.label:Hide()
		value:ClearAllPoints()
		value:SetPoint("CENTER", row, "CENTER", 0, 0)
		value:SetWidth(UWU_CACHED_GEAR_INFO_WIDTH - 8)
		value:SetJustifyH("CENTER")
	end
	return row
end

local function CreateCachedGearPanel(ownerPanel)
	if not ownerPanel or ownerPanel.cachedGearPanel then
		return ownerPanel and ownerPanel.cachedGearPanel or nil
	end

	local panel = CreateFrame("Frame", nil, ownerPanel:GetParent() or UIParent)
	ownerPanel.cachedGearPanel = panel
	SetFrameSize(panel, UWU_CACHED_GEAR_PANEL_WIDTH, UWU_CACHED_GEAR_PANEL_HEIGHT)
	panel:SetPoint("TOPRIGHT", ownerPanel, "TOPLEFT", -UWU_CACHED_GEAR_PANEL_GAP, 0)
	panel:SetFrameStrata(ownerPanel:GetFrameStrata())
	panel:SetFrameLevel(ownerPanel:GetFrameLevel() + 1)
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = false,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	panel:SetBackdropColor(0.02, 0.018, 0.014, 1)
	panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
	panel:EnableMouse(true)
	panel:SetScript("OnMouseDown", function()
		if ownerPanel.coolstatsManagedWindow then
			coolstats.TouchManagedWindow(ownerPanel)
		end
	end)

	local tabardBackground = panel:CreateTexture(nil, "ARTWORK")
	tabardBackground:SetTexture("Interface\\TabardFrame\\TabardFrameBackground")
	tabardBackground:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
	tabardBackground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
	tabardBackground:SetTexCoord(0.05, 0.95, 0.08, 0.92)
	tabardBackground:SetVertexColor(0.72, 0.72, 0.68, 0.95)
	panel.tabardBackground = tabardBackground

	local tabardShade = panel:CreateTexture(nil, "ARTWORK")
	tabardShade:SetTexture("Interface\\Buttons\\WHITE8X8")
	tabardShade:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
	tabardShade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
	tabardShade:SetVertexColor(0, 0, 0, 0.38)
	panel.tabardShade = tabardShade

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", panel, "TOP", 0, -12)
	title:SetWidth(UWU_CACHED_GEAR_PANEL_WIDTH - 20)
	title:SetJustifyH("CENTER")
	title:SetTextColor(ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
	panel.title = title

	local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
	subtitle:SetWidth(UWU_CACHED_GEAR_PANEL_WIDTH - 20)
	subtitle:SetJustifyH("CENTER")
	subtitle:SetTextColor(0.78, 0.78, 0.72)
	panel.subtitle = subtitle

	local classIconFrame = CreateFrame("Frame", nil, panel)
	SetFrameSize(classIconFrame, UWU_CACHED_GEAR_CLASS_ICON_SIZE + 10, UWU_CACHED_GEAR_CLASS_ICON_SIZE + 10)
	classIconFrame:SetPoint("CENTER", panel, "TOP", 0, -146)
	classIconFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	classIconFrame:SetBackdropColor(0, 0, 0, 0.42)
	classIconFrame:SetBackdropBorderColor(0.38, 0.36, 0.32, 0.9)
	panel.classIconFrame = classIconFrame

	local classIcon = classIconFrame:CreateTexture(nil, "ARTWORK")
	SetFrameSize(classIcon, UWU_CACHED_GEAR_CLASS_ICON_SIZE, UWU_CACHED_GEAR_CLASS_ICON_SIZE)
	classIcon:SetPoint("CENTER", classIconFrame, "CENTER", 0, 0)
	classIcon:SetTexture(UWU_CLASS_ICON_ATLAS)
	panel.classIcon = classIcon

	local classText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	classText:SetPoint("TOP", classIconFrame, "BOTTOM", 0, -5)
	classText:SetWidth(UWU_CACHED_GEAR_PANEL_WIDTH - 60)
	classText:SetJustifyH("CENTER")
	classText:SetTextColor(0.86, 0.86, 0.78)
	panel.classText = classText

	panel.infoHeaders = {
		equipment = CreateCachedGearInfoHeader(panel, "Equipment", -226),
		general = CreateCachedGearInfoHeader(panel, "Stats (Implied)", -278),
	}
	panel.statRows = {
		gearScore = CreateCachedGearInfoRow(panel, -248, 1, true),
		itemLevel = CreateCachedGearInfoRow(panel, -261, 2, true),
		hit = CreateCachedGearInfoRow(panel, -300, 1),
		spellHit = CreateCachedGearInfoRow(panel, -313, 2),
		expertise = CreateCachedGearInfoRow(panel, -326, 3),
		armorPen = CreateCachedGearInfoRow(panel, -339, 4),
		defense = CreateCachedGearInfoRow(panel, -352, 5),
	}

	panel.slotButtons = {}
	for index = 1, #UWU_CACHED_GEAR_SLOTS do
		local info = UWU_CACHED_GEAR_SLOTS[index]
		panel.slotButtons[info.slot] = CreateCachedGearSlotButton(panel, info)
	end
	panel:Hide()
	return panel
end

local function UpdateCachedGearSlotButton(button, item)
	if not button then
		return
	end

	button.link = item and item.link or nil
	button.itemID = item and item.itemID or nil
	button.itemLevel = item and item.itemLevel or nil
	if item and item.texture then
		button.icon:SetTexture(item.texture)
		button.icon:SetDesaturated(false)
		button.icon:SetAlpha(1)
	else
		button.icon:SetTexture(button.emptyTexture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
		button.icon:SetDesaturated(true)
		button.icon:SetAlpha(0.45)
	end

	local red, green, blue = item and item.red, item and item.green, item and item.blue
	local qualityColor = item and item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
	if not (red and green and blue) and qualityColor then
		red, green, blue = qualityColor.r, qualityColor.g, qualityColor.b
	end
	if item and red and green and blue then
		button.border:SetVertexColor(0.82, 0.82, 0.78, 0.86)
		button.qualityBorder:SetVertexColor(red, green, blue, 0.72)
		button.qualityBorder:Show()
	else
		button.border:SetVertexColor(0.82, 0.82, 0.78, 0.68)
		button.qualityBorder:Hide()
	end

	if item and item.itemLevel and item.itemLevel > 0 then
		button.itemLevelText:SetText(tostring(item.itemLevel))
		if red and green and blue then
			button.itemLevelText:SetTextColor(red, green, blue)
		else
			button.itemLevelText:SetTextColor(1, 1, 1)
		end
	else
		button.itemLevelText:SetText("")
	end
end

local function SetCachedGearInfoRow(row, labelText, valueText, red, green, blue)
	if not row then
		return
	end
	if row.centered then
		if labelText and labelText ~= "" then
			row.value:SetText(labelText .. " " .. (valueText or "-"))
		else
			row.value:SetText(valueText or "-")
		end
	else
		row.label:SetText(labelText or "")
		row.value:SetText(valueText or "-")
	end
	if red and green and blue then
		row.value:SetTextColor(red, green, blue)
	else
		row.value:SetTextColor(1, 1, 1)
	end
end

local function UpdateCachedGearPanel(ownerPanel, name, player)
	if not ownerPanel or not ownerPanel.playTalentPanelSounds then
		return
	end

	local snapshot = GetCachedGearSnapshot(player and player[1] or name)
	local panel = CreateCachedGearPanel(ownerPanel)
	if not panel then
		return
	end

	panel.title:SetText(snapshot and (snapshot.name or name or "Unknown") or (player and player[1] or name or "Cached Gear"))
	panel.subtitle:SetText(snapshot and FormatCachedGearDateTime(snapshot.seenAt) or "No cached gear")
	local classFile = GetClassFileForSnapshot(snapshot, player)
	local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
	panel.classIcon:SetTexture(UWU_CLASS_ICON_ATLAS)
	if coords then
		panel.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		panel.classIcon:SetTexCoord(0, 1, 0, 1)
	end
	local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if classColor then
		panel.classText:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		panel.classText:SetTextColor(0.86, 0.86, 0.78)
	end
	panel.classText:SetText(classFile or "Unknown")

	local summary = snapshot and BuildCachedGearStatSummary(snapshot) or nil
	if summary and summary.itemLevelCount and summary.itemLevelCount > 0 then
		local scoreRed, scoreGreen, scoreBlue = 1, 1, 1
		if coolstats and coolstats.GetScoreColor then
			scoreRed, scoreGreen, scoreBlue = coolstats.GetScoreColor(summary.gearScore or 0)
		end
		SetCachedGearInfoRow(panel.statRows.gearScore, "GS", FormatCachedInteger(summary.gearScore or 0), scoreRed, scoreGreen, scoreBlue)
		SetCachedGearInfoRow(panel.statRows.itemLevel, "Item Level", FormatCachedInteger(summary.averageItemLevel or 0), scoreRed, scoreGreen, scoreBlue)
		SetCachedGearInfoRow(panel.statRows.hit, "Hit", FormatCachedRatingPercent(summary.hit, UWU_LEVEL_80_HIT_RATING_PER_PERCENT))
		SetCachedGearInfoRow(panel.statRows.spellHit, "Spell Hit", FormatCachedRatingPercent(summary.spellHit, UWU_LEVEL_80_HIT_RATING_PER_PERCENT))
		SetCachedGearInfoRow(panel.statRows.expertise, "Expertise", FormatCachedExpertise(summary.expertise))
		SetCachedGearInfoRow(panel.statRows.armorPen, "Armor Pen", FormatCachedRatingPercent(summary.armorPen, UWU_LEVEL_80_ARMOR_PEN_RATING_PER_PERCENT))
		SetCachedGearInfoRow(panel.statRows.defense, "Def", FormatCachedDefense(summary.defense))
	else
		SetCachedGearInfoRow(panel.statRows.gearScore, "GS", "-")
		SetCachedGearInfoRow(panel.statRows.itemLevel, "Item Level", "-")
		SetCachedGearInfoRow(panel.statRows.hit, "Hit", "-")
		SetCachedGearInfoRow(panel.statRows.spellHit, "Spell Hit", "-")
		SetCachedGearInfoRow(panel.statRows.expertise, "Expertise", "-")
		SetCachedGearInfoRow(panel.statRows.armorPen, "Armor Pen", "-")
		SetCachedGearInfoRow(panel.statRows.defense, "Def", tostring(UWU_LEVEL_80_BASE_DEFENSE_SKILL))
	end

	local slots = snapshot and snapshot.slots or {}
	for index = 1, #UWU_CACHED_GEAR_SLOTS do
		local info = UWU_CACHED_GEAR_SLOTS[index]
		UpdateCachedGearSlotButton(panel.slotButtons[info.slot], slots[info.slot])
	end
	panel:Show()
end

local function CreateUwUPanel(frameName, parent, anchorFrame, standalone)
	parent = parent or UIParent
	local panel = CreateFrame("Frame", frameName, parent)
	panel.playTalentPanelSounds = standalone == true
	SetFrameSize(panel, UWU_INSPECT_PANEL_WIDTH, UWU_INSPECT_PANEL_HEIGHT)
	if anchorFrame then
		panel:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", -1, -18)
		panel:SetFrameStrata(anchorFrame:GetFrameStrata())
		panel:SetFrameLevel(anchorFrame:GetFrameLevel() + 6)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		panel:SetFrameStrata("DIALOG")
		panel:SetFrameLevel(50)
	end
	panel:SetBackdrop({
		bgFile = "Interface\\CharacterFrame\\UI-Party-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	panel:SetBackdropColor(0.02, 0.018, 0.014, 1)
	panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
	panel:EnableMouse(true)

	if standalone then
		panel:SetMovable(true)
		if panel.SetToplevel then
			panel:SetToplevel(true)
		end
		panel:RegisterForDrag("LeftButton")
		panel:SetScript("OnMouseDown", function(self)
			if coolstats and coolstats.cachedPlayerBrowser and coolstats.cachedPlayerBrowser:IsShown() then
				self:SetFrameStrata("DIALOG")
				self:SetFrameLevel((coolstats.cachedPlayerBrowser:GetFrameLevel() or 80) + 12)
				if self.cachedGearPanel then
					self.cachedGearPanel:SetFrameStrata("DIALOG")
					self.cachedGearPanel:SetFrameLevel(self:GetFrameLevel() + 1)
				end
			end
		end)
		panel:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		panel:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
		end)

		local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -4)
		close:SetScript("OnClick", function()
			panel:Hide()
		end)
		panel.close = close

		if frameName and UISpecialFrames then
			local registered = false
			for index = 1, #UISpecialFrames do
				if UISpecialFrames[index] == frameName then
					registered = true
					break
				end
			end
			if not registered then
				table.insert(UISpecialFrames, frameName)
			end
		end
		coolstats.RegisterManagedWindow(panel)
	end
	panel:SetScript("OnHide", function(self)
		ResetInspectPanelSelectedSpec(self)
		if self.cachedGearPanel then
			self.cachedGearPanel:Hide()
		end
		if self.playTalentPanelSounds and PlaySound then
			PlaySound("igCharacterInfoClose")
		end
	end)

	local top = panel:CreateTexture(nil, "ARTWORK")
	top:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
	top:SetTexCoord(0, 0.8984375, 0, 0.125)
	top:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
	top:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
	top:SetHeight(16)

	local previous = top
	local remaining = UWU_INSPECT_PANEL_HEIGHT - 32
	while remaining > 0 do
		local middle = panel:CreateTexture(nil, "ARTWORK")
		middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
		middle:SetTexCoord(0, 0.8984375, 0.125, 0.1953125)
		middle:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
		middle:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, 0)
		middle:SetHeight(math.min(53, remaining))
		previous = middle
		remaining = remaining - 53
	end

	local bottom = panel:CreateTexture(nil, "ARTWORK")
	bottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
	bottom:SetTexCoord(0, 0.8984375, 0.484375, 0.609375)
	bottom:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 3, 3)
	bottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
	bottom:SetHeight(16)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", panel, "TOP", 0, -10)
	title:SetWidth(UWU_INSPECT_PANEL_WIDTH - 16)
	title:SetJustifyH("CENTER")
	title:SetTextColor(ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
	title:SetText("")
	panel.title = title

	local titleLinkButton = CreateFrame("Button", nil, panel)
	SetFrameSize(titleLinkButton, UWU_INSPECT_PANEL_WIDTH - 56, 18)
	titleLinkButton:SetPoint("CENTER", title, "CENTER", 0, 0)
	titleLinkButton:SetFrameLevel(panel:GetFrameLevel() + 8)
	titleLinkButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	titleLinkButton:SetScript("OnClick", function(self, button)
		if button == "RightButton" or (IsModifiedClick and IsModifiedClick("CHATLINK")) then
			coolstats.InsertPlayerLogLink(self:GetParent().renderName)
		end
	end)
	titleLinkButton:SetScript("OnEnter", function(self)
		local linkName = self:GetParent().renderName
		if not linkName or linkName == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(linkName, 0.0, 0.75, 1.0)
		GameTooltip:AddLine("Shift-click or right-click to link these logs in chat.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	titleLinkButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	panel.titleLinkButton = titleLinkButton

	local logLinkButton = CreateFrame("Button", nil, panel)
	SetFrameSize(logLinkButton, 32, 16)
	logLinkButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -34, -9)
	logLinkButton:SetFrameLevel(panel:GetFrameLevel() + 9)
	logLinkButton:SetNormalTexture("Interface\\TradeSkillFrame\\UI-TradeSkill-LinkButton")
	local logLinkNormal = logLinkButton:GetNormalTexture()
	if logLinkNormal then
		logLinkNormal:SetTexCoord(0, 1, 0, 0.5)
	end
	logLinkButton:SetHighlightTexture("Interface\\TradeSkillFrame\\UI-TradeSkill-LinkButton", "ADD")
	local logLinkHighlight = logLinkButton:GetHighlightTexture()
	if logLinkHighlight then
		logLinkHighlight:SetTexCoord(0, 1, 0.5, 1)
	end
	logLinkButton:RegisterForClicks("LeftButtonUp")
	logLinkButton:SetScript("OnClick", function(self)
		coolstats.InsertPlayerLogLink(self:GetParent().renderName)
	end)
	logLinkButton:SetScript("OnEnter", function(self)
		local linkName = self:GetParent().renderName
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Link UwU Logs", 0.0, 0.75, 1.0)
		if linkName and linkName ~= "" then
			GameTooltip:AddLine("Insert [coolstats: " .. linkName .. "] into chat.", 0.86, 0.86, 0.78, true)
		end
		GameTooltip:Show()
	end)
	logLinkButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	logLinkButton:Hide()
	panel.logLinkButton = logLinkButton

	local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
	subtitle:SetWidth(UWU_INSPECT_PANEL_WIDTH - 16)
	subtitle:SetJustifyH("CENTER")
	subtitle:SetTextColor(0.82, 0.82, 0.76)
	subtitle:SetText("UwU Logs")
	panel.subtitle = subtitle

	panel.specButtons = {}
	for index = 1, 3 do
		local button = CreateFrame("CheckButton", nil, panel)
		SetFrameSize(button, UWU_INSPECT_SPEC_TAB_SIZE, UWU_INSPECT_SPEC_TAB_SIZE)
		button:SetPoint("TOPLEFT", panel, "TOPRIGHT", UWU_INSPECT_SPEC_TAB_LEFT, UWU_INSPECT_SPEC_TAB_TOP - ((index - 1) * UWU_INSPECT_SPEC_TAB_SPACING))
		button:SetFrameLevel(panel:GetFrameLevel() + 7)
		button:RegisterForClicks("LeftButtonUp")

		local tabBackground = button:CreateTexture(nil, "BACKGROUND")
		tabBackground:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
		SetFrameSize(tabBackground, 64, 64)
		tabBackground:SetPoint("TOPLEFT", button, "TOPLEFT", UWU_INSPECT_SPEC_TAB_BG_LEFT, UWU_INSPECT_SPEC_TAB_BG_TOP)
		button.tabBackground = tabBackground

		button:SetNormalTexture("Interface\\Icons\\Ability_Marksmanship")
		local normalTexture = button:GetNormalTexture()
		if normalTexture then
			normalTexture:SetAllPoints(button)
		end

		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		local highlightTexture = button:GetHighlightTexture()
		if highlightTexture then
			highlightTexture:SetAllPoints(button)
		end

		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
		local checkedTexture = button:GetCheckedTexture()
		if checkedTexture then
			checkedTexture:SetAllPoints(button)
		end

		button:SetScript("OnClick", InspectPanelSpecButton_OnClick)
		button:SetScript("OnEnter", InspectPanelSpecButton_OnEnter)
		button:SetScript("OnLeave", InspectPanelSpecButton_OnLeave)
		button:Hide()
		panel.specButtons[index] = button
	end

	panel.rows = {}
	for index = 1, UWU_INSPECT_ROW_COUNT do
		local row = CreateFrame("Button", nil, panel)
		SetFrameSize(row, UWU_INSPECT_ROW_WIDTH, UWU_INSPECT_ROW_HEIGHT)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", UWU_INSPECT_ROW_LEFT, -44 - ((index - 1) * UWU_INSPECT_ROW_HEIGHT))
		row:EnableMouse(false)
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", function(self, button)
			coolstats.TouchManagedWindowOwner(self.uwuPanel)
			if button == "LeftButton" and self.uwuCollapseRaid then
				ToggleInspectPanelRaid(self.uwuPanel, self.uwuCollapseRaid)
			end
		end)

		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.05, 0.06, 0.07, 0.10)
		bg:Hide()
		row.bg = bg

		local headerRight = row:CreateTexture(nil, "ARTWORK")
		headerRight:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
		SetFrameSize(headerRight, 31, UWU_INSPECT_ROW_HEIGHT)
		headerRight:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		headerRight:SetTexCoord(0, 0.14453125, 0.296875, 0.578125)
		headerRight:Hide()
		row.headerRight = headerRight

		local headerLeft = row:CreateTexture(nil, "ARTWORK")
		headerLeft:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
		headerLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
		headerLeft:SetPoint("BOTTOMRIGHT", headerRight, "BOTTOMLEFT", 0, 0)
		headerLeft:SetTexCoord(0, 1, 0, 0.28125)
		headerLeft:Hide()
		row.headerLeft = headerLeft

		row:SetHighlightTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton", "ADD")
		local highlight = row:GetHighlightTexture()
		if highlight then
			highlight:ClearAllPoints()
			highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)
			highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 2)
			highlight:SetTexCoord(0, 1, 0.609375, 0.796875)
		end

		local headerText = row:CreateFontString(nil, "OVERLAY")
		headerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
		headerText:SetPoint("CENTER", row, "CENTER", 0, 0)
		headerText:SetWidth(UWU_INSPECT_ROW_WIDTH - 32)
		headerText:SetJustifyH("CENTER")
		headerText:SetTextColor(1, 0.82, 0)
		headerText:SetShadowOffset(1, -1)
		headerText:SetShadowColor(0, 0, 0, 1)
		headerText:Hide()
		row.headerText = headerText

		local headerToggle = row:CreateTexture(nil, "OVERLAY")
		headerToggle:SetTexture("Interface\\Buttons\\UI-PlusMinus-Buttons")
		SetFrameSize(headerToggle, 7, 7)
		headerToggle:SetPoint("RIGHT", row, "RIGHT", -9, 0)
		headerToggle:SetTexCoord(0.5625, 1, 0, 0.4375)
		headerToggle:Hide()
		row.headerToggle = headerToggle

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", row, "LEFT", UWU_INSPECT_TEXT_LEFT, 0)
		label:SetWidth(UWU_INSPECT_LABEL_WIDTH)
		label:SetHeight(UWU_INSPECT_ROW_HEIGHT)
		label:SetJustifyH("LEFT")
		if label.SetWordWrap then
			label:SetWordWrap(false)
		end
		if label.SetNonSpaceWrap then
			label:SetNonSpaceWrap(false)
		end
		label:SetTextColor(0.86, 0.86, 0.78)
		label:Hide()
		row.label = label

		local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		value:SetPoint("RIGHT", row, "RIGHT", UWU_INSPECT_TEXT_RIGHT, 0)
		value:SetWidth(UWU_INSPECT_VALUE_WIDTH)
		value:SetJustifyH("RIGHT")
		value:SetTextColor(1, 1, 1)
		value:Hide()
		row.value = value

		local parse = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		parse:SetPoint("LEFT", row, "LEFT", UWU_INSPECT_PARSE_LEFT, 0)
		parse:SetWidth(UWU_INSPECT_PARSE_WIDTH)
		parse:SetJustifyH("RIGHT")
		parse:Hide()
		row.parse = parse

		local playerRank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		playerRank:SetPoint("LEFT", row, "LEFT", UWU_INSPECT_PLAYER_RANK_LEFT, 0)
		playerRank:SetWidth(UWU_INSPECT_RANK_WIDTH)
		playerRank:SetJustifyH("RIGHT")
		playerRank:Hide()
		row.playerRank = playerRank

		local raidRank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		raidRank:SetPoint("LEFT", row, "LEFT", UWU_INSPECT_RAID_RANK_LEFT, 0)
		raidRank:SetWidth(UWU_INSPECT_RANK_WIDTH)
		raidRank:SetJustifyH("RIGHT")
		raidRank:Hide()
		row.raidRank = raidRank

		local dps = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		dps:SetPoint("RIGHT", row, "RIGHT", UWU_INSPECT_TEXT_RIGHT, 0)
		dps:SetWidth(UWU_INSPECT_DPS_WIDTH)
		dps:SetJustifyH("RIGHT")
		dps:Hide()
		row.dps = dps

		row:Hide()
		panel.rows[index] = row
	end

	return panel
end

local function CreateInspectUwUPanel()
	if inspectUwUPanel or not InspectFrame then
		return
	end
	inspectUwUPanel = CreateUwUPanel("coolstatsUwUInspectPanel", InspectFrame, InspectFrame, false)
	inspectUwUPanel.isInspectPanel = true

	local close = CreateFrame("Button", nil, inspectUwUPanel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", inspectUwUPanel, "TOPRIGHT", -3, -4)
	close:SetScript("OnClick", function()
		inspectUwUPanel.dismissedName = NormalizeName(inspectUwUPanel.renderName or "")
		inspectUwUPanel:Hide()
	end)
	inspectUwUPanel.close = close
end

local function CreateLookupUwUPanel()
	if lookupUwUPanel then
		return
	end
	lookupUwUPanel = CreateUwUPanel("coolstatsUwULookupPanel", UIParent, nil, true)
end

function coolstats.ResizeUwUPanelForRows(panel, state)
	local visibleRows = math.max(0, ((state and state.index) or 1) - 1)
	local requiredHeight = 68 + (visibleRows * UWU_INSPECT_ROW_HEIGHT)
	SetFrameSize(panel, UWU_INSPECT_PANEL_WIDTH, math.max(UWU_INSPECT_PANEL_HEIGHT, requiredHeight))
end

RenderUwUPanel = function(panel, name, player, subtitle)
	if not panel then
		return
	end

	local wasShown = panel:IsShown()
	panel:Show()
	if panel.playTalentPanelSounds and (not wasShown or panel.forceTalentPanelOpenSound) and PlaySound then
		PlaySound("igCharacterInfoOpen")
	end
	panel.forceTalentPanelOpenSound = nil
	panel.renderName = name
	panel.renderPlayer = player
	panel.renderSubtitle = subtitle
	if panel.logLinkButton then
		if player and name and name ~= "" then
			panel.logLinkButton:Show()
		else
			panel.logLinkButton:Hide()
		end
	end
	SetFrameSize(panel, UWU_INSPECT_PANEL_WIDTH, UWU_INSPECT_PANEL_HEIGHT)
	UpdateCachedGearPanel(panel, name, player)
	for index = 1, #panel.rows do
		panel.rows[index]:Hide()
	end

	if not player then
		HideInspectPanelSpecButtons(panel)
		panel.title:SetText(name or "No player")
		panel.title:SetTextColor(ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B)
		panel.subtitle:SetText(subtitle or "UwU Logs")
		local state = { rows = panel.rows, index = 1, stripeIndex = 1, panel = panel }
		AddInspectPanelSection(state, "Summary")
		AddInspectPanelLine(state, "Raid Score", "Not ranked", 0.45, 0.45, 0.45)
		coolstats.ResizeUwUPanelForRows(panel, state)
		return
	end

	local state = { rows = panel.rows, index = 1, stripeIndex = 1, panel = panel }
	local selectedSpecIndex = GetInspectPanelSelectedSpecIndex(panel, player)
	local scoreCenti = GetUwUSpecScoreCenti(player, selectedSpecIndex) or player[2]
	local currentPhaseRanked = coolstats.IsUwUPlayerRankedForCurrentPhase(player)
	local red, green, blue = 0.45, 0.45, 0.45
	if currentPhaseRanked then
		red, green, blue = GetUwUScoreColor(scoreCenti)
	end
	local specName = GetUwUSpecName(player, selectedSpecIndex) or "Unknown"
	local rank = GetUwUSpecRank(player, selectedSpecIndex)
	local classFile = UWU_CLASS_FILE_BY_INDEX[player[3]]
	local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	local titleText = (player[1] or name or "Unknown") .. " - " .. specName
	if currentPhaseRanked and rank then
		titleText = titleText .. " #" .. tostring(rank)
	end
	panel.title:SetText(titleText)
	if classColor then
		panel.title:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		panel.title:SetTextColor(red, green, blue)
	end
	panel.subtitle:SetText(subtitle or "UwU Logs")
	UpdateInspectPanelSpecButtons(panel, player, selectedSpecIndex)
	AddInspectPanelSection(state, "Summary")
	AddInspectPanelLine(state, "Raid Score", currentPhaseRanked and FormatUwUScoreWithRank(scoreCenti, rank) or "Not ranked", red, green, blue)
	local historicalScore, historicalRank = coolstats.GetUwUHistoricalOverall(player)
	if historicalScore then
		local historicalRed, historicalGreen, historicalBlue = GetUwUScoreColor(historicalScore)
		AddInspectPanelLine(state, coolstats.GetUwUHistoricalOverallLabel(), FormatUwUScoreWithRank(historicalScore, historicalRank), historicalRed, historicalGreen, historicalBlue)
	end
	AddInspectPanelLine(state, "Spec", specName, classColor and classColor.r or 1.0, classColor and classColor.g or 1.0, classColor and classColor.b or 1.0)
	if selectedSpecIndex ~= player[4] then
		AddInspectPanelLine(state, "Best Spec", GetUwUSpecName(player) or "Unknown", classColor and classColor.r or 1.0, classColor and classColor.g or 1.0, classColor and classColor.b or 1.0)
	end

	if currentPhaseRanked then
		AddInspectPanelSection(state, "Specs")
	end
	local classSpecs = coolstatsUwUData and coolstatsUwUData.specs and coolstatsUwUData.specs[player[3]]
	local specScores = player[6]
	local specRanks = player[7]
	if currentPhaseRanked and classSpecs and specScores then
		for specIndex = 1, 3 do
			local specScore = specScores[specIndex]
			if specScore and classSpecs[specIndex] then
				local specRed, specGreen, specBlue = GetUwUScoreColor(specScore)
				local specRank = specRanks and specRanks[specIndex]
				local labelR, labelG, labelB = 0.86, 0.86, 0.78
				if specIndex == selectedSpecIndex then
					labelR, labelG, labelB = 1.0, 0.82, 0
				end
				AddInspectPanelLine(state, classSpecs[specIndex], FormatUwUScoreWithRank(specScore, specRank), specRed, specGreen, specBlue, labelR, labelG, labelB)
			end
		end
	end

	local bossData = GetUwUSpecBossData(player, selectedSpecIndex)
	local currentRaidName = nil
	local currentRaidCollapsed = false
	if coolstatsUwUData and coolstatsUwUData.bosses then
		for bossIndex = 1, #coolstatsUwUData.bosses do
			local bossName = coolstatsUwUData.bosses[bossIndex]
			if bossName then
				local raidName = GetUwUBossRaidName(bossName)
				if raidName ~= currentRaidName then
					currentRaidCollapsed = AddInspectPanelSection(state, raidName, raidName)
					if not currentRaidCollapsed then
						AddInspectPanelColumns(state)
					end
					currentRaidName = raidName
				end

				if not currentRaidCollapsed then
					local entry = bossData and bossData[bossIndex]
					AddInspectPanelBoss(state, bossName, entry)
				end
			end
		end
	end
end

UpdateInspectUwUPanel = function()
	CreateInspectUwUPanel()
	if not inspectUwUPanel then
		return
	end

	if not InspectFrame or not InspectFrame:IsShown() then
		inspectUwUPanel:Hide()
		return
	end

	local unit = GetInspectUwUUnit()
	CacheInspectGearForUnit(unit)
	local name = unit and UnitName(unit)
	local normalizedName = NormalizeName(name or "")
	if inspectUwUPanel.dismissedName == normalizedName then
		inspectUwUPanel:Hide()
		return
	end
	inspectUwUPanel.dismissedName = nil
	local player = name and GetUwUPlayerByName(name)
	RenderUwUPanel(inspectUwUPanel, name or "No inspected player", player, GetUnitGuildNameText(unit) or "UwU Logs")
end

local function ShowUwULogsPanelForName(name)
	CreateLookupUwUPanel()
	if not lookupUwUPanel then
		return false
	end

	local lookupName = tostring(name or "")
	lookupName = string.gsub(lookupName, "^%s+", "")
	lookupName = string.gsub(lookupName, "%s+$", "")
	if lookupName == "" then
		lookupName = UnitName("target") or UnitName("player") or "Unknown"
	end

	local player = GetUwUPlayerByName(lookupName)
	CacheGearForLookupName(player and player[1] or lookupName)
	lookupUwUPanel.forceTalentPanelOpenSound = true
	RenderUwUPanel(lookupUwUPanel, lookupName, player, "UwU Logs Lookup")
	coolstats.TouchManagedWindow(lookupUwUPanel)
	return player ~= nil, player and player[1] or lookupName
end

function coolstats.CreateLogsComparePanel()
	if coolstats.logsComparePanel then
		return coolstats.logsComparePanel
	end

	local panel = CreateFrame("Frame", "coolstatsLogsComparePanel", UIParent)
	coolstats.logsComparePanel = panel
	SetFrameSize(panel, 780, 520)
	panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(90)
	if panel.SetToplevel then
		panel:SetToplevel(true)
	end
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	if panel.SetClampedToScreen then
		panel:SetClampedToScreen(true)
	end
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = false,
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	panel:SetBackdropColor(0.02, 0.018, 0.014, 0.98)
	panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
	if coolstats.ApplyTabardPanelBackground then
		coolstats.ApplyTabardPanelBackground(panel, 0.72, 0.48)
	end

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", panel, "TOP", 0, -13)
	title:SetText("Logs Compare")
	title:SetTextColor(0.0, 0.75, 1.0)
	panel.title = title

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function()
		panel:Hide()
	end)

	local leftPanel = CreateUwUPanel(nil, panel, nil, false)
	leftPanel:ClearAllPoints()
	leftPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -48)
	leftPanel:SetFrameStrata("DIALOG")
	leftPanel:SetFrameLevel(panel:GetFrameLevel() + 1)
	leftPanel.coolstatsManagedWindowOwner = panel
	leftPanel:SetScript("OnMouseDown", function()
		coolstats.TouchManagedWindow(panel)
	end)
	panel.leftPanel = leftPanel

	local rightPanel = CreateUwUPanel(nil, panel, nil, false)
	rightPanel:ClearAllPoints()
	rightPanel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -45, -48)
	rightPanel:SetFrameStrata("DIALOG")
	rightPanel:SetFrameLevel(panel:GetFrameLevel() + 2)
	rightPanel.coolstatsManagedWindowOwner = panel
	rightPanel:SetScript("OnMouseDown", function()
		coolstats.TouchManagedWindow(panel)
	end)
	panel.rightPanel = rightPanel
	panel.coolstatsManagedChildren = { leftPanel, rightPanel }

	panel:SetScript("OnShow", function(self)
		self.wasShownOnce = true
		if PlaySound then
			PlaySound("igCharacterInfoOpen")
		end
	end)
	panel:SetScript("OnHide", function(self)
		if self.wasShownOnce and PlaySound then
			PlaySound("igCharacterInfoClose")
		end
	end)
	coolstats.RegisterManagedWindow(panel)
	panel:Hide()
	return panel
end

function coolstats.OpenLogsCompareWithName(name)
	local compareName = tostring(name or "")
	compareName = string.gsub(compareName, "^%s+", "")
	compareName = string.gsub(compareName, "%s+$", "")
	if compareName == "" then
		return false
	end

	local panel = coolstats.CreateLogsComparePanel()
	local playerName = UnitName("player") or "You"
	local selfPlayer = GetUwUPlayerByName(playerName)
	local comparePlayer = GetUwUPlayerByName(compareName)
	ResetInspectPanelSelectedSpec(panel.leftPanel)
	ResetInspectPanelSelectedSpec(panel.rightPanel)
	RenderUwUPanel(panel.leftPanel, playerName, selfPlayer, "Your Logs")
	RenderUwUPanel(panel.rightPanel, compareName, comparePlayer, "Compared Player")
	panel:Show()
	coolstats.TouchManagedWindow(panel)
	return comparePlayer ~= nil
end

function coolstats.FormatLogAnalysisDifference(value, suffix)
	value = tonumber(value) or 0
	local prefix = value > 0 and "+" or ""
	return prefix .. string.format("%.2f", value) .. tostring(suffix or "")
end

function coolstats.GetLogAnalysisDifferenceColor(value)
	value = tonumber(value) or 0
	if value > 0 then
		return 0.25, 1.0, 0.25
	elseif value < 0 then
		return 1.0, 0.3, 0.25
	end
	return 0.72, 0.72, 0.68
end

function coolstats.CanOpenLogAnalysisWithName(name)
	local selfPlayer = GetUwUPlayerByName(UnitName("player") or "")
	local comparePlayer = GetUwUPlayerByName(name)
	if not selfPlayer then
		return false, "Your character needs logs before it can be compared."
	end
	if not comparePlayer then
		return false, "This player does not have logs in the current database."
	end
	if selfPlayer[3] ~= comparePlayer[3] then
		return false, "Log Analysis is only available for players of your class."
	end
	return true, nil, selfPlayer, comparePlayer
end

function coolstats.LogAnalysisSpecButton_OnEnter(self)
	if not self.specName then
		return
	end
	GameTooltip:SetOwner(self, self.analysisSide == "self" and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
	GameTooltip:AddLine((self.analysisSide == "self" and "Your " or "Their ") .. self.specName, 1.0, 0.82, 0)
	local red, green, blue = GetUwUScoreColor(self.scoreCenti)
	GameTooltip:AddDoubleLine("Raid Score", FormatUwUScoreWithRank(self.scoreCenti, self.rank), ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, red, green, blue)
	GameTooltip:Show()
end

function coolstats.LogAnalysisSpecButton_OnClick(self)
	local panel = self.analysisPanel
	if not panel or not self.specIndex then
		return
	end
	if self.analysisSide == "self" then
		panel.selfSpecIndex = self.specIndex
	else
		panel.compareSpecIndex = self.specIndex
	end
	if PlaySound then
		PlaySound("igCharacterInfoTab")
	end
	coolstats.RenderLogAnalysisPanel(panel)
end

function coolstats.UpdateLogAnalysisSpecButtons(panel, side, player, selectedSpecIndex)
	local buttons = side == "self" and panel.selfSpecButtons or panel.compareSpecButtons
	local choices = player and BuildUwUSpecChoices(player) or {}
	for index = 1, #buttons do
		local button = buttons[index]
		local choice = choices[index]
		if choice then
			button.analysisPanel = panel
			button.analysisSide = side
			button.specIndex = choice.specIndex
			button.specName = choice.name
			button.scoreCenti = choice.scoreCenti
			button.rank = choice.rank
			button:SetNormalTexture(GetUwUSpecIcon(player, choice.specIndex, nil))
			local texture = button:GetNormalTexture()
			if texture then
				texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			button:SetChecked(choice.specIndex == selectedSpecIndex)
			button:SetAlpha(choice.specIndex == selectedSpecIndex and 1.0 or 0.68)
			button:Show()
		else
			button:Hide()
		end
	end
end

function coolstats.AcquireLogAnalysisChartDot(chart, index)
	local dot = chart.dots[index]
	if dot then
		return dot
	end
	dot = CreateFrame("Button", nil, chart)
	SetFrameSize(dot, 9, 9)
	local texture = dot:CreateTexture(nil, "OVERLAY")
	texture:SetTexture("Interface\\Buttons\\WHITE8X8")
	texture:SetAllPoints(dot)
	dot.texture = texture
	dot:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.playerLabel or "Player", self.red or 1, self.green or 1, self.blue or 1)
		GameTooltip:AddDoubleLine(self.bossLabel or "Boss", self.parseText or "-", 0.86, 0.86, 0.78, self.red or 1, self.green or 1, self.blue or 1)
		if self.comparisonParseText then
			GameTooltip:AddDoubleLine("Parse vs " .. tostring(self.comparisonLabel or "other player"), self.comparisonParseText, 0.78, 0.78, 0.72, self.comparisonParseRed, self.comparisonParseGreen, self.comparisonParseBlue)
		end
		if self.dpsText then
			GameTooltip:AddDoubleLine("DPS", self.dpsText, 0.78, 0.78, 0.72, self.red or 1, self.green or 1, self.blue or 1)
		end
		if self.comparisonDpsText then
			GameTooltip:AddDoubleLine("DPS vs " .. tostring(self.comparisonLabel or "other player"), self.comparisonDpsText, 0.78, 0.78, 0.72, self.comparisonDpsRed, self.comparisonDpsGreen, self.comparisonDpsBlue)
		end
		GameTooltip:Show()
	end)
	dot:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	chart.dots[index] = dot
	return dot
end

function coolstats.AcquireLogAnalysisCurvePoint(chart, index)
	local point = chart.curvePoints[index]
	if point then
		return point
	end
	point = chart:CreateTexture(nil, "ARTWORK")
	point:SetTexture("Interface\\Buttons\\WHITE8X8")
	SetFrameSize(point, 2, 2)
	chart.curvePoints[index] = point
	return point
end

function coolstats.AcquireLogAnalysisBossLabel(chart, index)
	local label = chart.bossLabels[index]
	if label then
		return label
	end
	label = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetWidth(28)
	label:SetJustifyH("CENTER")
	label:SetTextColor(0.72, 0.72, 0.68)
	chart.bossLabels[index] = label
	return label
end

function coolstats.GetLogAnalysisMainRaidBossIndexes()
	local indexes = {}
	local data = coolstatsUwUData
	local mainRaidName = data and data.defaultRaidName
	for bossIndex, bossName in ipairs((data and data.bosses) or {}) do
		if GetUwUBossRaidName(bossName) == mainRaidName then
			indexes[#indexes + 1] = bossIndex
		end
	end
	return indexes
end

function coolstats.AddLogAnalysisCurveRun(chart, run, red, green, blue, startPointIndex)
	if #run < 2 then
		return startPointIndex
	end
	local samplesPerSegment = 18
	for index = 1, #run - 1 do
		local p0 = run[math.max(1, index - 1)]
		local p1 = run[index]
		local p2 = run[index + 1]
		local p3 = run[math.min(#run, index + 2)]
		for sample = 0, samplesPerSegment - 1 do
			local t = sample / samplesPerSegment
			local t2 = t * t
			local t3 = t2 * t
			local x = 0.5 * (
				(2 * p1.x)
				+ ((-p0.x + p2.x) * t)
				+ ((2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2)
				+ ((-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
			)
			local y = 0.5 * (
				(2 * p1.y)
				+ ((-p0.y + p2.y) * t)
				+ ((2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2)
				+ ((-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
			)
			y = math.max(chart.plotBottom or y, math.min(chart.plotTop or y, y))
			startPointIndex = startPointIndex + 1
			local point = coolstats.AcquireLogAnalysisCurvePoint(chart, startPointIndex)
			point:ClearAllPoints()
			point:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
			point:SetVertexColor(red, green, blue, 0.90)
			point:Show()
		end
	end
	startPointIndex = startPointIndex + 1
	local final = run[#run]
	local point = coolstats.AcquireLogAnalysisCurvePoint(chart, startPointIndex)
	point:ClearAllPoints()
	point:SetPoint("CENTER", chart, "BOTTOMLEFT", final.x, final.y)
	point:SetVertexColor(red, green, blue, 0.90)
	point:Show()
	return startPointIndex
end

function coolstats.RenderLogAnalysisChart(panel, selfPlayer, comparePlayer, selfBosses, compareBosses)
	local chart = panel.chart
	if not chart then
		return
	end
	for _, dot in ipairs(chart.dots) do
		dot:Hide()
	end
	for _, point in ipairs(chart.curvePoints) do
		point:Hide()
	end
	for _, label in ipairs(chart.bossLabels) do
		label:Hide()
	end

	local mainRaidBossIndexes = coolstats.GetLogAnalysisMainRaidBossIndexes()
	local bossCount = #mainRaidBossIndexes
	local plotLeft = 46
	local plotRight = 882
	local plotBottom = 36
	local plotTop = 140
	local plotWidth = plotRight - plotLeft
	local plotHeight = plotTop - plotBottom
	chart.plotBottom = plotBottom
	chart.plotTop = plotTop
	local selfScore = GetUwUSpecScoreCenti(selfPlayer, panel.selfSpecIndex)
	local compareScore = GetUwUSpecScoreCenti(comparePlayer, panel.compareSpecIndex)
	local selfR, selfG, selfB = 0.05, 0.52, 1.0
	local compareR, compareG, compareB = 1.0, 0.78, 0.28
	local lowestScore = nil
	for _, bossIndex in ipairs(mainRaidBossIndexes) do
		for _, bosses in ipairs({ selfBosses, compareBosses }) do
			local score = GetUwUBossScoreCenti(bosses[bossIndex])
			if score and (not lowestScore or score < lowestScore) then
				lowestScore = score
			end
		end
	end
	local axisMinimum = lowestScore and math.max(0, (math.floor(lowestScore / 500) * 500) - 500) or 0
	if axisMinimum >= 10000 then
		axisMinimum = 9500
	end
	chart.axisMinimumCenti = axisMinimum
	local axisRange = math.max(500, 10000 - axisMinimum)
	local axisStep = math.max(500, math.ceil((axisRange / 4) / 500) * 500)
	local axisValues = {}
	local axisValue = axisMinimum
	while axisValue < 10000 and #axisValues < 5 do
		axisValues[#axisValues + 1] = axisValue
		axisValue = axisValue + axisStep
	end
	axisValues[#axisValues + 1] = 10000
	for index = 1, #chart.axisLabels do
		local label = chart.axisLabels[index]
		local grid = chart.axisGrids[index]
		local value = axisValues[index]
		if value then
			local y = plotBottom + (((value - axisMinimum) / axisRange) * plotHeight)
			grid:ClearAllPoints()
			grid:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", plotLeft, y)
			grid:SetPoint("BOTTOMRIGHT", chart, "BOTTOMRIGHT", -18, y)
			label:ClearAllPoints()
			label:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", 8, y - 6)
			label:SetText(tostring(math.floor((value / 100) + 0.5)))
			grid:Show()
			label:Show()
		else
			grid:Hide()
			label:Hide()
		end
	end
	chart.selfLegend:SetText((selfPlayer[1] or "You") .. " " .. FormatUwUScore(selfScore))
	chart.selfLegend:SetTextColor(selfR, selfG, selfB)
	chart.compareLegend:SetText((comparePlayer[1] or "Compared") .. " " .. FormatUwUScore(compareScore))
	chart.compareLegend:SetTextColor(compareR, compareG, compareB)
	for chartIndex, bossIndex in ipairs(mainRaidBossIndexes) do
		local bossName = coolstatsUwUData.bosses[bossIndex]
		local x = bossCount > 1 and (plotLeft + (((chartIndex - 1) / (bossCount - 1)) * plotWidth)) or (plotLeft + (plotWidth / 2))
		local label = coolstats.AcquireLogAnalysisBossLabel(chart, chartIndex)
		label:ClearAllPoints()
		label:SetPoint("CENTER", chart, "BOTTOMLEFT", x, 25)
		label:SetText(coolstats.UWU_BOSS_CHART_ABBREVIATIONS[bossName] or string.upper(string.sub(GetUwUBossDisplayName(bossName), 1, 2)))
		label:Show()
	end

	local dotIndex = 0
	local curvePointIndex = 0
	for seriesIndex, series in ipairs({
		{ player = selfPlayer, bosses = selfBosses, otherPlayer = comparePlayer, otherBosses = compareBosses, red = selfR, green = selfG, blue = selfB },
		{ player = comparePlayer, bosses = compareBosses, otherPlayer = selfPlayer, otherBosses = selfBosses, red = compareR, green = compareG, blue = compareB },
	}) do
		local run = {}
		for chartIndex, bossIndex in ipairs(mainRaidBossIndexes) do
			local bossName = coolstatsUwUData.bosses[bossIndex]
			local score = GetUwUBossScoreCenti(series.bosses[bossIndex])
			if score then
				local otherScore = GetUwUBossScoreCenti(series.otherBosses[bossIndex])
				local ownDps = tonumber(GetUwUBossDps(series.bosses[bossIndex])) or 0
				local otherDps = tonumber(GetUwUBossDps(series.otherBosses[bossIndex])) or 0
				local x = bossCount > 1 and (plotLeft + (((chartIndex - 1) / (bossCount - 1)) * plotWidth)) or (plotLeft + (plotWidth / 2))
				local y = plotBottom + ((math.max(axisMinimum, math.min(10000, score)) - axisMinimum) / axisRange * plotHeight)
				run[#run + 1] = { x = x, y = y }
				dotIndex = dotIndex + 1
				local dot = coolstats.AcquireLogAnalysisChartDot(chart, dotIndex)
				dot:ClearAllPoints()
				dot:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
				dot.texture:SetVertexColor(series.red, series.green, series.blue, 1)
				dot.playerLabel = series.player[1]
				dot.bossLabel = GetUwUBossDisplayLabel(bossName)
				dot.parseText = FormatUwUScore(score)
				dot.red, dot.green, dot.blue = series.red, series.green, series.blue
				dot.comparisonLabel = series.otherPlayer[1] or "other player"
				dot.comparisonParseText = nil
				dot.comparisonDpsText = nil
				dot.dpsText = ownDps > 0 and FormatUwUDps(ownDps) or nil
				if otherScore then
					local parseDifference = (score - otherScore) / 100
					dot.comparisonParseText = coolstats.FormatLogAnalysisDifference(parseDifference)
					dot.comparisonParseRed, dot.comparisonParseGreen, dot.comparisonParseBlue = coolstats.GetLogAnalysisDifferenceColor(parseDifference)
				end
				if ownDps > 0 and otherDps > 0 then
					local dpsDifference = ((ownDps - otherDps) / otherDps) * 100
					dot.comparisonDpsText = coolstats.FormatLogAnalysisDifference(dpsDifference, "%")
					dot.comparisonDpsRed, dot.comparisonDpsGreen, dot.comparisonDpsBlue = coolstats.GetLogAnalysisDifferenceColor(dpsDifference)
				end
				dot:Show()
			else
				curvePointIndex = coolstats.AddLogAnalysisCurveRun(chart, run, series.red, series.green, series.blue, curvePointIndex)
				run = {}
			end
		end
		curvePointIndex = coolstats.AddLogAnalysisCurveRun(chart, run, series.red, series.green, series.blue, curvePointIndex)
	end
end

function coolstats.CreateLogAnalysisPanel()
	if coolstats.logAnalysisPanel then
		return coolstats.logAnalysisPanel
	end

	local panel = CreateFrame("Frame", "coolstatsLogAnalysisPanel", UIParent)
	coolstats.logAnalysisPanel = panel
	SetFrameSize(panel, 1000, 720)
	panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(96)
	if panel.SetToplevel then
		panel:SetToplevel(true)
	end
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	if panel.SetClampedToScreen then
		panel:SetClampedToScreen(true)
	end
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = false,
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	panel:SetBackdropColor(0.02, 0.018, 0.014, 0.98)
	panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
	if coolstats.ApplyTabardPanelBackground then
		coolstats.ApplyTabardPanelBackground(panel, 0.76, 0.52)
	end

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function()
		panel:Hide()
	end)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", panel, "TOP", 0, -14)
	title:SetText("Log Analysis")
	title:SetTextColor(0.0, 0.75, 1.0)
	panel.title = title

	local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
	subtitle:SetWidth(900)
	subtitle:SetJustifyH("CENTER")
	subtitle:SetTextColor(0.78, 0.78, 0.72)
	panel.subtitle = subtitle

	local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	summary:SetPoint("TOP", subtitle, "BOTTOM", 0, -8)
	summary:SetWidth(900)
	summary:SetJustifyH("CENTER")
	summary:SetTextColor(1.0, 0.82, 0.16)
	panel.summary = summary

	local columns = {
		{ "Boss", 0, 210, "CENTER" },
		{ "Your Parse", 210, 110, "CENTER" },
		{ "Their Parse", 320, 110, "CENTER" },
		{ "Parse Diff", 430, 110, "CENTER" },
		{ "Your DPS", 540, 110, "CENTER" },
		{ "Their DPS", 650, 110, "CENTER" },
		{ "DPS Diff", 760, 140, "CENTER" },
	}
	panel.analysisColumns = columns

	local chartHeader = CreateFrame("Frame", nil, panel)
	SetFrameSize(chartHeader, 900, 18)
	chartHeader:SetPoint("BOTTOM", panel, "BOTTOM", 0, 188)
	coolstats.ApplyCachedPlayerBrowserHeaderBackground(chartHeader)
	local chartHeaderText = chartHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	chartHeaderText:SetAllPoints(chartHeader)
	chartHeaderText:SetJustifyH("CENTER")
	chartHeaderText:SetText("Parse Comparison")
	chartHeaderText:SetTextColor(1.0, 0.82, 0.0)

	local chart = CreateFrame("Frame", nil, panel)
	SetFrameSize(chart, 900, 160)
	chart:SetPoint("BOTTOM", panel, "BOTTOM", 0, 20)
	chart:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	chart:SetBackdropColor(0.02, 0.018, 0.014, 0.90)
	chart:SetBackdropBorderColor(0.35, 0.42, 0.45, 0.90)
	chart.dots = {}
	chart.curvePoints = {}
	chart.bossLabels = {}
	chart.axisGrids = {}
	chart.axisLabels = {}
	for index = 1, 6 do
		local grid = chart:CreateTexture(nil, "BACKGROUND")
		grid:SetTexture("Interface\\Buttons\\WHITE8X8")
		grid:SetHeight(1)
		grid:SetVertexColor(0.45, 0.45, 0.45, index == 1 and 0.40 or 0.18)
		local label = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetWidth(30)
		label:SetJustifyH("RIGHT")
		label:SetTextColor(0.62, 0.62, 0.58)
		chart.axisGrids[index] = grid
		chart.axisLabels[index] = label
	end
	local selfLegend = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	selfLegend:SetPoint("BOTTOMRIGHT", chart, "BOTTOM", -10, 8)
	selfLegend:SetWidth(360)
	selfLegend:SetJustifyH("RIGHT")
	chart.selfLegend = selfLegend
	local compareLegend = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	compareLegend:SetPoint("BOTTOMLEFT", chart, "BOTTOM", 10, 8)
	compareLegend:SetWidth(360)
	compareLegend:SetJustifyH("LEFT")
	chart.compareLegend = compareLegend
	panel.chart = chart

	panel.selfSpecButtons = {}
	panel.compareSpecButtons = {}
	panel.specButtons = {}
	for index = 1, 3 do
		for _, side in ipairs({ "self", "compare" }) do
			local button = CreateFrame("CheckButton", nil, panel)
			SetFrameSize(button, 34, 34)
			if side == "self" then
				button:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -108 - ((index - 1) * 38))
				panel.selfSpecButtons[index] = button
			else
				button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -108 - ((index - 1) * 38))
				panel.compareSpecButtons[index] = button
			end
			button.analysisSide = side
			button.analysisPanel = panel
			button:SetFrameLevel(panel:GetFrameLevel() + 7)
			button:RegisterForClicks("LeftButtonUp")
			local tabBackground = button:CreateTexture(nil, "BACKGROUND")
			tabBackground:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
			SetFrameSize(tabBackground, 64, 64)
			tabBackground:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 11)
			button.tabBackground = tabBackground
			button:SetNormalTexture("Interface\\Icons\\Ability_Marksmanship")
			local normalTexture = button:GetNormalTexture()
			if normalTexture then
				normalTexture:SetAllPoints(button)
			end
			button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			local highlightTexture = button:GetHighlightTexture()
			if highlightTexture then
				highlightTexture:SetAllPoints(button)
			end
			button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
			local checkedTexture = button:GetCheckedTexture()
			if checkedTexture then
				checkedTexture:SetAllPoints(button)
			end
			button:SetScript("OnClick", coolstats.LogAnalysisSpecButton_OnClick)
			button:SetScript("OnEnter", coolstats.LogAnalysisSpecButton_OnEnter)
			button:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			panel.specButtons[#panel.specButtons + 1] = button
		end
	end

	panel.rows = {}
	for index = 1, 32 do
		local row = CreateFrame("Frame", nil, panel)
		SetFrameSize(row, 900, 18)
		row:SetPoint("TOP", panel, "TOP", 0, -92 - ((index - 1) * 18))
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(index % 2 == 0 and 0.28 or 0.05, index % 2 == 0 and 0.27 or 0.06, index % 2 == 0 and 0.25 or 0.07, index % 2 == 0 and 0.24 or 0.12)
		row.bg = bg
		row.values = {}
		for columnIndex, column in ipairs(columns) do
			local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			text:SetPoint("LEFT", row, "LEFT", column[2], 0)
			text:SetWidth(column[3])
			text:SetJustifyH(column[4])
			row.values[columnIndex] = text
		end
		local raidHeader = CreateFrame("Frame", nil, row)
		raidHeader:SetAllPoints(row)
		coolstats.ApplyCachedPlayerBrowserHeaderBackground(raidHeader)
		local raidHeaderText = raidHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		raidHeaderText:SetAllPoints(raidHeader)
		raidHeaderText:SetJustifyH("CENTER")
		raidHeaderText:SetTextColor(1.0, 0.82, 0.0)
		raidHeader.text = raidHeaderText
		raidHeader:Hide()
		row.raidHeader = raidHeader
		row:Hide()
		panel.rows[index] = row
	end

	panel:SetScript("OnShow", function()
		if PlaySound then
			PlaySound("igCharacterInfoOpen")
		end
	end)
	panel:SetScript("OnHide", function()
		if PlaySound then
			PlaySound("igCharacterInfoClose")
		end
	end)
	coolstats.RegisterManagedWindow(panel)
	panel:Hide()
	return panel
end

function coolstats.RenderLogAnalysisPanel(panel)
	if not panel or not panel.selfPlayer or not panel.comparePlayer then
		return
	end
	local panelHeight = coolstats.GetActiveUwUPhaseId and coolstats.GetActiveUwUPhaseId() == "toc" and 860 or 720
	SetFrameSize(panel, 1000, panelHeight)
	if panel.SetScale and UIParent and UIParent.GetHeight then
		local parentHeight = tonumber(UIParent:GetHeight())
		panel:SetScale(parentHeight and parentHeight > 0 and math.min(1, (parentHeight - 20) / panelHeight) or 1)
	end
	local selfPlayer = panel.selfPlayer
	local comparePlayer = panel.comparePlayer
	local selfName = selfPlayer[1] or UnitName("player") or "You"
	local compareName = comparePlayer[1] or panel.compareName or "Player"
	local selfSpec = panel.selfSpecIndex or selfPlayer[4]
	local compareSpec = panel.compareSpecIndex or comparePlayer[4]
	local selfBosses = GetUwUSpecBossData(selfPlayer, selfSpec) or {}
	local compareBosses = GetUwUSpecBossData(comparePlayer, compareSpec) or {}
	coolstats.UpdateLogAnalysisSpecButtons(panel, "self", selfPlayer, selfSpec)
	coolstats.UpdateLogAnalysisSpecButtons(panel, "compare", comparePlayer, compareSpec)
	panel.subtitle:SetText(
		selfName
			.. " ("
			.. tostring(GetUwUSpecName(selfPlayer, selfSpec) or "Unknown")
			.. ") vs "
			.. compareName
			.. " ("
			.. tostring(GetUwUSpecName(comparePlayer, compareSpec) or "Unknown")
			.. ")"
	)

	local compared = 0
	local parseDifferenceTotal = 0
	local dpsDifferenceTotal = 0
	for index = 1, #panel.rows do
		panel.rows[index].raidHeader:Hide()
		panel.rows[index]:Hide()
	end
	coolstats.RenderLogAnalysisChart(panel, selfPlayer, comparePlayer, selfBosses, compareBosses)
	local rowIndex = 0
	local currentRaidName = nil
	for bossIndex, bossName in ipairs((coolstatsUwUData and coolstatsUwUData.bosses) or {}) do
		local selfEntry = selfBosses[bossIndex]
		local compareEntry = compareBosses[bossIndex]
		local selfParse = GetUwUBossScoreCenti(selfEntry)
		local compareParse = GetUwUBossScoreCenti(compareEntry)
		local raidName = GetUwUBossRaidName(bossName)
		if raidName ~= currentRaidName and rowIndex < #panel.rows then
			rowIndex = rowIndex + 1
			local raidRow = panel.rows[rowIndex]
			raidRow.analysisType = "raid"
			raidRow.raidHeader.text:SetText(raidName)
			raidRow.raidHeader:Show()
			for valueIndex = 1, #raidRow.values do
				raidRow.values[valueIndex]:SetText("")
			end
			raidRow:Show()
			currentRaidName = raidName
			if rowIndex < #panel.rows then
				rowIndex = rowIndex + 1
				local columnRow = panel.rows[rowIndex]
				columnRow.analysisType = "columns"
				columnRow.raidHeader:Hide()
				columnRow.bg:SetVertexColor(0.08, 0.08, 0.08, 0.42)
				for valueIndex, column in ipairs(panel.analysisColumns) do
					columnRow.values[valueIndex]:SetText(column[1])
					columnRow.values[valueIndex]:SetTextColor(0.86, 0.86, 0.78)
				end
				columnRow:Show()
			end
		end
		if rowIndex < #panel.rows then
			rowIndex = rowIndex + 1
			local row = panel.rows[rowIndex]
			row.analysisType = "boss"
			row.raidHeader:Hide()
			if (rowIndex % 2) == 0 then
				row.bg:SetVertexColor(0.28, 0.27, 0.25, 0.24)
			else
				row.bg:SetVertexColor(0.05, 0.06, 0.07, 0.12)
			end
			local selfDps = tonumber(GetUwUBossDps(selfEntry)) or 0
			local compareDps = tonumber(GetUwUBossDps(compareEntry)) or 0
			local parseDiff = selfParse and compareParse and ((selfParse - compareParse) / 100) or nil
			local dpsDiff = selfDps > 0 and compareDps > 0 and (selfDps - compareDps) or nil
			local dpsPercent = dpsDiff and (dpsDiff / compareDps) * 100 or nil
			row.values[1]:SetText(GetUwUBossDisplayLabel(bossName))
			row.values[1]:SetTextColor(0.86, 0.86, 0.78)
			row.values[2]:SetText(selfParse and FormatUwUScore(selfParse) or "-")
			row.values[3]:SetText(compareParse and FormatUwUScore(compareParse) or "-")
			row.values[4]:SetText(parseDiff and coolstats.FormatLogAnalysisDifference(parseDiff) or "-")
			row.values[5]:SetText(selfDps > 0 and FormatUwUDps(selfDps) or "-")
			row.values[6]:SetText(compareDps > 0 and FormatUwUDps(compareDps) or "-")
			row.values[7]:SetText(dpsPercent and coolstats.FormatLogAnalysisDifference(dpsPercent, "%") or "-")
			local selfR, selfG, selfB = 0.45, 0.45, 0.45
			local compareR, compareG, compareB = 0.45, 0.45, 0.45
			if selfParse then
				selfR, selfG, selfB = GetUwUScoreColor(selfParse)
			end
			if compareParse then
				compareR, compareG, compareB = GetUwUScoreColor(compareParse)
			end
			row.values[2]:SetTextColor(selfR, selfG, selfB)
			row.values[5]:SetTextColor(selfR, selfG, selfB)
			row.values[3]:SetTextColor(compareR, compareG, compareB)
			row.values[6]:SetTextColor(compareR, compareG, compareB)
			local parseR, parseG, parseB = coolstats.GetLogAnalysisDifferenceColor(parseDiff)
			local dpsR, dpsG, dpsB = coolstats.GetLogAnalysisDifferenceColor(dpsPercent)
			row.values[4]:SetTextColor(parseR, parseG, parseB)
			row.values[7]:SetTextColor(dpsR, dpsG, dpsB)
			row:Show()
		end
		if selfParse and compareParse then
			compared = compared + 1
			local selfDps = tonumber(GetUwUBossDps(selfEntry)) or 0
			local compareDps = tonumber(GetUwUBossDps(compareEntry)) or 0
			local parseDiff = (selfParse - compareParse) / 100
			local dpsPercent = selfDps > 0 and compareDps > 0 and ((selfDps - compareDps) / compareDps) * 100 or 0
			parseDifferenceTotal = parseDifferenceTotal + parseDiff
			dpsDifferenceTotal = dpsDifferenceTotal + dpsPercent
		end
	end

	if compared > 0 then
		panel.summary:SetText(string.format("%d shared bosses   Your average parse advantage %s   Your average DPS advantage %s", compared, coolstats.FormatLogAnalysisDifference(parseDifferenceTotal / compared), coolstats.FormatLogAnalysisDifference(dpsDifferenceTotal / compared, "%")))
	else
		panel.summary:SetText("No shared boss parses are available for these two players.")
	end
end

function coolstats.OpenLogAnalysisWithName(name)
	local allowed, reason, selfPlayer, comparePlayer = coolstats.CanOpenLogAnalysisWithName(name)
	if not allowed then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00c0ffcoolstats:|r " .. tostring(reason or "Log Analysis is unavailable."))
		end
		return false
	end

	local panel = coolstats.CreateLogAnalysisPanel()
	panel.selfPlayer = selfPlayer
	panel.comparePlayer = comparePlayer
	panel.compareName = name
	panel.selfSpecIndex = selfPlayer[4]
	panel.compareSpecIndex = comparePlayer[4]
	coolstats.RenderLogAnalysisPanel(panel)
	panel:Show()
	coolstats.TouchManagedWindow(panel)
	return true
end

local function HookInspectUwUPanel()
	if not InspectFrame or InspectFrame.__coolstatsUwUInspectHooked then
		return
	end
	InspectFrame.__coolstatsUwUInspectHooked = true
	InspectFrame:HookScript("OnShow", function()
		CreateInspectUwUPanel()
		if inspectUwUPanel then
			inspectUwUPanel.dismissedName = nil
		end
		UpdateInspectUwUPanel()
	end)
	InspectFrame:HookScript("OnHide", function()
		if inspectUwUPanel then
			inspectUwUPanel.dismissedName = nil
			inspectUwUPanel:Hide()
		end
	end)
	CreateInspectUwUPanel()
end

if type(coolstats) == "table" then
	function coolstats.ShowUwULogsPanelForName(name)
		return ShowUwULogsPanelForName(name)
	end

	function coolstats.GetUwULogsScoreForName(name)
		local player = GetUwUPlayerByName(name)
		if not player then
			return nil
		end
		local specName = GetUwUSpecName(player) or "Unknown"
		return FormatUwUScore(player[2]), specName, player[5], player[1]
	end

	function coolstats.GetCachedTalentsGroup(snapshot, groupIndex)
		local groups = coolstats.GetCachedTalentGroups(snapshot)
		if type(groups) ~= "table" then
			return nil
		end
		groupIndex = tonumber(groupIndex) or 1
		return groups[groupIndex] or groups[1]
	end

	function coolstats.CachedTalentButton_OnEnter(self)
		if not self.talentName and not self.talentLink then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.talentLink and GameTooltip.SetHyperlink then
			GameTooltip:SetHyperlink(self.talentLink)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Shift-click to link this talent in chat.", 0.62, 0.62, 0.58, true)
			GameTooltip:Show()
			return
		end
		if not self.talentName then
			return
		end
		GameTooltip:SetText(self.talentName, 1, 0.82, 0.16)
		GameTooltip:AddDoubleLine("Rank", tostring(self.rank or 0) .. "/" .. tostring(self.maxRank or 0), 0.86, 0.86, 0.78, 1, 1, 1)
		if self.tabName then
			GameTooltip:AddDoubleLine("Tree", self.tabName, 0.86, 0.86, 0.78, 1, 1, 1)
		end
		if self.playerName then
			GameTooltip:AddLine(self.playerName .. " cached talent snapshot", 0.62, 0.62, 0.58, true)
		end
		GameTooltip:AddLine("Shift-click to link this talent in chat.", 0.62, 0.62, 0.58, true)
		GameTooltip:Show()
	end

	function coolstats.CachedTalentButton_OnLeave()
		GameTooltip:Hide()
	end

	function coolstats.CachedTalentButton_OnClick(self)
		coolstats.TouchManagedWindowOwner(self.cachedTalentPanel)
		if self.talentLink and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
			ChatEdit_InsertLink(self.talentLink)
		end
	end

	function coolstats.HideCachedTalentButtons(panel)
		if not panel or not panel.talentButtons then
			return
		end
		for index = 1, #panel.talentButtons do
			panel.talentButtons[index]:Hide()
		end
	end

	function coolstats.ApplyTabardPanelBackground(panel, alpha, shadeAlpha)
		if not panel then
			return
		end
		if not panel.coolstatsTabardBackground then
			local background = panel:CreateTexture(nil, "BACKGROUND")
			background:SetTexture("Interface\\TabardFrame\\TabardFrameBackground")
			background:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
			background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
			background:SetTexCoord(0.05, 0.95, 0.08, 0.92)
			panel.coolstatsTabardBackground = background
			local shade = panel:CreateTexture(nil, "BACKGROUND")
			shade:SetTexture("Interface\\Buttons\\WHITE8X8")
			shade:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
			shade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
			panel.coolstatsTabardShade = shade
		end
		panel.coolstatsTabardBackground:SetVertexColor(0.72, 0.72, 0.68, alpha or 0.82)
		panel.coolstatsTabardBackground:Show()
		panel.coolstatsTabardShade:SetVertexColor(0, 0, 0, shadeAlpha or 0.54)
		panel.coolstatsTabardShade:Show()
	end

	function coolstats.HideCachedTalentLines(panel)
		if not panel or not panel.talentLines then
			return
		end
		for index = 1, #panel.talentLines do
			panel.talentLines[index]:Hide()
		end
		panel.nextTalentLineIndex = 1
	end

	function coolstats.AcquireCachedTalentLine(panel)
		panel.talentLines = panel.talentLines or {}
		panel.nextTalentLineIndex = panel.nextTalentLineIndex or 1
		local index = panel.nextTalentLineIndex
		panel.nextTalentLineIndex = index + 1
		local line = panel.talentLines[index]
		if line then
			return line
		end
		line = panel:CreateTexture(nil, "ARTWORK")
		line:SetTexture("Interface\\Buttons\\WHITE8X8")
		panel.talentLines[index] = line
		return line
	end

	function coolstats.AcquireCachedTalentArrow(panel)
		panel.talentArrows = panel.talentArrows or {}
		panel.nextTalentArrowIndex = panel.nextTalentArrowIndex or 1
		local index = panel.nextTalentArrowIndex
		panel.nextTalentArrowIndex = index + 1
		local arrow = panel.talentArrows[index]
		if arrow then
			return arrow
		end
		arrow = panel:CreateTexture(nil, "OVERLAY")
		arrow:SetTexture("Interface\\TalentFrame\\UI-TalentFrame-Arrow")
		panel.talentArrows[index] = arrow
		return arrow
	end

	function coolstats.HideCachedTalentArrows(panel)
		if not panel or not panel.talentArrows then
			return
		end
		for index = 1, #panel.talentArrows do
			panel.talentArrows[index]:Hide()
		end
		panel.nextTalentArrowIndex = 1
	end

	function coolstats.AddCachedTalentLine(panel, tree, x1, y1, x2, y2, active)
		if not panel or not tree then
			return
		end
		local red, green, blue, alpha = 0.88, 0.72, 0.12, 0.88
		if not active then
			red, green, blue, alpha = 0.45, 0.45, 0.42, 0.52
		end
		local function AddSegment(left, top, width, height)
			local line = coolstats.AcquireCachedTalentLine(panel)
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", tree, "TOPLEFT", left, top)
			SetFrameSize(line, math.max(2, width), math.max(2, height))
			line:SetVertexColor(red, green, blue, alpha)
			line:Show()
		end
		if math.abs(x1 - x2) > 2 then
			AddSegment(math.min(x1, x2), y2 + 1, math.abs(x2 - x1), 3)
		end
		AddSegment(x1 - 1, math.max(y1, y2), 3, math.abs(y2 - y1))
		local arrow = coolstats.AcquireCachedTalentArrow(panel)
		arrow:ClearAllPoints()
		arrow:SetPoint("CENTER", tree, "TOPLEFT", x2, y2 + 3)
		SetFrameSize(arrow, 16, 16)
		arrow:SetVertexColor(red, green, blue, alpha)
		arrow:Show()
	end

	function coolstats.GetCachedTalentButtonPosition(talent)
		local column = math.max(1, math.min(4, tonumber(coolstats.GetCachedTalentValue(talent, "column", 4)) or 1))
		local tier = math.max(1, tonumber(coolstats.GetCachedTalentValue(talent, "tier", 3)) or 1)
		return 22 + ((column - 1) * 58), -48 - ((tier - 1) * 45)
	end

	function coolstats.SyncCachedTalentPanelFrameLevels(panel)
		if not panel then
			return
		end
		local baseLevel = panel:GetFrameLevel()
		for _, tree in ipairs(panel.trees or {}) do
			tree:SetFrameLevel(baseLevel + 1)
		end
		for _, button in ipairs(panel.talentButtons or {}) do
			button:SetFrameLevel(baseLevel + 6)
		end
		for _, button in ipairs(panel.groupButtons or {}) do
			button:SetFrameLevel(baseLevel + 7)
		end
	end

	function coolstats.FindCachedTalentPrerequisite(talent, talentByPosition)
		if not talent or not talentByPosition then
			return nil
		end
		local prereqTier = coolstats.GetCachedTalentValue(talent, "prereqTier", 8)
		local prereqColumn = coolstats.GetCachedTalentValue(talent, "prereqColumn", 9)
		if prereqTier and prereqColumn then
			return talentByPosition[tostring(prereqTier) .. ":" .. tostring(prereqColumn)], prereqTier, prereqColumn
		end
		if (tonumber(coolstats.GetCachedTalentValue(talent, "rank", 5)) or 0) <= 0 then
			return nil
		end
		local tier = tonumber(coolstats.GetCachedTalentValue(talent, "tier", 3)) or 1
		local column = tonumber(coolstats.GetCachedTalentValue(talent, "column", 4)) or 1
		for candidateTier = tier - 1, 1, -1 do
			local candidate = talentByPosition[tostring(candidateTier) .. ":" .. tostring(column)]
			if candidate and (tonumber(coolstats.GetCachedTalentValue(candidate, "rank", 5)) or 0) > 0 then
				return candidate, candidateTier, column
			end
		end
		return nil
	end

	function coolstats.ApplyCachedTalentTreeBackground(tree, background)
		if not tree then
			return
		end
		if not tree.backgroundPieces then
			tree.backgroundPieces = {}
			for index = 1, 4 do
				tree.backgroundPieces[index] = tree:CreateTexture(nil, "BACKGROUND")
			end
			local shade = tree:CreateTexture(nil, "BORDER")
			shade:SetTexture("Interface\\Buttons\\WHITE8X8")
			shade:SetPoint("TOPLEFT", tree, "TOPLEFT", 4, -28)
			shade:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", -4, 4)
			tree.backgroundShade = shade
		end
		if not background or background == "" then
			for index = 1, #tree.backgroundPieces do
				tree.backgroundPieces[index]:Hide()
			end
			tree.backgroundShade:Hide()
			return
		end
		local base = "Interface\\TalentFrame\\" .. background .. "-"
		local pieces = tree.backgroundPieces
		local areaLeft, areaTop = 4, -26
		local areaWidth, areaHeight = math.max(1, (tree:GetWidth() or 188) - 8), math.max(1, (tree:GetHeight() or 344) - 30)
		local sourceWidth, sourceHeight = 300, 331
		local scale = math.max(areaWidth / sourceWidth, areaHeight / sourceHeight) * 1.12
		local displayWidth, displayHeight = sourceWidth * scale, sourceHeight * scale
		local offsetX = areaLeft + ((areaWidth - displayWidth) * 0.5)
		local offsetY = areaTop - ((areaHeight - displayHeight) * 0.5)
		local cropLeft = math.max(0, -((offsetX - areaLeft) / scale))
		local cropTop = math.max(0, ((offsetY - areaTop) / scale))
		local cropRight = math.min(sourceWidth, cropLeft + (areaWidth / scale))
		local cropBottom = math.min(sourceHeight, cropTop + (areaHeight / scale))
		local pieceData = {
			{ texture = base .. "TopLeft", sx1 = 0, sy1 = 0, sx2 = 256, sy2 = 256, texWidth = 256, texHeight = 256 },
			{ texture = base .. "TopRight", sx1 = 256, sy1 = 0, sx2 = 300, sy2 = 256, texWidth = 64, texHeight = 256 },
			{ texture = base .. "BottomLeft", sx1 = 0, sy1 = 256, sx2 = 256, sy2 = 331, texWidth = 256, texHeight = 128 },
			{ texture = base .. "BottomRight", sx1 = 256, sy1 = 256, sx2 = 300, sy2 = 331, texWidth = 64, texHeight = 128 },
		}
		for index = 1, #pieces do
			local piece = pieces[index]
			local data = pieceData[index]
			local sourceLeft = math.max(cropLeft, data.sx1)
			local sourceTop = math.max(cropTop, data.sy1)
			local sourceRight = math.min(cropRight, data.sx2)
			local sourceBottom = math.min(cropBottom, data.sy2)
			piece:ClearAllPoints()
			if sourceRight > sourceLeft and sourceBottom > sourceTop then
				piece:SetTexture(data.texture)
				piece:SetPoint("TOPLEFT", tree, "TOPLEFT", areaLeft + ((sourceLeft - cropLeft) * scale), areaTop - ((sourceTop - cropTop) * scale))
				SetFrameSize(piece, (sourceRight - sourceLeft) * scale + 1, (sourceBottom - sourceTop) * scale + 1)
				piece:SetTexCoord((sourceLeft - data.sx1) / data.texWidth, (sourceRight - data.sx1) / data.texWidth, (sourceTop - data.sy1) / data.texHeight, (sourceBottom - data.sy1) / data.texHeight)
				piece:SetAlpha(0.92)
				piece:Show()
			else
				piece:Hide()
			end
		end
		tree.backgroundShade:SetVertexColor(0, 0, 0, 0.24)
		tree.backgroundShade:Show()
	end

	function coolstats.AcquireCachedTalentButton(panel, index)
		panel.talentButtons = panel.talentButtons or {}
		local button = panel.talentButtons[index]
		if button then
			return button
		end
		button = CreateFrame("Button", nil, panel)
		SetFrameSize(button, 42, 42)
		button:SetFrameLevel(panel:GetFrameLevel() + 6)
		button.cachedTalentPanel = panel
		button:RegisterForClicks("LeftButtonUp")
		button:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		local normal = button:GetNormalTexture()
		if normal then
			normal:ClearAllPoints()
			normal:SetPoint("CENTER", button, "CENTER", 0, 0)
			SetFrameSize(normal, 34, 34)
			normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		local border = button:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
		SetFrameSize(border, 64, 64)
		border:SetPoint("CENTER", button, "CENTER", 0, 0)
		border:SetVertexColor(0.95, 0.82, 0.36, 0.95)
		button.border = border
		local rank = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		rank:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		rank:SetTextColor(1, 0.82, 0.16)
		rank:SetShadowOffset(1, -1)
		rank:SetShadowColor(0, 0, 0, 1)
		button.rankText = rank
		button:SetScript("OnClick", coolstats.CachedTalentButton_OnClick)
		button:SetScript("OnEnter", coolstats.CachedTalentButton_OnEnter)
		button:SetScript("OnLeave", coolstats.CachedTalentButton_OnLeave)
		panel.talentButtons[index] = button
		return button
	end

	function coolstats.GetCachedTalentGroupSummary(group)
		local bestTab
		local bestPoints = -1
		local totalPoints = 0
		if group and type(group.tabs) == "table" then
			for index = 1, #group.tabs do
				local tab = group.tabs[index]
				local points = tonumber(tab and tab.points) or 0
				totalPoints = totalPoints + points
				if points > bestPoints then
					bestPoints = points
					bestTab = tab
				end
			end
		end
		return bestTab and bestTab.icon or "Interface\\Icons\\INV_Misc_QuestionMark", bestTab and bestTab.name or "Talent Set", math.max(0, bestPoints), totalPoints
	end

	function coolstats.CachedTalentGroupButton_OnClick(self)
		local panel = self.cachedTalentPanel
		if not panel or not self.groupIndex then
			return
		end
		coolstats.TouchManagedWindowOwner(panel)
		panel.selectedGroupIndex = self.groupIndex
		if PlaySound then
			PlaySound("igCharacterInfoTab")
		end
		coolstats.RenderCachedTalentsPanel(panel, panel.snapshot)
	end

	function coolstats.CachedTalentGroupButton_OnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.groupName or "Talent Set", 1, 0.82, 0.16)
		if self.totalPoints then
			GameTooltip:AddDoubleLine("Points", tostring(self.totalPoints), 0.86, 0.86, 0.78, 1, 1, 1)
		end
		if self.groupActive then
			GameTooltip:AddLine("Active when cached", 0.25, 1, 0.25)
		end
		GameTooltip:AddLine("Click to view this cached talent set.", 0.62, 0.62, 0.58, true)
		GameTooltip:Show()
	end

	function coolstats.CachedTalentGroupButton_OnLeave()
		GameTooltip:Hide()
	end

	function coolstats.CreateCachedTalentsPanel()
		if coolstats.cachedTalentsPanel then
			return coolstats.cachedTalentsPanel
		end

		local panel = CreateFrame("Frame", "coolstatsCachedTalentsPanel", UIParent)
		coolstats.cachedTalentsPanel = panel
		SetFrameSize(panel, 860, 650)
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		panel:SetFrameStrata("DIALOG")
		panel:SetFrameLevel(95)
		if panel.SetToplevel then
			panel:SetToplevel(true)
		end
		panel:SetMovable(true)
		panel:EnableMouse(true)
		panel:RegisterForDrag("LeftButton")
		panel:SetScript("OnMouseDown", function(self)
			self:SetFrameStrata("DIALOG")
			self:SetFrameLevel(110)
			coolstats.SyncCachedTalentPanelFrameLevels(self)
		end)
		panel:SetScript("OnShow", function(self)
			self.wasShownOnce = true
			coolstats.SyncCachedTalentPanelFrameLevels(self)
		end)
		panel:SetScript("OnHide", function(self)
			if self.wasShownOnce and PlaySound then
				PlaySound("igCharacterInfoClose")
			end
		end)
		panel:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		panel:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
		end)
		if panel.SetClampedToScreen then
			panel:SetClampedToScreen(true)
		end
		panel:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = false,
			tileSize = 32,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		})
		panel:SetBackdropColor(0.02, 0.018, 0.014, 0.98)
		panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
		coolstats.ApplyTabardPanelBackground(panel, 0.78, 0.52)

		local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
		close:SetScript("OnClick", function()
			panel:Hide()
		end)
		if UISpecialFrames then
			local registered = false
			for index = 1, #UISpecialFrames do
				if UISpecialFrames[index] == "coolstatsCachedTalentsPanel" then
					registered = true
					break
				end
			end
			if not registered then
				table.insert(UISpecialFrames, "coolstatsCachedTalentsPanel")
			end
		end
		coolstats.RegisterManagedWindow(panel)

		local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", panel, "TOP", 0, -14)
		title:SetWidth(820)
		title:SetJustifyH("CENTER")
		title:SetTextColor(0.0, 0.75, 1.0)
		panel.title = title

		local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
		subtitle:SetWidth(820)
		subtitle:SetJustifyH("CENTER")
		subtitle:SetTextColor(0.78, 0.78, 0.72)
		panel.subtitle = subtitle

		local emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		emptyText:SetPoint("CENTER", panel, "CENTER", 0, -8)
		emptyText:SetWidth(710)
		emptyText:SetJustifyH("CENTER")
		emptyText:SetTextColor(0.86, 0.86, 0.78)
		emptyText:SetText("No cached talents for this player yet.\n\nInspect, interact with, or be in range of that player to cache their talents.")
		emptyText:Hide()
		panel.emptyText = emptyText

		panel.groupButtons = {}
		for index = 1, 2 do
			local button = CreateFrame("CheckButton", nil, panel)
			SetFrameSize(button, UWU_INSPECT_SPEC_TAB_SIZE, UWU_INSPECT_SPEC_TAB_SIZE)
			button:SetPoint("TOPLEFT", panel, "TOPRIGHT", UWU_INSPECT_SPEC_TAB_LEFT, -86 - ((index - 1) * UWU_INSPECT_SPEC_TAB_SPACING))
			button:SetFrameLevel(panel:GetFrameLevel() + 7)
			button.groupIndex = index
			button.cachedTalentPanel = panel

			local tabBackground = button:CreateTexture(nil, "BACKGROUND")
			tabBackground:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
			SetFrameSize(tabBackground, 64, 64)
			tabBackground:SetPoint("TOPLEFT", button, "TOPLEFT", UWU_INSPECT_SPEC_TAB_BG_LEFT, UWU_INSPECT_SPEC_TAB_BG_TOP)
			button.tabBackground = tabBackground

			button:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			local normalTexture = button:GetNormalTexture()
			if normalTexture then
				normalTexture:SetAllPoints(button)
				normalTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end

			button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			local highlightTexture = button:GetHighlightTexture()
			if highlightTexture then
				highlightTexture:SetAllPoints(button)
			end

			button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
			local checkedTexture = button:GetCheckedTexture()
			if checkedTexture then
				checkedTexture:SetAllPoints(button)
			end

			button:SetScript("OnClick", coolstats.CachedTalentGroupButton_OnClick)
			button:SetScript("OnEnter", coolstats.CachedTalentGroupButton_OnEnter)
			button:SetScript("OnLeave", coolstats.CachedTalentGroupButton_OnLeave)
			button:Hide()
			panel.groupButtons[index] = button
		end

		panel.trees = {}
		for index = 1, 3 do
			local tree = CreateFrame("Frame", nil, panel)
			SetFrameSize(tree, 250, 548)
			tree:SetFrameLevel(panel:GetFrameLevel() + 1)
			tree:SetPoint("TOPLEFT", panel, "TOPLEFT", 30 + ((index - 1) * 280), -78)
			tree:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = false,
				edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			tree:SetBackdropColor(0, 0, 0, 0.12)
			tree:SetBackdropBorderColor(0.38, 0.36, 0.32, 0.9)
			local header = tree:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			header:SetPoint("TOP", tree, "TOP", 0, -8)
			header:SetWidth(234)
			header:SetJustifyH("CENTER")
			header:SetTextColor(1, 0.82, 0)
			tree.header = header
			panel.trees[index] = tree
		end

		panel.talentButtons = {}
		coolstats.SyncCachedTalentPanelFrameLevels(panel)
		panel:Hide()
		return panel
	end

	function coolstats.RenderCachedTalentsPanel(panel, snapshot)
		if not panel or not snapshot then
			return
		end
		panel.snapshot = snapshot
		coolstats.SyncCachedTalentPanelFrameLevels(panel)
		panel.displayTalentGroups = coolstats.GetCachedTalentGroups(snapshot)
		local selectedGroupIndex = panel.selectedGroupIndex or 1
		local group = panel.displayTalentGroups and (panel.displayTalentGroups[selectedGroupIndex] or panel.displayTalentGroups[1])
		if not group then
			selectedGroupIndex = 1
			group = panel.displayTalentGroups and panel.displayTalentGroups[1]
		end
		panel.selectedGroupIndex = selectedGroupIndex
		panel.title:SetText(snapshot.name or "Unknown")
		if snapshot.referenceOnly then
			panel.subtitle:SetText("Class talent reference - allocation not cached")
		elseif snapshot.missing then
			panel.subtitle:SetText("No cached talents")
		else
			panel.subtitle:SetText(FormatCachedGearDateTime(snapshot.seenAt))
		end

		for index = 1, 2 do
			local button = panel.groupButtons[index]
			local candidate = panel.displayTalentGroups and panel.displayTalentGroups[index]
			if candidate then
				local icon, groupName, _, totalPoints = coolstats.GetCachedTalentGroupSummary(candidate)
				button.groupIndex = index
				button.groupName = groupName
				button.totalPoints = totalPoints
				button.groupActive = candidate.active
				local normalTexture = button:GetNormalTexture()
				if normalTexture then
					normalTexture:SetTexture(icon)
					normalTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				else
					button:SetNormalTexture(icon)
				end
				button:SetChecked(index == selectedGroupIndex)
				button:SetAlpha(index == selectedGroupIndex and 1 or 0.72)
				button:Show()
			else
				button.groupName = nil
				button.totalPoints = nil
				button.groupActive = nil
				button:Hide()
			end
		end

		coolstats.HideCachedTalentButtons(panel)
		coolstats.HideCachedTalentLines(panel)
		coolstats.HideCachedTalentArrows(panel)
		if not group then
			for tabIndex = 1, 3 do
				local tree = panel.trees[tabIndex]
				if tree then
					tree.header:SetText("")
					coolstats.ApplyCachedTalentTreeBackground(tree, nil)
					tree:Hide()
				end
			end
			if panel.emptyText then
				panel.emptyText:SetText(snapshot.emptyText or "No cached talents for this player yet.\n\nInspect, interact with, or be in range of that player to cache their talents.")
				panel.emptyText:Show()
			end
			return
		elseif panel.emptyText then
			panel.emptyText:Hide()
		end
		local buttonIndex = 1
		for tabIndex = 1, 3 do
			local tree = panel.trees[tabIndex]
			local tab = group and group.tabs and group.tabs[tabIndex]
			if tree and tab then
				tree.header:SetText((tab.name or "Tree") .. " " .. tostring(tab.points or 0))
				coolstats.ApplyCachedTalentTreeBackground(tree, tab.background)
				tree:Show()
				local talents = tab.talents or {}
				for talentIndex = 1, #talents do
					local talent = talents[talentIndex]
					local rankValue = tonumber(coolstats.GetCachedTalentValue(talent, "rank", 5)) or 0
					local maxRankValue = tonumber(coolstats.GetCachedTalentValue(talent, "maxRank", 6)) or 0
					local button = coolstats.AcquireCachedTalentButton(panel, buttonIndex)
					buttonIndex = buttonIndex + 1
					button:ClearAllPoints()
					local x, y = coolstats.GetCachedTalentButtonPosition(talent)
					button:SetPoint("TOPLEFT", tree, "TOPLEFT", x, y)
					button:SetNormalTexture(coolstats.GetCachedTalentValue(talent, "icon", 2) or "Interface\\Icons\\INV_Misc_QuestionMark")
					local normal = button:GetNormalTexture()
					if normal then
						normal:ClearAllPoints()
						normal:SetPoint("CENTER", button, "CENTER", 0, 0)
						SetFrameSize(normal, 34, 34)
						normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
						if normal.SetDesaturated then
							normal:SetDesaturated(rankValue <= 0)
						end
						if rankValue > 0 then
							normal:SetVertexColor(1, 1, 1, 1)
						else
							normal:SetVertexColor(0.58, 0.58, 0.58, 0.72)
						end
					end
					if rankValue > 0 then
						button.rankText:SetText(tostring(rankValue))
						if maxRankValue > 0 and rankValue < maxRankValue then
							button.rankText:SetTextColor(0.25, 1, 0.25)
						else
							button.rankText:SetTextColor(1, 0.82, 0.16)
						end
						button.rankText:Show()
					else
						button.rankText:SetText("")
						button.rankText:Hide()
					end
					if button.border then
						if rankValue > 0 then
							local exceptional = coolstats.GetCachedTalentValue(talent, "exceptional", 7)
							button.border:SetVertexColor(exceptional and 0.55 or 0.95, exceptional and 0.86 or 0.82, exceptional and 1.0 or 0.36, 0.95)
						else
							button.border:SetVertexColor(0.35, 0.35, 0.35, 0.62)
						end
					end
					button.talentName = coolstats.GetCachedTalentValue(talent, "name", 1)
					button.tabName = tab.name
					button.rank = rankValue
					button.maxRank = maxRankValue
					button.talentLink = coolstats.GetCachedTalentValue(talent, "link", 10)
					button.playerName = snapshot.name
					button:Show()
				end
			elseif tree then
				tree.header:SetText("")
				coolstats.ApplyCachedTalentTreeBackground(tree, nil)
				tree:Hide()
			end
		end
	end

	function coolstats.BuildUncachedTalentReferenceSnapshot(name)
		local player = GetUwUPlayerByName and GetUwUPlayerByName(name)
		local gear = GetCachedGearSnapshot(name)
		local classIndex = player and player[3] or gear and gear.classIndex
		local classFile = gear and gear.classFile or UWU_CLASS_FILE_BY_INDEX[classIndex]
		local catalog = coolstats.GetCachedTalentCatalog(classFile)
		if not classFile or not catalog or type(catalog.tabs) ~= "table" then
			return nil
		end
		local talentCount = 0
		for _, tab in ipairs(catalog.tabs) do
			talentCount = talentCount + #(tab.talents or {})
		end
		if talentCount <= 0 then
			return nil
		end
		return {
			name = player and player[1] or gear and gear.name or name,
			classFile = classFile,
			classIndex = classIndex or UWU_CLASS_INDEX_BY_FILE[classFile],
			activeGroup = 1,
			talentVersion = 2,
			rankGroups = { { 1, string.rep("0", talentCount) } },
			referenceOnly = true,
		}
	end

	function coolstats.OpenCachedTalentsForName(name)
		if not name or name == "" then
			return false
		end
		local cached, requested = coolstats.CacheTalentsForLookupName(name)
		local snapshot = cached or coolstats.GetCachedTalentSnapshot(name)
		if not snapshot then
			snapshot = coolstats.BuildUncachedTalentReferenceSnapshot(name)
		end
		if not snapshot then
			snapshot = {
				name = name,
				seenAt = nil,
				activeGroup = 1,
				groups = {},
				missing = true,
				emptyText = requested and "Talent inspect requested.\n\nIf this panel stays empty, inspect, interact with, or be in range of that player to cache their talents." or "No cached talents for this player yet.\n\nInspect, interact with, or be in range of that player to cache their talents.",
			}
			if requested then
				coolstats.pendingCachedTalentsOpenName = name
			end
		elseif requested and snapshot.referenceOnly then
			coolstats.pendingCachedTalentsOpenName = name
		end
		local panel = coolstats.CreateCachedTalentsPanel()
		panel.selectedGroupIndex = snapshot.activeGroup or 1
		coolstats.RenderCachedTalentsPanel(panel, snapshot)
		panel:Show()
		if PlaySound then
			PlaySound(snapshot.missing and "igCharacterInfoOpen" or "igCharacterInfoTab")
		end
		return not snapshot.missing and not snapshot.referenceOnly
	end

	function coolstats.GetCachedPlayerBrowserBestRank(player)
		if not player then
			return nil, nil, nil
		end
		local bestRank = tonumber(player[5])
		local bestSpecIndex = player[4]
		local bestScoreCenti = player[2]
		local specRanks = player[7]
		if type(specRanks) == "table" then
			for specIndex, rank in pairs(specRanks) do
				rank = tonumber(rank)
				if rank and rank > 0 and (not bestRank or rank < bestRank) then
					bestRank = rank
					bestSpecIndex = specIndex
					bestScoreCenti = GetUwUSpecScoreCenti(player, specIndex)
				end
			end
		end
		return bestRank, bestSpecIndex, bestScoreCenti
	end

	function coolstats.IsOnyxiaPhase3Browser()
		local data = coolstatsUwUData
		local realmKey = data and coolstats.NormalizeCachedPlayerRealmKey(data.realm)
		if not realmKey or realmKey == "" then
			realmKey = coolstats.GetCurrentRealmKey and coolstats.GetCurrentRealmKey()
		end
		local phaseId = coolstats.GetActiveUwUPhaseId and coolstats.GetActiveUwUPhaseId()
		return realmKey == "onyxia" and phaseId == "toc"
	end

	function coolstats.GetCachedPlayerBrowserClassName(classIndex)
		local data = coolstatsUwUData
		if data and data.classes and data.classes[classIndex] then
			return data.classes[classIndex]
		end
		return UWU_CLASS_FILE_BY_INDEX[classIndex] or "Unknown"
	end

	function coolstats.GetCachedPlayerBrowserFavorites()
		EnsureTooltipDatabase()
		return coolstatsDB.cachedPlayerBrowserFavorites
	end

	function coolstats.GetCachedPlayerBrowserFavoriteKey(nameOrKey)
		local key = NormalizeName(nameOrKey or "")
		if key == "" then
			return nil
		end
		return key
	end

	function coolstats.IsCachedPlayerBrowserFavorite(nameOrKey)
		local key = coolstats.GetCachedPlayerBrowserFavoriteKey(nameOrKey)
		local favorites = key and coolstats.GetCachedPlayerBrowserFavorites()
		return favorites and favorites[key] == true
	end

	function coolstats.SetCachedPlayerBrowserFavorite(nameOrKey, favorite)
		local key = coolstats.GetCachedPlayerBrowserFavoriteKey(nameOrKey)
		if not key then
			return
		end
		local favorites = coolstats.GetCachedPlayerBrowserFavorites()
		if favorite then
			favorites[key] = true
		else
			favorites[key] = nil
		end
	end

	function coolstats.ToggleCachedPlayerBrowserFavorite(nameOrKey)
		local key = coolstats.GetCachedPlayerBrowserFavoriteKey(nameOrKey)
		if not key then
			return
		end
		local active = not coolstats.IsCachedPlayerBrowserFavorite(key)
		coolstats.SetCachedPlayerBrowserFavorite(key, active)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffcoolstats:|r " .. (active and "favourited " or "removed favourite ") .. (nameOrKey or key) .. ".")
		end
		coolstats.RefreshCachedPlayerBrowser(true)
	end

	function coolstats.IsCachedPlayerBrowserLeapYear(year)
		year = tonumber(year)
		return year and ((year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0)
	end

	function coolstats.GetCachedPlayerBrowserDaysInMonth(year, month)
		local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
		month = tonumber(month)
		if month == 2 and coolstats.IsCachedPlayerBrowserLeapYear(year) then
			return 29
		end
		return days[month or 0] or 31
	end

	function coolstats.ShiftCachedPlayerBrowserTime(year, month, day, hour, minute, offsetHours)
		year = tonumber(year)
		month = tonumber(month)
		day = tonumber(day)
		hour = tonumber(hour)
		minute = tonumber(minute)
		offsetHours = tonumber(offsetHours) or 0
		if not year or not month or not day or not hour or not minute then
			return nil
		end
		hour = hour + offsetHours
		while hour >= 24 do
			hour = hour - 24
			day = day + 1
			if day > coolstats.GetCachedPlayerBrowserDaysInMonth(year, month) then
				day = 1
				month = month + 1
				if month > 12 then
					month = 1
					year = year + 1
				end
			end
		end
		while hour < 0 do
			hour = hour + 24
			day = day - 1
			if day < 1 then
				month = month - 1
				if month < 1 then
					month = 12
					year = year - 1
				end
				day = coolstats.GetCachedPlayerBrowserDaysInMonth(year, month)
			end
		end
		return year, month, day, hour, minute
	end

	function coolstats.FormatCachedPlayerBrowserDateTime(year, month, day, hour, minute)
		return string.format("%02d/%02d/%04d %02d:%02d", month, day, year, hour, minute)
	end

	function coolstats.FormatCachedPlayerBrowserGeneratedAt()
		local generatedAt = coolstatsUwUData and coolstatsUwUData.generatedAt
		if type(generatedAt) ~= "string" or generatedAt == "" then
			return "Last UwU logs refresh: unknown"
		end
		local year, month, day, hour, minute = string.match(generatedAt, "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)")
		if year and month and day and hour and minute then
			local cetYear, cetMonth, cetDay, cetHour, cetMinute = coolstats.ShiftCachedPlayerBrowserTime(year, month, day, hour, minute, 2)
			local serverYear, serverMonth, serverDay, serverHour, serverMinute = coolstats.ShiftCachedPlayerBrowserTime(year, month, day, hour, minute, 0)
			if cetYear and serverYear then
				return "Last UwU logs refresh: " .. coolstats.FormatCachedPlayerBrowserDateTime(cetYear, cetMonth, cetDay, cetHour, cetMinute) .. " CET (Server " .. coolstats.FormatCachedPlayerBrowserDateTime(serverYear, serverMonth, serverDay, serverHour, serverMinute) .. ")"
			end
		end
		return "Last UwU logs refresh: " .. generatedAt
	end

	function coolstats.GetUwULogsDataAgeDays()
		local generatedAt = coolstatsUwUData and coolstatsUwUData.generatedAt
		if type(generatedAt) ~= "string" or generatedAt == "" or type(date) ~= "function" then
			return nil
		end
		local year, month, day, hour, minute = string.match(generatedAt, "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)")
		if not year or not month or not day or not hour or not minute then
			return nil
		end
		local ok, current = pcall(date, "!*t")
		if not ok or type(current) ~= "table" then
			return nil
		end
		local function MinuteStamp(stampYear, stampMonth, stampDay, stampHour, stampMinute)
			stampYear = tonumber(stampYear)
			stampMonth = tonumber(stampMonth)
			stampDay = tonumber(stampDay)
			stampHour = tonumber(stampHour)
			stampMinute = tonumber(stampMinute)
			if not stampYear or not stampMonth or not stampDay or not stampHour or not stampMinute then
				return nil
			end
			local days = 0
			for checkedYear = 1970, stampYear - 1 do
				days = days + (coolstats.IsCachedPlayerBrowserLeapYear(checkedYear) and 366 or 365)
			end
			for checkedMonth = 1, stampMonth - 1 do
				days = days + coolstats.GetCachedPlayerBrowserDaysInMonth(stampYear, checkedMonth)
			end
			days = days + stampDay - 1
			return (days * 1440) + (stampHour * 60) + stampMinute
		end
		local generatedMinutes = MinuteStamp(year, month, day, hour, minute)
		local currentMinutes = MinuteStamp(current.year, current.month, current.day, current.hour, current.min)
		if not generatedMinutes or not currentMinutes then
			return nil
		end
		return math.max(0, math.floor((currentMinutes - generatedMinutes) / 1440))
	end

	function coolstats.GetCachedPlayerBrowserSpecKey(classIndex, specIndex)
		if classIndex == nil or specIndex == nil then
			return nil
		end
		return tostring(classIndex) .. ":" .. tostring(specIndex)
	end

	function coolstats.ParseCachedPlayerBrowserSpecKey(specKey)
		if type(specKey) ~= "string" then
			return nil, nil
		end
		local classText, specText = string.match(specKey, "^(%d+):(%d+)$")
		return tonumber(classText), tonumber(specText)
	end

	function coolstats.GetCachedPlayerBrowserSpecLabel(classIndex, specIndex, includeClass)
		local data = coolstatsUwUData
		local specs = data and data.specs and data.specs[classIndex]
		local specName = specs and specs[specIndex]
		if not specName then
			return nil
		end
		if includeClass then
			return coolstats.GetCachedPlayerBrowserClassName(classIndex) .. " " .. specName
		end
		return specName
	end

	function coolstats.GetCachedPlayerBrowserSpecFilterChoices(panel)
		local choices = {}
		local data = coolstatsUwUData
		if not data or not data.specs then
			return choices
		end
		local classFilter = panel and panel.browserClassFilter
		local function AddClassSpecs(classIndex, includeClass)
			local classSpecs = data.specs[classIndex]
			if not classSpecs then
				return
			end
			for specIndex = 1, 3 do
				local label = coolstats.GetCachedPlayerBrowserSpecLabel(classIndex, specIndex, includeClass)
				if label then
					choices[#choices + 1] = {
						classIndex = classIndex,
						specIndex = specIndex,
						key = coolstats.GetCachedPlayerBrowserSpecKey(classIndex, specIndex),
						label = label,
					}
				end
			end
		end
		if type(classFilter) == "number" then
			AddClassSpecs(classFilter, false)
		else
			for classIndex = 0, 9 do
				AddClassSpecs(classIndex, true)
			end
		end
		return choices
	end

	function coolstats.DoesCachedPlayerBrowserRowMatch(row, filterKey, classFilter, specFilterKey)
		if not row then
			return false
		end
		if classFilter ~= nil then
			if classFilter == "favorites" then
				if not row.isFavorite then
					return false
				end
			elseif row.classIndex ~= classFilter then
				return false
			end
		end
		if specFilterKey then
			local specClassIndex, specIndex = coolstats.ParseCachedPlayerBrowserSpecKey(specFilterKey)
			if specClassIndex and specIndex then
				if row.classIndex ~= specClassIndex then
					return false
				end
				if row.mainSpecIndex ~= specIndex then
					return false
				end
			end
		end
		if filterKey and filterKey ~= "" then
			local nameKey = NormalizeName(row.name or row.key or "")
			local classNameKey = NormalizeName(coolstats.GetCachedPlayerBrowserClassName(row.classIndex))
			local specNameKey = NormalizeName((row.mainSpecName or "") .. " " .. (row.offSpecName or "") .. " " .. (row.bestSpecName or "") .. " " .. (row.specName or ""))
			if string.find(nameKey, filterKey, 1, true) == nil and string.find(classNameKey, filterKey, 1, true) == nil and string.find(specNameKey, filterKey, 1, true) == nil then
				return false
			end
		end
		return true
	end

	function coolstats.GetCachedPlayerBrowserSortValue(row, sortKey)
		if sortKey == "logs" then
			return row.hasLogs and 1 or 0
		elseif sortKey == "gear" then
			return row.hasGear and 1 or 0
		elseif sortKey == "talents" then
			return row.hasTalents and 1 or 0
		elseif sortKey == "main" then
			return tonumber(row.mainSpecScoreCenti) or -1
		elseif sortKey == "off" then
			return tonumber(row.offSpecScoreCenti) or -1
		elseif sortKey == "parses" then
			return tonumber(row.scoreCenti) or -1
		elseif sortKey == "rank" then
			return tonumber(row.bestRank) or 9999999
		elseif sortKey == "phase2" then
			return tonumber(row.phase2ScoreCenti) or -1
		elseif sortKey == "cache" then
			return tonumber(row.seenAt) or 0
		end
		return string.lower(row.name or row.key or "")
	end

	function coolstats.SortCachedPlayerBrowserRows(rows, panel)
		local sortKey = panel and panel.browserSortKey
		local sortState = panel and panel.browserSortState
		local ascending = sortState == "asc"
		if not sortKey or not sortState then
			table.sort(rows, function(left, right)
				if panel and panel.browserPrioritizeFavorites and left.isFavorite ~= right.isFavorite then
					return left.isFavorite == true
				end
				return string.lower(left.name or left.key or "") < string.lower(right.name or right.key or "")
			end)
			return
		end
		table.sort(rows, function(left, right)
			local leftMissing = false
			local rightMissing = false
			if sortKey == "parses" then
				leftMissing = not left.scoreCenti
				rightMissing = not right.scoreCenti
			elseif sortKey == "main" then
				leftMissing = not left.mainSpecScoreCenti
				rightMissing = not right.mainSpecScoreCenti
			elseif sortKey == "off" then
				leftMissing = not left.offSpecScoreCenti
				rightMissing = not right.offSpecScoreCenti
			elseif sortKey == "rank" then
				leftMissing = not left.bestRank
				rightMissing = not right.bestRank
			elseif sortKey == "phase2" then
				leftMissing = not left.phase2ScoreCenti
				rightMissing = not right.phase2ScoreCenti
			elseif sortKey == "cache" then
				leftMissing = not left.seenAt
				rightMissing = not right.seenAt
			end
			if leftMissing ~= rightMissing then
				return not leftMissing
			end
			local leftValue = coolstats.GetCachedPlayerBrowserSortValue(left, sortKey)
			local rightValue = coolstats.GetCachedPlayerBrowserSortValue(right, sortKey)
			if leftValue == rightValue then
				local leftName = string.lower(left.name or left.key or "")
				local rightName = string.lower(right.name or right.key or "")
				return leftName < rightName
			end
			if ascending then
				return leftValue < rightValue
			end
			return leftValue > rightValue
		end)
	end

	function coolstats.GetCachedPlayerBrowserRows(filterText, panel)
		PruneCachedGearCache(false)
		coolstats.PruneCachedTalentCache(false)
		local filterKey = NormalizeName(filterText or "")
		local classFilter = panel and panel.browserClassFilter
		local specFilterKey = panel and panel.browserSpecFilterKey
		if panel then
			panel.browserPrioritizeFavorites = filterKey == "" and classFilter == nil and specFilterKey == nil
		end
		local rowsByKey = {}
		local rows = {}
		local counts = { logs = 0, current = 0, phase2 = 0, gear = 0, talents = 0, both = 0 }

		local function GetRow(key, name)
			key = key or NormalizeName(name or "")
			if key == "" then
				return nil
			end
			local row = rowsByKey[key]
			if not row then
		row = { key = key, name = name or key }
				rowsByKey[key] = row
			elseif name and name ~= "" then
				row.name = name
			end
			return row
		end

		local data = coolstatsUwUData
		if data and data.players then
			for key, player in pairs(data.players) do
				local row = player and GetRow(key, player[1])
				if row then
					row.player = player
					row.hasLogs = true
					row.name = player[1] or row.name
					row.classIndex = player[3]
					row.specIndex = player[4]
					row.specName = GetUwUSpecName(player)
					row.specScores = player[6]
					row.currentPhaseRanked = coolstats.IsUwUPlayerRankedForCurrentPhase(player)
					if row.currentPhaseRanked then
						row.scoreCenti = player[2]
						row.rank = player[5]
						local specChoices = BuildUwUSpecChoices(player)
						local mainSpec = specChoices[1]
						local offSpec = specChoices[2]
						if mainSpec then
							row.mainSpecIndex = mainSpec.specIndex
							row.mainSpecName = mainSpec.name
							row.mainSpecScoreCenti = mainSpec.scoreCenti
						end
						if offSpec then
							row.offSpecIndex = offSpec.specIndex
							row.offSpecName = offSpec.name
							row.offSpecScoreCenti = offSpec.scoreCenti
						end
						row.bestRank, row.bestRankSpecIndex, row.bestRankScoreCenti = coolstats.GetCachedPlayerBrowserBestRank(player)
						row.bestSpecName = GetUwUSpecName(player, row.bestRankSpecIndex)
					end
					row.phase2ScoreCenti, row.phase2Rank = coolstats.GetUwUHistoricalOverall(player)
				end
			end
		end

		local store = GetCachedGearStore()
		if store and store.players then
			for key, snapshot in pairs(store.players) do
				local row = snapshot and GetRow(key, snapshot.name)
				if row then
					row.hasGear = true
					row.name = snapshot.name or row.name
					row.seenAt = snapshot.seenAt
					row.slotCount = snapshot.slotCount
					row.classFile = snapshot.classFile or row.classFile
					row.classIndex = row.classIndex or snapshot.classIndex or (snapshot.classFile and UWU_CLASS_INDEX_BY_FILE[snapshot.classFile])
				end
			end
		end

		local talentStore = coolstats.GetCachedTalentStore()
		if talentStore and talentStore.players then
			for key, snapshot in pairs(talentStore.players) do
				local row = snapshot and coolstats.CachedTalentSnapshotMatchesClass(snapshot) and GetRow(key, snapshot.name)
				if row then
					row.hasTalents = true
					row.name = snapshot.name or row.name
					row.talentsSeenAt = snapshot.seenAt
					row.classFile = snapshot.classFile or row.classFile
					row.classIndex = row.classIndex or snapshot.classIndex or (snapshot.classFile and UWU_CLASS_INDEX_BY_FILE[snapshot.classFile])
				end
			end
		end

		for _, row in pairs(rowsByKey) do
			row.favoriteKey = coolstats.GetCachedPlayerBrowserFavoriteKey(row.key or row.name)
			row.isFavorite = coolstats.IsCachedPlayerBrowserFavorite(row.favoriteKey or row.name)
			if coolstats.DoesCachedPlayerBrowserRowMatch(row, filterKey, classFilter, specFilterKey) then
				rows[#rows + 1] = row
				if row.hasLogs then
					counts.logs = counts.logs + 1
				end
				if row.currentPhaseRanked then
					counts.current = counts.current + 1
				end
				if row.phase2ScoreCenti then
					counts.phase2 = counts.phase2 + 1
				end
				if row.hasGear then
					counts.gear = counts.gear + 1
				end
				if row.hasTalents then
					counts.talents = counts.talents + 1
				end
				if row.hasLogs and row.hasGear then
					counts.both = counts.both + 1
				end
			end
		end

		coolstats.SortCachedPlayerBrowserRows(rows, panel)
		counts.total = #rows
		return rows, counts
	end

	function coolstats.GetCachedPlayerBrowserCacheText(row)
		local seenAt = row and tonumber(row.seenAt)
		if not seenAt or seenAt <= 0 then
			return "-"
		end
		if date then
			return date("%m/%d %H:%M", seenAt)
		end
		return tostring(seenAt)
	end

	function coolstats.CachedPlayerBrowserRow_OnEnter(self)
		if not self.playerName then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.playerName, 1, 0.82, 0.16)
		GameTooltip:AddDoubleLine("UwU Logs", self.hasLogs and "Available" or "Missing", 0.86, 0.86, 0.78, self.hasLogs and 0.25 or 1, self.hasLogs and 1 or 0.25, 0.25)
		GameTooltip:AddDoubleLine("Cached Gear", self.hasGear and "Available" or "Missing", 0.86, 0.86, 0.78, self.hasGear and 0.25 or 1, self.hasGear and 1 or 0.25, 0.25)
		GameTooltip:AddDoubleLine("Cached Talents", self.hasTalents and "Available" or "Missing", 0.86, 0.86, 0.78, self.hasTalents and 0.25 or 1, self.hasTalents and 1 or 0.25, 0.25)
		if self.className then
			GameTooltip:AddDoubleLine("Class", self.className, 0.86, 0.86, 0.78, 1, 1, 1)
		end
		if self.mainSpecText and self.mainSpecText ~= "-" then
			GameTooltip:AddDoubleLine("Main Spec", self.mainSpecText, 0.86, 0.86, 0.78, self.mainSpecR or 1, self.mainSpecG or 1, self.mainSpecB or 1)
		end
		if self.offSpecText and self.offSpecText ~= "-" then
			GameTooltip:AddDoubleLine("Off Spec", self.offSpecText, 0.86, 0.86, 0.78, self.offSpecR or 1, self.offSpecG or 1, self.offSpecB or 1)
		end
		if self.bestRankText and self.bestRankText ~= "-" then
			local rankText = self.bestRankText
			if self.bestRankSpecName then
				rankText = rankText .. " " .. self.bestRankSpecName
			end
			GameTooltip:AddDoubleLine(self.currentRankLabel or "Best Rank", rankText, 0.86, 0.86, 0.78, 1, 0.82, 0.16)
		end
		if self.phase2Text and self.phase2Text ~= "-" then
			GameTooltip:AddDoubleLine("Phase 2 Overall", self.phase2Text, 0.86, 0.86, 0.78, self.phase2R or 1, self.phase2G or 1, self.phase2B or 1)
		end
		if self.cacheText and self.cacheText ~= "-" then
			GameTooltip:AddDoubleLine("Gear Cached", self.cacheText, 0.86, 0.86, 0.78, 1, 1, 1)
		end
		GameTooltip:AddLine("Left-click to open the standard UwU lookup.", 0.62, 0.62, 0.58, true)
		GameTooltip:AddLine("Shift-click to link this player's logs in chat.", 0.62, 0.72, 0.86, true)
		GameTooltip:AddLine("Right-click for actions, including armory and talents.", 0.62, 0.62, 0.58, true)
		GameTooltip:Show()
	end

	function coolstats.CachedPlayerBrowserRow_OnLeave()
		GameTooltip:Hide()
	end

	function coolstats.OpenCachedPlayerBrowserPlayer(name)
		if not name or name == "" then
			return
		end
		if PlaySound then
			PlaySound("igCharacterInfoTab")
		end
		ShowUwULogsPanelForName(name)
		if lookupUwUPanel and coolstats.cachedPlayerBrowser then
			lookupUwUPanel:SetFrameStrata("DIALOG")
			lookupUwUPanel:SetFrameLevel((coolstats.cachedPlayerBrowser:GetFrameLevel() or 80) + 10)
			if lookupUwUPanel.cachedGearPanel then
				lookupUwUPanel.cachedGearPanel:SetFrameStrata("DIALOG")
				lookupUwUPanel.cachedGearPanel:SetFrameLevel(lookupUwUPanel:GetFrameLevel() + 1)
			end
		end
	end

	function coolstats.ShowCachedPlayerBrowserUrl(title, url)
		if not url or url == "" then
			return
		end
		local panel = coolstats.CreateCachedPlayerBrowserUrlDialog()
		if not panel then
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffcoolstats:|r " .. url)
			end
			return
		end
		panel.title:SetText(title or "External URL")
		panel.editBox:SetText(url)
		panel:Show()
		panel.editBox:SetFocus()
		panel.editBox:HighlightText()
		coolstats.TouchManagedWindow(panel)
	end

	function coolstats.CreateCachedPlayerBrowserUrlDialog()
		if coolstats.cachedPlayerBrowserUrlDialog then
			return coolstats.cachedPlayerBrowserUrlDialog
		end
		local panel = CreateFrame("Frame", "coolstatsCachedPlayerBrowserUrlDialog", UIParent)
		coolstats.cachedPlayerBrowserUrlDialog = panel
		SetFrameSize(panel, 960, 146)
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		panel:SetFrameStrata("DIALOG")
		panel:SetFrameLevel(120)
		panel:SetMovable(true)
		panel:EnableMouse(true)
		panel:RegisterForDrag("LeftButton")
		panel:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		panel:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
		end)
		panel:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = false,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		})
		panel:SetBackdropColor(0.02, 0.018, 0.014, 0.98)
		panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
		if coolstats.ApplyTabardPanelBackground then
			coolstats.ApplyTabardPanelBackground(panel, 0.80, 0.58)
		end

		local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

		local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", panel, "TOP", 0, -18)
		title:SetTextColor(0.0, 0.75, 1.0)
		panel.title = title

		local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
		SetFrameSize(editBox, 860, 22)
		editBox:SetPoint("TOP", panel, "TOP", 0, -54)
		editBox:SetAutoFocus(false)
		editBox:SetMaxLetters(512)
		editBox:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			panel:Hide()
		end)
		editBox:SetScript("OnEnterPressed", function(self)
			self:HighlightText()
		end)
		panel.editBox = editBox

		local okay = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(okay, 120, 24)
		okay:SetPoint("BOTTOM", panel, "BOTTOM", 0, 18)
		okay:SetText(OKAY or "Okay")
		okay:SetScript("OnClick", function()
			panel:Hide()
		end)

		panel:SetScript("OnHide", function()
			editBox:ClearFocus()
		end)
		coolstats.RegisterManagedWindow(panel)
		panel:Hide()
		return panel
	end

	function coolstats.GetCachedPlayerBrowserRealmName()
		local realm = GetRealmName and GetRealmName() or ""
		local realmKey = string.lower(string.gsub(tostring(realm), "[^%a%d]", ""))
		local supportedRealms = {
			icecrown = "Icecrown",
			lordaeron = "Lordaeron",
			onyxia = "Onyxia",
		}
		return supportedRealms[realmKey] or realm
	end

	function coolstats.EncodeCachedPlayerBrowserUrlSegment(value)
		return string.gsub(tostring(value or ""), "([^%w%-%._~])", function(character)
			return string.format("%%%02X", string.byte(character))
		end)
	end

	function coolstats.GetCachedPlayerBrowserWarmaneArmoryUrl(name)
		name = string.gsub(tostring(name or ""), "%-.+$", "")
		local realm = coolstats.GetCachedPlayerBrowserRealmName()
		if name == "" or realm == "" then
			return nil
		end
		return "https://armory.warmane.com/character/"
			.. coolstats.EncodeCachedPlayerBrowserUrlSegment(name)
			.. "/"
			.. coolstats.EncodeCachedPlayerBrowserUrlSegment(realm)
			.. "/summary"
	end

	function coolstats.OpenCachedPlayerBrowserWarmaneArmory(name)
		local url = coolstats.GetCachedPlayerBrowserWarmaneArmoryUrl(name)
		if not url then
			return
		end
		if CloseDropDownMenus then
			CloseDropDownMenus()
		end
		coolstats.ShowCachedPlayerBrowserUrl("Warmane Armory", url)
	end

	function coolstats.WhisperCachedPlayerBrowserPlayer(name)
		if not name or name == "" then
			return
		end
		if ChatFrame_SendTell then
			ChatFrame_SendTell(name)
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffcoolstats:|r /w " .. name)
		end
	end

	function coolstats.InviteCachedPlayerBrowserPlayer(name)
		if not name or name == "" then
			return
		end
		if InviteUnit then
			InviteUnit(name)
		elseif InviteByName then
			InviteByName(name)
		end
	end

	function coolstats.GetCachedPlayerBrowserHelpName()
		return "Jumpscared"
	end

	function coolstats.NormalizeCachedPlayerBrowserUnitName(name)
		name = tostring(name or "")
		name = string.gsub(name, "%-.+", "")
		return NormalizeName(name)
	end

	function coolstats.GetCachedPlayerBrowserActivity(statusText, connected)
		if connected == false then
			return "Offline", "Interface\\FriendsFrame\\StatusIcon-Offline", 0.62, 0.62, 0.58
		end
		statusText = string.upper(tostring(statusText or ""))
		if string.find(statusText, "DND", 1, true) or string.find(statusText, "BUSY", 1, true) then
			return "Do Not Disturb", "Interface\\FriendsFrame\\StatusIcon-DnD", 1.0, 0.28, 0.20
		end
		if string.find(statusText, "AFK", 1, true) or string.find(statusText, "AWAY", 1, true) then
			return "Away", "Interface\\FriendsFrame\\StatusIcon-Away", 1.0, 0.82, 0.16
		end
		if connected == true then
			return "Online", "Interface\\FriendsFrame\\StatusIcon-Online", 0.25, 1.0, 0.25
		end
		return "Unknown", "Interface\\FriendsFrame\\StatusIcon-Offline", 0.62, 0.72, 0.86
	end

	function coolstats.GetCachedPlayerBrowserHelpStatus()
		local helpName = coolstats.GetCachedPlayerBrowserHelpName()
		local helpKey = coolstats.NormalizeCachedPlayerBrowserUnitName(helpName)
		if helpKey == "" then
			return helpName, "Unknown", "Interface\\FriendsFrame\\StatusIcon-Offline", 0.62, 0.72, 0.86
		end
		if UnitExists and UnitName then
			local units = { "player", "target", "focus", "mouseover", "party1", "party2", "party3", "party4", "raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10", "raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20", "raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30", "raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40" }
			for index = 1, #units do
				if UnitExists(units[index]) then
					local unitName = UnitName(units[index])
					if coolstats.NormalizeCachedPlayerBrowserUnitName(unitName) == helpKey then
						local status = UnitIsDND and UnitIsDND(units[index]) and "DND" or UnitIsAFK and UnitIsAFK(units[index]) and "AFK" or ""
						local label, icon, red, green, blue = coolstats.GetCachedPlayerBrowserActivity(status, true)
						return helpName, label, icon, red, green, blue
					end
				end
			end
		end
		if GetNumFriends and GetFriendInfo then
			local friendCount = GetNumFriends() or 0
			for index = 1, friendCount do
				local friendName, _, _, _, connected, statusText = GetFriendInfo(index)
				if coolstats.NormalizeCachedPlayerBrowserUnitName(friendName) == helpKey then
					local label, icon, red, green, blue = coolstats.GetCachedPlayerBrowserActivity(statusText, connected)
					return helpName, label, icon, red, green, blue
				end
			end
		end
		if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
			local guildCount = GetNumGuildMembers() or 0
			for index = 1, guildCount do
				local guildName, _, _, _, _, _, _, _, online, statusText = GetGuildRosterInfo(index)
				if coolstats.NormalizeCachedPlayerBrowserUnitName(guildName) == helpKey then
					local label, icon, red, green, blue = coolstats.GetCachedPlayerBrowserActivity(statusText, online)
					return helpName, label, icon, red, green, blue
				end
			end
		end
		return helpName, "Unknown", "Interface\\FriendsFrame\\StatusIcon-Offline", 0.62, 0.72, 0.86
	end

	function coolstats.OpenCachedPlayerBrowserHelpWhisper()
		coolstats.WhisperCachedPlayerBrowserPlayer(coolstats.GetCachedPlayerBrowserHelpName())
	end

	function coolstats.ApplyCachedPlayerBrowserBlueButton(button)
		if not button then
			return
		end
		local regions = { button:GetRegions() }
		for index = 1, #regions do
			local region = regions[index]
			if region and region.GetObjectType and region:GetObjectType() == "Texture" then
				region:SetVertexColor(0.12, 0.42, 1.0, 1)
			end
		end
		if button.GetFontString and button:GetFontString() then
			button:GetFontString():SetTextColor(0.85, 0.95, 1.0)
		end
	end

	function coolstats.CachedPlayerBrowserHelpButton_OnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("HELP", 0.0, 0.75, 1.0)
		local name, label, icon, red, green, blue = coolstats.GetCachedPlayerBrowserHelpStatus()
		GameTooltip:AddLine("|T" .. tostring(icon or "Interface\\FriendsFrame\\StatusIcon-Offline") .. ":14:14:0:0|t " .. tostring(name or "Jumpscared") .. " - " .. tostring(label or "Unknown"), red or 0.62, green or 0.72, blue or 0.86)
		GameTooltip:AddLine("Click to open a whisper.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end

	function coolstats.CachedPlayerBrowserHelpButton_OnLeave()
		GameTooltip:Hide()
	end

	function coolstats.InitializeCachedPlayerBrowserRowMenu(frame, level)
		local name = frame and frame.playerName
		if not name or name == "" or not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then
			return
		end
		local favoriteKey = frame.favoriteKey or name
		local isFavorite = coolstats.IsCachedPlayerBrowserFavorite(favoriteKey)
		local info = UIDropDownMenu_CreateInfo()
		info.text = "Whisper"
		info.notCheckable = 1
		info.func = function()
			coolstats.WhisperCachedPlayerBrowserPlayer(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "Invite"
		info.notCheckable = 1
		info.func = function()
			coolstats.InviteCachedPlayerBrowserPlayer(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "Talents"
		info.notCheckable = 1
		info.func = function()
			coolstats.OpenCachedTalentsForName(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "Compare Logs"
		info.notCheckable = 1
		info.func = function()
			coolstats.OpenLogsCompareWithName(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "Link UwU Logs"
		info.notCheckable = 1
		info.func = function()
			if CloseDropDownMenus then
				CloseDropDownMenus()
			end
			coolstats.InsertPlayerLogLink(name)
		end
		UIDropDownMenu_AddButton(info, level)

		local analysisAllowed, analysisReason = coolstats.CanOpenLogAnalysisWithName(name)
		info = UIDropDownMenu_CreateInfo()
		info.text = "Log Analysis"
		info.notCheckable = 1
		info.disabled = not analysisAllowed
		info.tooltipTitle = not analysisAllowed and "Log Analysis" or nil
		info.tooltipText = not analysisAllowed and analysisReason or nil
		info.tooltipOnButton = not analysisAllowed and 1 or nil
		info.func = function()
			coolstats.OpenLogAnalysisWithName(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = isFavorite and "Unfavourite" or "Favourite"
		info.notCheckable = 1
		info.func = function()
			coolstats.ToggleCachedPlayerBrowserFavorite(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "|cff00bfffWarmane Armory|r"
		info.notCheckable = 1
		info.func = function()
			coolstats.OpenCachedPlayerBrowserWarmaneArmory(name)
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = CLOSE or "Close"
		info.notCheckable = 1
		info.func = function()
			if CloseDropDownMenus then
				CloseDropDownMenus()
			end
		end
		UIDropDownMenu_AddButton(info, level)
	end

	function coolstats.OpenCachedPlayerBrowserRowMenu(row)
		if not row or not row.playerName or not UIDropDownMenu_Initialize or not ToggleDropDownMenu then
			return
		end
		if not coolstats.cachedPlayerBrowserRowMenu then
			coolstats.cachedPlayerBrowserRowMenu = CreateFrame("Frame", "coolstatsCachedPlayerBrowserRowMenu", UIParent, "UIDropDownMenuTemplate")
		end
		local menu = coolstats.cachedPlayerBrowserRowMenu
		menu.playerName = row.playerName
		menu.favoriteKey = row.favoriteKey or row.playerName
		UIDropDownMenu_Initialize(menu, coolstats.InitializeCachedPlayerBrowserRowMenu, "MENU")
		ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
	end

	function coolstats.CachedPlayerBrowserRow_OnClick(self, button)
		coolstats.TouchManagedWindow(coolstats.cachedPlayerBrowser)
		if button == "RightButton" then
			coolstats.OpenCachedPlayerBrowserRowMenu(self)
			return
		end
		if IsModifiedClick and IsModifiedClick("CHATLINK") then
			coolstats.InsertPlayerLogLink(self.playerName)
			return
		end
		coolstats.OpenCachedPlayerBrowserPlayer(self.playerName)
	end

	function coolstats.QueueCachedPlayerBrowserSearch(panel)
		if not panel then
			return
		end
		panel.searchDelay = 0.45
		panel:SetScript("OnUpdate", function(self, elapsed)
			self.searchDelay = (self.searchDelay or 0) - elapsed
			if self.searchDelay <= 0 then
				self:SetScript("OnUpdate", nil)
				self.searchDelay = nil
				coolstats.RefreshCachedPlayerBrowser(true)
			end
		end)
	end

	function coolstats.SetCachedPlayerBrowserSort(sortKey)
		local panel = coolstats.cachedPlayerBrowser
		if not panel or not sortKey then
			return
		end
		if panel.browserSortKey ~= sortKey or not panel.browserSortState then
			panel.browserSortKey = sortKey
			panel.browserSortState = "asc"
		elseif panel.browserSortState == "asc" then
			panel.browserSortState = "desc"
		else
			panel.browserSortKey = nil
			panel.browserSortState = nil
		end
		coolstats.RefreshCachedPlayerBrowser(true)
	end

	function coolstats.UpdateCachedPlayerBrowserHeaderSort(panel)
		if not panel or not panel.header then
			return
		end
		local columns = panel.header.columns or {}
		for index = 1, #columns do
			local column = columns[index]
			local label = column.baseLabel or ""
			if column.sortKey and column.sortKey == panel.browserSortKey then
				label = label .. (panel.browserSortState == "asc" and " ^" or " v")
				column.text:SetTextColor(0.0, 0.75, 1.0)
			else
				column.text:SetTextColor(1, 0.82, 0)
			end
			column.text:SetText(label)
		end
	end

	function coolstats.CreateCachedPlayerBrowserColumn(parent, label, x, width, justify, sortKey)
		local button = CreateFrame("Button", nil, parent)
		SetFrameSize(button, width, 16)
		button:SetPoint("LEFT", parent, "LEFT", x, 0)
		button.baseLabel = label
		button.sortKey = sortKey
		local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetAllPoints(button)
		text:SetJustifyH(justify or "CENTER")
		text:SetText(label)
		text:SetTextColor(1, 0.82, 0)
		button.text = text
		if sortKey then
			button:RegisterForClicks("LeftButtonUp")
			button:SetScript("OnClick", function(self)
				coolstats.SetCachedPlayerBrowserSort(self.sortKey)
			end)
			button:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText("Sort by " .. (self.baseLabel or "column"), 1, 0.82, 0.16)
				GameTooltip:AddLine("Click cycles ascending, descending, default.", 0.86, 0.86, 0.78, true)
				GameTooltip:Show()
			end)
			button:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		end
		return button
	end

	function coolstats.UpdateCachedPlayerBrowserFilterButtons(panel)
		if not panel then
			return
		end
		local classText = "Class: All"
		if panel.browserClassFilter == "favorites" then
			classText = "Class: Favourites"
		elseif panel.browserClassFilter ~= nil then
			classText = "Class: " .. coolstats.GetCachedPlayerBrowserClassName(panel.browserClassFilter)
		end
		if panel.classFilterButton then
			if panel.browserClassFilter == nil then
				panel.classFilterButton:SetText("Class: All")
			elseif panel.browserClassFilter == "favorites" then
				panel.classFilterButton:SetText("Class: Favourites")
			else
				panel.classFilterButton:SetText("Class: " .. coolstats.GetCachedPlayerBrowserClassName(panel.browserClassFilter))
			end
		end
		if panel.classDropdown and UIDropDownMenu_SetText then
			UIDropDownMenu_SetText(panel.classDropdown, classText)
		end
		local specText = "Spec: All"
		if panel.browserSpecFilterKey then
			local classIndex, specIndex = coolstats.ParseCachedPlayerBrowserSpecKey(panel.browserSpecFilterKey)
			local specLabel = coolstats.GetCachedPlayerBrowserSpecLabel(classIndex, specIndex, type(panel.browserClassFilter) ~= "number")
			if specLabel then
				specText = "Spec: " .. specLabel
			end
		end
		if panel.specFilterButton then
			panel.specFilterButton:SetText(specText)
		end
		if panel.specDropdown and UIDropDownMenu_SetText then
			UIDropDownMenu_SetText(panel.specDropdown, specText)
		end
	end

	function coolstats.NormalizeCachedPlayerBrowserSpecFilter(panel)
		if not panel or not panel.browserSpecFilterKey or panel.browserClassFilter == nil or type(panel.browserClassFilter) ~= "number" then
			return
		end
		local classIndex = coolstats.ParseCachedPlayerBrowserSpecKey(panel.browserSpecFilterKey)
		if classIndex ~= panel.browserClassFilter then
			panel.browserSpecFilterKey = nil
		end
	end

	function coolstats.SetCachedPlayerBrowserClassFilter(panel, classIndex)
		if not panel then
			return
		end
		panel.browserClassFilter = classIndex
		coolstats.NormalizeCachedPlayerBrowserSpecFilter(panel)
		coolstats.UpdateCachedPlayerBrowserFilterButtons(panel)
		coolstats.RefreshCachedPlayerBrowser(true)
	end

	function coolstats.SetCachedPlayerBrowserSpecFilter(panel, specKey)
		if not panel then
			return
		end
		if specKey then
			local classIndex = coolstats.ParseCachedPlayerBrowserSpecKey(specKey)
			if type(panel.browserClassFilter) == "number" and classIndex ~= panel.browserClassFilter then
				specKey = nil
			end
		end
		panel.browserSpecFilterKey = specKey
		coolstats.UpdateCachedPlayerBrowserFilterButtons(panel)
		coolstats.RefreshCachedPlayerBrowser(true)
	end

	function coolstats.InitializeCachedPlayerBrowserClassDropdown(frame, level)
		local panel = frame and frame.ownerPanel
		if not panel or not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then
			return
		end
		local info = UIDropDownMenu_CreateInfo()
		info.text = "All Classes"
		info.notCheckable = nil
		info.checked = panel.browserClassFilter == nil
		info.func = function()
			coolstats.SetCachedPlayerBrowserClassFilter(panel, nil)
			if CloseDropDownMenus then
				CloseDropDownMenus()
			end
		end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = "Favourites"
		info.notCheckable = nil
		info.checked = panel.browserClassFilter == "favorites"
		info.func = function()
			coolstats.SetCachedPlayerBrowserClassFilter(panel, "favorites")
			if CloseDropDownMenus then
				CloseDropDownMenus()
			end
		end
		info.colorCode = "|cffffd100"
		UIDropDownMenu_AddButton(info, level)

		local data = coolstatsUwUData
		for classIndex = 0, 9 do
			local selectedClassIndex = classIndex
			info = UIDropDownMenu_CreateInfo()
			info.text = coolstats.GetCachedPlayerBrowserClassName(selectedClassIndex)
			info.notCheckable = nil
			info.checked = panel.browserClassFilter == selectedClassIndex
			info.func = function()
				coolstats.SetCachedPlayerBrowserClassFilter(panel, selectedClassIndex)
				if CloseDropDownMenus then
					CloseDropDownMenus()
				end
			end
			local classFile = UWU_CLASS_FILE_BY_INDEX[selectedClassIndex]
			local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
			if classColor then
				info.colorCode = string.format("|cff%02x%02x%02x", math.floor(classColor.r * 255 + 0.5), math.floor(classColor.g * 255 + 0.5), math.floor(classColor.b * 255 + 0.5))
			end
			if data and data.classes and data.classes[selectedClassIndex] then
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	function coolstats.CreateCachedPlayerBrowserClassDropdown(panel)
		local dropdown = CreateFrame("Frame", "coolstatsCachedPlayerBrowserClassDropdown", panel, "UIDropDownMenuTemplate")
		dropdown.ownerPanel = panel
		UIDropDownMenu_SetWidth(dropdown, 150)
		UIDropDownMenu_Initialize(dropdown, coolstats.InitializeCachedPlayerBrowserClassDropdown)
		panel.classDropdown = dropdown
		return dropdown
	end

	function coolstats.InitializeCachedPlayerBrowserSpecDropdown(frame, level)
		local panel = frame and frame.ownerPanel
		if not panel or not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then
			return
		end
		local info = UIDropDownMenu_CreateInfo()
		info.text = "All Specs"
		info.notCheckable = nil
		info.checked = panel.browserSpecFilterKey == nil
		info.func = function()
			coolstats.SetCachedPlayerBrowserSpecFilter(panel, nil)
			if CloseDropDownMenus then
				CloseDropDownMenus()
			end
		end
		UIDropDownMenu_AddButton(info, level)

		local choices = coolstats.GetCachedPlayerBrowserSpecFilterChoices(panel)
		for index = 1, #choices do
			local choice = choices[index]
			local choiceKey = choice.key
			info = UIDropDownMenu_CreateInfo()
			info.text = choice.label
			info.notCheckable = nil
			info.checked = panel.browserSpecFilterKey == choiceKey
			info.func = function()
				coolstats.SetCachedPlayerBrowserSpecFilter(panel, choiceKey)
				if CloseDropDownMenus then
					CloseDropDownMenus()
				end
			end
			local classFile = UWU_CLASS_FILE_BY_INDEX[choice.classIndex]
			local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
			if classColor then
				info.colorCode = string.format("|cff%02x%02x%02x", math.floor(classColor.r * 255 + 0.5), math.floor(classColor.g * 255 + 0.5), math.floor(classColor.b * 255 + 0.5))
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end

	function coolstats.CreateCachedPlayerBrowserSpecDropdown(panel)
		local dropdown = CreateFrame("Frame", "coolstatsCachedPlayerBrowserSpecDropdown", panel, "UIDropDownMenuTemplate")
		dropdown.ownerPanel = panel
		UIDropDownMenu_SetWidth(dropdown, 180)
		UIDropDownMenu_Initialize(dropdown, coolstats.InitializeCachedPlayerBrowserSpecDropdown)
		panel.specDropdown = dropdown
		return dropdown
	end

	function coolstats.CreateCachedPlayerBrowserClassResetButton(panel, anchor)
		local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(reset, 24, 22)
		reset:SetText("x")
		reset:SetPoint("LEFT", anchor, "RIGHT", -6, 3)
		reset:SetScript("OnClick", function()
			coolstats.SetCachedPlayerBrowserClassFilter(panel, nil)
		end)
		reset:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Reset Class Filter", 1, 0.82, 0.16)
			GameTooltip:Show()
		end)
		reset:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		panel.classResetButton = reset
		return reset
	end

	function coolstats.CreateCachedPlayerBrowserSpecResetButton(panel, anchor)
		local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(reset, 24, 22)
		reset:SetText("x")
		reset:SetPoint("LEFT", anchor, "RIGHT", -6, 3)
		reset:SetScript("OnClick", function()
			coolstats.SetCachedPlayerBrowserSpecFilter(panel, nil)
		end)
		reset:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Reset Spec Filter", 1, 0.82, 0.16)
			GameTooltip:Show()
		end)
		reset:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		panel.specResetButton = reset
		return reset
	end

	function coolstats.CycleCachedPlayerBrowserClassFilter(panel)
		if not panel then
			return
		end
		if panel.browserClassFilter == nil then
			coolstats.SetCachedPlayerBrowserClassFilter(panel, "favorites")
		elseif panel.browserClassFilter == "favorites" then
			coolstats.SetCachedPlayerBrowserClassFilter(panel, 0)
		elseif panel.browserClassFilter >= 9 then
			coolstats.SetCachedPlayerBrowserClassFilter(panel, nil)
		else
			coolstats.SetCachedPlayerBrowserClassFilter(panel, panel.browserClassFilter + 1)
		end
	end

	function coolstats.ClearCachedPlayerBrowserGearCache()
		local store = GetCachedGearStore()
		store.players = {}
		store.order = {}
		lastCachedGearPruneAt = 0
		local talentStore = coolstats.GetCachedTalentStore()
		talentStore.players = {}
		talentStore.order = {}
		coolstats.lastCachedTalentPruneAt = 0
		if lookupUwUPanel and lookupUwUPanel:IsShown() then
			UpdateCachedGearPanel(lookupUwUPanel, lookupUwUPanel.renderName, lookupUwUPanel.renderPlayer)
		end
		coolstats.RefreshCachedPlayerBrowser(true)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffcoolstats:|r cached gear and talents cleared for " .. (GetRealmName and GetRealmName() or "this realm") .. ".")
		end
	end

	function coolstats.ShowClearCachedPlayerBrowserGearConfirm()
		if not StaticPopupDialogs or not StaticPopup_Show then
			coolstats.ClearCachedPlayerBrowserGearCache()
			return
		end
		if not StaticPopupDialogs["COOLSTATS_CLEAR_CACHED_GEAR"] then
			StaticPopupDialogs["COOLSTATS_CLEAR_CACHED_GEAR"] = {
				text = "Clear cached gear and talents for this realm?\n\nLogs data and caches from other realms will stay intact.",
				button1 = YES or "Yes",
				button2 = NO or "No",
				OnAccept = function()
					coolstats.ClearCachedPlayerBrowserGearCache()
				end,
				timeout = 0,
				whileDead = 1,
				hideOnEscape = 1,
			}
		end
		StaticPopup_Show("COOLSTATS_CLEAR_CACHED_GEAR")
	end

	function coolstats.ApplyCachedPlayerBrowserHeaderBackground(header)
		if not header or header.headerLeft then
			return
		end
		local right = header:CreateTexture(nil, "ARTWORK")
		right:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
		SetFrameSize(right, 37, 18)
		right:SetPoint("RIGHT", header, "RIGHT", 0, 0)
		right:SetTexCoord(0, 0.14453125, 0.296875, 0.578125)
		header.headerRight = right

		local left = header:CreateTexture(nil, "ARTWORK")
		left:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
		left:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		left:SetTexCoord(0.18, 1, 0, 0.28125)
		header.headerLeft = left
	end

	function coolstats.UpdateCachedPlayerBrowserFavoriteIcon(button, active)
		if not button or not button.icon then
			return
		end
		if button.icon.SetDesaturated then
			button.icon:SetDesaturated(not active)
		end
		if active then
			button.icon:SetVertexColor(1.0, 0.82, 0.16, 1)
		else
			button.icon:SetVertexColor(0.58, 0.58, 0.58, 0.72)
		end
	end

	function coolstats.CreateCachedPlayerBrowserRow(panel, index)
		local row = CreateFrame("Button", "coolstatsCachedPlayerBrowserRow" .. tostring(index), panel)
		local showPhase2History = panel and panel.showPhase2History
		SetFrameSize(row, 860, 18)
		row:SetPoint("TOPLEFT", panel.listTop, "BOTTOMLEFT", 0, -((index - 1) * 18))
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", coolstats.CachedPlayerBrowserRow_OnClick)
		row:SetScript("OnEnter", coolstats.CachedPlayerBrowserRow_OnEnter)
		row:SetScript("OnLeave", coolstats.CachedPlayerBrowserRow_OnLeave)

		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetAllPoints(row)
		if (index % 2) == 0 then
			bg:SetVertexColor(0.28, 0.27, 0.25, 0.24)
		else
			bg:SetVertexColor(0.05, 0.06, 0.07, 0.12)
		end
		row.bg = bg

		local favoriteButton = CreateFrame("Button", nil, row)
		SetFrameSize(favoriteButton, 14, 14)
		favoriteButton:SetPoint("LEFT", row, "LEFT", 3, 0)
		favoriteButton:SetFrameLevel(row:GetFrameLevel() + 3)
		favoriteButton:RegisterForClicks("LeftButtonUp")
		local favoriteIcon = favoriteButton:CreateTexture(nil, "OVERLAY")
		favoriteIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
		SetFrameSize(favoriteIcon, 13, 13)
		favoriteIcon:SetPoint("CENTER", favoriteButton, "CENTER", 0, 0)
		favoriteButton.icon = favoriteIcon
		favoriteButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		favoriteButton:SetScript("OnClick", function(self)
			coolstats.ToggleCachedPlayerBrowserFavorite(self.playerName or self.favoriteKey)
		end)
		favoriteButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.isFavorite and "Unfavourite" or "Favourite", 1, 0.82, 0.16)
			GameTooltip:AddLine(self.playerName or "", 0.86, 0.86, 0.78)
			GameTooltip:Show()
		end)
		favoriteButton:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		row.favoriteButton = favoriteButton

		local classIcon = row:CreateTexture(nil, "OVERLAY")
		classIcon:SetTexture(UWU_CLASS_ICON_ATLAS)
		SetFrameSize(classIcon, 14, 14)
		classIcon:SetPoint("LEFT", row, "LEFT", 20, 0)
		classIcon:SetVertexColor(1, 1, 1, 1)
		row.classIcon = classIcon

		local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		nameText:SetPoint("LEFT", row, "LEFT", 40, 0)
		nameText:SetWidth(145)
		nameText:SetJustifyH("LEFT")
		row.nameText = nameText

		local mainSpecText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		mainSpecText:SetPoint("LEFT", row, "LEFT", 190, 0)
		mainSpecText:SetWidth(84)
		mainSpecText:SetJustifyH("CENTER")
		row.mainSpecTextFrame = mainSpecText

		local offSpecText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		offSpecText:SetPoint("LEFT", row, "LEFT", 280, 0)
		offSpecText:SetWidth(84)
		offSpecText:SetJustifyH("CENTER")
		row.offSpecTextFrame = offSpecText

		local logsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		logsText:SetPoint("LEFT", row, "LEFT", 370, 0)
		logsText:SetWidth(32)
		logsText:SetJustifyH("CENTER")
		row.logsText = logsText

		local gearText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		gearText:SetPoint("LEFT", row, "LEFT", 405, 0)
		gearText:SetWidth(32)
		gearText:SetJustifyH("CENTER")
		row.gearText = gearText

		local talentsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		talentsText:SetPoint("LEFT", row, "LEFT", 440, 0)
		talentsText:SetWidth(44)
		talentsText:SetJustifyH("CENTER")
		row.talentsText = talentsText

		local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		scoreText:SetPoint("LEFT", row, "LEFT", 494, 0)
		scoreText:SetWidth(60)
		scoreText:SetJustifyH("RIGHT")
		row.scoreText = scoreText

		local bestRankText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bestRankText:SetPoint("LEFT", row, "LEFT", 562, 0)
		bestRankText:SetWidth(66)
		bestRankText:SetJustifyH("RIGHT")
		row.bestRankTextFrame = bestRankText

		local phase2Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		phase2Text:SetPoint("LEFT", row, "LEFT", 638, 0)
		phase2Text:SetWidth(106)
		phase2Text:SetJustifyH("RIGHT")
		if not showPhase2History then
			phase2Text:Hide()
		end
		row.phase2TextFrame = phase2Text

		local cacheText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cacheText:SetPoint("LEFT", row, "LEFT", showPhase2History and 754 or 638, 0)
		cacheText:SetWidth(showPhase2History and 88 or 104)
		cacheText:SetJustifyH("RIGHT")
		row.cacheTextFrame = cacheText

		return row
	end

	function coolstats.CreateCachedPlayerBrowser()
		if coolstats.cachedPlayerBrowser then
			return coolstats.cachedPlayerBrowser
		end

		local panel = CreateFrame("Frame", "coolstatsCachedPlayerBrowser", UIParent)
		coolstats.cachedPlayerBrowser = panel
		panel.showPhase2History = coolstats.IsOnyxiaPhase3Browser()
		SetFrameSize(panel, 940, 512)
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		panel:SetFrameStrata("DIALOG")
		panel:SetFrameLevel(80)
		panel.browserSortKey = nil
		panel.browserSortState = nil
		if panel.SetToplevel then
			panel:SetToplevel(true)
		end
		panel:SetMovable(true)
		panel:EnableMouse(true)
		panel:RegisterForDrag("LeftButton")
		panel:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		panel:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
		end)
		if panel.SetClampedToScreen then
			panel:SetClampedToScreen(true)
		end
		panel:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = false,
			tileSize = 32,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		})
		panel:SetBackdropColor(0.02, 0.018, 0.014, 0.98)
		panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
		coolstats.ApplyTabardPanelBackground(panel, 0.80, 0.58)

		local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
		if UISpecialFrames then
			local registered = false
			for index = 1, #UISpecialFrames do
				if UISpecialFrames[index] == "coolstatsCachedPlayerBrowser" then
					registered = true
					break
				end
			end
			if not registered then
				table.insert(UISpecialFrames, "coolstatsCachedPlayerBrowser")
			end
		end
		coolstats.RegisterManagedWindow(panel)
		local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", panel, "TOP", 0, -14)
		title:SetText("coolstats")
		title:SetTextColor(0.0, 0.75, 1.0)
		panel.title = title

		local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
		subtitle:SetWidth(860)
		subtitle:SetJustifyH("CENTER")
		subtitle:SetTextColor(0.78, 0.78, 0.72)
		panel.subtitle = subtitle

		local generated = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		generated:SetPoint("TOP", subtitle, "BOTTOM", 0, -2)
		generated:SetWidth(860)
		generated:SetJustifyH("CENTER")
		generated:SetTextColor(0.58, 0.76, 0.86)
		generated:SetText(coolstats.FormatCachedPlayerBrowserGeneratedAt())
		panel.generatedText = generated

		local search = CreateFrame("EditBox", "coolstatsCachedPlayerBrowserSearch", panel, "InputBoxTemplate")
		SetFrameSize(search, 210, 20)
		search:SetPoint("TOPLEFT", panel, "TOPLEFT", 48, -62)
		search:SetAutoFocus(false)
		search:SetScript("OnTextChanged", function(self)
			if self.suppressTextChanged then
				return
			end
			coolstats.QueueCachedPlayerBrowserSearch(panel)
		end)
		search:SetScript("OnMouseDown", function()
			coolstats.TouchManagedWindow(panel)
		end)
		search:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			coolstats.RefreshCachedPlayerBrowser(true)
		end)
		search:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
		end)
		panel.searchBox = search

		local searchButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(searchButton, 70, 22)
		searchButton:SetPoint("LEFT", search, "RIGHT", 10, 0)
		searchButton:SetText("Search")
		searchButton:SetScript("OnClick", function()
			coolstats.RefreshCachedPlayerBrowser(true)
		end)

		local clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(clearButton, 62, 22)
		clearButton:SetPoint("LEFT", searchButton, "RIGHT", 6, 0)
		clearButton:SetText("Clear")
		clearButton:SetScript("OnClick", function()
			panel.searchBox.suppressTextChanged = true
			panel.searchBox:SetText("")
			panel.searchBox.suppressTextChanged = nil
			panel.browserClassFilter = nil
			panel.browserSpecFilterKey = nil
			coolstats.UpdateCachedPlayerBrowserFilterButtons(panel)
			panel.searchBox:ClearFocus()
			coolstats.RefreshCachedPlayerBrowser(true)
		end)

		local clearGearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(clearGearButton, 104, 22)
		clearGearButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
		clearGearButton:SetText("Clear Cache")
		clearGearButton:SetScript("OnClick", function()
			coolstats.ShowClearCachedPlayerBrowserGearConfirm()
		end)

		local helpButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		SetFrameSize(helpButton, 62, 22)
		helpButton:SetPoint("LEFT", clearGearButton, "RIGHT", 8, 0)
		helpButton:SetText("HELP")
		coolstats.ApplyCachedPlayerBrowserBlueButton(helpButton)
		helpButton:SetScript("OnClick", function()
			coolstats.OpenCachedPlayerBrowserHelpWhisper()
		end)
		helpButton:SetScript("OnEnter", coolstats.CachedPlayerBrowserHelpButton_OnEnter)
		helpButton:SetScript("OnLeave", coolstats.CachedPlayerBrowserHelpButton_OnLeave)

		local classFilter = coolstats.CreateCachedPlayerBrowserClassDropdown(panel)
		classFilter:SetPoint("TOPLEFT", panel, "TOPLEFT", 34, -84)
		coolstats.CreateCachedPlayerBrowserClassResetButton(panel, classFilter)
		local specFilter = coolstats.CreateCachedPlayerBrowserSpecDropdown(panel)
		specFilter:SetPoint("TOPLEFT", panel, "TOPLEFT", 244, -84)
		coolstats.CreateCachedPlayerBrowserSpecResetButton(panel, specFilter)
		coolstats.UpdateCachedPlayerBrowserFilterButtons(panel)

		local header = CreateFrame("Frame", nil, panel)
		SetFrameSize(header, 860, 18)
		header:SetPoint("TOPLEFT", panel, "TOPLEFT", 46, -124)
		header.columns = {}
		coolstats.ApplyCachedPlayerBrowserHeaderBackground(header)
		header.nameText = coolstats.CreateCachedPlayerBrowserColumn(header, "Name", 40, 145, "LEFT", "name")
		header.mainSpecText = coolstats.CreateCachedPlayerBrowserColumn(header, "Main Spec", 190, 84, "CENTER", "main")
		header.offSpecText = coolstats.CreateCachedPlayerBrowserColumn(header, "Off Spec", 280, 84, "CENTER", "off")
		header.logsText = coolstats.CreateCachedPlayerBrowserColumn(header, "Logs", 370, 32, "CENTER", "logs")
		header.gearText = coolstats.CreateCachedPlayerBrowserColumn(header, "Gear", 405, 32, "CENTER", "gear")
		header.talentsText = coolstats.CreateCachedPlayerBrowserColumn(header, "Talents", 440, 44, "CENTER", "talents")
		header.scoreText = coolstats.CreateCachedPlayerBrowserColumn(header, panel.showPhase2History and "P3 Parse" or "Parses", 494, 60, "RIGHT", "parses")
		header.rankText = coolstats.CreateCachedPlayerBrowserColumn(header, panel.showPhase2History and "P3 Rank" or "Best Rank", 562, 66, "RIGHT", "rank")
		header.phase2Text = coolstats.CreateCachedPlayerBrowserColumn(header, "P2 Overall", 638, 106, "RIGHT", "phase2")
		if not panel.showPhase2History then
			header.phase2Text:Hide()
		end
		header.cacheText = coolstats.CreateCachedPlayerBrowserColumn(header, "Gear Cached", panel.showPhase2History and 754 or 638, panel.showPhase2History and 88 or 104, "RIGHT", "cache")
		header.columns[1] = header.nameText
		header.columns[2] = header.mainSpecText
		header.columns[3] = header.offSpecText
		header.columns[4] = header.logsText
		header.columns[5] = header.gearText
		header.columns[6] = header.talentsText
		header.columns[7] = header.scoreText
		header.columns[8] = header.rankText
		if panel.showPhase2History then
			header.columns[9] = header.phase2Text
			header.columns[10] = header.cacheText
		else
			header.columns[9] = header.cacheText
		end
		panel.header = header
		panel.listTop = header

		local scrollFrame = CreateFrame("ScrollFrame", "coolstatsCachedPlayerBrowserScrollFrame", panel, "FauxScrollFrameTemplate")
		SetFrameSize(scrollFrame, 860, 342)
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 46, -144)
		scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
			if FauxScrollFrame_OnVerticalScroll then
				FauxScrollFrame_OnVerticalScroll(self, offset, 18, coolstats.PaintCachedPlayerBrowserRows)
			end
		end)
		panel.scrollFrame = scrollFrame

		panel.rows = {}
		for index = 1, 18 do
			panel.rows[index] = coolstats.CreateCachedPlayerBrowserRow(panel, index)
		end

		panel:Hide()
		return panel
	end

	function coolstats.PaintCachedPlayerBrowserRows()
		local panel = coolstats.CreateCachedPlayerBrowser()
		if not panel then
			return
		end
		local rows = panel.browserRows or {}
		local counts = panel.browserCounts or { total = 0, logs = 0, current = 0, phase2 = 0, gear = 0, talents = 0, both = 0 }
		if panel.showPhase2History then
			panel.subtitle:SetText(string.format("%d shown   P3 Ranked %d   P2 History %d   Gear %d   Talents %d   Both %d", counts.total or 0, counts.current or 0, counts.phase2 or 0, counts.gear or 0, counts.talents or 0, counts.both or 0))
		else
			panel.subtitle:SetText(string.format("%d shown   Logs %d   Gear %d   Talents %d   Both %d", counts.total or 0, counts.logs or 0, counts.gear or 0, counts.talents or 0, counts.both or 0))
		end
		if panel.generatedText then
			panel.generatedText:SetText(coolstats.FormatCachedPlayerBrowserGeneratedAt())
		end
		coolstats.UpdateCachedPlayerBrowserFilterButtons(panel)
		coolstats.UpdateCachedPlayerBrowserHeaderSort(panel)

		if FauxScrollFrame_Update then
			FauxScrollFrame_Update(panel.scrollFrame, #rows, 18, 18)
		end
		local offset = 0
		if FauxScrollFrame_GetOffset then
			offset = FauxScrollFrame_GetOffset(panel.scrollFrame) or 0
		elseif panel.scrollFrame then
			offset = panel.scrollFrame.offset or 0
		end

		for index = 1, 18 do
			local rowFrame = panel.rows[index]
			local row = rows[offset + index]
			if row then
				rowFrame.playerName = row.name
				rowFrame.favoriteKey = row.favoriteKey
				rowFrame.isFavorite = row.isFavorite
				rowFrame.hasLogs = row.hasLogs
				rowFrame.hasGear = row.hasGear
				rowFrame.hasTalents = row.hasTalents
				rowFrame.cacheText = coolstats.GetCachedPlayerBrowserCacheText(row)
				rowFrame.className = coolstats.GetCachedPlayerBrowserClassName(row.classIndex)
				rowFrame.bestRankText = row.bestRank and ("#" .. tostring(row.bestRank)) or "-"
				rowFrame.bestRankSpecName = row.bestSpecName
				rowFrame.currentRankLabel = panel.showPhase2History and "Phase 3 Best Rank" or "Best Rank"
				rowFrame.phase2Text = panel.showPhase2History and row.phase2ScoreCenti and FormatUwUScoreWithRank(row.phase2ScoreCenti, row.phase2Rank) or "-"
				rowFrame.mainSpecText = row.mainSpecName and (row.mainSpecName .. " " .. FormatUwUScore(row.mainSpecScoreCenti)) or "-"
				rowFrame.offSpecText = row.offSpecName and (row.offSpecName .. " " .. FormatUwUScore(row.offSpecScoreCenti)) or "-"
				rowFrame.nameText:SetText(row.name or row.key or "Unknown")
				local classFile = row.classFile or UWU_CLASS_FILE_BY_INDEX[row.classIndex]
				local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
				local specIcon = row.currentPhaseRanked and row.player and GetUwUSpecIcon(row.player, row.mainSpecIndex or row.specIndex)
				if specIcon then
					rowFrame.classIcon:SetTexture(specIcon)
					rowFrame.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					rowFrame.classIcon:SetVertexColor(1, 1, 1, 1)
				else
					local classCoords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
					if classCoords then
						rowFrame.classIcon:SetTexture(UWU_CLASS_ICON_ATLAS)
						rowFrame.classIcon:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4])
						rowFrame.classIcon:SetVertexColor(1, 1, 1, 1)
					else
						rowFrame.classIcon:SetTexture("Interface\\Buttons\\WHITE8X8")
						rowFrame.classIcon:SetTexCoord(0, 1, 0, 1)
						rowFrame.classIcon:SetVertexColor(0.35, 0.35, 0.35, 0.75)
					end
				end
				if classColor then
					rowFrame.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
				else
					rowFrame.nameText:SetTextColor(0.86, 0.86, 0.78)
				end
				if rowFrame.favoriteButton then
					rowFrame.favoriteButton.playerName = row.name
					rowFrame.favoriteButton.favoriteKey = row.favoriteKey
					rowFrame.favoriteButton.isFavorite = row.isFavorite
					coolstats.UpdateCachedPlayerBrowserFavoriteIcon(rowFrame.favoriteButton, row.isFavorite)
					rowFrame.favoriteButton:Show()
				end
				rowFrame.logsText:SetText(row.hasLogs and "+" or "-")
				rowFrame.logsText:SetTextColor(row.hasLogs and 0.25 or 1, row.hasLogs and 1 or 0.25, 0.25)
				rowFrame.gearText:SetText(row.hasGear and "+" or "-")
				rowFrame.gearText:SetTextColor(row.hasGear and 0.25 or 1, row.hasGear and 1 or 0.25, 0.25)
				rowFrame.talentsText:SetText(row.hasTalents and "+" or "-")
				rowFrame.talentsText:SetTextColor(row.hasTalents and 0.25 or 1, row.hasTalents and 1 or 0.25, 0.25)
				if row.mainSpecName then
					local red, green, blue = GetUwUScoreColor(row.mainSpecScoreCenti)
					rowFrame.mainSpecTextFrame:SetText(row.mainSpecName)
					rowFrame.mainSpecTextFrame:SetTextColor(red, green, blue)
					rowFrame.mainSpecR, rowFrame.mainSpecG, rowFrame.mainSpecB = red, green, blue
				else
					rowFrame.mainSpecTextFrame:SetText("-")
					rowFrame.mainSpecTextFrame:SetTextColor(0.62, 0.62, 0.58)
					rowFrame.mainSpecR, rowFrame.mainSpecG, rowFrame.mainSpecB = 0.62, 0.62, 0.58
				end
				if row.offSpecName then
					local red, green, blue = GetUwUScoreColor(row.offSpecScoreCenti)
					rowFrame.offSpecTextFrame:SetText(row.offSpecName)
					rowFrame.offSpecTextFrame:SetTextColor(red, green, blue)
					rowFrame.offSpecR, rowFrame.offSpecG, rowFrame.offSpecB = red, green, blue
				else
					rowFrame.offSpecTextFrame:SetText("-")
					rowFrame.offSpecTextFrame:SetTextColor(0.62, 0.62, 0.58)
					rowFrame.offSpecR, rowFrame.offSpecG, rowFrame.offSpecB = 0.62, 0.62, 0.58
				end
				local rankRed, rankGreen, rankBlue = 1, 0.82, 0.16
				if row.scoreCenti then
					local red, green, blue = GetUwUScoreColor(row.scoreCenti)
					rowFrame.scoreText:SetText(FormatUwUScore(row.scoreCenti))
					rowFrame.scoreText:SetTextColor(red, green, blue)
					rankRed, rankGreen, rankBlue = GetUwUScoreColor(row.bestRankScoreCenti or row.scoreCenti)
				else
					rowFrame.scoreText:SetText("-")
					rowFrame.scoreText:SetTextColor(0.62, 0.62, 0.58)
					rankRed, rankGreen, rankBlue = 0.62, 0.62, 0.58
				end
				rowFrame.bestRankTextFrame:SetText(rowFrame.bestRankText)
				rowFrame.bestRankTextFrame:SetTextColor(rankRed, rankGreen, rankBlue)
				if panel.showPhase2History and row.phase2ScoreCenti then
					local phase2Red, phase2Green, phase2Blue = GetUwUScoreColor(row.phase2ScoreCenti)
					rowFrame.phase2TextFrame:Show()
					rowFrame.phase2TextFrame:SetText(rowFrame.phase2Text)
					rowFrame.phase2TextFrame:SetTextColor(phase2Red, phase2Green, phase2Blue)
					rowFrame.phase2R, rowFrame.phase2G, rowFrame.phase2B = phase2Red, phase2Green, phase2Blue
				else
					rowFrame.phase2TextFrame:SetText("-")
					rowFrame.phase2TextFrame:SetTextColor(0.62, 0.62, 0.58)
					rowFrame.phase2R, rowFrame.phase2G, rowFrame.phase2B = 0.62, 0.62, 0.58
					if not panel.showPhase2History then
						rowFrame.phase2TextFrame:Hide()
					end
				end
				rowFrame.cacheTextFrame:SetText(rowFrame.cacheText)
				rowFrame.cacheTextFrame:SetTextColor(row.hasGear and 1 or 0.62, row.hasGear and 1 or 0.62, row.hasGear and 1 or 0.58)
				rowFrame:Show()
			else
				rowFrame.playerName = nil
				rowFrame.favoriteKey = nil
				rowFrame.isFavorite = nil
				rowFrame.hasLogs = nil
				rowFrame.hasGear = nil
				rowFrame.hasTalents = nil
				rowFrame.className = nil
				rowFrame.bestRankText = nil
				rowFrame.bestRankSpecName = nil
				rowFrame.currentRankLabel = nil
				rowFrame.phase2Text = nil
				rowFrame.mainSpecText = nil
				rowFrame.offSpecText = nil
				if rowFrame.talentsText then
					rowFrame.talentsText:SetText("")
				end
				if rowFrame.favoriteButton then
					rowFrame.favoriteButton.playerName = nil
					rowFrame.favoriteButton.favoriteKey = nil
					rowFrame.favoriteButton.isFavorite = nil
					rowFrame.favoriteButton:Hide()
				end
				rowFrame:Hide()
			end
		end
	end

	function coolstats.RefreshCachedPlayerBrowser(rebuild)
		local panel = coolstats.CreateCachedPlayerBrowser()
		if not panel then
			return
		end
		if rebuild == true or not panel.browserRows then
			panel.browserRows, panel.browserCounts = coolstats.GetCachedPlayerBrowserRows(panel.searchBox and panel.searchBox:GetText() or "", panel)
			if panel.scrollFrame then
				panel.scrollFrame.offset = 0
			end
			local scrollBar = panel.scrollFrame and _G[panel.scrollFrame:GetName() .. "ScrollBar"]
			if scrollBar then
				scrollBar:SetValue(0)
			end
		end
		coolstats.PaintCachedPlayerBrowserRows()
	end

	function coolstats.OpenCachedPlayerBrowser()
		local panel = coolstats.CreateCachedPlayerBrowser()
		coolstats.RefreshCachedPlayerBrowser(true)
		panel:Show()
		if PlaySound then
			PlaySound("igCharacterInfoOpen")
		end
	end
end

local function AddTooltipLines()
	local unit = GetTooltipUnit()
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end
	local options = coolstats.GetTooltipFeatureOptions()
	if options.cacheOnHover ~= false then
		CacheInspectGearForUnit(unit)
	end

	if options.guildRank ~= false then
		ApplyGuildRankLine(unit)
	end
	if options.classLine ~= false then
		AddClassLine(unit)
	end

	if options.target ~= false then
		GameTooltip:AddLine(" ")
		local targetUnit = unit .. "target"
		local targetText = nil
		local targetR, targetG, targetB = 0.6, 0.6, 0.6

		if UnitExists(targetUnit) then
			targetText = GetTargetText(targetUnit)
			if UnitIsPlayer(targetUnit) then
				targetR, targetG, targetB = GetClassColor(targetUnit)
			else
				targetR, targetG, targetB = GetReactionColor(targetUnit)
			end
		end

		if targetText then
			GameTooltip:AddDoubleLine("Target", targetText, ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, targetR, targetG, targetB)
		else
			GameTooltip:AddDoubleLine("Target", "None", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, targetR, targetG, targetB)
		end
	end

	if options.raidProgressFallback ~= false then
		local ok = pcall(AddRaidProgressLines, unit)
		if not ok then
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine("Raid Progress", "Unavailable", ADDON_COLOR_R, ADDON_COLOR_G, ADDON_COLOR_B, 0.6, 0.6, 0.6)
		end
	end
	AddUwULogsLines(unit)
	lastTooltipAltState = IsAltKeyDown and IsAltKeyDown() or false
	GameTooltip:Show()
end

RefreshCurrentTooltip = function()
	local unit = GetTooltipUnit()
	if not unit or not UnitExists(unit) or not GameTooltip.SetUnit then
		return
	end
	GameTooltip:ClearLines()
	GameTooltip:SetUnit(unit)
end

tooltipFrame:RegisterEvent("ADDON_LOADED")
tooltipFrame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
tooltipFrame:RegisterEvent("INSPECT_READY")
tooltipFrame:RegisterEvent("INSPECT_TALENT_READY")
tooltipFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
tooltipFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
tooltipFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
tooltipFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == ADDON_NAME then
			EnsureTooltipDatabase()
			PruneRaidProgressCache(true)
			PruneCachedGearCache(true)
			coolstats.PruneCachedTalentCache(true)
			HookInspectUwUPanel()
		elseif addonName == "Blizzard_InspectUI" then
			HookInspectUwUPanel()
			UpdateInspectUwUPanel()
		elseif addonName == "Blizzard_AchievementUI" then
			coolstats.HookAchievementComparisonUI()
		end
		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		if coolstats.EnsureRealmDataLoaded then
			coolstats.EnsureRealmDataLoaded()
		end
		for key in pairs(raidProgressCache) do
			raidProgressCache[key] = nil
		end
		for key in pairs(uwuTooltipCache) do
			uwuTooltipCache[key] = nil
		end
		pendingRaidProgress = nil
		coolstats.raidProgressRequestState.queued = nil
		coolstats.ClearTooltipAchievementComparison()
		self:SetScript("OnUpdate", nil)
		return
	end

	if event == "INSPECT_READY" then
		local inspectGuid = ...
		local inspectUnit = coolstats.FindInspectReadyUnit(inspectGuid or pendingGearInspectGuid, inspectGuid and nil or pendingGearInspectName)
		if inspectUnit then
			CacheInspectGearForUnit(inspectUnit)
		end
		pendingGearInspectName = nil
		pendingGearInspectGuid = nil
		if lookupUwUPanel and lookupUwUPanel:IsShown() then
			UpdateCachedGearPanel(lookupUwUPanel, lookupUwUPanel.renderName, lookupUwUPanel.renderPlayer)
		end
		if coolstats and coolstats.pendingCachedTalentsOpenName then
			local pendingName = coolstats.pendingCachedTalentsOpenName
			if coolstats.GetCachedTalentSnapshot(pendingName) then
				coolstats.pendingCachedTalentsOpenName = nil
				coolstats.OpenCachedTalentsForName(pendingName)
			end
		end
	end

	if event == "INSPECT_TALENT_READY" then
		coolstats.CaptureReadyInspectTalents(coolstats.pendingTalentInspectGuid, coolstats.pendingTalentInspectName)
	end

	if event == "PLAYER_TARGET_CHANGED" then
		RequestGearInspectForUnit("target")
		if lookupUwUPanel and lookupUwUPanel:IsShown() then
			UpdateCachedGearPanel(lookupUwUPanel, lookupUwUPanel.renderName, lookupUwUPanel.renderPlayer)
		end
	end

	if event == "INSPECT_READY" or event == "INSPECT_TALENT_READY" or event == "PLAYER_TARGET_CHANGED" then
		UpdateInspectUwUPanel()
		return
	end

	if event == "MODIFIER_STATE_CHANGED" then
		local key = ...
		if key == "LALT" or key == "RALT" then
			local altDown = IsAltKeyDown and IsAltKeyDown() or false
			if altDown ~= lastTooltipAltState then
				lastTooltipAltState = altDown
				QueueCurrentTooltipRefresh()
			end
		end
		return
	end

	if event ~= "INSPECT_ACHIEVEMENT_READY" or not pendingRaidProgress then
		return
	end

	local key = pendingRaidProgress.key
	if coolstats.IsAchievementComparisonUIVisible() then
		pendingRaidProgress = nil
		coolstats.raidProgressRequestState.queued = nil
		tooltipAchievementComparisonOwned = false
		CacheRaidProgressFailure(key, true, "Achievement UI busy")
		self:SetScript("OnUpdate", nil)
		return
	end
	local unit = pendingRaidProgress.unit
	raidProgressCache[key] = BuildRaidProgress("comparison", unit)
	pendingRaidProgress = nil

	coolstats.ClearTooltipAchievementComparison()

	if coolstats.raidProgressRequestState.queued then
		self:SetScript("OnUpdate", coolstats.RaidProgressFrame_OnUpdate)
	else
		self:SetScript("OnUpdate", nil)
	end
	RefreshTooltipForKey(key)
end)

GameTooltip:HookScript("OnTooltipSetUnit", AddTooltipLines)
coolstats.HookAchievementComparisonUI()
coolstats.InstallPlayerLogLinkHandler()
coolstats.InstallPlayerLogChatFilters()
