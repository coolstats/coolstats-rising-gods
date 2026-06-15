local ADDON_NAME = ...

local coolstats = _G.coolstats or {}
_G.coolstats = coolstats

local floor = math.floor
local ceil = math.ceil
local abs = math.abs
local min = math.min
local max = math.max
local format = string.format
local lower = string.lower
local match = string.match
local gsub = string.gsub

local db
local ui = { rows = {}, rowByKey = {}, sections = {}, badges = { player = {}, inspect = {} }, modelScores = {}, appearanceToggles = {}, statPopouts = {} }
local nativeStatFrames = {}
local repairTooltip
local defaultStatsHooked = false
local updatePending = false
local updateElapsed = 0
local tooltipsHooked = false
local gearScoreTamed = false
local QueueUpdate

local defaults = {
	enableCharacterPanel = true,
	showStatsPanel = true,
	showItemLevels = true,
	showSlotBorders = true,
	cleanGearScoreTooltips = true,
	tooltip = {
		guildRank = true,
		classLine = true,
		target = true,
		raidProgressFallback = true,
		logsSummary = true,
		logsBossDetails = true,
		cacheOnHover = true,
	},
	editMode = false,
	popoutMode = false,
	favoriteMode = false,
	hiddenSections = {},
	hiddenRows = {},
	collapsedSections = {},
	sectionOrder = {},
	favoriteRows = {},
	itemLevelBadges = {
		position = "default",
		fontSize = 15,
	},
	lootAlerts = {
		enabled = true,
		minQuality = 3,
		selfLoot = true,
		groupRolls = true,
		professions = false,
		sound = true,
		animations = true,
	},
	statPopouts = {},
	popoutOptions = {
		alpha = 0.96,
		fontIndex = 1,
		fontScale = 1.0,
		snapDistance = 10,
		showHeader = true,
		syncSize = false,
	},
	backgrounds = {
		stats = {
			texture = "default",
			alpha = 1.0,
			contrast = 0,
			zoom = 1.6,
			panX = 1,
			panY = 0,
			palette = "classic",
		},
	},
	minimap = {
		angle = 150,
		radius = 80,
	},
}

local PANEL_WIDTH = 236
local PANEL_HEIGHT = 404
local PANEL_ANCHOR_X = -34
local PANEL_ANCHOR_Y = -22
local PANEL_APPEARANCE_TOP = 32
local PANEL_APPEARANCE_HEIGHT = 24
local PANEL_SCROLL_TOP = 68
local PANEL_CONTENT_WIDTH = 214
local PANEL_ROW_WIDTH = 206
local PANEL_ROW_HEIGHT = 15
local PANEL_LABEL_WIDTH = 94
local PANEL_VALUE_WIDTH = 104
local SECTION_HEADER_WIDTH = 210
local STAT_POPOUT_DEFAULT_WIDTH = 142
local STAT_POPOUT_DEFAULT_HEIGHT = 48
local STAT_POPOUT_MIN_WIDTH = 96
local STAT_POPOUT_MIN_HEIGHT = 38
local STAT_POPOUT_SNAP_DISTANCE = 10
local STAT_POPOUT_GRID_SPACING = 40
local STATS_BACKGROUND_DEFAULT = "Interface\\CharacterFrame\\UI-Party-Background"
local SOLID_BACKGROUND_TEXTURE = "Interface\\Buttons\\WHITE8X8"

coolstats.ITEM_LEVEL_BADGE_DEFAULT_FONT_SIZE = 15
coolstats.ITEM_LEVEL_BADGE_POSITIONS = {
	{ key = "default", label = "Default" },
	{ key = "lowerLeft", label = "Lower left" },
	{ key = "lowerRight", label = "Lower right" },
	{ key = "off", label = "Off" },
}

local BACKGROUND_TEXTURES = {
	{ key = "default", label = "Default", file = STATS_BACKGROUND_DEFAULT },
	{ key = "lowHealth", label = "Blizzard Low Health", file = "Interface\\FullScreenTextures\\LowHealth" },
	{ key = "outOfControl", label = "Blizzard Losing Control", file = "Interface\\FullScreenTextures\\OutOfControl" },
	{ key = "tabard", label = "Blizzard Tabard Background", file = "Interface\\TabardFrame\\TabardFrameBackground" },
	{ key = "talentDeathKnightBlood", label = "Talent: Death Knight Blood", talent = "DeathKnightBlood" },
	{ key = "talentDeathKnightFrost", label = "Talent: Death Knight Frost", talent = "DeathKnightFrost" },
	{ key = "talentDeathKnightUnholy", label = "Talent: Death Knight Unholy", talent = "DeathKnightUnholy" },
	{ key = "talentDruidBalance", label = "Talent: Druid Balance", talent = "DruidBalance" },
	{ key = "talentDruidFeralCombat", label = "Talent: Druid Feral Combat", talent = "DruidFeralCombat" },
	{ key = "talentDruidRestoration", label = "Talent: Druid Restoration", talent = "DruidRestoration" },
	{ key = "talentHunterBeastMastery", label = "Talent: Hunter Beast Mastery", talent = "HunterBeastMastery" },
	{ key = "talentHunterMarksmanship", label = "Talent: Hunter Marksmanship", talent = "HunterMarksmanship" },
	{ key = "talentHunterSurvival", label = "Talent: Hunter Survival", talent = "HunterSurvival" },
	{ key = "talentMageArcane", label = "Talent: Mage Arcane", talent = "MageArcane" },
	{ key = "talentMageFire", label = "Talent: Mage Fire", talent = "MageFire" },
	{ key = "talentMageFrost", label = "Talent: Mage Frost", talent = "MageFrost" },
	{ key = "talentPaladinHoly", label = "Talent: Paladin Holy", talent = "PaladinHoly" },
	{ key = "talentPaladinProtection", label = "Talent: Paladin Protection", talent = "PaladinProtection" },
	{ key = "talentPaladinCombat", label = "Talent: Paladin Retribution", talent = "PaladinCombat" },
	{ key = "talentPriestDiscipline", label = "Talent: Priest Discipline", talent = "PriestDiscipline" },
	{ key = "talentPriestHoly", label = "Talent: Priest Holy", talent = "PriestHoly" },
	{ key = "talentPriestShadow", label = "Talent: Priest Shadow", talent = "PriestShadow" },
	{ key = "talentRogueAssassination", label = "Talent: Rogue Assassination", talent = "RogueAssassination" },
	{ key = "talentRogueCombat", label = "Talent: Rogue Combat", talent = "RogueCombat" },
	{ key = "talentRogueSubtlety", label = "Talent: Rogue Subtlety", talent = "RogueSubtlety" },
	{ key = "talentShamanElementalCombat", label = "Talent: Shaman Elemental", talent = "ShamanElementalCombat" },
	{ key = "talentShamanEnhancement", label = "Talent: Shaman Enhancement", talent = "ShamanEnhancement" },
	{ key = "talentShamanRestoration", label = "Talent: Shaman Restoration", talent = "ShamanRestoration" },
	{ key = "talentWarlockCurses", label = "Talent: Warlock Affliction", talent = "WarlockCurses" },
	{ key = "talentWarlockSummoning", label = "Talent: Warlock Demonology", talent = "WarlockSummoning" },
	{ key = "talentWarlockDestruction", label = "Talent: Warlock Destruction", talent = "WarlockDestruction" },
	{ key = "talentWarriorArms", label = "Talent: Warrior Arms", talent = "WarriorArms" },
	{ key = "talentWarriorFury", label = "Talent: Warrior Fury", talent = "WarriorFury" },
	{ key = "talentWarriorProtection", label = "Talent: Warrior Protection", talent = "WarriorProtection" },
	{ key = "none", label = "None", file = nil },
}

local backgroundTextureByKey = {}
local backgroundOptionKeys = { "stats" }
for index = 1, #BACKGROUND_TEXTURES do
	local info = BACKGROUND_TEXTURES[index]
	backgroundTextureByKey[info.key] = info
end

coolstats.STAT_TEXT_PALETTES = {
	{ key = "classic", label = "Classic Gold", header = { 1.00, 0.82, 0.00 }, labelColor = { 1.00, 0.78, 0.12 }, value = { 1.00, 1.00, 1.00 } },
	{ key = "arcane", label = "Arcane Blue", header = { 0.28, 0.88, 1.00 }, labelColor = { 0.58, 0.84, 1.00 }, value = { 0.92, 0.98, 1.00 } },
	{ key = "emerald", label = "Emerald Watch", header = { 0.32, 1.00, 0.48 }, labelColor = { 0.72, 0.96, 0.54 }, value = { 0.92, 1.00, 0.90 } },
	{ key = "crimson", label = "Crimson Steel", header = { 1.00, 0.36, 0.24 }, labelColor = { 1.00, 0.66, 0.36 }, value = { 0.96, 0.92, 0.88 } },
	{ key = "moonwell", label = "Moonwell", header = { 0.58, 0.78, 1.00 }, labelColor = { 0.78, 0.88, 1.00 }, value = { 0.96, 0.98, 1.00 } },
	{ key = "felFire", label = "Fel Fire", header = { 0.58, 1.00, 0.10 }, labelColor = { 0.86, 1.00, 0.36 }, value = { 0.92, 1.00, 0.74 } },
	{ key = "silvermoon", label = "Silvermoon", header = { 1.00, 0.72, 0.18 }, labelColor = { 1.00, 0.48, 0.38 }, value = { 1.00, 0.94, 0.78 } },
	{ key = "northrend", label = "Northrend Frost", header = { 0.54, 0.92, 1.00 }, labelColor = { 0.72, 0.96, 1.00 }, value = { 0.88, 0.98, 1.00 } },
	{ key = "plagueglass", label = "Plagueglass", header = { 0.66, 0.92, 0.22 }, labelColor = { 0.82, 0.92, 0.46 }, value = { 0.96, 1.00, 0.80 } },
	{ key = "violetCitadel", label = "Violet Citadel", header = { 0.80, 0.58, 1.00 }, labelColor = { 0.92, 0.74, 1.00 }, value = { 0.98, 0.94, 1.00 } },
	{ key = "titanBronze", label = "Titan Bronze", header = { 1.00, 0.70, 0.30 }, labelColor = { 0.98, 0.78, 0.48 }, value = { 0.98, 0.92, 0.82 } },
	{ key = "shadowflame", label = "Shadowflame", header = { 0.94, 0.34, 1.00 }, labelColor = { 1.00, 0.48, 0.62 }, value = { 1.00, 0.90, 0.98 } },
	{ key = "ashen", label = "Ashen", header = { 0.90, 0.86, 0.74 }, labelColor = { 0.78, 0.74, 0.66 }, value = { 0.96, 0.94, 0.88 } },
	{ key = "sunwell", label = "Sunwell", header = { 1.00, 0.88, 0.28 }, labelColor = { 1.00, 0.76, 0.44 }, value = { 1.00, 0.98, 0.86 } },
	{ key = "deepSea", label = "Deep Sea", header = { 0.26, 0.86, 0.92 }, labelColor = { 0.50, 0.92, 0.86 }, value = { 0.88, 1.00, 0.96 } },
	{ key = "ebon", label = "Ebon", header = { 0.72, 0.78, 0.88 }, labelColor = { 0.62, 0.70, 0.82 }, value = { 0.92, 0.94, 0.98 } },
}

coolstats.statTextPaletteByKey = {}
for index = 1, #coolstats.STAT_TEXT_PALETTES do
	local info = coolstats.STAT_TEXT_PALETTES[index]
	coolstats.statTextPaletteByKey[info.key] = info
end

function coolstats.GetItemLevelBadgePositionInfo(key)
	for index = 1, #coolstats.ITEM_LEVEL_BADGE_POSITIONS do
		local info = coolstats.ITEM_LEVEL_BADGE_POSITIONS[index]
		if info.key == key then
			return info
		end
	end
	return nil
end

