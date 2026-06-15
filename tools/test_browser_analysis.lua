local tooltipPath = assert(arg[1], "usage: lua test_browser_analysis.lua <coolstats_tooltip.lua> <coolstats_player_menu.lua>")
local playerMenuPath = assert(arg[2], "usage: lua test_browser_analysis.lua <coolstats_tooltip.lua> <coolstats_player_menu.lua>")

local frames = {}
local methods = {}
setmetatable(methods, {
	__index = function(_, key)
		return function(self, ...)
			if key == "IsShown" then
				return rawget(self, "shown") ~= false
			elseif key == "GetFrameLevel" then
				return rawget(self, "frameLevel") or 1
			elseif key == "SetFrameLevel" then
				self.frameLevel = ...
			elseif key == "GetName" then
				return self.name
			elseif key == "GetParent" then
				return self.parent or UIParent
			elseif key == "CreateTexture" or key == "CreateFontString" then
				return CreateFrame()
			elseif key == "SetText" then
				self.text = ...
			elseif key == "SetTextColor" then
				self.textColor = { ... }
			elseif key == "GetText" then
				return self.text
			elseif key == "SetScript" then
				local script, handler = ...
				local scripts = rawget(self, "scripts") or {}
				scripts[script] = handler
				rawset(self, "scripts", scripts)
			elseif key == "HookScript" then
				local script, handler = ...
				local hooks = rawget(self, "hooks") or {}
				hooks[script] = handler
				rawset(self, "hooks", hooks)
			elseif key == "SetAttribute" then
				local attribute, value = ...
				local attributes = rawget(self, "attributes") or {}
				attributes[attribute] = value
				rawset(self, "attributes", attributes)
			elseif key == "SetWidth" then
				self.width = ...
			elseif key == "SetHeight" then
				self.height = ...
			elseif key == "SetSize" then
				local width, height = ...
				self.width = width
				self.height = height
			elseif key == "SetChecked" then
				self.checked = ...
			elseif key == "SetPoint" then
				self.point = { ... }
			elseif key == "Show" then
				self.shown = true
			elseif key == "Hide" then
				self.shown = false
			end
			return self
		end
	end,
})

