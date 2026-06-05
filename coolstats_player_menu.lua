local coolstats = _G.coolstats or {}

local UWU_LOGS_BUTTON = "COOLSTATS_UWU_LOGS"
local UWU_LOGS_TEXT = "|cffffd100UWU Logs|r"

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

local function AddUwULogsToPlayerMenus()
	if type(UnitPopupButtons) ~= "table" or type(UnitPopupMenus) ~= "table" then
		return false
	end

	UnitPopupButtons[UWU_LOGS_BUTTON] = UnitPopupButtons[UWU_LOGS_BUTTON] or {
		text = UWU_LOGS_TEXT,
		dist = 0,
		notCheckable = 1,
	}
	UnitPopupButtons[UWU_LOGS_BUTTON].text = UWU_LOGS_TEXT
	UnitPopupButtons[UWU_LOGS_BUTTON].dist = 0
	UnitPopupButtons[UWU_LOGS_BUTTON].notCheckable = 1

	for menuName, menu in pairs(UnitPopupMenus) do
		if type(menu) == "table" and MenuLooksPlayerRelated(menuName, menu) and not MenuHasButton(menu, UWU_LOGS_BUTTON) then
			table.insert(menu, GetInsertIndex(menu), UWU_LOGS_BUTTON)
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

local function OnUnitPopupClick(button)
	if not button or button.value ~= UWU_LOGS_BUTTON then
		return
	end

	OpenUwULogsForMenuPlayer(button)
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
	AddUwULogsToPlayerMenus()
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