local STAT_POPOUT_FONTS = {
	{ name = "Classic", file = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
	{ name = "Morpheus", file = "Fonts\\MORPHEUS.TTF", flags = "OUTLINE" },
	{ name = "Skurri", file = "Fonts\\SKURRI.TTF", flags = "OUTLINE" },
	{ name = "Narrow", file = "Fonts\\ARIALN.TTF", flags = "OUTLINE" },
}

local paperDollSlotButtons = {
	{ slot = 1, button = "CharacterHeadSlot" },
	{ slot = 2, button = "CharacterNeckSlot" },
	{ slot = 3, button = "CharacterShoulderSlot" },
	{ slot = 15, button = "CharacterBackSlot" },
	{ slot = 5, button = "CharacterChestSlot" },
	{ slot = 4, button = "CharacterShirtSlot" },
	{ slot = 19, button = "CharacterTabardSlot" },
	{ slot = 9, button = "CharacterWristSlot" },
	{ slot = 10, button = "CharacterHandsSlot" },
	{ slot = 6, button = "CharacterWaistSlot" },
	{ slot = 7, button = "CharacterLegsSlot" },
	{ slot = 8, button = "CharacterFeetSlot" },
	{ slot = 11, button = "CharacterFinger0Slot" },
	{ slot = 12, button = "CharacterFinger1Slot" },
	{ slot = 13, button = "CharacterTrinket0Slot" },
	{ slot = 14, button = "CharacterTrinket1Slot" },
	{ slot = 16, button = "CharacterMainHandSlot" },
	{ slot = 17, button = "CharacterSecondaryHandSlot" },
	{ slot = 18, button = "CharacterRangedSlot" },
}

local inspectSlotButtons = {
	{ slot = 1, button = "InspectHeadSlot" },
	{ slot = 2, button = "InspectNeckSlot" },
	{ slot = 3, button = "InspectShoulderSlot" },
	{ slot = 15, button = "InspectBackSlot" },
	{ slot = 5, button = "InspectChestSlot" },
	{ slot = 4, button = "InspectShirtSlot" },
	{ slot = 19, button = "InspectTabardSlot" },
	{ slot = 9, button = "InspectWristSlot" },
	{ slot = 10, button = "InspectHandsSlot" },
	{ slot = 6, button = "InspectWaistSlot" },
	{ slot = 7, button = "InspectLegsSlot" },
	{ slot = 8, button = "InspectFeetSlot" },
	{ slot = 11, button = "InspectFinger0Slot" },
	{ slot = 12, button = "InspectFinger1Slot" },
	{ slot = 13, button = "InspectTrinket0Slot" },
	{ slot = 14, button = "InspectTrinket1Slot" },
	{ slot = 16, button = "InspectMainHandSlot" },
	{ slot = 17, button = "InspectSecondaryHandSlot" },
	{ slot = 18, button = "InspectRangedSlot" },
}

local scoreSlots = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local slotWeights = {
	INVTYPE_RELIC = { mod = 0.3164, itemSlot = 18, enchantable = false },
	INVTYPE_TRINKET = { mod = 0.5625, itemSlot = 33, enchantable = false },
	INVTYPE_2HWEAPON = { mod = 2.0000, itemSlot = 16, enchantable = true },
	INVTYPE_WEAPONMAINHAND = { mod = 1.0000, itemSlot = 16, enchantable = true },
	INVTYPE_WEAPONOFFHAND = { mod = 1.0000, itemSlot = 17, enchantable = true },
	INVTYPE_RANGED = { mod = 0.3164, itemSlot = 18, enchantable = true },
	INVTYPE_THROWN = { mod = 0.3164, itemSlot = 18, enchantable = false },
	INVTYPE_RANGEDRIGHT = { mod = 0.3164, itemSlot = 18, enchantable = false },
	INVTYPE_SHIELD = { mod = 1.0000, itemSlot = 17, enchantable = true },
	INVTYPE_WEAPON = { mod = 1.0000, itemSlot = 36, enchantable = true },
	INVTYPE_HOLDABLE = { mod = 1.0000, itemSlot = 17, enchantable = false },
	INVTYPE_HEAD = { mod = 1.0000, itemSlot = 1, enchantable = true },
	INVTYPE_NECK = { mod = 0.5625, itemSlot = 2, enchantable = false },
	INVTYPE_SHOULDER = { mod = 0.7500, itemSlot = 3, enchantable = true },
	INVTYPE_CHEST = { mod = 1.0000, itemSlot = 5, enchantable = true },
	INVTYPE_ROBE = { mod = 1.0000, itemSlot = 5, enchantable = true },
	INVTYPE_WAIST = { mod = 0.7500, itemSlot = 6, enchantable = false },
	INVTYPE_LEGS = { mod = 1.0000, itemSlot = 7, enchantable = true },
	INVTYPE_FEET = { mod = 0.7500, itemSlot = 8, enchantable = true },
	INVTYPE_WRIST = { mod = 0.5625, itemSlot = 9, enchantable = true },
	INVTYPE_HAND = { mod = 0.7500, itemSlot = 10, enchantable = true },
	INVTYPE_FINGER = { mod = 0.5625, itemSlot = 31, enchantable = false },
	INVTYPE_CLOAK = { mod = 0.5625, itemSlot = 15, enchantable = true },
	INVTYPE_BODY = { mod = 0.0000, itemSlot = 4, enchantable = false },
}

local highItemFormula = {
	[4] = { a = 91.4500, b = 0.6500 },
	[3] = { a = 81.3750, b = 0.8125 },
	[2] = { a = 73.0000, b = 1.0000 },
}

local lowItemFormula = {
	[4] = { a = 26.0000, b = 1.2000 },
	[3] = { a = 0.7500, b = 1.8000 },
	[2] = { a = 8.0000, b = 2.0000 },
	[1] = { a = 0.0000, b = 2.2500 },
}

local scoreColorBands = {
	{ max = 1000, label = "Trash", r = { 0.55, 0, 0.00045, 1 }, g = { 0.55, 0, 0.00045, 1 }, b = { 0.55, 0, 0.00045, 1 } },
	{ max = 2000, label = "Common", r = { 1.00, 1000, 0.00088, -1 }, g = { 1.00, 0, 0, 0 }, b = { 1.00, 1000, 0.00100, -1 } },
	{ max = 3000, label = "Uncommon", r = { 0.12, 2000, 0.00012, -1 }, g = { 1.00, 2000, 0.00050, -1 }, b = { 0.00, 2000, 0.00100, 1 } },
	{ max = 4000, label = "Superior", r = { 0.00, 3000, 0.00069, 1 }, g = { 0.50, 3000, 0.00022, -1 }, b = { 1.00, 3000, 0.00003, -1 } },
	{ max = 5000, label = "Epic", r = { 0.69, 4000, 0.00025, 1 }, g = { 0.28, 4000, 0.00019, 1 }, b = { 0.97, 4000, 0.00096, -1 } },
	{ max = 6000, label = "Legendary", r = { 0.94, 5000, 0.00006, 1 }, g = { 0.47, 5000, 0.00047, -1 }, b = { 0.00, 0, 0, 0 } },
}

local powerNames = {
	[0] = MANA or "Mana",
	[1] = RAGE or "Rage",
	[2] = FOCUS or "Focus",
	[3] = ENERGY or "Energy",
	[6] = RUNIC_POWER or "Runic Power",
}

local statTokens = {
	[1] = "STRENGTH",
	[2] = "AGILITY",
	[3] = "STAMINA",
	[4] = "INTELLECT",
	[5] = "SPIRIT",
}

local function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00c0ffcoolstats:|r " .. tostring(message))
	end
end

local function CopyDefaults(target, source)
	if type(target) ~= "table" then
		target = {}
	end
	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = CopyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

local function SetVisible(frame, shown)
	if not frame then
		return
	end
	if shown then
		frame:Show()
	else
		frame:Hide()
	end
end

local function EnsureEditOptions()
	if not db then
		return
	end
	if type(db.hiddenSections) ~= "table" then
		db.hiddenSections = {}
	end
	if type(db.hiddenRows) ~= "table" then
		db.hiddenRows = {}
	end
	if type(db.collapsedSections) ~= "table" then
		db.collapsedSections = {}
	end
	if type(db.sectionOrder) ~= "table" then
		db.sectionOrder = {}
	end
	if type(db.favoriteRows) ~= "table" then
		db.favoriteRows = {}
	end
	if type(db.itemLevelBadges) ~= "table" then
		db.itemLevelBadges = CopyDefaults({}, defaults.itemLevelBadges)
	else
		db.itemLevelBadges = CopyDefaults(db.itemLevelBadges, defaults.itemLevelBadges)
	end
	if not coolstats.GetItemLevelBadgePositionInfo(db.itemLevelBadges.position or "") then
		db.itemLevelBadges.position = defaults.itemLevelBadges.position
	end
	db.itemLevelBadges.fontSize = max(0, min(30, tonumber(db.itemLevelBadges.fontSize) or defaults.itemLevelBadges.fontSize))
	if type(db.lootAlerts) ~= "table" then
		db.lootAlerts = CopyDefaults({}, defaults.lootAlerts)
	else
		db.lootAlerts = CopyDefaults(db.lootAlerts, defaults.lootAlerts)
	end
	if type(db.tooltip) ~= "table" then
		db.tooltip = CopyDefaults({}, defaults.tooltip)
	else
		db.tooltip = CopyDefaults(db.tooltip, defaults.tooltip)
	end
	if type(db.minimap) ~= "table" then
		db.minimap = CopyDefaults({}, defaults.minimap)
	else
		db.minimap = CopyDefaults(db.minimap, defaults.minimap)
	end
	db.minimap.angle = tonumber(db.minimap.angle) or defaults.minimap.angle
	db.minimap.radius = max(58, min(92, tonumber(db.minimap.radius) or defaults.minimap.radius))
	if type(db.statPopouts) ~= "table" then
		db.statPopouts = {}
	end
	if type(db.popoutOptions) ~= "table" then
		db.popoutOptions = CopyDefaults({}, defaults.popoutOptions)
	else
		db.popoutOptions = CopyDefaults(db.popoutOptions, defaults.popoutOptions)
	end
	local migrateBackgroundPanXDefault = tonumber(db.backgroundDefaultsVersion) ~= 2
	if type(db.backgrounds) ~= "table" then
		db.backgrounds = CopyDefaults({}, defaults.backgrounds)
	else
		db.backgrounds = CopyDefaults(db.backgrounds, defaults.backgrounds)
	end
	for index = 1, #backgroundOptionKeys do
		local key = backgroundOptionKeys[index]
		if type(db.backgrounds[key]) ~= "table" then
			db.backgrounds[key] = CopyDefaults({}, defaults.backgrounds[key])
		else
			db.backgrounds[key] = CopyDefaults(db.backgrounds[key], defaults.backgrounds[key])
		end
		if not backgroundTextureByKey[db.backgrounds[key].texture or ""] then
			db.backgrounds[key].texture = defaults.backgrounds[key].texture
		end
		if key == "stats" and migrateBackgroundPanXDefault and tonumber(db.backgrounds[key].panX) == 0 then
			db.backgrounds[key].panX = defaults.backgrounds[key].panX
		end
		db.backgrounds[key].alpha = max(0, min(1, tonumber(db.backgrounds[key].alpha) or defaults.backgrounds[key].alpha))
		db.backgrounds[key].contrast = max(-1, min(1, tonumber(db.backgrounds[key].contrast) or defaults.backgrounds[key].contrast))
		db.backgrounds[key].panX = max(-1, min(1, tonumber(db.backgrounds[key].panX) or defaults.backgrounds[key].panX))
		db.backgrounds[key].panY = max(-1, min(1, tonumber(db.backgrounds[key].panY) or defaults.backgrounds[key].panY))
		if tonumber(db.backgrounds[key].zoom) == 1 or tonumber(db.backgrounds[key].zoom) == 3 then
			db.backgrounds[key].zoom = defaults.backgrounds[key].zoom
		end
		db.backgrounds[key].zoom = max(0.7, min(3.0, tonumber(db.backgrounds[key].zoom) or defaults.backgrounds[key].zoom))
		if not coolstats.statTextPaletteByKey[db.backgrounds[key].palette or ""] then
			db.backgrounds[key].palette = defaults.backgrounds[key].palette
		end
	end
	db.backgroundDefaultsVersion = 2
end

function coolstats.EnsureOptions()
	EnsureEditOptions()
end

function coolstats.IsCharacterPanelEnabled()
	return not db or db.enableCharacterPanel ~= false
end

function coolstats.ShowCharacterPanelReloadPrompt()
	local promptText = "Changing character panel features requires a UI reload.\n\nReload now?"
	if not ReloadUI then
		Print("Reload your UI to apply the character panel feature change.")
		return
	end
	if not StaticPopupDialogs or not StaticPopup_Show then
		ReloadUI()
		return
	end
	if not StaticPopupDialogs["COOLSTATS_CHARACTER_PANEL_RELOAD"] then
		StaticPopupDialogs["COOLSTATS_CHARACTER_PANEL_RELOAD"] = {
			text = promptText,
			button1 = YES or "Yes",
			button2 = NO or "No",
			OnAccept = function()
				ReloadUI()
			end,
			timeout = 0,
			whileDead = 1,
			hideOnEscape = 1,
		}
	else
		StaticPopupDialogs["COOLSTATS_CHARACTER_PANEL_RELOAD"].text = promptText
	end
	StaticPopup_Show("COOLSTATS_CHARACTER_PANEL_RELOAD")
end

function coolstats.SetCharacterPanelEnabled(enabled, promptReload)
	if not db then
		return
	end
	local newValue = enabled ~= false
	if db.enableCharacterPanel == newValue then
		return
	end
	db.enableCharacterPanel = newValue
	db.editMode = false
	db.favoriteMode = false
	db.popoutMode = false
	Print("Character panel features: " .. (newValue and "|cff00ff00on|r" or "|cffff4040off|r"))
	if QueueUpdate then
		QueueUpdate()
	end
	if promptReload ~= false then
		coolstats.ShowCharacterPanelReloadPrompt()
	end
end

function coolstats.GetDB()
	return db
end

function coolstats.GetDefaults()
	return defaults
end

function coolstats.CopyDefaults(target, source)
	return CopyDefaults(target, source)
end

function coolstats.GetLootAlertOptions()
	EnsureEditOptions()
	return db and db.lootAlerts or defaults.lootAlerts
end

function coolstats.GetTooltipOptions()
	EnsureEditOptions()
	return db and db.tooltip or defaults.tooltip
end

function coolstats.GetItemLevelBadgeOptions()
	EnsureEditOptions()
	return db and db.itemLevelBadges or defaults.itemLevelBadges
end

function coolstats.GetItemLevelBadgePositions()
	return coolstats.ITEM_LEVEL_BADGE_POSITIONS
end

function coolstats.GetItemLevelBadgePositionLabel(key)
	local info = coolstats.GetItemLevelBadgePositionInfo(key or "default") or coolstats.GetItemLevelBadgePositionInfo("default")
	return info and info.label or "Default"
end

function coolstats.GetBackgroundOptions()
	EnsureEditOptions()
	return db and db.backgrounds or defaults.backgrounds
end

function coolstats.GetBackgroundTextures()
	return BACKGROUND_TEXTURES
end

function coolstats.GetBackgroundTextureLabel(key)
	local info = backgroundTextureByKey[key or "default"] or backgroundTextureByKey.default
	return info and info.label or "Default"
end

function coolstats.GetStatTextPalettes()
	return coolstats.STAT_TEXT_PALETTES
end

function coolstats.GetStatTextPaletteLabel(key)
	local info = coolstats.statTextPaletteByKey[key or "classic"] or coolstats.statTextPaletteByKey.classic
	return info and info.label or "Classic Gold"
end

function coolstats.RefreshAll()
	QueueUpdate()
end

local function ConfigKey(text)
	text = lower(tostring(text or ""))
	text = gsub(text, "[^%w]+", "_")
	text = gsub(text, "^_+", "")
	text = gsub(text, "_+$", "")
	if text == "" then
		return "entry"
	end
	return text
end

local function HideDefaultCharacterStats()
	if CharacterAttributesFrame then
		CharacterAttributesFrame:Hide()
		if not defaultStatsHooked and CharacterAttributesFrame.HookScript then
			defaultStatsHooked = true
			CharacterAttributesFrame:HookScript("OnShow", function(self)
				self:Hide()
			end)
		end
	end

	if CharacterModelFrame and CharacterModelFrame.SetHeight then
		CharacterModelFrame:SetHeight(300)
	end
end

local function SetSize(frame, width, height)
	frame:SetWidth(width)
	frame:SetHeight(height)
end

local function SafeRegisterEvent(frame, eventName)
	pcall(frame.RegisterEvent, frame, eventName)
end

local function SafeCall(method, ...)
	if type(method) == "function" then
		return method(...)
	end
end

function coolstats.AddMinimapMenuButton(text, func, disabled, isTitle)
	if not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then
		return
	end
	local info = UIDropDownMenu_CreateInfo()
	info.text = text
	info.notCheckable = 1
	info.disabled = disabled and 1 or nil
	info.isTitle = isTitle and 1 or nil
	info.func = func
	UIDropDownMenu_AddButton(info)
end

function coolstats.OpenSettingsFromMinimap()
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
	if PlaySound then
		PlaySound("igMainMenuOption")
	end
	if coolstats.OpenOptionsPanel then
		coolstats.OpenOptionsPanel()
	else
		Print("Settings are not available yet.")
	end
end

function coolstats.OpenCachedPlayerBrowserFromMinimap()
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
	if coolstats.OpenCachedPlayerBrowser then
		coolstats.OpenCachedPlayerBrowser()
	else
		Print("Player browser is not available yet.")
	end
end

function coolstats.InitializeMinimapMenu()
	coolstats.AddMinimapMenuButton("coolstats", nil, true, true)
	coolstats.AddMinimapMenuButton("Reset Minimap Button", function()
		if CloseDropDownMenus then
			CloseDropDownMenus()
		end
		local options = coolstats.GetMinimapOptions()
		if options then
			options.angle = defaults.minimap.angle
			options.radius = defaults.minimap.radius
		end
		coolstats.PositionMinimapButton()
	end)
	coolstats.AddMinimapMenuButton("Logs Browser", coolstats.OpenCachedPlayerBrowserFromMinimap)
	coolstats.AddMinimapMenuButton("Settings", coolstats.OpenSettingsFromMinimap)
	coolstats.AddMinimapMenuButton(CLOSE or "Close", function()
		if CloseDropDownMenus then
			CloseDropDownMenus()
		end
	end)
end

function coolstats.OpenMinimapMenu(button)
	if not button then
		return
	end
	if not (UIDropDownMenu_Initialize and ToggleDropDownMenu) then
		coolstats.OpenSettingsFromMinimap()
		return
	end
	if not ui.minimapMenu then
		ui.minimapMenu = CreateFrame("Frame", "coolstatsMinimapMenu", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(ui.minimapMenu, coolstats.InitializeMinimapMenu, "MENU")
	ToggleDropDownMenu(1, nil, ui.minimapMenu, button, 0, 0)
end

function coolstats.GetMinimapOptions()
	if not db then
		return defaults.minimap
	end
	if type(db.minimap) ~= "table" then
		db.minimap = CopyDefaults({}, defaults.minimap)
	else
		db.minimap = CopyDefaults(db.minimap, defaults.minimap)
	end
	db.minimap.angle = tonumber(db.minimap.angle) or defaults.minimap.angle
	db.minimap.radius = max(58, min(92, tonumber(db.minimap.radius) or defaults.minimap.radius))
	return db.minimap
end

function coolstats.PositionMinimapButton()
	if not ui.minimapButton or not Minimap then
		return
	end
	local options = coolstats.GetMinimapOptions()
	local angle = tonumber(options and options.angle) or defaults.minimap.angle
	local radius = tonumber(options and options.radius) or defaults.minimap.radius
	local radians = math.rad(angle)
	ui.minimapButton:ClearAllPoints()
	ui.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function coolstats.GetMinimapCursorAngle()
	if not Minimap or not GetCursorPosition then
		return nil
	end
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale() or 1
	local centerX, centerY = Minimap:GetCenter()
	if not cursorX or not cursorY or not centerX or not centerY or scale == 0 then
		return nil
	end
	cursorX = cursorX / scale
	cursorY = cursorY / scale
	local deltaX = cursorX - centerX
	local deltaY = cursorY - centerY
	local angle
	if math.atan2 then
		angle = math.deg(math.atan2(deltaY, deltaX))
	else
		if deltaX == 0 then
			angle = deltaY >= 0 and 90 or -90
		else
			angle = math.deg(math.atan(deltaY / deltaX))
			if deltaX < 0 then
				angle = angle + 180
			end
		end
	end
	if angle < 0 then
		angle = angle + 360
	end
	return angle
end

function coolstats.MinimapButton_OnUpdate(self)
	local angle = coolstats.GetMinimapCursorAngle()
	if not angle then
		return
	end
	local options = coolstats.GetMinimapOptions()
	if options then
		options.angle = angle
	end
	self.dragMoved = true
	coolstats.PositionMinimapButton()
end

function coolstats.CreateMinimapButton()
	if ui.minimapButton or not Minimap then
		return ui.minimapButton
	end

	local button = CreateFrame("Button", "coolstatsMinimapButton", Minimap)
	ui.minimapButton = button
	SetSize(button, 32, 32)
	button:SetPoint("CENTER", Minimap, "CENTER", -70, 40)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:EnableMouse(true)

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	SetSize(background, 25, 25)
	background:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -4)
	background:SetVertexColor(1, 1, 1, 0.6)
	button.background = background

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\coolstats\\assets\\coolstats_logo")
	SetSize(icon, 20, 20)
	icon:SetPoint("CENTER", button, "CENTER", 1, 0)
	icon:SetTexCoord(0, 1, 0, 1)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	SetSize(border, 54, 54)
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	button.border = border

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints(button)
	end

	button:SetScript("OnClick", function(self, mouseButton)
		if self.dragMoved then
			self.dragMoved = nil
			return
		end
		if mouseButton == "RightButton" then
			coolstats.OpenMinimapMenu(self)
		else
			coolstats.OpenCachedPlayerBrowserFromMinimap()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self.dragMoved = true
		self:SetScript("OnUpdate", coolstats.MinimapButton_OnUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		coolstats.MinimapButton_OnUpdate(self)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("coolstats", 0.0, 0.75, 1.0)
		GameTooltip:AddLine("Left-click: Player Browser", 0.86, 0.86, 0.78)
		GameTooltip:AddLine("Right-click: Menu", 0.86, 0.86, 0.78)
		GameTooltip:AddLine("Drag: Move button", 0.86, 0.86, 0.78)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	coolstats.PositionMinimapButton()
	return button
end

local function GetInspectUnit()
	if InspectFrame and InspectFrame.unit then
		return InspectFrame.unit
	end
	return "target"
end

local function ClampColor(value)
	if not value then
		return 0
	end
	return max(0, min(1, value))
end

local function GetFontColorRGB(color, fallbackRed, fallbackGreen, fallbackBlue)
	if color and color.r and color.g and color.b then
		return color.r, color.g, color.b
	end
	return fallbackRed, fallbackGreen, fallbackBlue
end

local function CalculateBandChannel(channel, score)
	return channel[1] + (((score - channel[2]) * channel[3]) * channel[4])
end

local function GetScoreColor(score)
	score = tonumber(score or 0) or 0
	if score <= 0 then
		return 0.55, 0.55, 0.55, "Trash"
	end
	if score > 5999 then
		score = 5999
	end

	for index = 1, #scoreColorBands do
		local band = scoreColorBands[index]
		local low = (index - 1) * 1000
		if score > low and score <= band.max then
			return ClampColor(CalculateBandChannel(band.r, score)),
				ClampColor(CalculateBandChannel(band.g, score)),
				ClampColor(CalculateBandChannel(band.b, score)),
				band.label
		end
	end

	return 0.94, 0.47, 0.00, "Legendary"
end

local function FormatNumber(value)
	value = floor(tonumber(value or 0) or 0)
	local sign = ""
	if value < 0 then
		sign = "-"
		value = -value
	end

	local text = tostring(value)
	while true do
		local nextText, count = gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if count == 0 then
			break
		end
	end

	return sign .. text
end

local function FormatGearScore(value)
	return tostring(ceil(tonumber(value or 0) or 0))
end

local function FormatItemLevel(value)
	return FormatNumber(ceil(tonumber(value or 0) or 0))
end

local function FormatPercent(value)
	if value == nil then
		return "-"
	end
	return format("%.2f%%", value)
end

local function GetNativeStatFrame(key)
	if nativeStatFrames[key] then
		return nativeStatFrames[key]
	end
	if not CharacterFrame then
		return nil
	end

	local name = "coolstatsNative" .. key
	local ok, frame = pcall(CreateFrame, "Frame", name, CharacterFrame, "StatFrameTemplate")
	if not ok or not frame then
		return nil
	end
	frame:Hide()
	nativeStatFrames[key] = frame
	return frame
end

local function RefreshNativeStatFrame(key, setter, arg)
	if type(setter) ~= "function" then
		return nil
	end

	local frame = GetNativeStatFrame(key)
	if not frame then
		return nil
	end

	local ok
	if arg ~= nil then
		ok = pcall(setter, frame, arg)
	else
		ok = pcall(setter, frame)
	end
	if not ok then
		return nil
	end

	return frame
end

local function ReadNativeStat(key, setter, arg)
	local frame = RefreshNativeStatFrame(key, setter, arg)
	if not frame then
		return nil
	end

	local statText = _G[frame:GetName() .. "StatText"]
	if not statText or not statText.GetText then
		return nil
	end

	local text = statText:GetText()
	if not text or text == "" then
		return nil
	end

	local red, green, blue = statText:GetTextColor()
	return text, red, green, blue
end

local function GetNativeStatValue(key, setter, arg)
	local text, red, green, blue = ReadNativeStat(key, setter, arg)
	if text then
		return text, red, green, blue
	end
	return "-"
end

local function AddGameTooltipLine(text, red, green, blue)
	if not text or text == "" then
		return false
	end
	GameTooltip:AddLine(text, red or 1, green or 1, blue or 1, true)
	return true
end

local nativeTooltipFallbackFields = {
	"tooltip",
	"tooltip2",
	"tooltip3",
	"tooltip4",
	"damage",
	"attackSpeed",
	"dps",
	"offhandAttackSpeed",
	"offhandDamage",
	"offhandDps",
	"weaponSkill",
	"weaponRating",
	"offhandSkill",
	"offhandRating",
	"bonusDamage",
	"minModifier",
	"spellCrit",
	"minCrit",
}

local function ApplyNativeTooltipState(row, frame)
	local savedThis = _G.this
	local savedFields = {}
	local copiedFields = {}
	local copiedFieldNames = {}

	local function CopyField(field)
		if not field or copiedFields[field] then
			return
		end
		copiedFields[field] = true
		copiedFieldNames[#copiedFieldNames + 1] = field
		savedFields[field] = row[field]
		row[field] = frame[field]
	end

	CopyField("tooltip")
	CopyField("tooltip2")
	CopyField("tooltip3")
	CopyField("tooltip4")

	local ok = pcall(function()
		for field, value in pairs(frame) do
			local valueType = type(value)
			if type(field) == "string" and valueType ~= "function" and valueType ~= "userdata" and valueType ~= "thread" then
				CopyField(field)
			end
		end
	end)
	if not ok then
		for index = 1, #nativeTooltipFallbackFields do
			CopyField(nativeTooltipFallbackFields[index])
		end
	end

	_G.this = row

	return function()
		_G.this = savedThis
		for index = 1, #copiedFieldNames do
			local field = copiedFieldNames[index]
			row[field] = savedFields[field]
		end
	end
end

local function ShowNativeStatTooltip(row)
	local frame = RefreshNativeStatFrame(row.nativeKey, row.nativeSetter, row.nativeArg)
	if not frame then
		return false
	end

	local handler = row.nativeHandler and _G[row.nativeHandler]
	if type(handler) == "function" then
		GameTooltip:ClearLines()
		local restoreNativeTooltipState = ApplyNativeTooltipState(row, frame)
		local ok = pcall(handler, row)
		restoreNativeTooltipState()
		if ok and GameTooltip:IsShown() then
			return true
		end
	end

	if not row.nativeHandler and type(PaperDollStatTooltip) == "function" then
		GameTooltip:ClearLines()
		local restoreNativeTooltipState = ApplyNativeTooltipState(row, frame)
		local ok = pcall(PaperDollStatTooltip, row, "player")
		restoreNativeTooltipState()
		if ok and GameTooltip:IsShown() then
			return true
		end
	end

	GameTooltip:ClearLines()
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local added = AddGameTooltipLine(frame.tooltip, 1, 0.82, 0.16)
	added = AddGameTooltipLine(frame.tooltip2, 0.86, 0.86, 0.78) or added
	added = AddGameTooltipLine(frame.tooltip3, 0.86, 0.86, 0.78) or added
	added = AddGameTooltipLine(frame.tooltip4, 0.86, 0.86, 0.78) or added
	if added then
		GameTooltip:Show()
	end
	return added
end

local function GetClassColor()
	local _, classFile = UnitClass("player")
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local color = colors and classFile and colors[classFile]
	if color then
		return color.r, color.g, color.b
	end
	return 0.00, 0.75, 1.00
end

local function GetBonusScannerBonus(effect)
	if BonusScanner and BonusScanner.GetBonus then
		return BonusScanner:GetBonus(effect) or 0
	end
	return nil
end

local function FormatRating(ratingConstant)
	if GetCombatRating and ratingConstant then
		return FormatNumber(GetCombatRating(ratingConstant) or 0)
	end
	return "-"
end

local function FormatRatingWithBonus(ratingConstant)
	local rating = GetCombatRating and ratingConstant and (GetCombatRating(ratingConstant) or 0) or 0
	local bonus = GetCombatRatingBonus and ratingConstant and (GetCombatRatingBonus(ratingConstant) or 0) or 0
	if rating > 0 or bonus > 0 then
		return FormatNumber(rating) .. " (" .. format("%.2f%%", bonus) .. ")"
	end
	return "-"
end

local function GetRatingBonusValue(ratingConstant)
	if GetCombatRatingBonus and ratingConstant then
		return GetCombatRatingBonus(ratingConstant) or 0
	end
	return 0
end

local function GetItemString(itemLink)
	return itemLink and match(itemLink, "item:([^|]+)")
end

local function GetEnchantMultiplier(itemLink, equipLoc)
	local weight = slotWeights[equipLoc]
	if not weight or not weight.enchantable then
		return 1
	end

	local itemString = GetItemString(itemLink)
	if not itemString then
		return 1
	end

	local _, enchantID = match(itemString, "^(%-?%d+):(%-?%d*)")
	if enchantID == "0" or enchantID == "" then
		return 1 - ((2 * weight.mod) / 100)
	end
	return 1
end

local function GetItemScore(itemLink)
	if not itemLink then
		return nil
	end

	local itemName, _, itemRarity, itemLevel, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
	if not itemName or not itemRarity or not itemLevel or not itemEquipLoc then
		return nil
	end

	local weight = slotWeights[itemEquipLoc]
	if not weight then
		return nil, itemLevel, nil, 1, 1, 1, itemEquipLoc
	end

	local qualityScale = 1
	local displayItemLevel = itemLevel

	if itemRarity == 5 then
		qualityScale = 1.3
		itemRarity = 4
	elseif itemRarity == 1 or itemRarity == 0 then
		qualityScale = 0.005
		itemRarity = 2
	elseif itemRarity == 7 then
		itemRarity = 3
		if itemLevel <= 1 then
			itemLevel = 187.05
		end
	end

	local formulaTable = itemLevel > 120 and highItemFormula or lowItemFormula
	local formulaData = formulaTable[itemRarity]
	if not formulaData or itemRarity < 2 or itemRarity > 4 then
		return nil, displayItemLevel, weight.itemSlot, 1, 1, 1, itemEquipLoc
	end

	local scale = 1.8618
	local base = (itemLevel - formulaData.a) / formulaData.b
	local colorScore = floor(base * scale) * 12.25
	local red, green, blue = GetScoreColor(colorScore)
	local gearScore = floor(base * weight.mod * scale * qualityScale)

	if gearScore < 0 then
		gearScore = 0
		red, green, blue = GetScoreColor(1)
	end

	gearScore = floor(gearScore * GetEnchantMultiplier(itemLink, itemEquipLoc))
	return gearScore, displayItemLevel, weight.itemSlot, red, green, blue, itemEquipLoc
end

coolstats.GetItemScore = GetItemScore
coolstats.GetScoreColor = GetScoreColor

local function GetSlotItem(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
	if not link then
		return nil
	end

	local score, itemLevel, itemSlot, red, green, blue, equipLoc = GetItemScore(link)
	if itemLevel then
		return {
			link = link,
			score = score,
			itemLevel = itemLevel,
			itemSlot = itemSlot,
			red = red or 0.55,
			green = green or 0.55,
			blue = blue or 0.55,
			equipLoc = equipLoc,
		}
	end
	return nil
end

local function CalculateUnitGear(unit)
	if not UnitExists(unit) then
		return 0, 0, 0
	end

	local _, classFile = UnitClass(unit)
	local gearScore = 0
	local levelTotal = 0
	local levelCount = 0
	local titanGrip = 1

	local mainHandLink = GetInventoryItemLink(unit, 16)
	local offHandLink = GetInventoryItemLink(unit, 17)
	if mainHandLink and offHandLink then
		local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(mainHandLink)
		if equipLoc == "INVTYPE_2HWEAPON" then
			titanGrip = 0.5
		end
	end
	if offHandLink then
		local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(offHandLink)
		if equipLoc == "INVTYPE_2HWEAPON" then
			titanGrip = 0.5
		end
	end

	if offHandLink then
		local item = GetSlotItem(unit, 17)
		if item and item.score then
			local score = item.score
			if classFile == "HUNTER" then
				score = score * 0.3164
			end
			gearScore = gearScore + (score * titanGrip)
			if item.itemLevel and item.itemLevel > 0 then
				levelTotal = levelTotal + item.itemLevel
				levelCount = levelCount + 1
			end
		end
	end

	for slot = 1, 18 do
		if slot ~= 4 and slot ~= 17 then
			local item = GetSlotItem(unit, slot)
			if item and item.score then
				local score = item.score
				if slot == 16 and classFile == "HUNTER" then
					score = score * 0.3164
				elseif slot == 18 and classFile == "HUNTER" then
					score = score * 5.3224
				end
				if slot == 16 then
					score = score * titanGrip
				end
				gearScore = gearScore + score
				if item.itemLevel and item.itemLevel > 0 then
					levelTotal = levelTotal + item.itemLevel
					levelCount = levelCount + 1
				end
			end
		end
	end

	local averageItemLevel = 0
	if levelCount > 0 then
		averageItemLevel = levelTotal / levelCount
	end

	return ceil(gearScore), averageItemLevel, levelCount
end

coolstats.CalculateUnitGear = CalculateUnitGear

local function GetDurability()
	local current, maximum = 0, 0
	for index = 1, #scoreSlots do
		local slot = scoreSlots[index]
		local slotCurrent, slotMax = GetInventoryItemDurability(slot)
		if slotCurrent and slotMax and slotMax > 0 then
			current = current + slotCurrent
			maximum = maximum + slotMax
		end
	end

	if maximum <= 0 then
		local red, green, blue = GetFontColorRGB(GREEN_FONT_COLOR, 0, 1, 0)
		return "100.0%", red, green, blue
	end

	local percent = (current / maximum) * 100
	local red, green, blue = GetFontColorRGB(GREEN_FONT_COLOR, 0, 1, 0)
	if percent < 30 then
		red, green, blue = GetFontColorRGB(RED_FONT_COLOR, 1, 0, 0)
	elseif percent < 70 then
		red, green, blue = GetFontColorRGB(YELLOW_FONT_COLOR, 1, 1, 0)
	end
	return format("%.1f%%", percent), red, green, blue
end

local function GetHealthValue()
	return FormatNumber(UnitHealthMax("player") or 0)
end

local function GetManaValue()
	local manaMax
	if UnitPowerMax then
		manaMax = UnitPowerMax("player", 0)
	elseif UnitManaMax then
		manaMax = UnitManaMax("player")
	end
	return FormatNumber(manaMax or 0)
end

local function GetMovementSpeedValue()
	if not GetUnitSpeed then
		return "-"
	end
	local currentSpeed = GetUnitSpeed("player") or 0
	if currentSpeed <= 0 then
		return "-"
	end
	return format("%.0f%%", (currentSpeed / 7) * 100)
end

local function GetRepairTooltip()
	if repairTooltip then
		return repairTooltip
	end
	repairTooltip = CreateFrame("GameTooltip", "coolstatsRepairTooltip", UIParent, "GameTooltipTemplate")
	repairTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	return repairTooltip
end

local function GetRepairCostValue()
	local tooltip = GetRepairTooltip()
	local totalCost = 0
	for index = 1, #scoreSlots do
		local slot = scoreSlots[index]
		tooltip:ClearLines()
		local _, _, repairCost = tooltip:SetInventoryItem("player", slot)
		if repairCost and repairCost > 0 then
			totalCost = totalCost + repairCost
		end
	end

	if GetCoinTextureString then
		return GetCoinTextureString(totalCost)
	end
	return FormatNumber(totalCost)
end

local function GetPowerValue()
	local powerType = 0
	if UnitPowerType then
		powerType = UnitPowerType("player") or 0
	end

	local powerMax
	if UnitPowerMax then
		powerMax = UnitPowerMax("player", powerType)
	elseif UnitManaMax then
		powerMax = UnitManaMax("player")
	end

	local label = powerNames[powerType] or "Power"
	return label, FormatNumber(powerMax or 0)
end

local function GetUnitStatValue(index)
	local text, red, green, blue = ReadNativeStat("Stat" .. index, PaperDollFrame_SetStat, index)
	if text then
		return text, red, green, blue
	end

	local _, effectiveStat, posBuff, negBuff = UnitStat("player", index)
	if negBuff and negBuff < 0 then
		return FormatNumber(effectiveStat or 0), 1.00, 0.20, 0.12
	elseif posBuff and posBuff > 0 then
		return FormatNumber(effectiveStat or 0), 0.25, 1.00, 0.25
	end
	return FormatNumber(effectiveStat or 0)
end

local function GetArmorValue()
	local text, red, green, blue = ReadNativeStat("Armor", PaperDollFrame_SetArmor)
	if text then
		return text, red, green, blue
	end

	local _, effectiveArmor = UnitArmor("player")
	return FormatNumber(effectiveArmor or 0)
end

local function GetAttackPowerValue()
	local text, red, green, blue = ReadNativeStat("AttackPower", PaperDollFrame_SetAttackPower)
	if text then
		return text, red, green, blue
	end

	local base, pos, neg = UnitAttackPower("player")
	local total = (base or 0) + (pos or 0) + (neg or 0)
	if neg and neg < 0 and abs(neg) > (pos or 0) then
		return FormatNumber(total), 1.00, 0.20, 0.12
	elseif pos and pos > 0 then
		return FormatNumber(total), 0.25, 1.00, 0.25
	end
	return FormatNumber(total)
end

local function GetRangedAttackPowerValue()
	local text, red, green, blue = ReadNativeStat("RangedAttackPower", PaperDollFrame_SetRangedAttackPower)
	if text then
		return text, red, green, blue
	end

	if not UnitRangedAttackPower then
		return "-"
	end
	local base, pos, neg = UnitRangedAttackPower("player")
	return FormatNumber((base or 0) + (pos or 0) + (neg or 0))
end

local function GetWeaponDPSValue()
	local frame = RefreshNativeStatFrame("MeleeDamage", PaperDollFrame_SetDamage)
	if frame and frame.dps then
		return format("%.1f", frame.dps)
	end

	local mainSpeed = UnitAttackSpeed("player")
	local minDamage, maxDamage, _, _, physicalBonusPos, physicalBonusNeg, percent = UnitDamage("player")
	if not mainSpeed or mainSpeed <= 0 then
		return "-"
	end
	local baseDamage = ((minDamage or 0) + (maxDamage or 0)) * 0.5
	local fullDamage = (baseDamage + (physicalBonusPos or 0) + (physicalBonusNeg or 0)) * (percent or 1)
	return format("%.1f", max(fullDamage, 1) / mainSpeed)
end

local function GetMeleeDamageValue()
	local text, red, green, blue = ReadNativeStat("MeleeDamage", PaperDollFrame_SetDamage)
	if text then
		return text, red, green, blue
	end

	local minDamage, maxDamage, _, _, _, _, percent = UnitDamage("player")
	if not minDamage or not maxDamage then
		return "-"
	end
	if percent and percent < 1 then
		return format("%d-%d", max(floor(minDamage), 1), max(ceil(maxDamage), 1)), 1.00, 0.20, 0.12
	end
	return format("%d-%d", max(floor(minDamage), 1), max(ceil(maxDamage), 1))
end

local function GetMeleeSpeedValue()
	local text, red, green, blue = ReadNativeStat("AttackSpeed", PaperDollFrame_SetAttackSpeed)
	if text then
		return text, red, green, blue
	end

	local mainSpeed, offSpeed = UnitAttackSpeed("player")
	if offSpeed then
		return format("%.2f/%.2f", mainSpeed or 0, offSpeed)
	end
	return format("%.2f", mainSpeed or 0)
end

local function GetMeleeDPSTooltip()
	local speed, offhandSpeed = UnitAttackSpeed("player")
	local minDamage, maxDamage, minOffHandDamage, maxOffHandDamage, physicalBonusPos, physicalBonusNeg, percent = UnitDamage("player")
	if not speed or not minDamage or not maxDamage then
		return "No melee weapon data available."
	end

	local baseDamage = ((minDamage or 0) + (maxDamage or 0)) * 0.5
	local fullDamage = (baseDamage + (physicalBonusPos or 0) + (physicalBonusNeg or 0)) * (percent or 1)
	local mainDPS = max(fullDamage, 1) / speed
	local mainDamage = GetMeleeDamageValue()
	if percent and percent < 1 and percent > 0 then
		mainDamage = format("%d - %d x%d%%", max(floor(minDamage / percent), 1), max(ceil(maxDamage / percent), 1), floor((percent * 100) + 0.5))
	end
	local text = "Main Hand\nAttack Speed: " .. format("%.2f", speed) .. "\nDamage: " .. mainDamage .. "\nDamage per Second: " .. format("%.1f", mainDPS)

	if offhandSpeed and minOffHandDamage and maxOffHandDamage then
		local offhandBase = (minOffHandDamage + maxOffHandDamage) * 0.5
		local offhandFull = (offhandBase + (physicalBonusPos or 0) + (physicalBonusNeg or 0)) * (percent or 1)
		local offhandDamage = max(floor(minOffHandDamage), 1) .. " - " .. max(ceil(maxOffHandDamage), 1)
		if percent and percent < 1 and percent > 0 then
			offhandDamage = format("%d - %d x%d%%", max(floor(minOffHandDamage / percent), 1), max(ceil(maxOffHandDamage / percent), 1), floor((percent * 100) + 0.5))
		end
		text = text .. "\n\nOff Hand\nAttack Speed: " .. format("%.2f", offhandSpeed) .. "\nDamage: " .. offhandDamage .. "\nDamage per Second: " .. format("%.1f", max(offhandFull, 1) / offhandSpeed)
	end
	return text
end

local function GetRangedDamageValue()
	local text, red, green, blue = ReadNativeStat("RangedDamage", PaperDollFrame_SetRangedDamage)
	if text then
		return text, red, green, blue
	end

	if not UnitRangedDamage then
		return "-"
	end
	local speed, minDamage, maxDamage = UnitRangedDamage("player")
	if not speed or speed == 0 or not minDamage or not maxDamage then
		return "-"
	end
	return format("%d-%d", max(floor(minDamage), 1), max(ceil(maxDamage), 1))
end

local function GetRangedSpeedValue()
	local text, red, green, blue = ReadNativeStat("RangedSpeed", PaperDollFrame_SetRangedAttackSpeed)
	if text then
		return text, red, green, blue
	end

	if not UnitRangedDamage then
		return "-"
	end
	local speed = UnitRangedDamage("player")
	if not speed or speed == 0 then
		return "-"
	end
	return format("%.2f", speed)
end

local function GetRangedDamageTooltip()
	if not UnitRangedDamage then
		return "No ranged weapon data available."
	end

	local speed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
	if not speed or speed == 0 or not minDamage or not maxDamage then
		return "No ranged weapon data available."
	end

	local baseDamage = (minDamage + maxDamage) * 0.5
	local fullDamage = (baseDamage + (physicalBonusPos or 0) + (physicalBonusNeg or 0)) * (percent or 1)
	local damagePerSecond = max(fullDamage, 1) / speed
	return "Ranged\nAttack Speed: " .. format("%.2f", speed) .. "\nDamage: " .. max(floor(minDamage), 1) .. " - " .. max(ceil(maxDamage), 1) .. "\nDamage per Second: " .. format("%.1f", damagePerSecond)
end

local function GetSpellPowerValue()
	if not GetSpellBonusDamage then
		return "-"
	end

	local best = 0
	for school = 2, 7 do
		best = max(best, GetSpellBonusDamage(school) or 0)
	end
	return FormatNumber(best)
end

local spellSchoolNames = {
	[2] = "Holy",
	[3] = "Fire",
	[4] = "Nature",
	[5] = "Frost",
	[6] = "Shadow",
	[7] = "Arcane",
}

local function GetSpellSchoolName(school)
	return _G["DAMAGE_SCHOOL" .. tostring(school)] or spellSchoolNames[school] or "School"
end

local function GetSpellSchoolPowerValue(school)
	if not GetSpellBonusDamage then
		return "-"
	end
	return FormatNumber(GetSpellBonusDamage(school) or 0)
end

local function GetSpellSchoolCritValue(school)
	if not GetSpellCritChance then
		return "-"
	end
	return FormatPercent(GetSpellCritChance(school) or 0)
end

local function GetSpellSchoolPowerTooltip(school)
	return GetSpellSchoolName(school) .. " spell power currently reported by the client."
end

local function GetSpellSchoolCritTooltip(school)
	return GetSpellSchoolName(school) .. " spell critical strike chance currently reported by the client."
end

local function GetCombatRatingPercent(ratingConstant)
	if GetCombatRatingBonus and ratingConstant then
		return FormatPercent(GetCombatRatingBonus(ratingConstant) or 0)
	end
	return "-"
end

local function GetExpertiseValue()
	local text, red, green, blue = ReadNativeStat("Expertise", PaperDollFrame_SetExpertise)
	local rating = FormatRating(CR_EXPERTISE)
	if text then
		return text .. " (" .. rating .. ")", red, green, blue
	end

	if GetExpertise then
		local main, off = GetExpertise()
		if off and off > 0 and off ~= main then
			return FormatNumber(main or 0) .. " / " .. FormatNumber(off) .. " (" .. rating .. ")"
		end
		return FormatNumber(main or 0) .. " (" .. rating .. ")"
	end
	return "-"
end

local function GetMeleeCritValue()
	local text, red, green, blue = ReadNativeStat("MeleeCrit", PaperDollFrame_SetMeleeCritChance)
	if text then
		return text, red, green, blue
	end
	return FormatPercent(GetCritChance and GetCritChance() or 0)
end

local function GetRangedCritValue()
	local text, red, green, blue = ReadNativeStat("RangedCrit", PaperDollFrame_SetRangedCritChance)
	if text then
		return text, red, green, blue
	end
	return FormatPercent(GetRangedCritChance and GetRangedCritChance() or 0)
end

local function GetDefenseValue()
	local text, red, green, blue = ReadNativeStat("Defense", PaperDollFrame_SetDefense)
	if text then
		return text, red, green, blue
	end
	if UnitDefense then
		local base, mod = UnitDefense("player")
		return FormatNumber((base or 0) + (mod or 0))
	end
	return "-"
end

local function GetDodgeValue()
	local text, red, green, blue = ReadNativeStat("Dodge", PaperDollFrame_SetDodge)
	if text then
		return text, red, green, blue
	end
	return FormatPercent(GetDodgeChance and GetDodgeChance() or 0)
end

local function GetParryValue()
	local text, red, green, blue = ReadNativeStat("Parry", PaperDollFrame_SetParry)
	if text then
		return text, red, green, blue
	end
	return FormatPercent(GetParryChance and GetParryChance() or 0)
end

local function GetBlockValue()
	local text, red, green, blue = ReadNativeStat("Block", PaperDollFrame_SetBlock)
	if text then
		return text, red, green, blue
	end
	return FormatPercent(GetBlockChance and GetBlockChance() or 0)
end

local function GetResilienceValue()
	local text, red, green, blue = ReadNativeStat("Resilience", PaperDollFrame_SetResilience)
	if text then
		return text, red, green, blue
	end
	return FormatRatingWithBonus(CR_CRIT_TAKEN_MELEE)
end

local function AddTooltipLines(text)
	if not text or text == "" then
		return
	end
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		if line == "" then
			GameTooltip:AddLine(" ")
		else
			GameTooltip:AddLine(line, 0.86, 0.86, 0.78, true)
		end
	end
end

local function GetBackgroundTextureInfo(key)
	return backgroundTextureByKey[key or "default"] or backgroundTextureByKey.default
end

local function GetBackgroundSetting(groupKey)
	EnsureEditOptions()
	local options = db and db.backgrounds and db.backgrounds[groupKey]
	if type(options) ~= "table" then
		return defaults.backgrounds[groupKey]
	end
	return options
end

local function GetBackgroundAlpha(groupKey)
	local options = GetBackgroundSetting(groupKey)
	return max(0, min(1, tonumber(options.alpha) or defaults.backgrounds[groupKey].alpha))
end

local function GetBackgroundContrast(groupKey)
	local options = GetBackgroundSetting(groupKey)
	return max(-1, min(1, tonumber(options.contrast) or defaults.backgrounds[groupKey].contrast))
end

local function GetBackgroundZoom(groupKey)
	local options = GetBackgroundSetting(groupKey)
	return max(0.7, min(3.0, tonumber(options.zoom) or defaults.backgrounds[groupKey].zoom))
end

function coolstats.GetBackgroundPan(groupKey, axis)
	local options = GetBackgroundSetting(groupKey)
	return max(-1, min(1, tonumber(options[axis]) or defaults.backgrounds[groupKey][axis] or 0))
end

local function GetStatTextPalette()
	local options = GetBackgroundSetting("stats")
	return coolstats.statTextPaletteByKey[options.palette or "classic"] or coolstats.statTextPaletteByKey.classic
end

local function SetFontStringColor(fontString, color)
	if fontString and color then
		fontString:SetTextColor(color[1], color[2], color[3])
	end
end

local function GetStatsPanelBackdrop(textureFile, tileBackground)
	return {
		bgFile = textureFile or SOLID_BACKGROUND_TEXTURE,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = tileBackground and true or false,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	}
end

function coolstats.HideStatsPanelTalentBackground(panel)
	if not panel then
		return
	end
	if panel.coolstatsTalentBackgroundPieces then
		for index = 1, #panel.coolstatsTalentBackgroundPieces do
			panel.coolstatsTalentBackgroundPieces[index]:Hide()
		end
	end
	if panel.coolstatsTalentBackgroundShade then
		panel.coolstatsTalentBackgroundShade:Hide()
	end
end

function coolstats.ApplyStatsPanelTalentBackground(panel, talentBackground, alpha, zoom, panX, panY)
	if not panel or not talentBackground then
		return
	end
	if not panel.coolstatsTalentBackgroundPieces then
		local topLeft = panel:CreateTexture(nil, "BACKGROUND")

		local topRight = panel:CreateTexture(nil, "BACKGROUND")

		local bottomLeft = panel:CreateTexture(nil, "BACKGROUND")

		local bottomRight = panel:CreateTexture(nil, "BACKGROUND")

		panel.coolstatsTalentBackgroundPieces = { topLeft, topRight, bottomLeft, bottomRight }
	end
	if not panel.coolstatsTalentBackgroundShade then
		local shade = panel:CreateTexture(nil, "BACKGROUND")
		shade:SetTexture(SOLID_BACKGROUND_TEXTURE)
		shade:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5)
		shade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 5)
		panel.coolstatsTalentBackgroundShade = shade
	end

	local base = "Interface\\TalentFrame\\" .. talentBackground .. "-"
	local pieces = panel.coolstatsTalentBackgroundPieces
	local talentInset = 5
	local panelWidth = max(1, (panel:GetWidth() or PANEL_WIDTH) - (talentInset * 2))
	local panelHeight = max(1, (panel:GetHeight() or PANEL_HEIGHT) - (talentInset * 2))
	local sourceWidth = 300
	local sourceHeight = 331
	local scale = min(panelWidth / sourceWidth, panelHeight / sourceHeight) * (zoom or 1)
	local displayWidth = sourceWidth * scale
	local displayHeight = sourceHeight * scale
	local offsetX = (panelWidth - displayWidth) * 0.5
	local offsetY = (panelHeight - displayHeight) * 0.5
	local overflowX = max(0, displayWidth - panelWidth)
	local overflowY = max(0, displayHeight - panelHeight)
	offsetX = offsetX + ((panX or 0) * overflowX * 0.5)
	offsetY = offsetY + ((panY or 0) * overflowY * 0.5)
	local cropLeft = max(0, -offsetX / scale)
	local cropTop = max(0, -offsetY / scale)
	local cropRight = min(sourceWidth, (panelWidth - offsetX) / scale)
	local cropBottom = min(sourceHeight, (panelHeight - offsetY) / scale)
	local pieceData = {
		{ texture = base .. "TopLeft", sx1 = 0, sy1 = 0, sx2 = 256, sy2 = 256, texWidth = 256, texHeight = 256 },
		{ texture = base .. "TopRight", sx1 = 256, sy1 = 0, sx2 = 300, sy2 = 256, texWidth = 64, texHeight = 256 },
		{ texture = base .. "BottomLeft", sx1 = 0, sy1 = 256, sx2 = 256, sy2 = 331, texWidth = 256, texHeight = 128 },
		{ texture = base .. "BottomRight", sx1 = 256, sy1 = 256, sx2 = 300, sy2 = 331, texWidth = 64, texHeight = 128 },
	}
	for index = 1, #pieces do
		local piece = pieces[index]
		local data = pieceData[index]
		local sourceLeft = max(cropLeft, data.sx1)
		local sourceTop = max(cropTop, data.sy1)
		local sourceRight = min(cropRight, data.sx2)
		local sourceBottom = min(cropBottom, data.sy2)
		piece:ClearAllPoints()
		if sourceRight > sourceLeft and sourceBottom > sourceTop then
			local widthOverlap = (sourceRight < cropRight and sourceRight < sourceWidth) and 2 or 0
			local heightOverlap = (sourceBottom < cropBottom and sourceBottom < sourceHeight) and 2 or 0
			piece:SetTexture(data.texture)
			piece:SetPoint("TOPLEFT", panel, "TOPLEFT", talentInset + offsetX + (sourceLeft * scale), -talentInset - offsetY - (sourceTop * scale))
			SetSize(piece, ((sourceRight - sourceLeft) * scale) + widthOverlap, ((sourceBottom - sourceTop) * scale) + heightOverlap)
			piece:SetTexCoord((sourceLeft - data.sx1) / data.texWidth, (sourceRight - data.sx1) / data.texWidth, (sourceTop - data.sy1) / data.texHeight, (sourceBottom - data.sy1) / data.texHeight)
			piece:SetVertexColor(1, 1, 1, 1)
			piece:SetAlpha(alpha)
			piece:Show()
		else
			piece:Hide()
		end
	end
	panel.coolstatsTalentBackgroundShade:SetVertexColor(0, 0, 0, alpha * 0.38)
	panel.coolstatsTalentBackgroundShade:Show()
end

function coolstats.ApplyStatsPanelContrastOverlay(panel, contrast)
	if not panel then
		return
	end
	if not panel.coolstatsBackgroundContrastOverlay then
		local overlay = panel:CreateTexture(nil, "ARTWORK")
		overlay:SetTexture(SOLID_BACKGROUND_TEXTURE)
		overlay:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5)
		overlay:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 5)
		panel.coolstatsBackgroundContrastOverlay = overlay
	end
	if abs(contrast or 0) < 0.01 then
		panel.coolstatsBackgroundContrastOverlay:Hide()
		return
	end
	if contrast > 0 then
		panel.coolstatsBackgroundContrastOverlay:SetVertexColor(0, 0, 0, contrast * 0.55)
	else
		panel.coolstatsBackgroundContrastOverlay:SetVertexColor(1, 1, 1, abs(contrast) * 0.30)
	end
	panel.coolstatsBackgroundContrastOverlay:Show()
end

function coolstats.EnsureStatsPanelBorderOverlay(panel)
	if not panel or panel.coolstatsBorderOverlay then
		return
	end
	local border = CreateFrame("Frame", nil, panel)
	border:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	border:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	if panel.GetFrameLevel and border.SetFrameLevel then
		border:SetFrameLevel(panel:GetFrameLevel() + 1)
	end
	border:SetBackdrop({
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	border:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)
	border:EnableMouse(false)
	panel.coolstatsBorderOverlay = border
end

function coolstats.ApplyStatsPanelBackground(panel)
	panel = panel or ui.panel
	if not panel or not panel.SetBackdrop then
		return
	end

	local options = GetBackgroundSetting("stats")
	local textureInfo = GetBackgroundTextureInfo(options.texture)
	local alpha = GetBackgroundAlpha("stats")
	local contrast = GetBackgroundContrast("stats")
	local zoom = GetBackgroundZoom("stats")
	local panX = coolstats.GetBackgroundPan("stats", "panX")
	local panY = coolstats.GetBackgroundPan("stats", "panY")
	if db and (db.editMode or db.favoriteMode) then
		textureInfo = backgroundTextureByKey.default
		alpha = defaults.backgrounds.stats.alpha
		contrast = defaults.backgrounds.stats.contrast
	end
	local textureFile = textureInfo.file or STATS_BACKGROUND_DEFAULT
	local backdropAlpha = alpha
	local detailAlpha = alpha
	local tileBackground = textureInfo.key == "default"

	if textureInfo.talent then
		textureFile = SOLID_BACKGROUND_TEXTURE
		backdropAlpha = 0
		detailAlpha = 0
		tileBackground = false
	elseif textureInfo.key == "none" then
		textureFile = SOLID_BACKGROUND_TEXTURE
		backdropAlpha = 0
		detailAlpha = 0
		contrast = 0
	elseif textureInfo.key ~= "default" then
		detailAlpha = alpha * 0.35
	end

	panel:SetBackdrop(GetStatsPanelBackdrop(textureFile, tileBackground))
	if textureInfo.key == "default" or textureInfo.key == "solid" or textureInfo.key == "none" then
		panel:SetBackdropColor(0.02, 0.018, 0.014, backdropAlpha)
	else
		panel:SetBackdropColor(1, 1, 1, backdropAlpha)
	end
	panel:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)

	if textureInfo.talent then
		coolstats.EnsureStatsPanelBorderOverlay(panel)
		panel.coolstatsBorderOverlay:Show()
		coolstats.ApplyStatsPanelTalentBackground(panel, textureInfo.talent, alpha, zoom, panX, panY)
	else
		if panel.coolstatsBorderOverlay then
			panel.coolstatsBorderOverlay:Hide()
		end
		coolstats.HideStatsPanelTalentBackground(panel)
	end
	coolstats.ApplyStatsPanelContrastOverlay(panel, contrast)

	if panel.coolstatsBackgroundPieces then
		for index = 1, #panel.coolstatsBackgroundPieces do
			panel.coolstatsBackgroundPieces[index]:SetAlpha(detailAlpha)
		end
	end
end

function coolstats.ApplyBackgroundOptions()
	coolstats.ApplyStatsPanelBackground(ui.panel)
	coolstats.ApplyStatsTextPalette()
end

function coolstats.ApplyStatsTextPalette()
	local palette = GetStatTextPalette()
	for index = 1, #ui.sections do
		local section = ui.sections[index]
		if section and section.title then
			SetFontStringColor(section.title, palette.header)
		end
	end
	for index = 1, #ui.rows do
		local row = ui.rows[index]
		if row and row.label then
			SetFontStringColor(row.label, palette.labelColor)
		end
	end
	if ui.appearanceBar and ui.appearanceBar.title then
		SetFontStringColor(ui.appearanceBar.title, palette.header)
	end
	if ui.appearanceToggles then
		for index = 1, #ui.appearanceToggles do
			local toggle = ui.appearanceToggles[index]
			if toggle and toggle.text then
				SetFontStringColor(toggle.text, palette.value)
			end
		end
	end
	return palette
end

local function CreateStatsDrawerBackground(parent)
	local top = parent:CreateTexture(nil, "ARTWORK")
	top:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
	top:SetTexCoord(0, 0.8984375, 0, 0.125)
	top:SetPoint("TOPLEFT", parent, "TOPLEFT", 3, -3)
	top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -3, -3)
	top:SetHeight(16)

	local bottom = parent:CreateTexture(nil, "ARTWORK")
	bottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
	bottom:SetTexCoord(0, 0.8984375, 0.484375, 0.609375)
	bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 3, 3)
	bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 3)
	bottom:SetHeight(16)

	local middle = parent:CreateTexture(nil, "ARTWORK")
	middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
	middle:SetTexCoord(0, 0.8984375, 0.125, 0.1953125)
	middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)

	parent.coolstatsBackgroundPieces = { top, bottom, middle }
	coolstats.ApplyStatsPanelBackground(parent)
