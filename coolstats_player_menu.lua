local coolstats = _G.coolstats or {}

local UWU_LOGS_BUTTON = "COOLSTATS_UWU_LOGS"
local UWU_LOGS_TEXT = "|cffffd100UWU Logs|r"
local TARGET_PLAYER_BUTTON = "COOLSTATS_TARGET_PLAYER"
local TARGET_PLAYER_TEXT = TARGET or "Target"

local function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00c0ffcoolstats:|r " .. tostring(message))
	end
end

local function Trim(text)
	text = tostring(text or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function CleanPlayerName(name)
	name = tostring(name or "")
	name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
	name = string.gsub(name, "|r", "")

	local linkedName = string.match(name, "|Hplayer:([^:%]|]+)")
	if linkedName then
		name = linkedName
	end

	name = string.gsub(name, "%[", "")
	name = string.gsub(name, "%]", "")
	name = Trim(name)
	name = string.gsub(name, "%-.+$", "")
	return Trim(name)
end

local function GetDropdownPlayerName(button)
	local dropdown = UIDROPDOWNMENU_INIT_MENU
	if dropdown then
		if dropdown.name then
			return dropdown.name
		end
		if dropdown.unit and UnitName then
			local unitName = UnitName(dropdown.unit)
			if unitName then
				return unitName
			end
		end
	end

	if button and button.owner then
		if button.owner.name then
			return button.owner.name
		end
		if button.owner.unit and UnitName then
			local unitName = UnitName(button.owner.unit)
			if unitName then
				return unitName
			end
		end
	end

	return UnitName and (UnitName("target") or UnitName("player")) or nil
end

local function MenuHasButton(menu, buttonName)
	for index = 1, #menu do
		if menu[index] == buttonName then
			return true
		end
	end
	return false
end

local function GetButtonIndex(menu, buttonName)
	for index = 1, #menu do
		if menu[index] == buttonName then
			return index
		end
	end
	return nil
end

local function MenuLooksPlayerRelated(menuName, menu)
	if menuName == "SELF" then
		return true
	end

	for index = 1, #menu do
		local value = menu[index]
		if value == "WHISPER" or value == "INSPECT" then
			return true
		end
	end
	return false
end

local function GetInsertIndex(menu)
	local fallbackIndex = #menu + 1
	local lowerAnchors = {
		"INVITE",
		"BN_INVITE",
		"UNINVITE",
		"RAID_TARGET_ICON",
		"DUEL",
		"FOLLOW",
		"TRADE",
		"ACHIEVEMENTS",
	}

	for anchorIndex = 1, #lowerAnchors do
		local anchor = lowerAnchors[anchorIndex]
		for index = 1, #menu do
			if menu[index] == anchor then
				return index + 1
			end
		end
	end

	for index = 1, #menu do
		if menu[index] == "INSPECT" then
			return index + 1
		end
	end

	for index = 1, #menu do
		if menu[index] == "WHISPER" then
			return index + 1
		end
	end

	for index = 1, #menu do
		if menu[index] == "CANCEL" then
			return index
		end
	end

	return fallbackIndex
end

local function ConfigurePopupButton(buttonName, text)
	UnitPopupButtons[buttonName] = UnitPopupButtons[buttonName] or {
		text = text,
		dist = 0,
		notCheckable = 1,
	}
	UnitPopupButtons[buttonName].text = text
	UnitPopupButtons[buttonName].dist = 0
	UnitPopupButtons[buttonName].notCheckable = 1
end

local function AddCoolstatsActionsToPlayerMenus()
	if type(UnitPopupButtons) ~= "table" or type(UnitPopupMenus) ~= "table" then
		return false
	end

	ConfigurePopupButton(TARGET_PLAYER_BUTTON, TARGET_PLAYER_TEXT)
	ConfigurePopupButton(UWU_LOGS_BUTTON, UWU_LOGS_TEXT)

	for menuName, menu in pairs(UnitPopupMenus) do
		if type(menu) == "table" and MenuLooksPlayerRelated(menuName, menu) then
			if menuName ~= "SELF" and not MenuHasButton(menu, TARGET_PLAYER_BUTTON) then
				table.insert(menu, GetInsertIndex(menu), TARGET_PLAYER_BUTTON)
			end
			if not MenuHasButton(menu, UWU_LOGS_BUTTON) then
				local targetIndex = GetButtonIndex(menu, TARGET_PLAYER_BUTTON)
				table.insert(menu, targetIndex and (targetIndex + 1) or GetInsertIndex(menu), UWU_LOGS_BUTTON)
			end
		end
	end

	return true
end

local function OpenUwULogsForMenuPlayer(button)
	local name = CleanPlayerName(GetDropdownPlayerName(button))
	if name == "" then
		Print("UWU Logs: no player name found.")
		return
	end

	if not coolstats.ShowUwULogsPanelForName then
		Print("UWU Logs data module is not loaded.")
		return
	end

	local found, displayName = coolstats.ShowUwULogsPanelForName(name)
	if found then
		Print("Showing UWU Logs for " .. tostring(displayName or name))
	else
		Print("UWU Logs: no top-list score found for " .. tostring(name))
	end
end

local function TargetMenuPlayer(button)
	local name = CleanPlayerName(GetDropdownPlayerName(button))
	if name == "" or not TargetByName then
		return
	end
	TargetByName(name, true)
end

local function OnUnitPopupClick(button)
	if not button then
		return
	end

	if button.value == TARGET_PLAYER_BUTTON then
		TargetMenuPlayer(button)
	elseif button.value == UWU_LOGS_BUTTON then
		OpenUwULogsForMenuPlayer(button)
	else
		return
	end

	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
end

local function HookUnitPopupClick()
	if coolstats.__uwuLogsMenuClickHooked then
		return true
	end
	if type(UnitPopup_OnClick) ~= "function" then
		return false
	end

	coolstats.__uwuLogsMenuClickHooked = true
	if hooksecurefunc then
		hooksecurefunc("UnitPopup_OnClick", OnUnitPopupClick)
	else
		local originalUnitPopupOnClick = UnitPopup_OnClick
		UnitPopup_OnClick = function(button, ...)
			originalUnitPopupOnClick(button, ...)
			OnUnitPopupClick(button)
		end
	end
	return true
end

local function InitializeUwULogsPlayerMenu()
	AddCoolstatsActionsToPlayerMenus()
	HookUnitPopupClick()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, addonName)
	if event == "ADDON_LOADED" and addonName ~= "coolstats" then
		return
	end
	InitializeUwULogsPlayerMenu()
end)

InitializeUwULogsPlayerMenu()