function CreateFrame(_, name, parent)
	local frame = setmetatable({
		name = name,
		parent = parent,
		shown = true,
		coolstatsTabardBackground = false,
		specButtons = {},
		trees = false,
		talentButtons = false,
		cachedGearPanel = false,
		coolstatsManagedChildren = {},
		classFilterButton = false,
		specFilterButton = false,
		classDropdown = false,
		specDropdown = false,
	}, { __index = methods })
	frames[#frames + 1] = frame
	if name then
		_G[name] = frame
	end
	return frame
end

coolstats = {}
coolstatsDB = {}
coolstatsCacheDB = {}
coolstatsUwUData = {
	phaseId = "icc",
	defaultRaidName = "Icecrown Citadel",
	bosses = {
		"Lord Marrowgar",
		"Lady Deathwhisper",
		"Toravon the Ice Watcher",
		"Halion",
		"Anub'arak",
	},
	classes = { [9] = "Warrior" },
	specs = { [9] = { "Arms", "Fury", "Protection" } },
	players = {
		self = {
			"Self",
			8000,
			9,
			2,
			10,
			{ [1] = 7600, [2] = 8000 },
			{ [1] = 20, [2] = 10 },
			{ { 8000, 10, 10, 10000 }, { 7000, 20, 20, 9000 }, nil, nil, { 6000, 30, 30, 8000 } },
			{
				[1] = { { 7600, 20, 20, 9500 }, { 6500, 30, 30, 8500 }, nil, nil, nil },
				[2] = { { 8000, 10, 10, 10000 }, { 7000, 20, 20, 9000 }, nil, nil, { 6000, 30, 30, 8000 } },
			},
		},
		peer = {
			"Peer",
			9000,
			9,
			2,
			5,
			{ [1] = 8500, [2] = 9000 },
			{ [1] = 12, [2] = 5 },
			{ { 9000, 5, 5, 12000 }, { 6500, 25, 25, 8000 }, { 7500, 20, 20, 9000 }, nil, nil },
			{
				[1] = { { 8500, 12, 12, 11000 }, { 6200, 35, 35, 7800 }, nil, nil, nil },
				[2] = { { 9000, 5, 5, 12000 }, { 6500, 25, 25, 8000 }, { 7500, 20, 20, 9000 }, nil, nil },
			},
		},
	},
}

UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("Frame", "GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
RAID_CLASS_COLORS = {}
UnitPopupButtons = {}
UnitPopupMenus = { PLAYER = { "WHISPER", "CANCEL" } }
UnitPopupShown = {}
UIDROPDOWNMENU_MENU_LEVEL = 1
DropDownList1 = CreateFrame("Frame", "DropDownList1")
DropDownList1.numButtons = 1
DropDownList1Button1 = CreateFrame("Button", "DropDownList1Button1", DropDownList1)
DropDownList1Button1.value = "COOLSTATS_TARGET_PLAYER"
DropDownList1Button1.shown = true

local dropdownButtons = {}
function UIDropDownMenu_CreateInfo()
	return {}
end
function UIDropDownMenu_AddButton(info)
	dropdownButtons[#dropdownButtons + 1] = info
end
function UIDropDownMenu_Initialize(frame, initialize)
	frame.initialize = initialize
end
function UIDropDownMenu_SetText(frame, text)
	frame.dropdownText = text
end
function UIDropDownMenu_SetWidth() end
function ToggleDropDownMenu() end
function CloseDropDownMenus() end
function RegisterStateDriver() end
function UnregisterStateDriver() end
function InCombatLockdown() return false end
function UnitPopup_OnClick() end
function UnitPopup_ShowMenu() end
function UnitPopup_HideButtons() end
function CompactUnitFrameDropDown_Initialize() end
function hooksecurefunc() end
function GetRealmName() return "Icecrown" end
function GetTime() return os.clock() end
function time() return os.time() end
function UnitName(unit)
	if unit == "player" then
		return "Self"
	end
	return nil
end

assert(loadfile(tooltipPath))("coolstats")
assert(loadfile(playerMenuPath))("coolstats")

assert(coolstats.ShowSecureTargetButtonForDropdown == nil, "secure target dropdown overlay is still exposed")
assert(CoolstatsSecureTargetButton == nil, "secure target dropdown overlay was still created")

local filterPanel = CreateFrame("Frame", "TestFilterPanel", UIParent)
filterPanel.classFilterButton = false
filterPanel.specFilterButton = false
filterPanel.specDropdown = false
local classDropdown = coolstats.CreateCachedPlayerBrowserClassDropdown(filterPanel)
assert(classDropdown and classDropdown.initialize == coolstats.InitializeCachedPlayerBrowserClassDropdown, "native class dropdown was not initialized")
dropdownButtons = {}
classDropdown.initialize(classDropdown, 1)
local warriorChoice
for _, choice in ipairs(dropdownButtons) do
	if choice.text == "Warrior" then
		warriorChoice = choice
		break
	end
end
assert(warriorChoice and warriorChoice.func, "native class dropdown did not populate Warrior")
warriorChoice.func()
assert(filterPanel.browserClassFilter == 9, "class dropdown choice did not apply its filter")

local specDropdown = coolstats.CreateCachedPlayerBrowserSpecDropdown(filterPanel)
assert(specDropdown and specDropdown.initialize == coolstats.InitializeCachedPlayerBrowserSpecDropdown, "native spec dropdown was not initialized")
dropdownButtons = {}
specDropdown.initialize(specDropdown, 1)
local armsChoice
for _, choice in ipairs(dropdownButtons) do
	if choice.text == "Arms" then
		armsChoice = choice
		break
	end
end
assert(armsChoice and armsChoice.func, "native spec dropdown did not populate Arms")
armsChoice.func()
assert(filterPanel.browserSpecFilterKey == "9:1", "spec dropdown choice did not apply its filter")

dropdownButtons = {}
coolstats.InitializeCachedPlayerBrowserRowMenu({ playerName = "Peer", favoriteKey = "peer" }, 1)
local favoriteIndex
local armoryIndex
local targetFound
for index, info in ipairs(dropdownButtons) do
	if info.text == "Favourite" then
		favoriteIndex = index
	elseif info.text == "|cff00bfffWarmane Armory|r" then
		armoryIndex = index
	elseif info.text == "Target" or info.value == "COOLSTATS_TARGET_PLAYER" then
		targetFound = true
	end
end
assert(favoriteIndex and armoryIndex and armoryIndex == favoriteIndex + 1, "blue Armory action is not directly below Favourite")
assert(not targetFound, "browser row menu still exposes the dropdown-tainting Target action")

coolstats.ShowCachedPlayerBrowserUrl("Warmane Armory", "https://armory.warmane.com/character/Peer/Icecrown/summary")
local urlDialog = assert(coolstats.cachedPlayerBrowserUrlDialog, "custom Armory URL dialog was not created")
assert(urlDialog.width == 960 and urlDialog.editBox.width == 860, "Armory URL dialog is not wide enough")

assert(coolstats.OpenLogAnalysisWithName("Peer"))
local panel = assert(coolstats.logAnalysisPanel, "log analysis panel was not created")
local shownRows = 0
local raidHeaders = 0
local bossRows = 0
local columnHeaders = 0
for _, row in ipairs(panel.rows or {}) do
	if row.shown then
		shownRows = shownRows + 1
		if row.analysisType == "raid" then
			raidHeaders = raidHeaders + 1
		elseif row.analysisType == "columns" then
			columnHeaders = columnHeaders + 1
		elseif row.analysisType == "boss" then
			bossRows = bossRows + 1
		end
	end
end

assert(bossRows == #coolstatsUwUData.bosses, "log analysis omitted bosses with missing parses")
assert(raidHeaders == 4, "log analysis did not split the active phase into raid sections")
assert(columnHeaders == raidHeaders, "each raid header was not followed by its own column header")
local firstBossRow
local secondBossRow
for _, row in ipairs(panel.rows or {}) do
	if row.analysisType == "boss" then
		if not firstBossRow then
			firstBossRow = row
		else
			secondBossRow = row
			break
		end
	end
end
assert(firstBossRow and firstBossRow.values[4].text == "-10.00", "log analysis difference is not calculated as you minus them")
assert(firstBossRow.values[4].textColor and firstBossRow.values[4].textColor[1] > firstBossRow.values[4].textColor[2], "worse personal parse difference is not red")
assert(secondBossRow and secondBossRow.values[4].text == "+5.00", "positive personal parse difference is incorrect")
assert(secondBossRow.values[4].textColor and secondBossRow.values[4].textColor[2] > secondBossRow.values[4].textColor[1], "better personal parse difference is not green")
assert(panel.chart and #panel.chart.dots == 4, "parse chart included bosses outside the phase's main raid")
assert(#panel.chart.curvePoints >= 20, "parse chart did not create smooth sampled curves")
assert(panel.chart.selfLegend.point and panel.chart.selfLegend.point[1] == "BOTTOMRIGHT", "personal chart legend is not centered below the plot")
assert(panel.chart.compareLegend.point and panel.chart.compareLegend.point[1] == "BOTTOMLEFT", "comparison chart legend is not centered below the plot")
assert(panel.selfSpecButtons[2].shown and panel.compareSpecButtons[2].shown, "multi-spec analysis buttons are not available")
panel.selfSpecButtons[2].scripts.OnClick(panel.selfSpecButtons[2])
assert(panel.selfSpecIndex == 1, "self spec selector did not update Log Analysis")
print("dropdown_choices=" .. tostring(#dropdownButtons))
print("analysis_boss_rows=" .. tostring(bossRows))
print("analysis_raid_headers=" .. tostring(raidHeaders))

coolstatsUwUData.phaseId = "ulduar"
coolstatsUwUData.defaultRaidName = "Ulduar"
coolstatsUwUData.bosses = { "Ignis the Furnace Master", "Emalon the Storm Watcher" }
coolstatsUwUData.players.self[8] = { nil, nil }
coolstatsUwUData.players.peer[8] = { nil, nil }
assert(coolstats.OpenLogAnalysisWithName("Peer"))

shownRows = 0
raidHeaders = 0
bossRows = 0
for _, row in ipairs(panel.rows or {}) do
	if row.shown then
		shownRows = shownRows + 1
		if row.analysisType == "raid" then
			raidHeaders = raidHeaders + 1
		elseif row.analysisType == "boss" then
			bossRows = bossRows + 1
		end
	end
end
assert(bossRows == 2, "Ulduar analysis omitted empty boss rows")
assert(raidHeaders == 2, "Ulduar analysis did not split Ulduar and Vault of Archavon")
print("ulduar_boss_rows=" .. tostring(bossRows))
print("ulduar_raid_headers=" .. tostring(raidHeaders))

local tooltipText = assert(io.open(tooltipPath, "rb")):read("*a")
assert(not tooltipText:find("options.raidProgressFallback ~= false and not hasLogs", 1, true), "logged players are still excluded from raid progress")