end

local function SafeFormatTooltip(template, ...)
	if not template then
		return nil
	end
	local ok, text = pcall(format, template, ...)
	if ok then
		return text
	end
	return template
end

local function GetStatTooltip(statIndex)
	local stat, effectiveStat, posBuff, negBuff = UnitStat("player", statIndex)
	local token = statTokens[statIndex]
	if not token then
		return "Base character attribute."
	end

	local _, classFileName = UnitClass("player")
	local name = _G["SPELL_STAT" .. statIndex .. "_NAME"] or token
	local classStatText = classFileName and _G[string.upper(classFileName) .. "_" .. token .. "_TOOLTIP"]
	if not classStatText then
		classStatText = _G["DEFAULT_" .. token .. "_TOOLTIP"] or _G["DEFAULT_STAT" .. statIndex .. "_TOOLTIP"]
	end

	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. name .. " "
	if (posBuff or 0) == 0 and (negBuff or 0) == 0 then
		tooltipText = tooltipText .. (effectiveStat or 0) .. FONT_COLOR_CODE_CLOSE
	else
		tooltipText = tooltipText .. (effectiveStat or 0)
		if (posBuff or 0) > 0 or (negBuff or 0) < 0 then
			tooltipText = tooltipText .. " (" .. ((stat or 0) - (posBuff or 0) - (negBuff or 0)) .. FONT_COLOR_CODE_CLOSE
		end
		if (posBuff or 0) > 0 then
			tooltipText = tooltipText .. FONT_COLOR_CODE_CLOSE .. GREEN_FONT_COLOR_CODE .. "+" .. posBuff .. FONT_COLOR_CODE_CLOSE
		end
		if (negBuff or 0) < 0 then
			tooltipText = tooltipText .. RED_FONT_COLOR_CODE .. " " .. negBuff .. FONT_COLOR_CODE_CLOSE
		end
		if (posBuff or 0) > 0 or (negBuff or 0) < 0 then
			tooltipText = tooltipText .. HIGHLIGHT_FONT_COLOR_CODE .. ")" .. FONT_COLOR_CODE_CLOSE
		end
	end

	if classStatText and classStatText ~= "" then
		return tooltipText .. "\n" .. classStatText
	end
	return tooltipText
end

local function GetArmorTooltip()
	local _, effectiveArmor = UnitArmor("player")
	local reduction = 0
	if PaperDollFrame_GetArmorReduction then
		reduction = PaperDollFrame_GetArmorReduction(effectiveArmor or 0, UnitLevel("player") or 80) or 0
	end
	return "Reduces physical damage taken.\nArmor reduction: " .. format("%.2f%%", reduction)
end

local function GetAttackPowerTooltip()
	local base, pos, neg = UnitAttackPower("player")
	local total = (base or 0) + (pos or 0) + (neg or 0)
	local dps = total / (ATTACK_POWER_MAGIC_NUMBER or 14)
	return "Increases melee weapon damage.\nDamage per second: " .. format("%.1f", dps) .. "\nGear AP: " .. FormatNumber((GetBonusScannerBonus("ATTACKPOWER") or 0) + (GetBonusScannerBonus("RANGEDATTACKPOWER") or 0))
end

local function GetCritTooltip()
	local crit = GetCritChance and GetCritChance() or 0
	return "Chance for melee attacks to critically strike.\nCurrent chance: " .. format("%.2f%%", crit) .. "\nCrit rating: " .. FormatRating(CR_CRIT_MELEE) .. "\nGear crit: " .. FormatNumber(GetBonusScannerBonus("CRIT") or 0)
end

local function GetRatingTooltip(label, ratingConstant, bonusScannerKey)
	local rating = GetCombatRating and ratingConstant and (GetCombatRating(ratingConstant) or 0) or 0
	local bonus = GetCombatRatingBonus and ratingConstant and (GetCombatRatingBonus(ratingConstant) or 0) or 0
	local text = label .. " from combat rating.\nRating: " .. FormatNumber(rating) .. "\nConversion: " .. format("%.2f%%", bonus)
	if bonusScannerKey then
		text = text .. "\nGear rating: " .. FormatNumber(GetBonusScannerBonus(bonusScannerKey) or 0)
	end
	return text
end

local function GetExpertiseTooltip()
	local dodge, parry = 0, 0
	if GetExpertisePercent then
		dodge, parry = GetExpertisePercent()
	end
	return "Reduces chance your attacks are dodged or parried.\nExpertise rating: " .. FormatRating(CR_EXPERTISE) .. "\nDodge reduction: " .. format("%.2f%%", dodge or 0) .. "\nParry reduction: " .. format("%.2f%%", parry or 0)
end

local function GetDefenseTooltip()
	return "Defense skill reduces chance to be hit or critically hit.\nDefense rating: " .. FormatRating(CR_DEFENSE_SKILL) .. "\nGear defense: " .. FormatNumber(GetBonusScannerBonus("DEFENSE") or 0)
end

local function GetEquipmentGearScoreValue()
	local gearScore = CalculateUnitGear("player")
	local red, green, blue = GetScoreColor(gearScore)
	return "GS " .. FormatGearScore(gearScore), red, green, blue
end

local function GetEquipmentItemLevelValue()
	local gearScore, averageItemLevel = CalculateUnitGear("player")
	local red, green, blue = GetScoreColor(gearScore)
	return "Item Level " .. FormatItemLevel(averageItemLevel), red, green, blue
end

