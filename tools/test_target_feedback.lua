local addonPath = assert(arg[1], "usage: lua test_target_feedback.lua <coolstats_player_menu.lua>")

local frames = {}
local secureHooks = {}

local methods = {}
function methods:RegisterEvent(event)
	self.events = self.events or {}
	self.events[event] = true
end
function methods:SetScript(name, handler)
	self.scripts = self.scripts or {}
	self.scripts[name] = handler
end

function CreateFrame(_, name, parent)
	local frame = setmetatable({ name = name, parent = parent }, { __index = methods })
	frames[#frames + 1] = frame
	if name then
		_G[name] = frame
	end
	return frame
end

coolstats = {}
UIParent = CreateFrame("Frame", "UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UnitPopupButtons = {
	COOLSTATS_TARGET_PLAYER = { text = "Target" },
}
UnitPopupMenus = {
	PLAYER = { "WHISPER", "COOLSTATS_TARGET_PLAYER", "CANCEL" },
	SELF = { "CANCEL" },
}
UnitPopup_OnClick = function() end
hooksecurefunc = function(name, handler)
	secureHooks[name] = handler
end

assert(loadfile(addonPath))()

assert(coolstats.ShowSecureTargetButtonForDropdown == nil, "secure target dropdown overlay is still exposed")
assert(CoolstatsSecureTargetButton == nil, "secure target dropdown overlay was still created")
assert(UnitPopupButtons.COOLSTATS_TARGET_PLAYER == nil, "legacy Target popup button still exists")
for _, menu in pairs(UnitPopupMenus) do
	for _, value in ipairs(menu) do
		assert(value ~= "COOLSTATS_TARGET_PLAYER", "legacy Target action still exists in player popup menus")
	end
end
assert(UnitPopupButtons.COOLSTATS_UWU_LOGS, "UWU Logs popup action was removed")
assert(secureHooks.UnitPopup_OnClick, "UWU Logs click hook was not installed")
assert(secureHooks.UnitPopup_ShowMenu == nil, "global dropdown show hook is still installed")
assert(secureHooks.UnitPopup_HideButtons == nil, "global dropdown hide hook is still installed")
assert(secureHooks.CompactUnitFrameDropDown_Initialize == nil, "compact raid dropdown hook is still installed")

print("secure_target_removed=true")
print("uwu_logs_menu_preserved=true")