local statSections = {
	{
		title = "Equipment",
		rows = {
			{ label = "GearScore", key = "gearscore", get = GetEquipmentGearScoreValue, tooltip = "Equipped gear score using the addon color palette.", centered = true, fontSize = 13 },
			{ label = "Item Level", key = "itemlevel", get = GetEquipmentItemLevelValue, tooltip = "Average equipped item level.", centered = true, fontSize = 10 },
		},
	},
	{
		title = "General",
		rows = {
			{ label = "Health", get = GetHealthValue, tooltip = "Maximum health." },
			{ label = "Mana", get = GetManaValue, tooltip = "Maximum mana." },
			{ label = "Durability", get = GetDurability, tooltip = "Average durability across equipped gear." },
			{ label = "Repair Cost", get = GetRepairCostValue, tooltip = "Total repair cost for equipped items." },
			{ label = "Move Speed", key = "movement_speed", get = GetMovementSpeedValue, tooltip = "Current movement speed including shapeshifts, buffs, items, and mounts." },
		},
	},
	{
		title = "Melee",
		rows = {
			{ label = "Damage", get = GetMeleeDamageValue, tooltip = GetMeleeDPSTooltip, nativeKey = "MeleeDamage", nativeSetter = PaperDollFrame_SetDamage, nativeHandler = "CharacterDamageFrame_OnEnter" },
			{ label = "Power", get = GetAttackPowerValue, tooltip = GetAttackPowerTooltip, nativeKey = "AttackPower", nativeSetter = PaperDollFrame_SetAttackPower },
			{ label = "Attack Speed", get = GetMeleeSpeedValue, tooltip = "Main hand / off hand attack speed in seconds.", nativeKey = "AttackSpeed", nativeSetter = PaperDollFrame_SetAttackSpeed },
			{ label = "Crit Chance", get = GetMeleeCritValue, tooltip = GetCritTooltip, nativeKey = "MeleeCrit", nativeSetter = PaperDollFrame_SetMeleeCritChance },
			{ label = "Hit Rating", get = function() return FormatRatingWithBonus(CR_HIT_MELEE) end, tooltip = function() return GetRatingTooltip("Melee hit chance", CR_HIT_MELEE, "TOHIT") end, nativeKey = "MeleeHit", nativeSetter = PaperDollFrame_SetRating, nativeArg = CR_HIT_MELEE },
			{ label = "Expertise", get = GetExpertiseValue, tooltip = GetExpertiseTooltip, nativeKey = "Expertise", nativeSetter = PaperDollFrame_SetExpertise },
			{ label = "Haste", get = function() return FormatRatingWithBonus(CR_HASTE_MELEE) end, tooltip = function() return GetRatingTooltip("Melee haste", CR_HASTE_MELEE, "HASTE") end, nativeKey = "MeleeHaste", nativeSetter = PaperDollFrame_SetRating, nativeArg = CR_HASTE_MELEE },
			{ label = "Armor Pen.", key = "armor_penetration", get = function() return FormatRatingWithBonus(CR_ARMOR_PENETRATION) end, tooltip = function() return "Ignores up to " .. format("%.2f%%", GetRatingBonusValue(CR_ARMOR_PENETRATION)) .. " of enemy armor.\nRating: " .. FormatRating(CR_ARMOR_PENETRATION) .. "\nSubject to WotLK armor caps." end, nativeKey = "ArmorPen", nativeSetter = PaperDollFrame_SetRating, nativeArg = CR_ARMOR_PENETRATION },
		},
	},
	{
		title = "Ranged",
		rows = {
			{ label = "Damage", get = function() return GetNativeStatValue("RangedDamage", PaperDollFrame_SetRangedDamage) end, nativeKey = "RangedDamage", nativeSetter = PaperDollFrame_SetRangedDamage, nativeHandler = "CharacterRangedDamageFrame_OnEnter" },
			{ label = "Attack Speed", get = function() return GetNativeStatValue("RangedSpeed", PaperDollFrame_SetRangedAttackSpeed) end, nativeKey = "RangedSpeed", nativeSetter = PaperDollFrame_SetRangedAttackSpeed },
			{ label = "Power", get = function() return GetNativeStatValue("RangedAttackPower", PaperDollFrame_SetRangedAttackPower) end, nativeKey = "RangedAttackPower", nativeSetter = PaperDollFrame_SetRangedAttackPower },
			{ label = "Hit Rating", get = function() return GetNativeStatValue("RangedHit", PaperDollFrame_SetRating, CR_HIT_RANGED) end, nativeKey = "RangedHit", nativeSetter = PaperDollFrame_SetRating, nativeArg = CR_HIT_RANGED },
			{ label = "Crit Chance", get = function() return GetNativeStatValue("RangedCrit", PaperDollFrame_SetRangedCritChance) end, nativeKey = "RangedCrit", nativeSetter = PaperDollFrame_SetRangedCritChance },
			{ label = "Armor Pen.", key = "armor_penetration", get = function() return FormatRatingWithBonus(CR_ARMOR_PENETRATION) end, tooltip = function() return "Ignores up to " .. format("%.2f%%", GetRatingBonusValue(CR_ARMOR_PENETRATION)) .. " of enemy armor.\nRating: " .. FormatRating(CR_ARMOR_PENETRATION) .. "\nSubject to WotLK armor caps." end, nativeKey = "RangedArmorPen", nativeSetter = PaperDollFrame_SetRating, nativeArg = CR_ARMOR_PENETRATION },
		},
	},
	{
		title = "Spell",
		rows = {
			{ label = "Spell Power", get = function() return GetNativeStatValue("SpellPower", PaperDollFrame_SetSpellBonusDamage) end, nativeKey = "SpellPower", nativeSetter = PaperDollFrame_SetSpellBonusDamage, nativeHandler = "CharacterSpellBonusDamage_OnEnter" },
			{ label = "Holy Power", key = "holy_spell_power", get = function() return GetSpellSchoolPowerValue(2) end, tooltip = function() return GetSpellSchoolPowerTooltip(2) end },
			{ label = "Fire Power", key = "fire_spell_power", get = function() return GetSpellSchoolPowerValue(3) end, tooltip = function() return GetSpellSchoolPowerTooltip(3) end },
			{ label = "Nature Power", key = "nature_spell_power", get = function() return GetSpellSchoolPowerValue(4) end, tooltip = function() return GetSpellSchoolPowerTooltip(4) end },
			{ label = "Frost Power", key = "frost_spell_power", get = function() return GetSpellSchoolPowerValue(5) end, tooltip = function() return GetSpellSchoolPowerTooltip(5) end },
			{ label = "Shadow Power", key = "shadow_spell_power", get = function() return GetSpellSchoolPowerValue(6) end, tooltip = function() return GetSpellSchoolPowerTooltip(6) end },
			{ label = "Arcane Power", key = "arcane_spell_power", get = function() return GetSpellSchoolPowerValue(7) end, tooltip = function() return GetSpellSchoolPowerTooltip(7) end },
			{ label = "Healing", get = function() return GetNativeStatValue("Healing", PaperDollFrame_SetSpellBonusHealing) end, nativeKey = "Healing", nativeSetter = PaperDollFrame_SetSpellBonusHealing },
			{ label = "Spell Hit", get = function() return FormatRatingWithBonus(CR_HIT_SPELL) end, nativeKey = "SpellHit", nativeSetter = PaperDollFrame_SetRating, nativeArg = CR_HIT_SPELL },
			{ label = "Spell Crit", get = function() return GetNativeStatValue("SpellCrit", PaperDollFrame_SetSpellCritChance) end, nativeKey = "SpellCrit", nativeSetter = PaperDollFrame_SetSpellCritChance, nativeHandler = "CharacterSpellCritChance_OnEnter" },
			{ label = "Holy Crit", key = "holy_spell_crit", get = function() return GetSpellSchoolCritValue(2) end, tooltip = function() return GetSpellSchoolCritTooltip(2) end },
			{ label = "Fire Crit", key = "fire_spell_crit", get = function() return GetSpellSchoolCritValue(3) end, tooltip = function() return GetSpellSchoolCritTooltip(3) end },
			{ label = "Nature Crit", key = "nature_spell_crit", get = function() return GetSpellSchoolCritValue(4) end, tooltip = function() return GetSpellSchoolCritTooltip(4) end },
			{ label = "Frost Crit", key = "frost_spell_crit", get = function() return GetSpellSchoolCritValue(5) end, tooltip = function() return GetSpellSchoolCritTooltip(5) end },
			{ label = "Shadow Crit", key = "shadow_spell_crit", get = function() return GetSpellSchoolCritValue(6) end, tooltip = function() return GetSpellSchoolCritTooltip(6) end },
			{ label = "Arcane Crit", key = "arcane_spell_crit", get = function() return GetSpellSchoolCritValue(7) end, tooltip = function() return GetSpellSchoolCritTooltip(7) end },
			{ label = "Spell Haste", get = function() return FormatRatingWithBonus(CR_HASTE_SPELL) end, nativeKey = "SpellHaste", nativeSetter = PaperDollFrame_SetSpellHaste },
			{ label = "Mana Regen", get = function() return GetNativeStatValue("ManaRegen", PaperDollFrame_SetManaRegen) end, nativeKey = "ManaRegen", nativeSetter = PaperDollFrame_SetManaRegen },
			{ label = "Spell Pen.", get = function() return GetNativeStatValue("SpellPen", PaperDollFrame_SetSpellPenetration) end, nativeKey = "SpellPen", nativeSetter = PaperDollFrame_SetSpellPenetration },
		},
	},
	{
		title = "Defense",
		rows = {
			{ label = "Defense", get = GetDefenseValue, tooltip = GetDefenseTooltip, nativeKey = "Defense", nativeSetter = PaperDollFrame_SetDefense },
			{ label = "Dodge", get = GetDodgeValue, tooltip = function() return GetRatingTooltip("Dodge chance", CR_DODGE, "DODGE") end, nativeKey = "Dodge", nativeSetter = PaperDollFrame_SetDodge },
			{ label = "Parry", get = GetParryValue, tooltip = function() return GetRatingTooltip("Parry chance", CR_PARRY, "PARRY") end, nativeKey = "Parry", nativeSetter = PaperDollFrame_SetParry },
			{ label = "Block", get = GetBlockValue, tooltip = function() return GetRatingTooltip("Block chance", CR_BLOCK, "BLOCK") end, nativeKey = "Block", nativeSetter = PaperDollFrame_SetBlock },
			{ label = "Resilience", get = GetResilienceValue, tooltip = function() return GetRatingTooltip("Reduces crit chance and player damage", CR_CRIT_TAKEN_MELEE, "RESILIENCE") end, nativeKey = "Resilience", nativeSetter = PaperDollFrame_SetResilience },
		},
	},
	{
		title = "Attributes",
		rows = {
			{ label = "Strength", get = function() return GetUnitStatValue(1) end, tooltip = function() return GetStatTooltip(1) end, nativeKey = "Stat1", nativeSetter = PaperDollFrame_SetStat, nativeArg = 1 },
			{ label = "Agility", get = function() return GetUnitStatValue(2) end, tooltip = function() return GetStatTooltip(2) end, nativeKey = "Stat2", nativeSetter = PaperDollFrame_SetStat, nativeArg = 2 },
			{ label = "Stamina", get = function() return GetUnitStatValue(3) end, tooltip = function() return GetStatTooltip(3) end, nativeKey = "Stat3", nativeSetter = PaperDollFrame_SetStat, nativeArg = 3 },
			{ label = "Intellect", get = function() return GetUnitStatValue(4) end, tooltip = function() return GetStatTooltip(4) end, nativeKey = "Stat4", nativeSetter = PaperDollFrame_SetStat, nativeArg = 4 },
			{ label = "Spirit", get = function() return GetUnitStatValue(5) end, tooltip = function() return GetStatTooltip(5) end, nativeKey = "Stat5", nativeSetter = PaperDollFrame_SetStat, nativeArg = 5 },
			{ label = "Armor", get = GetArmorValue, tooltip = GetArmorTooltip, nativeKey = "Armor", nativeSetter = PaperDollFrame_SetArmor },
		},
	},
}

local function IsSectionEnabled(section)
	EnsureEditOptions()
	return not (db and db.hiddenSections and db.hiddenSections[section.configKey])
end

local function IsRowEnabled(row)
	EnsureEditOptions()
	return not (db and db.hiddenRows and db.hiddenRows[row.configKey])
end

local function SetSectionEnabled(section, enabled)
	EnsureEditOptions()
	if not db then
		return
	end
	if enabled then
		db.hiddenSections[section.configKey] = nil
	else
		db.hiddenSections[section.configKey] = true
	end
	for index = 1, #section.rows do
		local row = section.rows[index]
		if enabled then
			db.hiddenRows[row.configKey] = nil
		else
			db.hiddenRows[row.configKey] = true
		end
	end
end

local function SetRowEnabled(row, enabled)
	EnsureEditOptions()
	if not db then
		return
	end
	if enabled then
		db.hiddenRows[row.configKey] = nil
		if row.section and not row.section.isFavorites then
			db.hiddenSections[row.section.configKey] = nil
		end
	else
		db.hiddenRows[row.configKey] = true
	end
end

local function IsSectionCollapsed(section)
	EnsureEditOptions()
	return db and db.collapsedSections and db.collapsedSections[section.configKey]
end

local function SetSectionCollapsed(section, collapsed)
	EnsureEditOptions()
	if not db then
		return
	end
	if collapsed then
		db.collapsedSections[section.configKey] = true
	else
		db.collapsedSections[section.configKey] = nil
	end
end

local function ToggleSectionCollapsed(section)
	SetSectionCollapsed(section, not IsSectionCollapsed(section))
	QueueUpdate()
end

function coolstats.GetUICursorPosition()
	if not GetCursorPosition then
		return nil, nil
	end

	local cursorX, cursorY = GetCursorPosition()
	local scale = 1
	if UIParent and UIParent.GetEffectiveScale then
		scale = UIParent:GetEffectiveScale() or 1
	end
	if scale <= 0 then
		scale = 1
	end
	return cursorX / scale, cursorY / scale
end

function coolstats.CreateSectionDragCursor()
	if ui.sectionDragCursor then
		return ui.sectionDragCursor
	end

	local frame = CreateFrame("Frame", "coolstatsSectionDragCursor", UIParent)
	SetSize(frame, 26, 26)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(1000)
	frame:EnableMouse(false)

	local function AddArrow(text, xOffset, yOffset)
		local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		arrow:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
		arrow:SetText(text)
		arrow:SetTextColor(1.0, 0.82, 0.16)
		arrow:SetShadowOffset(1, -1)
		arrow:SetShadowColor(0, 0, 0, 1)
		arrow:SetPoint("CENTER", frame, "CENTER", xOffset, yOffset)
		return arrow
	end

	AddArrow("^", 0, 8)
	AddArrow("v", 0, -8)
	AddArrow("<", -8, 0)
	AddArrow(">", 8, 0)
	AddArrow("+", 0, 0)

	frame:Hide()
	ui.sectionDragCursor = frame
	return frame
end

function coolstats.CreateSectionDragGhost()
	if ui.sectionDragGhost then
		return ui.sectionDragGhost
	end

	local frame = CreateFrame("Frame", "coolstatsSectionDragGhost", UIParent)
	SetSize(frame, SECTION_HEADER_WIDTH, 20)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(995)
	frame:EnableMouse(false)

	local glow = frame:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture("Interface\\Buttons\\WHITE8X8")
	glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 1)
	glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -1)
	glow:SetVertexColor(1.0, 0.82, 0.16, 0.20)
	frame.glow = glow

	local right = frame:CreateTexture(nil, "ARTWORK")
	right:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
	SetSize(right, 37, 18)
	right:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	right:SetTexCoord(0, 0.14453125, 0.296875, 0.578125)

	local left = frame:CreateTexture(nil, "ARTWORK")
	left:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
	left:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 1)
	left:SetTexCoord(0, 1, 0, 0.28125)

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	SetSize(title, SECTION_HEADER_WIDTH - 28, 16)
	title:SetPoint("CENTER", frame, "CENTER", 0, 0)
	title:SetJustifyH("CENTER")
	title:SetTextColor(1, 0.92, 0.26)
	title:SetShadowOffset(1, -1)
	title:SetShadowColor(0, 0, 0, 1)
	frame.title = title

	frame:Hide()
	ui.sectionDragGhost = frame
	return frame
end

function coolstats.UpdateSectionDragCursor(cursorX, cursorY)
	if not cursorX or not cursorY then
		return
	end

	local frame = coolstats.CreateSectionDragCursor()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX + 38, cursorY - 32)
	frame:Show()
end

function coolstats.HideSectionDragCursor()
	if ui.sectionDragCursor then
		ui.sectionDragCursor:Hide()
	end
end

function coolstats.UpdateSectionDragGhost(section, cursorX, cursorY)
	if not section or not cursorX or not cursorY then
		return
	end

	local frame = coolstats.CreateSectionDragGhost()
	if frame.title and section.title then
		frame.title:SetText(section.title:GetText() or "")
	end

	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local width = frame:GetWidth() or SECTION_HEADER_WIDTH
	local height = frame:GetHeight() or 20
	local left = cursorX + 34
	local top = cursorY + 2

	if left + width > parentWidth - 6 then
		left = cursorX - width - 14
	end
	top = max(height + 6, min(parentHeight - 6, top))
	left = max(6, min(parentWidth - width - 6, left))

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	frame:SetAlpha(0.94)
	frame:Show()
end

function coolstats.HideSectionDragGhost()
	if ui.sectionDragGhost then
		ui.sectionDragGhost:Hide()
	end
end

function coolstats.CreateSectionDropLine()
	if ui.sectionDropLine then
		return ui.sectionDropLine
	end

	local frame = CreateFrame("Frame", "coolstatsSectionDropLine", UIParent)
	SetSize(frame, SECTION_HEADER_WIDTH + 10, 10)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(990)
	frame:EnableMouse(false)

	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetTexture("Interface\\Buttons\\WHITE8X8")
	line:SetPoint("LEFT", frame, "LEFT", 5, 0)
	line:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
	line:SetHeight(2)
	line:SetVertexColor(1.0, 0.82, 0.16, 0.92)
	frame.line = line

	local leftCap = frame:CreateTexture(nil, "ARTWORK")
	leftCap:SetTexture("Interface\\Buttons\\WHITE8X8")
	SetSize(leftCap, 5, 5)
	leftCap:SetPoint("LEFT", frame, "LEFT", 1, 0)
	leftCap:SetVertexColor(1.0, 0.82, 0.16, 0.92)
	frame.leftCap = leftCap

	local rightCap = frame:CreateTexture(nil, "ARTWORK")
	rightCap:SetTexture("Interface\\Buttons\\WHITE8X8")
	SetSize(rightCap, 5, 5)
	rightCap:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
	rightCap:SetVertexColor(1.0, 0.82, 0.16, 0.92)
	frame.rightCap = rightCap

	frame:Hide()
	ui.sectionDropLine = frame
	return frame
end

function coolstats.HideSectionDropLine()
	if ui.sectionDropLine then
		ui.sectionDropLine:Hide()
	end
end

function coolstats.SetSectionDragTarget(targetSection, insertIndex)
	ui.dragTargetSection = targetSection
	ui.dragInsertIndex = insertIndex
	for index = 1, #ui.sections do
		local section = ui.sections[index]
		SetVisible(section.targetHighlight, targetSection == section)
	end
end

function coolstats.UpdateSectionDropLine(lineY)
	if not lineY or not ui.content then
		coolstats.HideSectionDropLine()
		return
	end

	local frame = coolstats.CreateSectionDropLine()
	local left = ui.content:GetLeft() or 0
	local scrollTop = ui.scrollFrame and ui.scrollFrame:GetTop()
	local scrollBottom = ui.scrollFrame and ui.scrollFrame:GetBottom()
	if scrollTop and scrollBottom then
		lineY = max(scrollBottom + 3, min(scrollTop - 3, lineY))
	end

	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", left + (SECTION_HEADER_WIDTH * 0.5), lineY)
	frame:Show()
end

function coolstats.SaveSectionOrder()
	EnsureEditOptions()
	if not db then
		return
	end

	local order = {}
	for index = 1, #ui.sections do
		order[#order + 1] = ui.sections[index].configKey
	end
	db.sectionOrder = order
end

function coolstats.ApplySavedSectionOrder()
	EnsureEditOptions()
	if not db or type(db.sectionOrder) ~= "table" or #ui.sections <= 1 then
		return
	end

	local sectionByKey = {}
	for index = 1, #ui.sections do
		local section = ui.sections[index]
		sectionByKey[section.configKey] = section
	end

	local ordered = {}
	local used = {}
	local savedHasFavorites = false
	if ui.favoriteSection then
		for index = 1, #db.sectionOrder do
			if db.sectionOrder[index] == ui.favoriteSection.configKey then
				savedHasFavorites = true
				break
			end
		end
	end
	if ui.favoriteSection and not savedHasFavorites then
		ordered[#ordered + 1] = ui.favoriteSection
		used[ui.favoriteSection] = true
	end

	for index = 1, #db.sectionOrder do
		local section = sectionByKey[db.sectionOrder[index]]
		if section and not used[section] then
			ordered[#ordered + 1] = section
			used[section] = true
		end
	end

	for index = 1, #ui.sections do
		local section = ui.sections[index]
		if not used[section] then
			ordered[#ordered + 1] = section
			used[section] = true
		end
	end

	if #ordered == #ui.sections then
		ui.sections = ordered
		coolstats.SaveSectionOrder()
	end
end

function coolstats.ReorderSectionForCursor(section, cursorY)
	if not section or not cursorY or #ui.sections <= 1 then
		return
	end

	local insertIndex = 1
	local targetSection = nil
	local lineY = nil
	local withoutCount = 0
	for index = 1, #ui.sections do
		local candidate = ui.sections[index]
		if candidate ~= section and candidate:IsShown() then
			withoutCount = withoutCount + 1
			local top = candidate:GetTop()
			local bottom = candidate:GetBottom()
			if top and bottom then
				if cursorY > ((top + bottom) * 0.5) then
					insertIndex = withoutCount
					targetSection = candidate
					lineY = top
					break
				elseif cursorY >= bottom and cursorY <= top then
					insertIndex = withoutCount + 1
					targetSection = candidate
					lineY = bottom
					break
				end
				insertIndex = withoutCount + 1
				lineY = bottom
			end
		end
	end

	coolstats.SetSectionDragTarget(targetSection, insertIndex)
	coolstats.UpdateSectionDropLine(lineY)
end

function coolstats.SectionParticipatesInCurrentDrag(section, draggedSection)
	return section == draggedSection or (section and section:IsShown())
end

function coolstats.CommitSectionDrag(section)
	if not section or not ui.dragInsertIndex then
		return
	end

	local visibleOrder = {}
	for index = 1, #ui.sections do
		local candidate = ui.sections[index]
		if candidate ~= section and coolstats.SectionParticipatesInCurrentDrag(candidate, section) then
			visibleOrder[#visibleOrder + 1] = candidate
		end
	end

	local insertIndex = max(1, min(#visibleOrder + 1, ui.dragInsertIndex))
	table.insert(visibleOrder, insertIndex, section)

	local ordered = {}
	local visibleIndex = 1
	for index = 1, #ui.sections do
		local candidate = ui.sections[index]
		if coolstats.SectionParticipatesInCurrentDrag(candidate, section) then
			ordered[#ordered + 1] = visibleOrder[visibleIndex]
			visibleIndex = visibleIndex + 1
		else
			ordered[#ordered + 1] = candidate
		end
	end

	if #ordered == #ui.sections then
		ui.sections = ordered
	end
	coolstats.SaveSectionOrder()
end

function coolstats.ClearSectionDragCues()
	coolstats.SetSectionDragTarget(nil, nil)
	coolstats.HideSectionDropLine()
	if ui.sectionDragFrame then
		ui.sectionDragFrame:SetScript("OnUpdate", nil)
	end
end

function coolstats.UpdateSectionDragScroll(cursorY, elapsed)
	if not ui.scrollFrame or not ui.content or not cursorY then
		return
	end

	local top = ui.scrollFrame:GetTop()
	local bottom = ui.scrollFrame:GetBottom()
	if not top or not bottom then
		return
	end

	local current = ui.scrollFrame:GetVerticalScroll() or 0
	local maxScroll = max(0, (ui.content:GetHeight() or 0) - (ui.scrollFrame:GetHeight() or 0))
	if maxScroll <= 0 then
		return
	end

	local direction = 0
	if cursorY > top - 30 then
		direction = -1
	elseif cursorY < bottom + 30 then
		direction = 1
	end

	if direction == 0 then
		return
	end

	local nextScroll = current + (direction * 240 * (elapsed or 0.016))
	nextScroll = max(0, min(maxScroll, nextScroll))
	if nextScroll ~= current then
		ui.scrollFrame:SetVerticalScroll(nextScroll)
		if ui.scrollFrame.GetName then
			local scrollBar = _G[ui.scrollFrame:GetName() .. "ScrollBar"]
			if scrollBar and scrollBar.SetValue then
				scrollBar:SetValue(nextScroll)
			end
		end
	end
end

function coolstats.UpdateSectionDrag(_, elapsed)
	local section = ui.dragSection
	if not section then
		return
	end

	local cursorX, cursorY = coolstats.GetUICursorPosition()
	coolstats.UpdateSectionDragCursor(cursorX, cursorY)
	coolstats.UpdateSectionDragGhost(section, cursorX, cursorY)
	coolstats.UpdateSectionDragScroll(cursorY, elapsed)
	coolstats.ReorderSectionForCursor(section, cursorY)
end

function coolstats.GetSectionDragFrame()
	if ui.sectionDragFrame then
		return ui.sectionDragFrame
	end
	ui.sectionDragFrame = CreateFrame("Frame")
	return ui.sectionDragFrame
end

function coolstats.StartSectionDrag(section)
	if not (db and db.editMode and section) then
		return
	end
	if section.isFavorites and not coolstats.HasFavoriteRows() then
		return
	end

	ui.dragSection = section
	ui.dragInsertIndex = nil
	ui.dragTargetSection = nil
	section.dragClickSuppressedUntil = (GetTime and GetTime() or 0) + 0.35
	section:SetFrameLevel((ui.content and ui.content:GetFrameLevel() or section:GetFrameLevel() or 0) + 20)
	section:SetAlpha(0.68)
	GameTooltip:Hide()
	coolstats.HideSectionDragGhost()
	if coolstats.LayoutSections then
		coolstats.LayoutSections()
	end

	local dragFrame = coolstats.GetSectionDragFrame()
	dragFrame:SetScript("OnUpdate", coolstats.UpdateSectionDrag)
	coolstats.UpdateSectionDrag(dragFrame, 0)
end

function coolstats.StopSectionDrag(section)
	if ui.dragSection ~= section then
		return
	end

	coolstats.CommitSectionDrag(section)
	ui.dragSection = nil
	coolstats.ClearSectionDragCues()
	coolstats.HideSectionDragCursor()
	coolstats.HideSectionDragGhost()
	section.dragClickSuppressedUntil = (GetTime and GetTime() or 0) + 0.18
	section:SetFrameLevel((ui.content and ui.content:GetFrameLevel() or 0) + 1)
	if coolstats.LayoutSections then
		coolstats.LayoutSections()
	end
end

function coolstats.IsSectionDragClickSuppressed(section)
	local suppressUntil = section and section.dragClickSuppressedUntil
	if not suppressUntil then
		return false
	end
	return (GetTime and GetTime() or 0) < suppressUntil
end

function coolstats.GetEditContentHeight()
	local total = 4
	if ui.sections and #ui.sections > 0 then
		for index = 1, #ui.sections do
			local section = ui.sections[index]
			local rowCount = #section.rows
			if section.isFavorites then
				rowCount = coolstats.GetFavoriteRowCount()
			end
			if not section.isFavorites or rowCount > 0 then
				total = total + (section.headerHeight or 25) + (rowCount * PANEL_ROW_HEIGHT) + 9
			end
		end
	else
		for index = 1, #statSections do
			total = total + 25 + (#statSections[index].rows * PANEL_ROW_HEIGHT) + 9
		end
	end
	return total + 4
end

function coolstats.GetPanelHeight()
	if not (db and (db.editMode or db.favoriteMode)) then
		return PANEL_HEIGHT
	end

	local desiredHeight = coolstats.GetEditContentHeight() + PANEL_SCROLL_TOP + 18
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local panelTop = parentHeight - 20
	if CharacterFrame and CharacterFrame.GetTop then
		panelTop = (CharacterFrame:GetTop() or panelTop) + PANEL_ANCHOR_Y
	end

	local maxHeight = max(PANEL_HEIGHT, panelTop - 12)
	return max(PANEL_HEIGHT, min(desiredHeight, maxHeight))
end

function coolstats.GetFavoriteRowCount()
	EnsureEditOptions()
	local count = 0
	if ui.favoriteSection and ui.favoriteSection.rows then
		for index = 1, #ui.favoriteSection.rows do
			if coolstats.IsRowFavorited(ui.favoriteSection.rows[index]) then
				count = count + 1
			end
		end
		return count
	end
	if db and db.favoriteRows then
		for _, enabled in pairs(db.favoriteRows) do
			if enabled then
				count = count + 1
			end
		end
	end
	return count
end

function coolstats.GetFavoriteKey(row)
	return row and (row.favoriteSourceKey or row.configKey)
end

function coolstats.IsRowFavorited(row)
	EnsureEditOptions()
	local key = coolstats.GetFavoriteKey(row)
	return key and db and db.favoriteRows and db.favoriteRows[key] == true
end

function coolstats.HasFavoriteRows()
	return coolstats.GetFavoriteRowCount() > 0
end

function coolstats.RestoreDefaultSectionOrder()
	if not ui.sections then
		return
	end

	local sectionByKey = {}
	for index = 1, #ui.sections do
		local section = ui.sections[index]
		if section and section.configKey then
			sectionByKey[section.configKey] = section
		end
	end

	local ordered = {}
	local used = {}
	if ui.favoriteSection then
		ordered[#ordered + 1] = ui.favoriteSection
		used[ui.favoriteSection] = true
	end
	for index = 1, #statSections do
		local key = ConfigKey(statSections[index].key or statSections[index].title)
		local section = sectionByKey[key]
		if section and not used[section] then
			ordered[#ordered + 1] = section
			used[section] = true
		end
	end
	for index = 1, #ui.sections do
		local section = ui.sections[index]
		if section and not used[section] then
			ordered[#ordered + 1] = section
			used[section] = true
		end
	end
	if #ordered == #ui.sections then
		ui.sections = ordered
	end
end

function coolstats.ResetCharacterPanel()
	for _, frame in pairs(ui.statPopouts) do
		if frame then
			frame:Hide()
		end
	end
	ui.statPopouts = {}
	local preservedData = {}
	for key, value in pairs(coolstatsDB or {}) do
		if defaults[key] == nil then
			preservedData[key] = value
		end
	end
	coolstatsDB = CopyDefaults({}, defaults)
	for key, value in pairs(preservedData) do
		coolstatsDB[key] = value
	end
	db = coolstatsDB
	EnsureEditOptions()
	coolstats.RestoreDefaultSectionOrder()
	if ui.scrollFrame then
		ui.scrollFrame:SetVerticalScroll(0)
		if ui.scrollFrame.GetName then
			local scrollBar = _G[ui.scrollFrame:GetName() .. "ScrollBar"]
			if scrollBar and scrollBar.SetValue then
				scrollBar:SetValue(0)
			end
		end
	end
	Print("Character panel reset. Cached player data preserved.")
	QueueUpdate()
end

function coolstats.ShowResetPanelConfirm()
	if not StaticPopupDialogs or not StaticPopup_Show then
		coolstats.ResetCharacterPanel()
		return
	end
	if not StaticPopupDialogs["COOLSTATS_RESET_CHARACTER_PANEL"] then
		StaticPopupDialogs["COOLSTATS_RESET_CHARACTER_PANEL"] = {
			text = "Are you sure you would like to reset your character panel?\n\nCached gear, talents, and browser favorites will be preserved.",
			button1 = YES or "Yes",
			button2 = NO or "No",
			OnAccept = function()
				coolstats.ResetCharacterPanel()
			end,
			timeout = 0,
			whileDead = 1,
			hideOnEscape = 1,
		}
	end
	StaticPopup_Show("COOLSTATS_RESET_CHARACTER_PANEL")
end

function coolstats.UpdateFavoriteButton(row)
	if not row or not row.favoriteButton then
		return
	end
	local active = coolstats.IsRowFavorited(row)
	if row.favoriteButton.icon then
		row.favoriteButton.icon:SetVertexColor(active and 1.0 or 0.55, active and 0.82 or 0.55, active and 0.16 or 0.55, active and 1.0 or 0.55)
	end
end

function coolstats.SetRowFavorited(row, favorited)
	EnsureEditOptions()
	local key = coolstats.GetFavoriteKey(row)
	if not key or not db then
		return
	end
	if favorited then
		db.favoriteRows[key] = true
	else
		db.favoriteRows[key] = nil
	end
	QueueUpdate()
end

function coolstats.ToggleFavoriteRow(row)
	coolstats.SetRowFavorited(row, not coolstats.IsRowFavorited(row))
end

function coolstats.GetPopoutOptions()
	EnsureEditOptions()
	return db and db.popoutOptions or defaults.popoutOptions
end

function coolstats.GetPopoutFont()
	local options = coolstats.GetPopoutOptions()
	local fontIndex = floor((tonumber(options.fontIndex or 1) or 1) + 0.5)
	fontIndex = max(1, min(#STAT_POPOUT_FONTS, fontIndex))
	return STAT_POPOUT_FONTS[fontIndex], fontIndex
end

function coolstats.GetPopoutAlpha()
	local options = coolstats.GetPopoutOptions()
	return max(0.15, min(1.0, tonumber(options.alpha or defaults.popoutOptions.alpha) or defaults.popoutOptions.alpha))
end

function coolstats.GetPopoutFontScale()
	local options = coolstats.GetPopoutOptions()
	return max(0.75, min(1.80, tonumber(options.fontScale or defaults.popoutOptions.fontScale) or defaults.popoutOptions.fontScale))
end

function coolstats.GetPopoutSnapDistance()
	local options = coolstats.GetPopoutOptions()
	return max(0, min(30, tonumber(options.snapDistance or STAT_POPOUT_SNAP_DISTANCE) or STAT_POPOUT_SNAP_DISTANCE))
end

function coolstats.GetPopoutShowHeader()
	local options = coolstats.GetPopoutOptions()
	return options.showHeader ~= false
end

function coolstats.GetPopoutSyncSize()
	local options = coolstats.GetPopoutOptions()
	return options.syncSize == true
end

function coolstats.SetFittedPopoutFont(fontString, font, size, flags, maxWidth, minSize)
	if not fontString or not fontString.SetFont then
		return
	end

	local fitSize = floor((size or minSize or 8) + 0.5)
	local smallest = floor((minSize or 8) + 0.5)
	maxWidth = maxWidth or 0
	fontString:SetFont(font.file, fitSize, flags or "")

	if maxWidth > 0 and fontString.GetStringWidth then
		local stringWidth = fontString:GetStringWidth() or 0
		while fitSize > smallest and stringWidth > maxWidth do
			fitSize = fitSize - 1
			fontString:SetFont(font.file, fitSize, flags or "")
			stringWidth = fontString:GetStringWidth() or 0
		end
	end
end

function coolstats.NormalizePopoutSize(width, height)
	width = floor((tonumber(width) or STAT_POPOUT_DEFAULT_WIDTH) + 0.5)
	height = floor((tonumber(height) or STAT_POPOUT_DEFAULT_HEIGHT) + 0.5)
	width = max(STAT_POPOUT_MIN_WIDTH, width)
	height = max(STAT_POPOUT_MIN_HEIGHT, height)
	return width, height
end

function coolstats.GetPopoutRect(frame)
	if not frame or not frame:IsShown() then
		return nil
	end
	local left = frame:GetLeft()
	local top = frame:GetTop()
	if not left or not top then
		return nil
	end
	local width, height = coolstats.NormalizePopoutSize(frame:GetWidth(), frame:GetHeight())
	return {
		frame = frame,
		left = left,
		top = top,
		width = width,
		height = height,
		right = left + width,
		bottom = top - height,
	}
end

function coolstats.GetPopoutAttachment(first, second, tolerance)
	if not first or not second then
		return nil
	end
	tolerance = tolerance or 3
	local verticalOverlap = min(first.top, second.top) - max(first.bottom, second.bottom)
	local horizontalOverlap = min(first.right, second.right) - max(first.left, second.left)

	if verticalOverlap > 1 then
		if abs(first.right - second.left) <= tolerance then
			return "right"
		elseif abs(first.left - second.right) <= tolerance then
			return "left"
		end
	end
	if horizontalOverlap > 1 then
		if abs(first.bottom - second.top) <= tolerance then
			return "below"
		elseif abs(first.top - second.bottom) <= tolerance then
			return "above"
		end
	end
	return nil
end

function coolstats.PopoutsAreGrouped(firstFrame, secondFrame)
	if firstFrame == secondFrame then
		return false
	end
	return coolstats.GetPopoutAttachment(coolstats.GetPopoutRect(firstFrame), coolstats.GetPopoutRect(secondFrame), 3) ~= nil
end

function coolstats.CollectGroupedPopouts(sourceFrame)
	local group = {}
	if not coolstats.GetPopoutRect(sourceFrame) then
		return group
	end

	local seen = {}
	local queue = { sourceFrame }
	seen[sourceFrame] = true
	local cursor = 1

	while queue[cursor] do
		local current = queue[cursor]
		cursor = cursor + 1
		group[#group + 1] = current

		for _, other in pairs(ui.statPopouts) do
			if other and not seen[other] and coolstats.PopoutsAreGrouped(current, other) then
				seen[other] = true
				queue[#queue + 1] = other
			end
		end
	end

	return group
end

function coolstats.CaptureGroupedPopouts(sourceFrame)
	local frames = coolstats.CollectGroupedPopouts(sourceFrame)
	local capture = { source = sourceFrame, entries = {}, byFrame = {} }
	for index = 1, #frames do
		local rect = coolstats.GetPopoutRect(frames[index])
		if rect then
			local entry = {
				frame = frames[index],
				left = rect.left,
				top = rect.top,
				right = rect.right,
				bottom = rect.bottom,
				width = rect.width,
				height = rect.height,
			}
			capture.entries[#capture.entries + 1] = entry
			capture.byFrame[frames[index]] = entry
		end
	end
	return capture
end

function coolstats.GetGroupedPopoutPreferredSize(capture, sourceFrame, referenceFrame)
	if referenceFrame then
		return coolstats.NormalizePopoutSize(referenceFrame:GetWidth(), referenceFrame:GetHeight())
	end
	if sourceFrame then
		return coolstats.NormalizePopoutSize(sourceFrame:GetWidth(), sourceFrame:GetHeight())
	end

	local width
	local height
	local area = 0
	for index = 1, #capture.entries do
		local entry = capture.entries[index]
		local entryArea = entry.width * entry.height
		if entryArea > area then
			width = entry.width
			height = entry.height
			area = entryArea
		end
	end

	return coolstats.NormalizePopoutSize(width or STAT_POPOUT_DEFAULT_WIDTH, height or STAT_POPOUT_DEFAULT_HEIGHT)
end

function coolstats.PlaceGroupedPopoutSizes(capture, sourceFrame, width, height)
	if not capture or #capture.entries < 2 then
		return false
	end

	width, height = coolstats.NormalizePopoutSize(width, height)
	local sourceEntry = capture.byFrame[sourceFrame] or capture.entries[1]
	local sourceLeft = sourceEntry.frame:GetLeft() or sourceEntry.left
	local sourceTop = sourceEntry.frame:GetTop() or sourceEntry.top
	local placed = {}
	local queue = { sourceEntry }
	placed[sourceEntry.frame] = { left = sourceLeft, top = sourceTop }
	local cursor = 1

	while queue[cursor] do
		local current = queue[cursor]
		local currentPosition = placed[current.frame]
		cursor = cursor + 1

		for index = 1, #capture.entries do
			local other = capture.entries[index]
			if not placed[other.frame] then
				local attachment = coolstats.GetPopoutAttachment(current, other, 3)
				if attachment then
					local left = currentPosition.left + (other.left - current.left)
					local top = currentPosition.top + (other.top - current.top)
					if attachment == "right" then
						left = currentPosition.left + width
					elseif attachment == "left" then
						left = currentPosition.left - width
					elseif attachment == "below" then
						top = currentPosition.top - height
					elseif attachment == "above" then
						top = currentPosition.top + height
					end
					placed[other.frame] = { left = left, top = top }
					queue[#queue + 1] = other
				end
			end
		end
	end

	for index = 1, #capture.entries do
		local entry = capture.entries[index]
		if not placed[entry.frame] then
			placed[entry.frame] = { left = entry.frame:GetLeft() or entry.left, top = entry.frame:GetTop() or entry.top }
		end
	end

	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local minLeft, maxRight, maxTop, minBottom
	for frame, position in pairs(placed) do
		minLeft = minLeft and min(minLeft, position.left) or position.left
		maxRight = maxRight and max(maxRight, position.left + width) or (position.left + width)
		maxTop = maxTop and max(maxTop, position.top) or position.top
		minBottom = minBottom and min(minBottom, position.top - height) or (position.top - height)
	end

	local dx = 0
	local dy = 0
	if minLeft and minLeft < 0 then
		dx = -minLeft
	elseif maxRight and maxRight > parentWidth then
		dx = parentWidth - maxRight
	end
	if maxTop and maxTop > parentHeight then
		dy = parentHeight - maxTop
	elseif minBottom and minBottom < 0 then
		dy = -minBottom
	end

	for frame, position in pairs(placed) do
		SetSize(frame, width, height)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.left + dx, position.top + dy)
		coolstats.UpdateStatPopoutAppearance(frame)
		coolstats.SaveStatPopoutFrame(frame)
	end

	return true
end

function coolstats.ApplyGroupedPopoutSizeSync(sourceFrame, preferSourceSize, referenceFrame)
	if not coolstats.GetPopoutSyncSize() then
		return false
	end

	local capture = coolstats.CaptureGroupedPopouts(sourceFrame)
	if #capture.entries < 2 then
		return false
	end

	local width, height = coolstats.GetGroupedPopoutPreferredSize(capture, preferSourceSize and sourceFrame or nil, referenceFrame)
	return coolstats.PlaceGroupedPopoutSizes(capture, referenceFrame or sourceFrame, width, height)
end

function coolstats.ApplyAllGroupedPopoutSizeSync()
	if not coolstats.GetPopoutSyncSize() then
		return
	end

	local processed = {}
	for _, frame in pairs(ui.statPopouts) do
		if frame and frame:IsShown() and not processed[frame] then
			local capture = coolstats.CaptureGroupedPopouts(frame)
			for index = 1, #capture.entries do
				processed[capture.entries[index].frame] = true
			end
			if #capture.entries > 1 then
				local width, height = coolstats.GetGroupedPopoutPreferredSize(capture)
				coolstats.PlaceGroupedPopoutSizes(capture, frame, width, height)
			end
		end
	end
end

function coolstats.SetPopoutSyncSize(enabled)
	local options = coolstats.GetPopoutOptions()
	options.syncSize = enabled == true
	if options.syncSize then
		coolstats.ApplyAllGroupedPopoutSizeSync()
	end
end

function coolstats.GetPopoutSourceRow(row)
	if row and row.isFavoriteClone and row.favoriteSourceKey and ui.rowByKey[row.favoriteSourceKey] then
		return ui.rowByKey[row.favoriteSourceKey]
	end
	return row
end

function coolstats.GetStatPopoutKey(row)
	local sourceRow = coolstats.GetPopoutSourceRow(row)
	return sourceRow and sourceRow.configKey
end

function coolstats.UpdateLinkedStatPopoutButtons(row)
	local key = coolstats.GetStatPopoutKey(row)
	if not key then
		return
	end
	for index = 1, #ui.rows do
		if coolstats.GetStatPopoutKey(ui.rows[index]) == key then
			coolstats.UpdateStatPopoutButton(ui.rows[index])
		end
	end
end

function coolstats.UpdateSyncedPopoutSizeFromFrame(frame)
	if not coolstats.GetPopoutSyncSize() or not frame then
		return false
	end
	local capture = frame.resizeGroup or coolstats.CaptureGroupedPopouts(frame)
	if not capture or #capture.entries < 2 then
		return false
	end
	local width, height = coolstats.NormalizePopoutSize(frame:GetWidth(), frame:GetHeight())
	return coolstats.PlaceGroupedPopoutSizes(capture, frame, width, height)
end

function coolstats.GetStatPopoutSettings(row)
	EnsureEditOptions()
	local key = coolstats.GetStatPopoutKey(row)
	if not db or not key then
		return nil
	end
	local settings = db.statPopouts[key]
	if type(settings) ~= "table" and row and row.isFavoriteClone and row.configKey and db.statPopouts[row.configKey] then
		settings = db.statPopouts[row.configKey]
		db.statPopouts[row.configKey] = nil
		db.statPopouts[key] = settings
	end
	if type(settings) ~= "table" then
		settings = {}
		db.statPopouts[key] = settings
	end
	return settings
end

function coolstats.GetDefaultStatPopoutPosition()
	local shown = 0
	if db and db.statPopouts then
		for _, settings in pairs(db.statPopouts) do
			if type(settings) == "table" and settings.shown then
				shown = shown + 1
			end
		end
	end

	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local left = ((parentWidth - STAT_POPOUT_DEFAULT_WIDTH) * 0.5) + ((shown % 4) * 18)
	local top = ((parentHeight + STAT_POPOUT_DEFAULT_HEIGHT) * 0.5) - ((shown % 4) * 18)
	return left, top
end

function coolstats.ClampStatPopoutPosition(frame, left, top)
	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local width = frame:GetWidth() or STAT_POPOUT_DEFAULT_WIDTH
	local height = frame:GetHeight() or STAT_POPOUT_DEFAULT_HEIGHT
	left = max(0, min(parentWidth - width, left or 0))
	top = max(height, min(parentHeight, top or height))
	return left, top
end

function coolstats.SaveStatPopoutFrame(frame)
	if not frame or not frame.row then
		return
	end
	local settings = coolstats.GetStatPopoutSettings(frame.row)
	if not settings then
		return
	end
	local left = frame:GetLeft()
	local top = frame:GetTop()
	if left and top then
		settings.x = floor(left + 0.5)
		settings.y = floor(top + 0.5)
	end
	settings.width = floor((frame:GetWidth() or STAT_POPOUT_DEFAULT_WIDTH) + 0.5)
	settings.height = floor((frame:GetHeight() or STAT_POPOUT_DEFAULT_HEIGHT) + 0.5)
	settings.shown = frame:IsShown() == 1 or frame:IsShown() == true
end

function coolstats.PositionStatPopout(frame, settings)
	local width = settings.width or STAT_POPOUT_DEFAULT_WIDTH
	local height = settings.height or STAT_POPOUT_DEFAULT_HEIGHT
	width, height = coolstats.NormalizePopoutSize(width, height)
	settings.width = width
	settings.height = height
	SetSize(frame, width, height)

	local left = settings.x
	local top = settings.y
	if not left or not top then
		left, top = coolstats.GetDefaultStatPopoutPosition()
	end
	left, top = coolstats.ClampStatPopoutPosition(frame, left, top)

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

function coolstats.SnapStatPopout(frame)
	if not frame then
		return
	end

	local left = frame:GetLeft()
	local top = frame:GetTop()
	local width = frame:GetWidth() or STAT_POPOUT_DEFAULT_WIDTH
	local height = frame:GetHeight() or STAT_POPOUT_DEFAULT_HEIGHT
	if not left or not top then
		return
	end
	local right = left + width
	local bottom = top - height
	local snapDistance = coolstats.GetPopoutSnapDistance()
	local snapTarget
	if snapDistance <= 0 then
		left, top = coolstats.ClampStatPopoutPosition(frame, left, top)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		coolstats.SaveStatPopoutFrame(frame)
		coolstats.ApplyGroupedPopoutSizeSync(frame)
		return
	end

	for _, other in pairs(ui.statPopouts) do
		if other ~= frame and other:IsShown() then
			local otherLeft = other:GetLeft()
			local otherTop = other:GetTop()
			local otherWidth = other:GetWidth() or STAT_POPOUT_DEFAULT_WIDTH
			local otherHeight = other:GetHeight() or STAT_POPOUT_DEFAULT_HEIGHT
			if otherLeft and otherTop then
				local otherRight = otherLeft + otherWidth
				local otherBottom = otherTop - otherHeight
				local overlapsX = left < otherRight and right > otherLeft
				local overlapsY = bottom < otherTop and top > otherBottom

				if overlapsX and overlapsY then
					local bestAxis
					local bestValue
					local bestDistance
					local distance = abs(otherRight - left)
					bestAxis = "x"
					bestValue = otherRight
					bestDistance = distance

					distance = abs((otherLeft - width) - left)
					if distance < bestDistance then
						bestAxis = "x"
						bestValue = otherLeft - width
						bestDistance = distance
					end

					distance = abs(otherBottom - top)
					if distance < bestDistance then
						bestAxis = "y"
						bestValue = otherBottom
						bestDistance = distance
					end

					distance = abs((otherTop + height) - top)
					if distance < bestDistance then
						bestAxis = "y"
						bestValue = otherTop + height
					end

					if bestAxis == "x" then
						left = bestValue
						right = left + width
						snapTarget = other
					elseif bestAxis == "y" then
						top = bestValue
						bottom = top - height
						snapTarget = other
					end
				end

				if abs(left - otherLeft) <= snapDistance then
					left = otherLeft
				elseif abs(right - otherRight) <= snapDistance then
					left = otherRight - width
				elseif abs(left - otherRight) <= snapDistance then
					left = otherRight
					snapTarget = other
				elseif abs(right - otherLeft) <= snapDistance then
					left = otherLeft - width
					snapTarget = other
				end

				if abs(top - otherTop) <= snapDistance then
					top = otherTop
				elseif abs(bottom - otherBottom) <= snapDistance then
					top = otherBottom + height
				elseif abs(top - otherBottom) <= snapDistance then
					top = otherBottom
					snapTarget = other
				elseif abs(bottom - otherTop) <= snapDistance then
					top = otherTop + height
					snapTarget = other
				end
			end
		end
	end

	left, top = coolstats.ClampStatPopoutPosition(frame, left, top)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	coolstats.SaveStatPopoutFrame(frame)
	coolstats.ApplyGroupedPopoutSizeSync(frame, false, snapTarget)
end

function coolstats.UpdateStatPopoutAppearance(frame)
	if not frame then
		return
	end

	local font = coolstats.GetPopoutFont()
	local fontScale = coolstats.GetPopoutFontScale()
	local width = frame:GetWidth() or STAT_POPOUT_DEFAULT_WIDTH
	local height = frame:GetHeight() or STAT_POPOUT_DEFAULT_HEIGHT
	local showHeader = coolstats.GetPopoutShowHeader()
	local valueSize = floor(max(11, min(38, min(width / 7.0, height / 1.85) * fontScale)) + 0.5)
	local titleSize = floor(max(8, min(14, valueSize * 0.55)) + 0.5)
	local valueWidth = max(44, width - 20)

	if frame.SetBackdropColor then
		frame:SetBackdropColor(0.02, 0.018, 0.014, coolstats.GetPopoutAlpha())
	end
	if frame.title and frame.title.SetFont then
		SetVisible(frame.title, showHeader)
		frame.title:SetWidth(max(30, width - 32))
		coolstats.SetFittedPopoutFont(frame.title, font, titleSize, "", max(30, width - 32), 7)
	end
	if frame.value and frame.value.SetFont then
		frame.value:ClearAllPoints()
		if showHeader then
			frame.value:SetPoint("CENTER", frame, "CENTER", 0, -5)
		else
			frame.value:SetPoint("CENTER", frame, "CENTER", 0, 0)
		end
		frame.value:SetWidth(valueWidth)
		coolstats.SetFittedPopoutFont(frame.value, font, valueSize, font.flags, valueWidth, 6)
	end
end

function coolstats.ApplyStatPopoutOptionsToAll()
	for _, frame in pairs(ui.statPopouts) do
		coolstats.UpdateStatPopoutAppearance(frame)
	end
end

function coolstats.CreateStatPopoutGrid()
	if ui.popoutGrid then
		return ui.popoutGrid
	end

	local grid = CreateFrame("Frame", "coolstatsPopoutGrid", UIParent)
	ui.popoutGrid = grid
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("DIALOG")
	grid:SetFrameLevel(70)
	grid:EnableMouse(false)
	grid.verticalLines = {}
	grid.horizontalLines = {}
	grid:Hide()

	local xAxis = grid:CreateTexture(nil, "ARTWORK")
	xAxis:SetTexture("Interface\\Buttons\\WHITE8X8")
	xAxis:SetVertexColor(1.0, 0.82, 0.16, 0.72)
	grid.xAxis = xAxis

	local yAxis = grid:CreateTexture(nil, "ARTWORK")
	yAxis:SetTexture("Interface\\Buttons\\WHITE8X8")
	yAxis:SetVertexColor(1.0, 0.82, 0.16, 0.72)
	grid.yAxis = yAxis

	local origin = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	origin:SetText("0,0")
	origin:SetTextColor(1.0, 0.82, 0.16)
	origin:SetShadowOffset(1, -1)
	origin:SetShadowColor(0, 0, 0, 1)
	grid.origin = origin

	local coords = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	coords:SetTextColor(0.25, 1.00, 1.00)
	coords:SetShadowOffset(1, -1)
	coords:SetShadowColor(0, 0, 0, 1)
	grid.coords = coords
	return grid
end

function coolstats.GetGridLine(lines, index, parent)
	if lines[index] then
		return lines[index]
	end
	local line = parent:CreateTexture(nil, "BACKGROUND")
	line:SetTexture("Interface\\Buttons\\WHITE8X8")
	lines[index] = line
	return line
end

function coolstats.LayoutStatPopoutGrid(grid)
	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local centerX = parentWidth * 0.5
	local centerY = parentHeight * 0.5
	local startX = centerX - (floor(centerX / STAT_POPOUT_GRID_SPACING) * STAT_POPOUT_GRID_SPACING)
	local startY = centerY - (floor(centerY / STAT_POPOUT_GRID_SPACING) * STAT_POPOUT_GRID_SPACING)
	local columns = floor((parentWidth - startX) / STAT_POPOUT_GRID_SPACING) + 1
	local rows = floor((parentHeight - startY) / STAT_POPOUT_GRID_SPACING) + 1

	grid.yAxis:ClearAllPoints()
	grid.yAxis:SetPoint("TOPLEFT", grid, "TOPLEFT", floor(centerX + 0.5) - 1, 0)
	SetSize(grid.yAxis, 3, parentHeight)
	grid.yAxis:Show()

	grid.xAxis:ClearAllPoints()
	grid.xAxis:SetPoint("LEFT", grid, "BOTTOMLEFT", 0, floor(centerY + 0.5))
	SetSize(grid.xAxis, parentWidth, 3)
	grid.xAxis:Show()

	grid.origin:ClearAllPoints()
	grid.origin:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", centerX + 6, centerY + 6)
	grid.origin:Show()

	for index = 1, columns do
		local line = coolstats.GetGridLine(grid.verticalLines, index, grid)
		local x = startX + ((index - 1) * STAT_POPOUT_GRID_SPACING)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", grid, "TOPLEFT", x, 0)
		SetSize(line, 1, parentHeight)
		line:SetVertexColor(0.25, 0.65, 1.00, 0.18)
		line:Show()
	end
	for index = columns + 1, #grid.verticalLines do
		grid.verticalLines[index]:Hide()
	end

	for index = 1, rows do
		local line = coolstats.GetGridLine(grid.horizontalLines, index, grid)
		local y = startY + ((index - 1) * STAT_POPOUT_GRID_SPACING)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, y)
		SetSize(line, parentWidth, 1)
		line:SetVertexColor(0.25, 0.65, 1.00, 0.18)
		line:Show()
	end
	for index = rows + 1, #grid.horizontalLines do
		grid.horizontalLines[index]:Hide()
	end
end

function coolstats.UpdateStatPopoutGridCoords(frame)
	local grid = ui.popoutGrid
	if not grid or not frame then
		return
	end
	local left = frame:GetLeft() or 0
	local top = frame:GetTop() or 0
	local width = frame:GetWidth() or 0
	local height = frame:GetHeight() or 0
	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local x = (left + (width * 0.5)) - (parentWidth * 0.5)
	local y = (top - (height * 0.5)) - (parentHeight * 0.5)
	grid.coords:SetText(format("x %d  y %d  w %d  h %d", floor(x + 0.5), floor(y + 0.5), floor(width + 0.5), floor(height + 0.5)))
	grid.coords:ClearAllPoints()
	grid.coords:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left + 4, max(0, top + 4))
end

function coolstats.ShowStatPopoutGrid(frame)
	if not (db and db.popoutMode) then
		return
	end
	local grid = coolstats.CreateStatPopoutGrid()
	coolstats.LayoutStatPopoutGrid(grid)
	grid.dragFrame = frame
	coolstats.UpdateStatPopoutGridCoords(frame)
	grid:SetScript("OnUpdate", function(self)
		coolstats.UpdateStatPopoutGridCoords(self.dragFrame)
	end)
	grid:Show()
end

function coolstats.HideStatPopoutGrid()
	local grid = ui.popoutGrid
	if not grid then
		return
	end
	grid.dragFrame = nil
	grid:SetScript("OnUpdate", nil)
	grid:Hide()
end

function coolstats.StartPopoutGroupDrag(frame)
	local capture = coolstats.CaptureGroupedPopouts(frame)
	if #capture.entries < 2 then
		return false
	end

	frame.groupDrag = {
		capture = capture,
		sourceLeft = frame:GetLeft() or 0,
		sourceTop = frame:GetTop() or 0,
	}
	frame:StartMoving()
	frame:SetScript("OnUpdate", function(self)
		coolstats.UpdatePopoutGroupDrag(self)
	end)
	return true
end

function coolstats.UpdatePopoutGroupDrag(frame)
	local drag = frame and frame.groupDrag
	if not drag or not drag.capture then
		return
	end

	local left = frame:GetLeft()
	local top = frame:GetTop()
	if not left or not top then
		return
	end
	local dx = left - drag.sourceLeft
	local dy = top - drag.sourceTop

	for index = 1, #drag.capture.entries do
		local entry = drag.capture.entries[index]
		if entry.frame ~= frame then
			entry.frame:ClearAllPoints()
			entry.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", entry.left + dx, entry.top + dy)
		end
	end
end

function coolstats.StopPopoutGroupDrag(frame)
	local drag = frame and frame.groupDrag
	if not drag or not drag.capture then
		return false
	end

	frame:SetScript("OnUpdate", nil)
	coolstats.UpdatePopoutGroupDrag(frame)

	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local minLeft, maxRight, maxTop, minBottom
	for index = 1, #drag.capture.entries do
		local current = drag.capture.entries[index].frame
		local rect = coolstats.GetPopoutRect(current)
		if rect then
			minLeft = minLeft and min(minLeft, rect.left) or rect.left
			maxRight = maxRight and max(maxRight, rect.right) or rect.right
			maxTop = maxTop and max(maxTop, rect.top) or rect.top
			minBottom = minBottom and min(minBottom, rect.bottom) or rect.bottom
		end
	end

	local dx = 0
	local dy = 0
	if minLeft and minLeft < 0 then
		dx = -minLeft
	elseif maxRight and maxRight > parentWidth then
		dx = parentWidth - maxRight
	end
	if maxTop and maxTop > parentHeight then
		dy = parentHeight - maxTop
	elseif minBottom and minBottom < 0 then
		dy = -minBottom
	end

	for index = 1, #drag.capture.entries do
		local current = drag.capture.entries[index].frame
		if dx ~= 0 or dy ~= 0 then
			local left = current:GetLeft()
			local top = current:GetTop()
			if left and top then
				current:ClearAllPoints()
				current:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
			end
		end
		coolstats.SaveStatPopoutFrame(current)
	end

	frame.groupDrag = nil
	return true
end

function coolstats.UpdateStatPopoutButton(row)
	if not row or not row.popoutButton then
		return
	end
	local key = coolstats.GetStatPopoutKey(row)
	local settings = key and db and db.statPopouts and db.statPopouts[key]
	if settings and settings.shown then
		row.popoutButton.icon:SetVertexColor(0.25, 1.00, 0.25, 1)
	else
		row.popoutButton.icon:SetVertexColor(1.00, 0.82, 0.16, 1)
	end
end

function coolstats.UpdateStatPopout(frame)
	if not frame or not frame.row then
		return
	end
	local row = frame.row
	local value, red, green, blue, label = row.get()
	frame.title:SetText(label or row.defaultLabel or "")
	frame.value:SetText(value or "-")
	if red and green and blue then
		frame.value:SetTextColor(red, green, blue)
	else
		frame.value:SetTextColor(1, 1, 1)
	end
	coolstats.UpdateStatPopoutAppearance(frame)
end

function coolstats.SetStatPopoutControlsVisible(frame, visible)
	if not frame then
		return
	end
	if frame.close then
		if visible then
			frame.close:SetAlpha(1)
			frame.close:Show()
		else
			frame.close:SetAlpha(0)
			frame.close:Hide()
		end
	end
end

function coolstats.QueueStatPopoutControlsHide(frame)
	if not frame then
		return
	end
	frame.closeHidePending = true
	frame:SetScript("OnUpdate", function(self)
		self.closeHidePending = nil
		self:SetScript("OnUpdate", nil)
		if MouseIsOver and (MouseIsOver(self) or (self.close and MouseIsOver(self.close))) then
			return
		end
		coolstats.SetStatPopoutControlsVisible(self, false)
	end)
end

function coolstats.CreateStatPopout(row)
	local sourceRow = coolstats.GetPopoutSourceRow(row)
	local key = coolstats.GetStatPopoutKey(row)
	if not sourceRow or not key then
		return nil
	end
	if ui.statPopouts[key] then
		return ui.statPopouts[key]
	end

	local settings = coolstats.GetStatPopoutSettings(sourceRow)
	if not settings then
		return nil
	end

	local frame = CreateFrame("Frame", nil, UIParent)
	ui.statPopouts[key] = frame
	frame.row = sourceRow
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(90)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	if frame.SetResizable then
		frame:SetResizable(true)
	end
	if frame.SetMinResize then
		pcall(frame.SetMinResize, frame, STAT_POPOUT_MIN_WIDTH, STAT_POPOUT_MIN_HEIGHT)
	end
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if db and db.popoutMode and IsShiftKeyDown and IsShiftKeyDown() then
			coolstats.ShowStatPopoutGrid(self)
		end
		if IsShiftKeyDown and IsShiftKeyDown() and IsControlKeyDown and IsControlKeyDown() and coolstats.StartPopoutGroupDrag(self) then
			return
		end
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		coolstats.HideStatPopoutGrid()
		if coolstats.StopPopoutGroupDrag(self) then
			return
		end
		coolstats.SnapStatPopout(self)
	end)
	frame:SetScript("OnSizeChanged", function(self)
		coolstats.UpdateStatPopoutAppearance(self)
	end)
	frame:SetScript("OnEnter", function(self)
		coolstats.SetStatPopoutControlsVisible(self, true)
	end)
	frame:SetScript("OnLeave", function(self)
		coolstats.QueueStatPopoutControlsHide(self)
	end)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 14,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.02, 0.018, 0.014, coolstats.GetPopoutAlpha())
	frame:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -6)
	title:SetJustifyH("LEFT")
	title:SetTextColor(1.00, 0.78, 0.12)
	frame.title = title

	local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	value:SetPoint("CENTER", frame, "CENTER", 0, -4)
	value:SetWidth(STAT_POPOUT_DEFAULT_WIDTH - 20)
	value:SetJustifyH("CENTER")
	value:SetText("-")
	value:SetShadowOffset(1, -1)
	value:SetShadowColor(0, 0, 0, 1)
	frame.value = value

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	frame.close = close
	SetSize(close, 20, 20)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
	close:SetAlpha(0)
	close:Hide()
	close:SetScript("OnClick", function(self)
		local parent = self:GetParent()
		local popoutSettings = coolstats.GetStatPopoutSettings(parent.row)
		if popoutSettings then
			popoutSettings.shown = false
		end
		parent:Hide()
		coolstats.UpdateLinkedStatPopoutButtons(parent.row)
	end)
	close:SetScript("OnEnter", function(self)
		coolstats.SetStatPopoutControlsVisible(self:GetParent(), true)
	end)
	close:SetScript("OnLeave", function(self)
		coolstats.QueueStatPopoutControlsHide(self:GetParent())
	end)

	local resize = CreateFrame("Button", nil, frame)
	SetSize(resize, 14, 14)
	resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
	resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resize:SetScript("OnMouseDown", function(self)
		local parent = self:GetParent()
		parent.resizeGroup = nil
		if coolstats.GetPopoutSyncSize() then
			local capture = coolstats.CaptureGroupedPopouts(parent)
			if capture and #capture.entries > 1 then
				parent.resizeGroup = capture
			end
		end
		if parent.StartSizing then
			parent:StartSizing("BOTTOMRIGHT")
		end
	end)
	resize:SetScript("OnMouseUp", function(self)
		local parent = self:GetParent()
		parent:StopMovingOrSizing()
		local synced = coolstats.UpdateSyncedPopoutSizeFromFrame(parent)
		parent.resizeGroup = nil
		if not synced then
			coolstats.SnapStatPopout(parent)
		end
	end)
	frame.resize = resize

	coolstats.PositionStatPopout(frame, settings)
	coolstats.UpdateStatPopoutAppearance(frame)
	coolstats.UpdateStatPopout(frame)
	frame:Hide()
	return frame
end

function coolstats.ToggleStatPopout(row)
	local settings = coolstats.GetStatPopoutSettings(row)
	if not settings then
		return
	end

	local frame = coolstats.CreateStatPopout(row)
	if not frame then
		return
	end

	if settings.shown and frame:IsShown() then
		settings.shown = false
		frame:Hide()
	else
		settings.shown = true
		coolstats.PositionStatPopout(frame, settings)
		coolstats.UpdateStatPopout(frame)
		frame:Show()
		coolstats.SaveStatPopoutFrame(frame)
	end
	coolstats.UpdateLinkedStatPopoutButtons(row)
end

local function CreateStatRow(parent, section, rowData, yOffset, rowIndex, sectionIndex)
	local row = CreateFrame("Frame", nil, parent)
	SetSize(row, PANEL_ROW_WIDTH, PANEL_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
	row:EnableMouse(true)
	row.isFavoriteClone = rowData.favoriteClone == true
	row.favoriteSourceKey = rowData.favoriteSourceKey

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

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetWidth(PANEL_LABEL_WIDTH)
	row.label:SetHeight(PANEL_ROW_HEIGHT)
	row.label:SetJustifyH("LEFT")
	if row.label.SetJustifyV then
		row.label:SetJustifyV("MIDDLE")
	end
	row.label:SetTextColor(1.00, 0.78, 0.12)
	row.label:SetText(rowData.label)
	if row.label.SetNonSpaceWrap then
		row.label:SetNonSpaceWrap(false)
	end
	if row.label.SetWordWrap then
		row.label:SetWordWrap(false)
	end

	row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value:SetWidth(PANEL_VALUE_WIDTH)
	row.value:SetHeight(PANEL_ROW_HEIGHT)
	row.value:SetJustifyH("RIGHT")
	if row.value.SetJustifyV then
		row.value:SetJustifyV("MIDDLE")
	end
	row.value:SetText("-")
	row.value:SetTextColor(1, 1, 1)
	if row.value.SetNonSpaceWrap then
		row.value:SetNonSpaceWrap(false)
	end
	if row.value.SetWordWrap then
		row.value:SetWordWrap(false)
	end
	if rowData.centered then
		row.value:ClearAllPoints()
		row.value:SetPoint("CENTER", row, "CENTER", 0, 0)
		row.value:SetWidth(PANEL_ROW_WIDTH - 8)
		row.value:SetJustifyH("CENTER")
		if rowData.fontSize then
			row.value:SetFont("Fonts\\FRIZQT__.TTF", rowData.fontSize, "OUTLINE")
		end
		row.label:Hide()
	end

	local check = CreateFrame("CheckButton", "coolstatsRowCheck" .. sectionIndex .. "_" .. rowIndex, row, "UICheckButtonTemplate")
	SetSize(check, 18, 18)
	check:SetPoint("LEFT", row, "LEFT", -3, 0)
	check:SetFrameLevel(row:GetFrameLevel() + 3)
	check:Hide()
	row.check = check

	local favoriteButton = CreateFrame("Button", "coolstatsRowFavorite" .. sectionIndex .. "_" .. rowIndex, row)
	SetSize(favoriteButton, 14, 14)
	favoriteButton:SetPoint("LEFT", row, "LEFT", 0, 0)
	favoriteButton:SetFrameLevel(row:GetFrameLevel() + 3)
	favoriteButton:Hide()
	local favoriteIcon = favoriteButton:CreateTexture(nil, "OVERLAY")
	favoriteIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	SetSize(favoriteIcon, 13, 13)
	favoriteIcon:SetPoint("CENTER", favoriteButton, "CENTER", 0, 0)
	favoriteButton.icon = favoriteIcon
	favoriteButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	favoriteButton:SetScript("OnClick", function()
		coolstats.ToggleFavoriteRow(row)
	end)
	favoriteButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if coolstats.IsRowFavorited(row) then
			GameTooltip:SetText("Remove Favourite", 1, 0.82, 0.16)
		else
			GameTooltip:SetText("Add Favourite", 1, 0.82, 0.16)
		end
		GameTooltip:Show()
	end)
	favoriteButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row.favoriteButton = favoriteButton

	row.section = section
	row.configKey = rowData.configKey or (section.configKey .. "." .. ConfigKey(rowData.key or rowData.label))
	row.centered = rowData.centered
	row.fontSize = rowData.fontSize
	row.defaultLabel = rowData.label
	row.get = rowData.get
	row.customTooltip = rowData.tooltip
	row.nativeKey = rowData.nativeKey
	row.nativeSetter = rowData.nativeSetter
	row.nativeArg = rowData.nativeArg
	row.nativeHandler = rowData.nativeHandler
	row:SetScript("OnEnter", function(self)
		if self.nativeSetter and ShowNativeStatTooltip(self) then
			return
		end
		if not self.customTooltip then
			return
		end
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.label:GetText() or self.defaultLabel, 1, 0.82, 0.16)
		local tooltipText = self.customTooltip
		if type(tooltipText) == "function" then
			tooltipText = tooltipText()
		end
		AddTooltipLines(tooltipText)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	check:SetScript("OnClick", function(self)
		SetRowEnabled(row, self:GetChecked())
		QueueUpdate()
	end)

	local popoutButton = CreateFrame("Button", "coolstatsRowPopout" .. sectionIndex .. "_" .. rowIndex, row)
	SetSize(popoutButton, 14, 14)
	popoutButton:SetPoint("LEFT", row, "LEFT", 0, 0)
	popoutButton:SetFrameLevel(row:GetFrameLevel() + 3)
	popoutButton:Hide()
	local popoutIcon = popoutButton:CreateTexture(nil, "OVERLAY")
	popoutIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
	SetSize(popoutIcon, 12, 12)
	popoutIcon:SetPoint("CENTER", popoutButton, "CENTER", 0, 0)
	popoutButton.icon = popoutIcon
	popoutButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	popoutButton:SetScript("OnClick", function()
		coolstats.ToggleStatPopout(row)
	end)
	popoutButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Pop Out Stat", 1, 0.82, 0.16)
		GameTooltip:AddLine("Create or close a draggable mini window for this stat.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	popoutButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row.popoutButton = popoutButton

	ui.rows[#ui.rows + 1] = row
	if not row.isFavoriteClone then
		ui.rowByKey[row.configKey] = row
	end
	section.rows[#section.rows + 1] = row
	return row
end

function coolstats.BuildFavoriteRows()
	if not ui.favoriteSection or ui.favoriteRowsBuilt then
		return
	end

	ui.favoriteRowsBuilt = true
	local sourceRows = {}
	for index = 1, #ui.rows do
		local row = ui.rows[index]
		if row and not row.isFavoriteClone then
			sourceRows[#sourceRows + 1] = row
		end
	end

	for index = 1, #sourceRows do
		local source = sourceRows[index]
		local legacyPopoutKey = "favorites." .. source.configKey
		if db and db.statPopouts and type(db.statPopouts[legacyPopoutKey]) == "table" then
			if type(db.statPopouts[source.configKey]) ~= "table" then
				db.statPopouts[source.configKey] = db.statPopouts[legacyPopoutKey]
			end
			db.statPopouts[legacyPopoutKey] = nil
		end
		CreateStatRow(ui.favoriteSection, ui.favoriteSection, {
			label = source.defaultLabel,
			key = "favorite_" .. ConfigKey(source.configKey),
			configKey = "favorites." .. source.configKey,
			get = source.get,
			tooltip = source.customTooltip,
			nativeKey = source.nativeKey,
			nativeSetter = source.nativeSetter,
			nativeArg = source.nativeArg,
			nativeHandler = source.nativeHandler,
			centered = source.centered,
			fontSize = source.fontSize,
			favoriteClone = true,
			favoriteSourceKey = source.configKey,
		}, -ui.favoriteSection.headerHeight - ((index - 1) * PANEL_ROW_HEIGHT), index, 0)
	end
end

local function CreateSection(parent, sectionData, yOffset, sectionIndex)
	local headerHeight = 25
	local height = headerHeight + (#sectionData.rows * PANEL_ROW_HEIGHT) + 5
	local section = CreateFrame("Frame", nil, parent)
	SetSize(section, PANEL_CONTENT_WIDTH, height)
	section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
	section.configKey = ConfigKey(sectionData.key or sectionData.title)
	section.rows = {}
	section.headerHeight = headerHeight
	section.isFavorites = sectionData.favoriteSection == true

	local header = CreateFrame("Button", nil, section)
	SetSize(header, SECTION_HEADER_WIDTH, 18)
	header:SetPoint("TOP", section, "TOP", 0, -1)
	header:RegisterForClicks("LeftButtonUp")
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnClick", function()
		if coolstats.IsSectionDragClickSuppressed(section) then
			return
		end
		ToggleSectionCollapsed(section)
	end)
	header:SetScript("OnDragStart", function()
		coolstats.StartSectionDrag(section)
	end)
	header:SetScript("OnDragStop", function()
		coolstats.StopSectionDrag(section)
	end)
	header:SetScript("OnMouseUp", function()
		coolstats.StopSectionDrag(section)
	end)
	header:SetScript("OnEnter", function(self)
		if not (db and db.editMode) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(sectionData.title, 1, 0.82, 0.16)
		GameTooltip:AddLine("Drag to reorder this section.", 0.86, 0.86, 0.78, true)
		GameTooltip:AddLine("Click to choose whether it opens collapsed when locked.", 0.62, 0.78, 1.0, true)
		GameTooltip:Show()
	end)
	header:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local right = header:CreateTexture(nil, "ARTWORK")
	right:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
	SetSize(right, 37, 18)
	right:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	right:SetTexCoord(0, 0.14453125, 0.296875, 0.578125)

	local left = header:CreateTexture(nil, "ARTWORK")
	left:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
	left:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	left:SetTexCoord(0, 1, 0, 0.28125)

	local expandIcon = header:CreateTexture(nil, "OVERLAY")
	expandIcon:SetTexture("Interface\\Buttons\\UI-PlusMinus-Buttons")
	SetSize(expandIcon, 7, 7)
	expandIcon:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	expandIcon:SetTexCoord(0.5625, 1, 0, 0.4375)
	section.expandIcon = expandIcon

	header:SetHighlightTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton", "ADD")
	local highlight = header:GetHighlightTexture()
	if highlight then
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", header, "TOPLEFT", 3, -2)
		highlight:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -3, 2)
		highlight:SetTexCoord(0, 1, 0.609375, 0.796875)
	end

	local targetHighlight = header:CreateTexture(nil, "OVERLAY")
	targetHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")
	targetHighlight:SetPoint("TOPLEFT", header, "TOPLEFT", 3, -2)
	targetHighlight:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -3, 2)
	targetHighlight:SetVertexColor(1.0, 0.82, 0.16, 0.18)
	targetHighlight:Hide()
	section.targetHighlight = targetHighlight

	local title = header:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	SetSize(title, SECTION_HEADER_WIDTH - 32, 16)
	title:SetPoint("CENTER", header, "CENTER", -4, 0)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("MIDDLE")
	title:SetText(sectionData.title)
	title:SetTextColor(1, 0.82, 0)
	title:SetShadowOffset(1, -1)
	title:SetShadowColor(0, 0, 0, 1)

	local check = CreateFrame("CheckButton", "coolstatsSectionCheck" .. sectionIndex, header, "UICheckButtonTemplate")
	SetSize(check, 20, 20)
	check:SetPoint("LEFT", header, "LEFT", 1, 0)
	check:SetFrameLevel(header:GetFrameLevel() + 3)
	check:Hide()
	check:SetScript("OnClick", function(self)
		SetSectionEnabled(section, self:GetChecked())
		QueueUpdate()
	end)
	section.check = check
	section.header = header
	section.title = title

	for index = 1, #sectionData.rows do
		CreateStatRow(section, section, sectionData.rows[index], -headerHeight - ((index - 1) * PANEL_ROW_HEIGHT), index, sectionIndex)
	end

	ui.sections[#ui.sections + 1] = section
	return section, height
end

local function SectionHasVisibleRows(section)
	for index = 1, #section.rows do
		if IsRowEnabled(section.rows[index]) then
			return true
		end
	end
	return false
end

local HideScrollFrameChrome

function coolstats.LayoutSections()
	if not ui.content then
		return
	end

	local editMode = db and db.editMode
	local popoutMode = db and db.popoutMode and not editMode
	local favoriteMode = db and db.favoriteMode and not editMode and not popoutMode
	local rowControlMode = editMode or popoutMode or favoriteMode
	local compactDrag = ui.dragSection ~= nil
	local y = 0
	local stripeIndex = 0
	for index = 1, #ui.sections do
		local section = ui.sections[index]
		local sectionEnabled = IsSectionEnabled(section)
		local sectionCollapsed = IsSectionCollapsed(section)
		local rowsCollapsed = compactDrag or (sectionCollapsed and not editMode and not favoriteMode)
		local showSection
		if section.isFavorites then
			showSection = coolstats.HasFavoriteRows()
			sectionEnabled = true
			rowsCollapsed = compactDrag or (sectionCollapsed and not editMode and not favoriteMode)
		else
			showSection = editMode or favoriteMode or (sectionEnabled and SectionHasVisibleRows(section))
		end
		SetVisible(section, showSection)
		SetVisible(section.check, editMode and not section.isFavorites)
		SetVisible(section.targetHighlight, ui.dragTargetSection == section)
		if section.check then
			section.check:SetChecked(sectionEnabled)
		end
		if section.expandIcon then
			if sectionCollapsed then
				section.expandIcon:SetTexCoord(0, 0.4375, 0, 0.4375)
			else
				section.expandIcon:SetTexCoord(0.5625, 1, 0, 0.4375)
			end
		end
		if showSection then
			section:ClearAllPoints()
			section:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, y)
			local sectionAlpha = ((editMode or favoriteMode) and not sectionEnabled) and 0.55 or 1
			if ui.dragSection == section then
				sectionAlpha = min(sectionAlpha, 0.68)
				section:SetFrameLevel((ui.content:GetFrameLevel() or 0) + 20)
			end
			section:SetAlpha(sectionAlpha)

			local rowY = -section.headerHeight
			local visibleRows = 0
			for rowIndex = 1, #section.rows do
				local row = section.rows[rowIndex]
				local rowEnabled = IsRowEnabled(row)
				local showRow
				if section.isFavorites then
					rowEnabled = true
					showRow = not compactDrag and coolstats.IsRowFavorited(row) and not rowsCollapsed
				else
					showRow = not compactDrag and (editMode or favoriteMode or (sectionEnabled and rowEnabled and not rowsCollapsed))
				end
				SetVisible(row, showRow)
				SetVisible(row.check, editMode and not section.isFavorites)
				SetVisible(row.favoriteButton, favoriteMode and showRow)
				SetVisible(row.popoutButton, popoutMode and showRow)
				if row.check then
					row.check:SetChecked(rowEnabled)
				end
				coolstats.UpdateFavoriteButton(row)
				coolstats.UpdateStatPopoutButton(row)
				if showRow then
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", section, "TOPLEFT", 4, rowY)
					row:SetAlpha(((editMode or favoriteMode) and (not sectionEnabled or not rowEnabled)) and 0.48 or 1)
					stripeIndex = stripeIndex + 1
					if (stripeIndex % 2) == 0 then
						row.bg:SetVertexColor(0.28, 0.27, 0.25, 0.26)
					else
						row.bg:SetVertexColor(0.05, 0.06, 0.07, 0.10)
					end
					row.label:ClearAllPoints()
					row.value:ClearAllPoints()
					local rowHasControl = rowControlMode and not (section.isFavorites and editMode)
					if row.centered then
						row.label:Hide()
						row.value:SetPoint("CENTER", row, "CENTER", rowHasControl and 8 or 0, 0)
						row.value:SetWidth(PANEL_ROW_WIDTH - (rowHasControl and 28 or 8))
						row.value:SetJustifyH("CENTER")
					else
						row.label:Show()
						if rowHasControl then
							row.label:SetPoint("LEFT", row, "LEFT", 17, 0)
							row.label:SetWidth(PANEL_LABEL_WIDTH - 17)
						else
							row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
							row.label:SetWidth(PANEL_LABEL_WIDTH)
						end
						row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
						row.value:SetWidth(PANEL_VALUE_WIDTH)
						row.value:SetJustifyH("RIGHT")
					end
					rowY = rowY - PANEL_ROW_HEIGHT
					visibleRows = visibleRows + 1
				end
			end

			local height = section.headerHeight + (visibleRows * PANEL_ROW_HEIGHT) + (visibleRows > 0 and 5 or 1)
			SetSize(section, PANEL_CONTENT_WIDTH, height)
			y = y - height - 4
		end
	end

	local panelHeight = ui.panel and ui.panel:GetHeight() or coolstats.GetPanelHeight()
	ui.content:SetHeight(max(-y + 4, panelHeight - 92))
	if ui.scrollFrame then
		local maxScroll = max(0, ui.content:GetHeight() - ui.scrollFrame:GetHeight())
		if ui.scrollFrame:GetVerticalScroll() > maxScroll then
			ui.scrollFrame:SetVerticalScroll(maxScroll)
		end
		HideScrollFrameChrome(ui.scrollFrame)
	end
end

local function SetToggleButtonTextures(button, expanded)
	if not button then
		return
	end
	local direction = expanded and "PrevPage" or "NextPage"
	button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "-Up")
	button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "-Down")
	button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "-Disabled")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end

local function CreateToggleButton()
	if ui.toggleButton or not PaperDollFrame then
		return
	end

	local button = CreateFrame("Button", "coolstatsButton", PaperDollFrame)
	ui.toggleButton = button
	SetSize(button, 32, 32)
	button:SetPoint("BOTTOMRIGHT", PaperDollFrame, "BOTTOMRIGHT", -38, 80)
	button:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 6)
	SetToggleButtonTextures(button, db and db.showStatsPanel)
	button:SetScript("OnClick", function()
		if not db then
			return
		end
		db.showStatsPanel = not db.showStatsPanel
		if PlaySound then
			PlaySound("igCharacterInfoTab")
		end
		QueueUpdate()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if db and db.showStatsPanel then
			GameTooltip:SetText("Hide Stats", 1, 0.82, 0.16)
		else
			GameTooltip:SetText("Show Stats", 1, 0.82, 0.16)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function HideScrollFrameChrome(scrollFrame)
	if not scrollFrame or not scrollFrame.GetName then
		return
	end

	local name = scrollFrame:GetName()
	local scrollBar = _G[name .. "ScrollBar"]
	SetVisible(scrollBar, false)
	SetVisible(_G[name .. "ScrollBarScrollUpButton"], false)
	SetVisible(_G[name .. "ScrollBarScrollDownButton"], false)
	SetVisible(_G[name .. "ScrollBarThumbTexture"], false)
	SetVisible(_G[name .. "Top"], false)
	SetVisible(_G[name .. "Bottom"], false)

	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		if not ui.content then
			return
		end
		local maxScroll = max(0, ui.content:GetHeight() - self:GetHeight())
		if maxScroll <= 0 then
			self:SetVerticalScroll(0)
			return
		end
		local offset = self:GetVerticalScroll() - (delta * 28)
		offset = max(0, min(maxScroll, offset))
		self:SetVerticalScroll(offset)
		local bar = _G[self:GetName() .. "ScrollBar"]
		if bar and bar.SetValue then
			bar:SetValue(offset)
		end
	end)
end

function coolstats.CreateEditModeBanner(panel)
	if ui.editModeBanner or not panel then
		return
	end

	local banner = CreateFrame("Frame", "coolstatsEditModeBanner", panel)
	ui.editModeBanner = banner
	SetSize(banner, PANEL_WIDTH - 156, 18)
	banner:SetPoint("TOP", panel, "TOP", 0, -7)
	banner:SetFrameLevel(panel:GetFrameLevel() + 7)

	local fill = banner:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	fill:SetAllPoints(banner)
	fill:SetVertexColor(1.0, 0.82, 0.16, 0.08)

	local topLine = banner:CreateTexture(nil, "ARTWORK")
	topLine:SetTexture("Interface\\Buttons\\WHITE8X8")
	topLine:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
	topLine:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 0, 0)
	topLine:SetHeight(2)
	topLine:SetVertexColor(1.0, 0.82, 0.16, 0.9)

	local bottomLine = banner:CreateTexture(nil, "ARTWORK")
	bottomLine:SetTexture("Interface\\Buttons\\WHITE8X8")
	bottomLine:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
	bottomLine:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
	bottomLine:SetHeight(1)
	bottomLine:SetVertexColor(1.0, 0.82, 0.16, 0.45)

	local leftLine = banner:CreateTexture(nil, "ARTWORK")
	leftLine:SetTexture("Interface\\Buttons\\WHITE8X8")
	leftLine:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
	leftLine:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
	leftLine:SetWidth(1)
	leftLine:SetVertexColor(1.0, 0.82, 0.16, 0.45)

	local rightLine = banner:CreateTexture(nil, "ARTWORK")
	rightLine:SetTexture("Interface\\Buttons\\WHITE8X8")
	rightLine:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 0, 0)
	rightLine:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
	rightLine:SetWidth(1)
	rightLine:SetVertexColor(1.0, 0.82, 0.16, 0.45)

	local text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("CENTER", banner, "CENTER", 0, -3)
	text:SetText("Editing layout")
	text:SetTextColor(1.0, 0.82, 0.16)
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	banner.text = text
	banner:Hide()
end

function coolstats.UpdateEditModeBanner()
	local visible = ui.panel and ui.panel:IsShown() and db and (db.editMode or db.favoriteMode)
	SetVisible(ui.editModeBanner, visible)
	if visible and ui.editModeBanner and ui.editModeBanner.text then
		if db.favoriteMode then
			ui.editModeBanner.text:SetText("Edit Favorites")
		else
			ui.editModeBanner.text:SetText("Editing layout")
		end
	end
end

function coolstats.UpdateFavoriteModeButton()
	if not ui.favoriteModeButton then
		return
	end
	SetVisible(ui.favoriteModeButton, ui.panel and ui.panel:IsShown())
	if ui.favoriteModeButton.icon then
		if db and db.favoriteMode then
			ui.favoriteModeButton.icon:SetVertexColor(1.0, 0.82, 0.16, 1)
		else
			ui.favoriteModeButton.icon:SetVertexColor(0.72, 0.72, 0.72, 0.85)
		end
	end
end

function coolstats.UpdateResetPanelButton()
	SetVisible(ui.resetPanelButton, ui.panel and ui.panel:IsShown())
end

function coolstats.UpdateSettingsPanelButton()
	SetVisible(ui.settingsPanelButton, ui.panel and ui.panel:IsShown())
end

function coolstats.CreateFavoriteModeButton(panel)
	if ui.favoriteModeButton or not panel then
		return
	end

	local button = CreateFrame("Button", "coolstatsFavoriteModeButton", panel)
	ui.favoriteModeButton = button
	SetSize(button, 18, 18)
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -8)
	button:SetFrameLevel(panel:GetFrameLevel() + 8)
	button:SetScript("OnClick", function()
		if not db then
			return
		end
		db.favoriteMode = not db.favoriteMode
		if db.favoriteMode then
			db.editMode = false
			db.popoutMode = false
		end
		QueueUpdate()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if db and db.favoriteMode then
			GameTooltip:SetText("Picking Favourites", 1, 0.82, 0.16)
			GameTooltip:AddLine("Click stat stars to add or remove favourites.", 0.86, 0.86, 0.78, true)
		else
			GameTooltip:SetText("Favourites", 1, 0.82, 0.16)
			GameTooltip:AddLine("Click to choose favourite stats.", 0.86, 0.86, 0.78, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	SetSize(icon, 15, 15)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
end

function coolstats.CreateResetPanelButton(panel)
	if ui.resetPanelButton or not panel then
		return
	end

	local button = CreateFrame("Button", "coolstatsResetPanelButton", panel)
	ui.resetPanelButton = button
	SetSize(button, 18, 18)
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", 35, -8)
	button:SetFrameLevel(panel:GetFrameLevel() + 8)
	button:SetScript("OnClick", function()
		GameTooltip:Hide()
		coolstats.ShowResetPanelConfirm()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Reset Panel", 1, 0.82, 0.16)
		GameTooltip:AddLine("Reset the character panel to defaults.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
	SetSize(icon, 15, 15)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
end

function coolstats.CreateSettingsPanelButton(panel)
	if ui.settingsPanelButton or not panel then
		return
	end

	local button = CreateFrame("Button", "coolstatsSettingsPanelButton", panel)
	ui.settingsPanelButton = button
	SetSize(button, 18, 18)
	button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -57, -8)
	button:SetFrameLevel(panel:GetFrameLevel() + 8)
	button:SetScript("OnClick", function()
		GameTooltip:Hide()
		coolstats.OpenSettingsFromMinimap()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Settings", 1, 0.82, 0.16)
		GameTooltip:AddLine("Open coolstats settings.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
	SetSize(icon, 15, 15)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
end

local function CreateEditButton(panel)
	if ui.editButton then
		return
	end

	local button = CreateFrame("Button", "coolstatsEditButton", panel)
	ui.editButton = button
	SetSize(button, 18, 18)
	button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -13, -8)
	button:SetFrameLevel(panel:GetFrameLevel() + 8)
	button:SetScript("OnClick", function()
		if not db then
			return
		end
		db.editMode = not db.editMode
		if db.editMode then
			db.popoutMode = false
			db.favoriteMode = false
		end
		QueueUpdate()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if db and db.editMode then
			GameTooltip:SetText("Editing", 1, 0.82, 0.16)
			GameTooltip:AddLine("Click to lock the stat layout.", 0.86, 0.86, 0.78, true)
		else
			GameTooltip:SetText("Locked", 1, 0.82, 0.16)
			GameTooltip:AddLine("Click to edit visible sections, rows, and section order.", 0.86, 0.86, 0.78, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
	SetSize(icon, 14, 14)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
end

function coolstats.FormatPercentSliderValue(value)
	return tostring(floor((value or 0) + 0.5)) .. "%"
end

function coolstats.FormatNumberSliderValue(value)
	return tostring(floor((value or 0) + 0.5))
end

function coolstats.FormatFontSliderValue(value)
	local index = max(1, min(#STAT_POPOUT_FONTS, floor((value or 1) + 0.5)))
	return STAT_POPOUT_FONTS[index].name
end

function coolstats.UpdatePopoutOptionSliderText(slider)
	if not slider or not slider.labelText then
		return
	end
	local value = slider:GetValue()
	local text = slider.formatter and slider.formatter(value) or tostring(value)
	slider.labelText:SetText(slider.label .. ": " .. text)
end

function coolstats.CreatePopoutOptionSlider(parent, key, label, yOffset, minValue, maxValue, step, formatter, setter)
	local sliderName = "coolstatsPopout" .. key .. "Slider"
	local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
	SetSize(slider, 168, 16)
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -yOffset)
	slider:SetMinMaxValues(minValue, maxValue)
	if slider.SetValueStep then
		slider:SetValueStep(step)
	end
	slider.label = label
	slider.step = step
	slider.formatter = formatter
	slider.setter = setter

	local templateText = _G[sliderName .. "Text"]
	if templateText then
		templateText:SetText("")
	end
	local low = _G[sliderName .. "Low"]
	if low then
		low:SetText(formatter(minValue))
	end
	local high = _G[sliderName .. "High"]
	if high then
		high:SetText(formatter(maxValue))
	end

	local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
	labelText:SetWidth(176)
	labelText:SetJustifyH("LEFT")
	labelText:SetTextColor(1.0, 0.82, 0.16)
	slider.labelText = labelText

	slider:SetScript("OnValueChanged", function(self, value)
		if self.settingValue then
			return
		end
		local adjusted = value
		if self.step and self.step > 0 then
			adjusted = floor((value / self.step) + 0.5) * self.step
		end
		adjusted = max(minValue, min(maxValue, adjusted))
		if abs(adjusted - value) > 0.001 then
			self.settingValue = true
			self:SetValue(adjusted)
			self.settingValue = false
		end
		self.setter(adjusted)
		coolstats.UpdatePopoutOptionSliderText(self)
		coolstats.ApplyStatPopoutOptionsToAll()
		if ui.popoutOptionsMenu and ui.popoutOptionsMenu.SetBackdropColor then
			ui.popoutOptionsMenu:SetBackdropColor(0.02, 0.018, 0.014, coolstats.GetPopoutAlpha())
		end
	end)

	return slider
end

function coolstats.SetPopoutOptionSliderValue(slider, value)
	if not slider then
		return
	end
	slider.settingValue = true
	slider:SetValue(value)
	slider.settingValue = false
	coolstats.UpdatePopoutOptionSliderText(slider)
end

function coolstats.CreatePopoutOptionCheckbox(parent, label, yOffset, getter, setter, tooltipText)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	SetSize(check, 18, 18)
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -yOffset)
	check.getter = getter
	check.setter = setter

	local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", check, "RIGHT", 0, 0)
	text:SetWidth(150)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	text:SetTextColor(0.86, 0.86, 0.78)
	check.text = text

	check:SetScript("OnClick", function(self)
		local checked = self:GetChecked() == 1 or self:GetChecked() == true
		self.setter(checked)
		coolstats.ApplyStatPopoutOptionsToAll()
	end)
	check:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, 1, 0.82, 0.16)
		GameTooltip:AddLine(tooltipText or "Toggle this popout setting.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	check:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return check
end

function coolstats.UpdatePopoutOptionCheckbox(checkbox)
	if checkbox and checkbox.getter then
		checkbox:SetChecked(checkbox.getter())
	end
end

function coolstats.UpdatePopoutOptionsMenuControls()
	local menu = ui.popoutOptionsMenu
	if not menu then
		return
	end
	local options = coolstats.GetPopoutOptions()
	if menu.SetBackdropColor then
		menu:SetBackdropColor(0.02, 0.018, 0.014, coolstats.GetPopoutAlpha())
	end
	coolstats.SetPopoutOptionSliderValue(menu.alphaSlider, (options.alpha or defaults.popoutOptions.alpha) * 100)
	coolstats.SetPopoutOptionSliderValue(menu.fontSlider, options.fontIndex or defaults.popoutOptions.fontIndex)
	coolstats.SetPopoutOptionSliderValue(menu.fontScaleSlider, (options.fontScale or defaults.popoutOptions.fontScale) * 100)
	coolstats.SetPopoutOptionSliderValue(menu.snapSlider, options.snapDistance or STAT_POPOUT_SNAP_DISTANCE)
	coolstats.UpdatePopoutOptionCheckbox(menu.headerCheckbox)
	coolstats.UpdatePopoutOptionCheckbox(menu.syncSizeCheckbox)
end

function coolstats.PositionPopoutOptionsMenu(menu, panel)
	if not menu or not panel then
		return
	end

	menu:ClearAllPoints()
	local gap = 6
	local parentWidth = UIParent and UIParent:GetWidth() or 1024
	local parentHeight = UIParent and UIParent:GetHeight() or 768
	local menuWidth = menu:GetWidth() or 208
	local menuHeight = menu:GetHeight() or 188
	local panelRight = panel:GetRight()
	local panelTop = panel:GetTop()

	if panelRight and panelTop then
		local left = panelRight + gap
		if left + menuWidth + gap > parentWidth then
			left = max(gap, parentWidth - menuWidth - gap)
		end
		local top = max(menuHeight + gap, min(parentHeight - gap, panelTop - 2))
		menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	else
		menu:SetPoint("TOPLEFT", panel, "TOPRIGHT", gap, -2)
	end
end

function coolstats.CreatePopoutOptionsMenu(panel)
	if ui.popoutOptionsMenu or not panel then
		return ui.popoutOptionsMenu
	end

	local menu = CreateFrame("Frame", "coolstatsPopoutOptionsMenu", panel)
	ui.popoutOptionsMenu = menu
	SetSize(menu, 208, 254)
	coolstats.PositionPopoutOptionsMenu(menu, panel)
	menu:SetFrameLevel(panel:GetFrameLevel() + 10)
	menu:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 14,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	menu:SetBackdropColor(0.02, 0.018, 0.014, 0.96)
	menu:SetBackdropBorderColor(0.55, 0.52, 0.48, 1)

	local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", menu, "TOP", 0, -10)
	title:SetText("Popout Settings")
	title:SetTextColor(1.0, 0.82, 0.16)
	menu.title = title

	menu.alphaSlider = coolstats.CreatePopoutOptionSlider(menu, "Alpha", "Background", 48, 15, 100, 5, coolstats.FormatPercentSliderValue, function(value)
		coolstats.GetPopoutOptions().alpha = value / 100
	end)
	menu.fontSlider = coolstats.CreatePopoutOptionSlider(menu, "Font", "Font", 88, 1, #STAT_POPOUT_FONTS, 1, coolstats.FormatFontSliderValue, function(value)
		coolstats.GetPopoutOptions().fontIndex = max(1, min(#STAT_POPOUT_FONTS, floor(value + 0.5)))
	end)
	menu.fontScaleSlider = coolstats.CreatePopoutOptionSlider(menu, "FontScale", "Font Scale", 128, 75, 180, 5, coolstats.FormatPercentSliderValue, function(value)
		coolstats.GetPopoutOptions().fontScale = value / 100
	end)
	menu.snapSlider = coolstats.CreatePopoutOptionSlider(menu, "Snap", "Magnet", 168, 0, 30, 1, coolstats.FormatNumberSliderValue, function(value)
		coolstats.GetPopoutOptions().snapDistance = floor(value + 0.5)
	end)
	menu.headerCheckbox = coolstats.CreatePopoutOptionCheckbox(menu, "Show popout headers", 202, coolstats.GetPopoutShowHeader, function(checked)
		coolstats.GetPopoutOptions().showHeader = checked == true
	end, "Show or hide the small label above each popped out stat.")
	menu.syncSizeCheckbox = coolstats.CreatePopoutOptionCheckbox(menu, "Sync popout sizes", 226, coolstats.GetPopoutSyncSize, function(checked)
		coolstats.SetPopoutSyncSize(checked)
	end, "Keep each snapped popout group at one shared width and height. Resizing one updates that group only.")

	menu:Hide()
	coolstats.UpdatePopoutOptionsMenuControls()
	return menu
end

function coolstats.UpdatePopoutOptionsMenuVisibility()
	local menu = ui.popoutOptionsMenu
	if not menu then
		return
	end
	local shown = db and db.popoutMode and ui.panel and ui.panel:IsShown()
	SetVisible(menu, shown)
	if shown then
		coolstats.PositionPopoutOptionsMenu(menu, ui.panel)
		coolstats.UpdatePopoutOptionsMenuControls()
	end
end

local function CreatePopoutModeButton(panel)
	if ui.popoutModeButton then
		return
	end

	local button = CreateFrame("Button", "coolstatsPopoutModeButton", panel)
	ui.popoutModeButton = button
	SetSize(button, 18, 18)
	button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -35, -8)
	button:SetFrameLevel(panel:GetFrameLevel() + 8)
	button:SetScript("OnClick", function()
		if not db then
			return
		end
		db.popoutMode = not db.popoutMode
		if db.popoutMode then
			db.editMode = false
			db.favoriteMode = false
		end
		coolstats.CreatePopoutOptionsMenu(panel)
		QueueUpdate()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if db and db.popoutMode then
			GameTooltip:SetText("Popout Mode", 1, 0.82, 0.16)
			GameTooltip:AddLine("Click to stop choosing stats to pop out.", 0.86, 0.86, 0.78, true)
		else
			GameTooltip:SetText("Popout Mode", 1, 0.82, 0.16)
			GameTooltip:AddLine("Click to choose stats for draggable mini windows.", 0.86, 0.86, 0.78, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
	SetSize(icon, 13, 13)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
end

local function GetAppearanceToggleValue(kind)
	local getter
	if kind == "helm" then
		getter = ShowingHelm
	elseif kind == "cloak" then
		getter = ShowingCloak
	end
	if type(getter) ~= "function" then
		return nil
	end
	local value = getter()
	return value == true or value == 1 or value == "1"
end

local function SetAppearanceToggleValue(kind, shown)
	local setter
	if kind == "helm" then
		setter = ShowHelm
	elseif kind == "cloak" then
		setter = ShowCloak
	end
	if type(setter) ~= "function" then
		return false
	end
	pcall(setter, shown == true)
	return true
end

local function UpdateAppearanceToggles()
	if not ui.appearanceToggles then
		return
	end

	local shown = ui.panel and ui.panel:IsShown()
	local anyVisible = false
	for index = 1, #ui.appearanceToggles do
		local toggle = ui.appearanceToggles[index]
		local value = GetAppearanceToggleValue(toggle.kind)
		local toggleShown = shown and value ~= nil
		SetVisible(toggle, toggleShown)
		if toggleShown then
			anyVisible = true
		end
		if value ~= nil then
			toggle:SetChecked(value)
		end
	end
	SetVisible(ui.appearanceBar, anyVisible)
end

local function CreateAppearanceToggle(parent, kind, label, xOffset)
	local name = "coolstats" .. label .. "Toggle"
	local toggle = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	SetSize(toggle, 18, 18)
	toggle:SetPoint("LEFT", parent, "LEFT", xOffset, -1)
	toggle:SetFrameLevel(parent:GetFrameLevel() + 1)
	toggle.kind = kind

	local text = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", toggle, "RIGHT", -1, 0)
	text:SetWidth(38)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	text:SetTextColor(0.86, 0.86, 0.78)
	toggle.text = text

	toggle:SetScript("OnClick", function(self)
		local checked = self:GetChecked() == 1 or self:GetChecked() == true
		if not SetAppearanceToggleValue(self.kind, checked) then
			self:SetChecked(not checked)
		end
	end)
	toggle:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Show " .. label, 1, 0.82, 0.16)
		GameTooltip:AddLine("Toggle " .. string.lower(label) .. " visibility on your character model.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	toggle:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	ui.appearanceToggles[#ui.appearanceToggles + 1] = toggle
	return toggle
end

local function CreateAppearanceToggles(panel)
	if ui.showHelmToggle or not panel then
		return
	end

	local bar = CreateFrame("Frame", "coolstatsAppearanceBar", panel)
	ui.appearanceBar = bar
	SetSize(bar, PANEL_CONTENT_WIDTH, PANEL_APPEARANCE_HEIGHT)
	bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -PANEL_APPEARANCE_TOP)
	bar:SetFrameLevel(panel:GetFrameLevel() + 7)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetAllPoints(bar)
	bg:SetVertexColor(0.05, 0.045, 0.04, 0.55)

	local topLine = bar:CreateTexture(nil, "ARTWORK")
	topLine:SetTexture("Interface\\Buttons\\WHITE8X8")
	topLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	topLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
	topLine:SetHeight(1)
	topLine:SetVertexColor(0.55, 0.48, 0.28, 0.45)

	local bottomLine = bar:CreateTexture(nil, "ARTWORK")
	bottomLine:SetTexture("Interface\\Buttons\\WHITE8X8")
	bottomLine:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
	bottomLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
	bottomLine:SetHeight(1)
	bottomLine:SetVertexColor(0.00, 0.00, 0.00, 0.55)

	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("LEFT", bar, "LEFT", 8, 0)
	title:SetWidth(76)
	title:SetJustifyH("LEFT")
	title:SetText("Appearance")
	title:SetTextColor(1.0, 0.82, 0.16)
	bar.title = title

	ui.showHelmToggle = CreateAppearanceToggle(bar, "helm", "Helm", 88)
	ui.showCloakToggle = CreateAppearanceToggle(bar, "cloak", "Cloak", 148)
end

local function CreatePanel()
	if ui.panel or not CharacterFrame then
		return
	end

	local parent = CharacterFrame
	local panel = CreateFrame("Frame", "coolstatsPanel", parent)
	ui.panel = panel
	SetSize(panel, PANEL_WIDTH, coolstats.GetPanelHeight())
	panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", PANEL_ANCHOR_X, PANEL_ANCHOR_Y)
	panel:SetFrameStrata(CharacterFrame:GetFrameStrata())
	panel:SetFrameLevel(parent:GetFrameLevel() + 5)
	if panel.SetToplevel then
		panel:SetToplevel(true)
	end
	CreateStatsDrawerBackground(panel)
	CreateToggleButton()
	coolstats.CreateFavoriteModeButton(panel)
	coolstats.CreateResetPanelButton(panel)
	coolstats.CreateSettingsPanelButton(panel)
	CreateEditButton(panel)
	coolstats.CreateEditModeBanner(panel)
	CreatePopoutModeButton(panel)
	coolstats.CreatePopoutOptionsMenu(panel)
	CreateAppearanceToggles(panel)

	local scrollFrame = CreateFrame("ScrollFrame", "coolstatsScrollFrame", panel)
	scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -PANEL_SCROLL_TOP)
	scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -11, 15)
	HideScrollFrameChrome(scrollFrame)
	ui.scrollFrame = scrollFrame

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(PANEL_CONTENT_WIDTH)
	content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
	scrollFrame:SetScrollChild(content)
	ui.content = content

	local y = 0
	for index = 1, #statSections do
		local _, height = CreateSection(content, statSections[index], y, index)
		y = y - height - 5
	end
	local favoriteSection = CreateSection(content, { title = "Favourites", key = "favorites", rows = {}, favoriteSection = true }, y, 0)
	ui.favoriteSection = favoriteSection
	table.remove(ui.sections, #ui.sections)
	table.insert(ui.sections, 1, favoriteSection)
	coolstats.BuildFavoriteRows()
	coolstats.ApplySavedSectionOrder()
	content:SetHeight(-y + 4)
	coolstats.LayoutSections()
end

local function AnchorPanel()
	if not ui.panel or not CharacterFrame then
		return
	end
	local parent = CharacterFrame
	if ui.panel:GetParent() ~= parent then
		ui.panel:SetParent(parent)
	end
	ui.panel:ClearAllPoints()
	ui.panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", PANEL_ANCHOR_X, PANEL_ANCHOR_Y)
	SetSize(ui.panel, PANEL_WIDTH, coolstats.GetPanelHeight())
	ui.panel:SetFrameStrata(CharacterFrame:GetFrameStrata())
	ui.panel:SetFrameLevel(parent:GetFrameLevel() + 5)
	CreateToggleButton()
	coolstats.CreateFavoriteModeButton(ui.panel)
	coolstats.CreateResetPanelButton(ui.panel)
	coolstats.CreateSettingsPanelButton(ui.panel)
	coolstats.CreateEditModeBanner(ui.panel)
	CreateAppearanceToggles(ui.panel)
	CreatePopoutModeButton(ui.panel)
	coolstats.CreatePopoutOptionsMenu(ui.panel)
end

function coolstats.GetItemLevelBadgePosition()
	local options = coolstats.GetItemLevelBadgeOptions()
	local position = options.position or defaults.itemLevelBadges.position
	if not coolstats.GetItemLevelBadgePositionInfo(position) then
		position = defaults.itemLevelBadges.position
	end
	return position
end

function coolstats.GetItemLevelBadgeFontSize(position)
	local options = coolstats.GetItemLevelBadgeOptions()
	local fontSize = max(0, min(30, tonumber(options.fontSize) or coolstats.ITEM_LEVEL_BADGE_DEFAULT_FONT_SIZE))
	if position == "lowerLeft" or position == "lowerRight" then
		fontSize = floor((fontSize * 0.5) + 0.5)
	end
	return fontSize
end

function coolstats.ApplyItemLevelBadgeAppearance(badge)
	if not badge or not badge.text then
		return "default"
	end

	local button = badge:GetParent()
	local position = coolstats.GetItemLevelBadgePosition()
	local fontSize = coolstats.GetItemLevelBadgeFontSize(position)
	badge:ClearAllPoints()
	badge.text:ClearAllPoints()
	badge.text:SetFont("Fonts\\FRIZQT__.TTF", max(1, fontSize), "OUTLINE")
	badge.text:SetHeight(14)

	if position == "lowerLeft" and button then
		SetSize(badge, 28, 14)
		badge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
		badge.text:SetPoint("LEFT", badge, "LEFT", 0, 0)
		badge.text:SetWidth(28)
		badge.text:SetJustifyH("LEFT")
	elseif position == "lowerRight" and button then
		SetSize(badge, 28, 14)
		badge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		badge.text:SetPoint("RIGHT", badge, "RIGHT", 0, 0)
		badge.text:SetWidth(28)
		badge.text:SetJustifyH("RIGHT")
	else
		SetSize(badge, 42, 20)
		if button then
			badge:SetPoint("CENTER", button, "CENTER", 0, 0)
		end
		badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
		badge.text:SetWidth(42)
		badge.text:SetJustifyH("CENTER")
	end

	return position
end

local function CreateBadgeForButton(groupKey, data)
	local button = _G[data.button]
	if not button or ui.badges[groupKey][data.slot] then
		return
	end

	local badge = CreateFrame("Frame", nil, button)
	ui.badges[groupKey][data.slot] = badge
	SetSize(badge, 42, 20)
	badge:SetPoint("CENTER", button, "CENTER", 0, 0)
	badge:SetFrameLevel(button:GetFrameLevel() + 9)

	local text = badge:CreateFontString(nil, "OVERLAY")
	text:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
	text:SetPoint("CENTER", badge, "CENTER", 0, 0)
	text:SetWidth(42)
	text:SetHeight(20)
	text:SetJustifyH("CENTER")
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetText("")
	badge.text = text

	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	SetSize(glow, 67, 67)
	glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	glow:Hide()
	badge.glow = glow
end

local function CreateBadges()
	for index = 1, #paperDollSlotButtons do
		CreateBadgeForButton("player", paperDollSlotButtons[index])
	end
	for index = 1, #inspectSlotButtons do
		CreateBadgeForButton("inspect", inspectSlotButtons[index])
	end
end

local function CreateInspectSummary()
	if ui.inspectSummary or not InspectFrame then
		return
	end

	local parent = InspectPaperDollFrame or InspectFrame
	local summary = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	if InspectGuildText then
		summary:SetPoint("TOP", InspectGuildText, "BOTTOM", 0, -5)
	elseif InspectTitleText then
		summary:SetPoint("TOP", InspectTitleText, "BOTTOM", 0, -5)
	elseif InspectLevelText then
		summary:SetPoint("TOP", InspectLevelText, "BOTTOM", 0, -14)
	else
		summary:SetPoint("TOP", parent, "TOP", 0, -72)
	end
	summary:SetWidth(230)
	summary:SetJustifyH("CENTER")
	summary:SetText("")
	ui.inspectSummary = summary
end

local function CreateModelScore(key, parent)
	if not parent or ui.modelScores[key] then
		return
	end

	local frame = CreateFrame("Frame", "coolstats" .. key .. "ModelScore", parent)
	SetSize(frame, 134, 30)
	frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 22, 7)
	frame:SetFrameLevel(parent:GetFrameLevel() + 8)

	local gearScore = frame:CreateFontString(nil, "OVERLAY")
	gearScore:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	gearScore:SetPoint("TOP", frame, "TOP", 0, 0)
	gearScore:SetWidth(134)
	gearScore:SetJustifyH("LEFT")
	gearScore:SetShadowOffset(1, -1)
	gearScore:SetShadowColor(0, 0, 0, 1)
	frame.gearScore = gearScore

	local itemLevel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	itemLevel:SetPoint("TOP", gearScore, "BOTTOM", 0, -1)
	itemLevel:SetWidth(134)
	itemLevel:SetJustifyH("LEFT")
	itemLevel:SetShadowOffset(1, -1)
	itemLevel:SetShadowColor(0, 0, 0, 1)
	frame.itemLevel = itemLevel

	ui.modelScores[key] = frame
end

local function CreateModelScores()
	CreateModelScore("Player", CharacterModelFrame)
	CreateModelScore("Inspect", InspectModelFrame)
end

local function UpdateModelScore(key, unit, shown)
	local frame = ui.modelScores[key]
	if not frame then
		return
	end

	SetVisible(frame, shown)
	if not shown or not unit or not UnitExists(unit) then
		return
	end

	local gearScore, averageItemLevel, itemCount = CalculateUnitGear(unit)
	if not itemCount or itemCount <= 0 then
		frame.gearScore:SetText("")
		frame.itemLevel:SetText("")
		return
	end

	local red, green, blue = GetScoreColor(gearScore)
	frame.gearScore:SetText("GS " .. FormatGearScore(gearScore))
	frame.gearScore:SetTextColor(red, green, blue)
	frame.itemLevel:SetText("Item Level " .. FormatItemLevel(averageItemLevel))
	frame.itemLevel:SetTextColor(red, green, blue)
end

local function UpdateModelScores()
	CreateModelScores()
	local playerShown = CharacterFrame and CharacterFrame:IsShown() and (not PaperDollFrame or PaperDollFrame:IsShown())
	UpdateModelScore("Player", "player", playerShown)
	UpdateModelScore("Inspect", GetInspectUnit(), InspectFrame and InspectFrame:IsShown() and InspectModelFrame and InspectModelFrame:IsShown())
end

local function UpdateInspectSummary()
	CreateInspectSummary()
	if not ui.inspectSummary then
		return
	end

	local shown = InspectFrame and InspectFrame:IsShown()
	SetVisible(ui.inspectSummary, shown and not ui.modelScores.Inspect)
	if not shown then
		return
	end

	local unit = GetInspectUnit()
	if not unit or not UnitExists(unit) then
		ui.inspectSummary:SetText("")
		return
	end

	local gearScore, averageItemLevel, itemCount = CalculateUnitGear(unit)
	local red, green, blue = GetScoreColor(gearScore)
	if itemCount and itemCount > 0 then
		ui.inspectSummary:SetText("GS " .. FormatGearScore(gearScore) .. "   Item Level " .. FormatItemLevel(averageItemLevel))
		ui.inspectSummary:SetTextColor(red, green, blue)
	else
		ui.inspectSummary:SetText("")
	end
end

local function HideCharacterPanelRuntime()
	SetVisible(ui.panel, false)
	SetVisible(ui.toggleButton, false)
	SetVisible(ui.editButton, false)
	SetVisible(ui.popoutModeButton, false)
	SetVisible(ui.favoriteModeButton, false)
	SetVisible(ui.resetPanelButton, false)
	SetVisible(ui.settingsPanelButton, false)
	SetVisible(ui.editModeBanner, false)
	SetVisible(ui.popoutOptionsMenu, false)
	SetVisible(ui.inspectSummary, false)

	for _, group in pairs(ui.badges) do
		for _, badge in pairs(group) do
			SetVisible(badge, false)
			if badge and badge.glow then
				badge.glow:Hide()
			end
		end
	end
	for _, frame in pairs(ui.modelScores) do
		SetVisible(frame, false)
	end
	for _, frame in pairs(ui.statPopouts) do
		SetVisible(frame, false)
	end
end

local function PaperDollIsVisible()
	return CharacterFrame and CharacterFrame:IsShown() and (not PaperDollFrame or PaperDollFrame:IsShown())
end

local function UpdateToggleButton()
	if not ui.toggleButton then
		return
	end
	SetVisible(ui.toggleButton, CharacterFrame and CharacterFrame:IsShown() and PaperDollFrame and PaperDollFrame:IsShown())
	SetToggleButtonTextures(ui.toggleButton, db and db.showStatsPanel)
end

local function UpdateEditButton()
	if not ui.editButton then
		return
	end
	SetVisible(ui.editButton, ui.panel and ui.panel:IsShown())
	if db and db.editMode then
		if ui.editButton.icon then
			ui.editButton.icon:SetVertexColor(0.25, 1.00, 0.25, 1)
		end
	else
		if ui.editButton.icon then
			ui.editButton.icon:SetVertexColor(1.00, 0.82, 0.16, 1)
		end
	end
end

local function UpdatePopoutModeButton()
	if not ui.popoutModeButton then
		return
	end
	SetVisible(ui.popoutModeButton, ui.panel and ui.panel:IsShown())
	if ui.popoutModeButton.icon then
		if db and db.popoutMode then
			ui.popoutModeButton.icon:SetVertexColor(0.25, 1.00, 0.25, 1)
		else
			ui.popoutModeButton.icon:SetVertexColor(1.00, 0.82, 0.16, 1)
		end
	end
end

local function UpdatePanelVisibility()
	local parent = ui.panel and ui.panel:GetParent()
	local parentShown = parent and parent:IsShown()
	local shown = db and db.showStatsPanel and PaperDollIsVisible() and parentShown
	if not shown and db then
		if ui.dragSection then
			coolstats.StopSectionDrag(ui.dragSection)
		end
		db.editMode = false
		db.favoriteMode = false
	end
	SetVisible(ui.panel, shown)
end

local function UpdateBadgeGroup(groupKey, unit, buttons, shown)
	for index = 1, #buttons do
		local data = buttons[index]
		local badge = ui.badges[groupKey][data.slot]
		if badge then
			local item = unit and GetSlotItem(unit, data.slot)
			local position = coolstats.ApplyItemLevelBadgeAppearance(badge)
			local hasScoredItem = shown and item and item.itemLevel and item.itemLevel > 0
			local shouldShowLevel = db.showItemLevels and position ~= "off" and hasScoredItem and coolstats.GetItemLevelBadgeFontSize(position) > 0
			if shouldShowLevel then
				badge.text:SetText(FormatItemLevel(item.itemLevel))
				badge.text:SetTextColor(item.red, item.green, item.blue)
				badge:Show()
			else
				badge.text:SetText("")
				badge:Hide()
			end

			if db.showSlotBorders and badge.glow and hasScoredItem and item.score and item.score >= 0 then
				badge.glow:SetVertexColor(item.red, item.green, item.blue, 0.72)
				badge.glow:Show()
			elseif badge.glow then
				badge.glow:Hide()
			end
		end
	end
end

local function UpdateBadges()
	if not db then
		return
	end

	CreateBadges()
	UpdateBadgeGroup("player", "player", paperDollSlotButtons, PaperDollIsVisible())
	UpdateBadgeGroup("inspect", GetInspectUnit(), inspectSlotButtons, InspectFrame and InspectFrame:IsShown())
end

local function UpdatePanel()
	if not ui.panel then
		return
	end

	coolstats.LayoutSections()
	local palette = coolstats.ApplyStatsTextPalette()

	for index = 1, #ui.rows do
		local row = ui.rows[index]
		local value, r, g, b, label = row.get()
		row.label:SetText(label or row.defaultLabel)
		SetFontStringColor(row.label, palette.labelColor)
		row.value:SetText(value or "-")
		if r and g and b then
			row.value:SetTextColor(r, g, b)
		else
			SetFontStringColor(row.value, palette.value)
		end
	end
end

function UpdateStatPopouts()
	if not db then
		return
	end
	EnsureEditOptions()

	for key, settings in pairs(db.statPopouts) do
		local row = ui.rowByKey[key]
		if row and type(settings) == "table" and settings.shown then
			local frame = coolstats.CreateStatPopout(row)
			if frame then
				if not frame:IsShown() then
					coolstats.PositionStatPopout(frame, settings)
					frame:Show()
				end
				coolstats.UpdateStatPopout(frame)
			end
		elseif ui.statPopouts[key] then
			ui.statPopouts[key]:Hide()
		end
	end

	for index = 1, #ui.rows do
		coolstats.UpdateStatPopoutButton(ui.rows[index])
	end
end

local function UpdateAll()
	if not db then
		return
	end
	if not coolstats.IsCharacterPanelEnabled() then
		HideCharacterPanelRuntime()
		return
	end
	HideDefaultCharacterStats()
	AnchorPanel()
	coolstats.ApplyBackgroundOptions()
	UpdateToggleButton()
	UpdatePanelVisibility()
	UpdateEditButton()
	UpdatePopoutModeButton()
	coolstats.UpdateFavoriteModeButton()
	coolstats.UpdateResetPanelButton()
	coolstats.UpdateSettingsPanelButton()
	coolstats.UpdateEditModeBanner()
	coolstats.UpdatePopoutOptionsMenuVisibility()
	UpdateAppearanceToggles()
	UpdatePanel()
	UpdateStatPopouts()
	UpdateBadges()
	UpdateModelScores()
	UpdateInspectSummary()
end

function QueueUpdate()
	if db and not coolstats.IsCharacterPanelEnabled() then
		updatePending = false
		updateElapsed = 0
		HideCharacterPanelRuntime()
		return
	end
	if db and ui.panel then
		updatePending = false
		updateElapsed = 0
		UpdateAll()
		return
	end
	updatePending = true
	updateElapsed = 0
end

local function HideFontString(fontString)
	if fontString then
		fontString:SetText("")
		fontString:Hide()
	end
end

local function TameGearScore()
	if gearScoreTamed then
		return
	end
	if not GS_Settings and not _G.CalculateClasicItemScore and not _G.PersonalGearScore then
		return
	end
	gearScoreTamed = true

	if GS_Settings then
		GS_Settings["Level"] = -1
		GS_Settings["Compare"] = -1
		GS_Settings["Detail"] = -1
		local specScoreOptions = GS_Settings["Show" .. "Spec" .. "Scores"]
		if specScoreOptions and GearScoreClassSpecList then
			for _, specs in pairs(GearScoreClassSpecList) do
				for _, specName in ipairs(specs) do
					specScoreOptions[specName] = 0
				end
			end
		end
	end

	if _G.CalculateClasicItemScore and not coolstats.OriginalCalculateClasicItemScore then
		coolstats.OriginalCalculateClasicItemScore = _G.CalculateClasicItemScore
		_G.CalculateClasicItemScore = function() end
	end
	if _G.CalculateClasicItemScore_two and not coolstats.OriginalCalculateClasicItemScoreTwo then
		coolstats.OriginalCalculateClasicItemScoreTwo = _G.CalculateClasicItemScore_two
		_G.CalculateClasicItemScore_two = function() end
	end

	HideFontString(_G.PersonalGearScore)
	HideFontString(_G.GearScore2)
end

local function CleanTooltip(tooltip)
	if not db or not db.cleanGearScoreTooltips or not tooltip or not tooltip.GetName or not tooltip.NumLines then
		return
	end

	local hiddenScoreTokens = { "Spec" .. "Score", "Custom" .. "Score", "Hunter" .. "Score" }
	local name = tooltip:GetName()
	local lines = tooltip:NumLines() or 0
	for index = 1, lines do
		local left = _G[name .. "TextLeft" .. index]
		local right = _G[name .. "TextRight" .. index]
		local leftText = left and left:GetText() or ""
		local rightText = right and right:GetText() or ""
		for tokenIndex = 1, #hiddenScoreTokens do
			local token = hiddenScoreTokens[tokenIndex]
			if string.find(leftText, token) or string.find(rightText, token) then
				HideFontString(left)
				HideFontString(right)
				break
			end
		end
	end
end

local function HookTooltip(tooltip)
	if not tooltip or tooltip.__coolstatsCleanHooked then
		return
	end
	tooltip.__coolstatsCleanHooked = true
	tooltip:HookScript("OnTooltipSetItem", function(self)
		TameGearScore()
		CleanTooltip(self)
	end)
	tooltip:HookScript("OnTooltipCleared", function(self)
		CleanTooltip(self)
	end)
end

local function HookTooltips()
	if tooltipsHooked then
		return
	end
	tooltipsHooked = true

	HookTooltip(GameTooltip)
	HookTooltip(ItemRefTooltip)
	HookTooltip(ShoppingTooltip1)
	HookTooltip(ShoppingTooltip2)
end

local function HookCharacterSlots()
	-- Slot tooltips are intentionally left to the client and GearScore.
	-- coolstats only draws centered item-level badges to avoid duplicate tooltip lines.
end

local function RefreshCharacterHooks()
	if CharacterFrame and not CharacterFrame.__coolstatsHooked then
		CharacterFrame.__coolstatsHooked = true
		CharacterFrame:HookScript("OnShow", QueueUpdate)
		CharacterFrame:HookScript("OnHide", QueueUpdate)
	end
	if PaperDollFrame and not PaperDollFrame.__coolstatsHooked then
		PaperDollFrame.__coolstatsHooked = true
		PaperDollFrame:HookScript("OnShow", QueueUpdate)
		PaperDollFrame:HookScript("OnHide", QueueUpdate)
	end
	if InspectFrame and not InspectFrame.__coolstatsHooked then
		InspectFrame.__coolstatsHooked = true
		InspectFrame:HookScript("OnShow", function()
			CreateBadges()
			CreateInspectSummary()
			QueueUpdate()
		end)
		InspectFrame:HookScript("OnHide", QueueUpdate)
	end
end

local function InitializeUI()
	if not coolstats.IsCharacterPanelEnabled() then
		HideCharacterPanelRuntime()
		return
	end
	HideDefaultCharacterStats()
	CreatePanel()
	CreateBadges()
	CreateInspectSummary()
	HookCharacterSlots()
	HookTooltips()
	TameGearScore()
	RefreshCharacterHooks()
	QueueUpdate()
end

local function ShowHelp()
	Print("/coolstats or /cs - open settings")
	Print("/coolstats settings - open settings")
	Print("/coolstats browser - open the player browser")
	Print("/coolstats uwu [player name] - open UwU Logs for a player")
end

local function SlashHandler(message)
	local rawMessage = message or ""
	local command, rest = match(rawMessage, "^(%S*)%s*(.-)$")
	local commandLower = lower(command or "")
	if commandLower == "" or commandLower == "settings" then
		if coolstats.OpenOptionsPanel then
			coolstats.OpenOptionsPanel()
		else
			ShowHelp()
		end
	elseif commandLower == "browser" then
		if coolstats.OpenCachedPlayerBrowser then
			coolstats.OpenCachedPlayerBrowser()
		else
			Print("Player browser is not available.")
		end
	elseif commandLower == "uwu" then
		local name = rest
		if not name or name == "" then
			name = UnitName("target") or UnitName("player")
		end
		if coolstats.ShowUwULogsPanelForName then
			local found, displayName = coolstats.ShowUwULogsPanelForName(name)
			if found then
				Print("Showing UwU Logs for " .. tostring(displayName or name))
			else
				Print("UwU Logs: no top-list score found for " .. tostring(name))
			end
		else
			Print("UwU Logs data module is not loaded.")
		end
	else
		ShowHelp()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Gear Score" then
			gearScoreTamed = false
			if coolstats.IsCharacterPanelEnabled() then
				TameGearScore()
			end
			return
		elseif arg1 == "Blizzard_InspectUI" then
			if coolstats.IsCharacterPanelEnabled() then
				CreateBadges()
				CreateInspectSummary()
				RefreshCharacterHooks()
				QueueUpdate()
			end
			return
		elseif arg1 ~= ADDON_NAME then
			return
		end

		if type(coolstatsDB) == "table" then
			if coolstatsDB.showPanel ~= nil and coolstatsDB.showStatsPanel == nil then
				coolstatsDB.showStatsPanel = coolstatsDB.showPanel
				coolstatsDB.showPanel = nil
			end
			if coolstatsDB.showTooltips ~= nil and coolstatsDB.cleanGearScoreTooltips == nil then
				coolstatsDB.cleanGearScoreTooltips = coolstatsDB.showTooltips
				coolstatsDB.showTooltips = nil
			end
		end
		coolstatsDB = CopyDefaults(coolstatsDB, defaults)
		db = coolstatsDB
		EnsureEditOptions()

		SLASH_COOLSTATS1 = "/coolstats"
		SLASH_COOLSTATS2 = "/cs"
		SlashCmdList.COOLSTATS = SlashHandler

		SafeRegisterEvent(self, "PLAYER_LOGIN")
		if coolstats.IsCharacterPanelEnabled() then
			SafeRegisterEvent(self, "PLAYER_ENTERING_WORLD")
			SafeRegisterEvent(self, "PLAYER_EQUIPMENT_CHANGED")
			SafeRegisterEvent(self, "UNIT_INVENTORY_CHANGED")
			SafeRegisterEvent(self, "UNIT_STATS")
			SafeRegisterEvent(self, "UNIT_AURA")
			SafeRegisterEvent(self, "UNIT_MAXHEALTH")
			SafeRegisterEvent(self, "UNIT_MAXPOWER")
			SafeRegisterEvent(self, "UNIT_MAXMANA")
			SafeRegisterEvent(self, "UNIT_MAXRAGE")
			SafeRegisterEvent(self, "UNIT_MAXENERGY")
			SafeRegisterEvent(self, "UNIT_MAXRUNIC_POWER")
			SafeRegisterEvent(self, "COMBAT_RATING_UPDATE")
			SafeRegisterEvent(self, "CVAR_UPDATE")
			SafeRegisterEvent(self, "GET_ITEM_INFO_RECEIVED")
			SafeRegisterEvent(self, "INSPECT_READY")
			SafeRegisterEvent(self, "INSPECT_ACHIEVEMENT_READY")
			SafeRegisterEvent(self, "PLAYER_REGEN_ENABLED")
			SafeRegisterEvent(self, "MERCHANT_SHOW")
			SafeRegisterEvent(self, "MERCHANT_CLOSED")
		end
		return
	end

	if event == "PLAYER_LOGIN" then
		if coolstats.EnsureRealmDataLoaded then
			coolstats.EnsureRealmDataLoaded()
		end
		coolstats.CreateMinimapButton()
		InitializeUI()
		local freshness = coolstats.FormatCachedPlayerBrowserGeneratedAt and coolstats.FormatCachedPlayerBrowserGeneratedAt() or "Last UwU logs refresh: unknown"
		local dataAgeDays = coolstats.GetUwULogsDataAgeDays and coolstats.GetUwULogsDataAgeDays()
		if dataAgeDays and dataAgeDays > 7 then
			local ageLabel = tostring(dataAgeDays) .. (dataAgeDays == 1 and " day" or " days")
			Print("|cff00ff00Loaded successfully.|r |cffff4040" .. freshness .. ". Please update your addon; parse data is outdated by " .. ageLabel .. ".|r")
		else
			Print("|cff00ff00Loaded successfully.|r " .. freshness)
		end
		return
	end

	if not coolstats.IsCharacterPanelEnabled() then
		return
	end

	if event == "CVAR_UPDATE" then
		UpdateAppearanceToggles()
		return
	end

	if event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_STATS" or event == "UNIT_AURA" or event == "UNIT_MAXHEALTH" or event == "UNIT_MAXPOWER" or event == "UNIT_MAXMANA" or event == "UNIT_MAXRAGE" or event == "UNIT_MAXENERGY" or event == "UNIT_MAXRUNIC_POWER" then
		if arg1 ~= "player" then
			return
		end
	end

	if not ui.panel and CharacterFrame then
		InitializeUI()
	end
	QueueUpdate()
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
	if not updatePending then
		return
	end
	if db and not coolstats.IsCharacterPanelEnabled() then
		updatePending = false
		updateElapsed = 0
		return
	end
	updateElapsed = updateElapsed + elapsed
	if updateElapsed < 0.08 then
		return
	end

	updatePending = false
	updateElapsed = 0
	UpdateAll()
end)
