local coolstats = _G.coolstats or {}

local DETACHED_BUTTON_GRACE_SECONDS = 5.0
local DETACHED_BUTTON_CLOSE_GRACE_SECONDS = 0.2
local DETACHED_BUTTON_OPEN_GRACE_SECONDS = 0.85
local DETACHED_BUTTON_DUPLICATE_OPEN_SECONDS = 0.06
local DETACHED_BUTTON_REOPEN_SUPPRESS_SECONDS = 0.35
local DETACHED_BUTTON_DROPDOWN_LOST_SECONDS = 0.0
local detachedButton
local hooked
local suppressPlayerName
local suppressUntil

local PLAYER_MENU_TYPES = {
	SELF = true,
	PLAYER = true,
	TARGET = true,
	FOCUS = true,
	PARTY = true,
	RAID_PLAYER = true,
	FRIEND = true,
	CHAT_ROSTER = true,
	GUILD = true,
	BN_FRIEND = true,
	WHISPER = true,
}

local PLAYER_MENU_ACTIONS = {
	ACHIEVEMENTS = true,
	CANCEL = true,
	DUEL = true,
	FOCUS = true,
	FOLLOW = true,
	IGNORE = true,
	INSPECT = true,
	INVITE = true,
	RAID_TARGET_ICON = true,
	REMOVE_FRIEND = true,
	REPORT_SPAM = true,
	SET_FOCUS = true,
	TRADE = true,
	WHISPER = true,
}

local PLAYER_MENU_TEXTS = {
	["Cancel"] = true,
	["Compare Achievements"] = true,
	["Duel"] = true,
	["Follow"] = true,
	["Ignore"] = true,
	["Inspect"] = true,
	["Invite"] = true,
	["Raid Target Icon"] = true,
	["Remove"] = true,
	["Report Spam"] = true,
	["Set Focus"] = true,
	["Set Main"] = true,
	["Trade"] = true,
	["Whisper"] = true,
}

local DROPDOWN_NAME_GLOBALS = {
	"UIDROPDOWNMENU_INIT_MENU",
	"FriendsDropDown",
	"ChatMenu",
	"UnitPopupDropDown",
	"GuildMemberDropDown",
	"RaidFrameDropDown",
	"PartyMemberFrameDropDown",
	"PlayerFrameDropDown",
}

local LEGACY_UNIT_POPUP_ACTIONS = {
	COOLSTATS_TARGET_PLAYER = true,
	COOLSTATS_UWU_LOGS = true,
}

local function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00c0ffcoolstats:|r " .. tostring(message))
	end
end

local function RemoveLegacyUnitPopupActions()
	if UnitPopupButtons then
		for action in pairs(LEGACY_UNIT_POPUP_ACTIONS) do
			UnitPopupButtons[action] = nil
		end
	end
	if UnitPopupMenus then
		for _, menu in pairs(UnitPopupMenus) do
			if type(menu) == "table" then
				for index = #menu, 1, -1 do
					if LEGACY_UNIT_POPUP_ACTIONS[menu[index]] then
						table.remove(menu, index)
					end
				end
			end
		end
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

local function IsVisibleFrame(frame)
	if not frame then
		return false
	end
	if frame.IsShown then
		return frame:IsShown()
	end
	return frame.shown ~= false
end

local function GetFrameText(frame)
	if not frame then
		return nil
	end
	if frame.GetText then
		local text = frame:GetText()
		if text and text ~= "" then
			return text
		end
	end
	if frame.text then
		if type(frame.text) == "string" then
			return frame.text
		end
		if frame.text.GetText then
			local text = frame.text:GetText()
			if text and text ~= "" then
				return text
			end
		end
	end
	return nil
end

local function GetPrimaryDropdownList()
	if DropDownList1 and IsVisibleFrame(DropDownList1) then
		return DropDownList1
	end
	return nil
end

local function GetDropdownButton(level, index)
	if not _G then
		return nil
	end
	local list = _G["DropDownList" .. tostring(level)]
	if not list then
		return nil
	end
	local listName = list.GetName and list:GetName() or ("DropDownList" .. tostring(level))
	return _G[listName .. "Button" .. tostring(index)]
end

local function IsMouseButtonDownOnDropdownAction()
	if IsMouseButtonDown and not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
		return false
	end
	local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 3
	local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
	local cancelText = CANCEL or "Cancel"
	for level = 1, maxLevels do
		for buttonIndex = 1, maxButtons do
			local button = GetDropdownButton(level, buttonIndex)
			if button and IsVisibleFrame(button) and button.IsMouseOver and button:IsMouseOver() then
				local value = type(button.value) == "string" and button.value or ""
				local text = CleanPlayerName(GetFrameText(button))
				if PLAYER_MENU_ACTIONS[value] or value == "CANCEL" or text == cancelText or text == "Cancel" or PLAYER_MENU_TEXTS[text] then
					return true
				end
			end
		end
	end
	return false
end

local function GetNameFromObject(object)
	if type(object) ~= "table" then
		return nil
	end

	local keys = { "name", "playerName", "unitName", "chatTarget", "target" }
	for index = 1, #keys do
		local value = object[keys[index]]
		if type(value) == "string" and value ~= "" then
			return value
		end
	end

	if type(object.value) == "string" and object.value ~= "" and not PLAYER_MENU_ACTIONS[object.value] then
		return object.value
	end

	if object.unit and UnitName then
		local unitName = UnitName(object.unit)
		if unitName and unitName ~= "" then
			return unitName
		end
	end

	return nil
end

local function GetDropdownTitleName()
	local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
	for buttonIndex = 1, maxButtons do
		local button = GetDropdownButton(1, buttonIndex)
		if button and IsVisibleFrame(button) then
			local text = CleanPlayerName(GetFrameText(button))
			if text ~= "" and not PLAYER_MENU_TEXTS[text] then
				return text
			end
		end
	end
	return nil
end

local function DropdownLooksPlayerRelated()
	local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
	for level = 1, 2 do
		for buttonIndex = 1, maxButtons do
			local button = GetDropdownButton(level, buttonIndex)
			if button and IsVisibleFrame(button) then
				if type(button.value) == "string" and PLAYER_MENU_ACTIONS[button.value] then
					return true
				end
				local text = GetFrameText(button)
				if text and PLAYER_MENU_TEXTS[CleanPlayerName(text)] then
					return true
				end
			end
		end
	end
	return false
end

local function GetMenuPlayerName(dropdownMenu, unit, name, ...)
	if name and name ~= "" then
		return name
	end
	if unit and UnitName then
		local unitName = UnitName(unit)
		if unitName and unitName ~= "" then
			return unitName
		end
	end
	local directName = GetNameFromObject(dropdownMenu)
	if directName and directName ~= "" then
		return directName
	end

	local objects = {}
	for index = 1, #DROPDOWN_NAME_GLOBALS do
		objects[#objects + 1] = _G and _G[DROPDOWN_NAME_GLOBALS[index]] or nil
	end
	for index = 1, select("#", ...) do
		objects[#objects + 1] = select(index, ...)
	end
	for index = 1, #objects do
		local objectName = GetNameFromObject(objects[index])
		if objectName and objectName ~= "" then
			return objectName
		end
		if type(objects[index]) == "string" and objects[index] ~= "" and not PLAYER_MENU_ACTIONS[objects[index]] then
			return objects[index]
		end
	end

	return GetDropdownTitleName()
end

local function AnchorButtonToDropdown(button)
	local list = GetPrimaryDropdownList()
	if not list then
		return false
	end

	if list.GetWidth then
		local width = list:GetWidth()
		if type(width) == "number" and width > 90 then
			button:SetWidth(width - 8)
		end
	end
	if list.GetFrameLevel and button.SetFrameLevel then
		local level = list:GetFrameLevel()
		if type(level) == "number" then
			button:SetFrameLevel(level + 5)
		end
	end
	button:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 4, 0)
	if list.GetLeft and list.GetRight and list.GetTop and list.GetBottom and button.GetHeight then
		local left, right, top, bottom = list:GetLeft(), list:GetRight(), list:GetTop(), list:GetBottom()
		local height = button:GetHeight()
		if left and right and top and bottom and height then
			button.menuLeft = left - 12
			button.menuRight = right + 12
			button.menuTop = top + 12
			button.menuBottom = bottom - 4
			button.travelLeft = left - 12
			button.travelRight = right + 12
			button.travelTop = bottom + 12
			button.travelBottom = bottom - height - 12
		end
	end
	return true
end

local function AnchorButtonNearCursor(button)
	if GetCursorPosition and UIParent and UIParent.GetEffectiveScale then
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		if scale and scale > 0 then
			button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
			return
		end
	end
	button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function ClearButtonTravelRegion(button)
	if button then
		button.dropdownLeft = nil
		button.dropdownRight = nil
		button.dropdownTop = nil
		button.dropdownBottom = nil
		button.menuLeft = nil
		button.menuRight = nil
		button.menuTop = nil
		button.menuBottom = nil
		button.travelLeft = nil
		button.travelRight = nil
		button.travelTop = nil
		button.travelBottom = nil
	end
end

local function UpdateOpenDropdownRegion(button)
	if not button or not _G then
		return false
	end

	local left, right, top, bottom
	local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 3
	for level = 1, maxLevels do
		local list = _G["DropDownList" .. tostring(level)]
		if list and IsVisibleFrame(list) and list.GetLeft and list.GetRight and list.GetTop and list.GetBottom then
			local l, r, t, b = list:GetLeft(), list:GetRight(), list:GetTop(), list:GetBottom()
			if l and r and t and b then
				left = left and math.min(left, l) or l
				right = right and math.max(right, r) or r
				top = top and math.max(top, t) or t
				bottom = bottom and math.min(bottom, b) or b
			end
		end
	end

	if left and right and top and bottom then
		button.dropdownLeft = left - 12
		button.dropdownRight = right + 12
		button.dropdownTop = top + 12
		button.dropdownBottom = bottom - 12
		return true
	end
	return false
end

local function GetCursorUiPosition()
	if not GetCursorPosition then
		return nil, nil
	end
	local x, y = GetCursorPosition()
	if UIParent and UIParent.GetEffectiveScale then
		local scale = UIParent:GetEffectiveScale()
		if scale and scale > 0 then
			x = x / scale
			y = y / scale
		end
	end
	return x, y
end

local function IsCursorInStoredDropdownRegion(button)
	if not button then
		return false
	end
	local x, y = GetCursorUiPosition()
	if not (x and y and button.dropdownLeft and button.dropdownRight and button.dropdownTop and button.dropdownBottom) then
		return false
	end
	return x >= button.dropdownLeft and x <= button.dropdownRight and y >= button.dropdownBottom and y <= button.dropdownTop
end

local function IsCursorInStoredMenuRegion(button)
	if not button then
		return false
	end
	local x, y = GetCursorUiPosition()
	if not (x and y and button.menuLeft and button.menuRight and button.menuTop and button.menuBottom) then
		return false
	end
	return x >= button.menuLeft and x <= button.menuRight and y >= button.menuBottom and y <= button.menuTop
end

local function IsCursorInButtonTravelRegion(button)
	if not button then
		return false
	end
	local x, y = GetCursorUiPosition()
	if not (x and y and button.travelLeft and button.travelRight and button.travelTop and button.travelBottom) then
		return false
	end
	return x >= button.travelLeft and x <= button.travelRight and y >= button.travelBottom and y <= button.travelTop
end

local function IsCursorNearDetachedButton(button)
	if not button then
		return false
	end
	if button.IsMouseOver and button:IsMouseOver() then
		return true
	end
	if IsCursorInStoredDropdownRegion(button) then
		return true
	end
	if IsCursorInStoredMenuRegion(button) then
		return true
	end
	if IsCursorInButtonTravelRegion(button) then
		return true
	end
	if not (button.GetLeft and button.GetRight and button.GetTop and button.GetBottom) then
		return false
	end

	local x, y = GetCursorUiPosition()
	local left, right, top, bottom = button:GetLeft(), button:GetRight(), button:GetTop(), button:GetBottom()
	if not (x and y and left and right and top and bottom) then
		return false
	end

	return x >= left - 8 and x <= right + 8 and y >= bottom - 8 and y <= top + 28
end

local function IsPlayerPopup(which, unit, name)
	if unit and UnitExists and UnitExists(unit) and UnitIsPlayer then
		return UnitIsPlayer(unit)
	end
	if CleanPlayerName(name) == "" then
		return false
	end
	return PLAYER_MENU_TYPES[which] or DropdownLooksPlayerRelated()
end

local function HideDetachedButton()
	if detachedButton then
		detachedButton:Hide()
		detachedButton.playerName = nil
		detachedButton.expiresAt = nil
		detachedButton.pendingAnchorUntil = nil
		detachedButton.closeGraceUntil = nil
		detachedButton.openGraceUntil = nil
		detachedButton.shownAt = nil
		detachedButton.readyForOutsideClick = nil
		detachedButton.sawDropdown = nil
		detachedButton.dropdownLostAt = nil
		ClearButtonTravelRegion(detachedButton)
	end
end

local function SuppressDetachedButtonReopen(playerName)
	playerName = CleanPlayerName(playerName)
	if playerName == "" then
		return
	end
	suppressPlayerName = playerName
	suppressUntil = ((GetTime and GetTime()) or 0) + DETACHED_BUTTON_REOPEN_SUPPRESS_SECONDS
end

local function IsDetachedButtonReopenSuppressed(playerName)
	local now = (GetTime and GetTime()) or 0
	if not suppressUntil or now > suppressUntil then
		suppressPlayerName = nil
		suppressUntil = nil
		return false
	end
	return suppressPlayerName == CleanPlayerName(playerName)
end

local function HideDetachedButtonForDropdownAction()
	if detachedButton and IsVisibleFrame(detachedButton) and not (detachedButton.IsMouseOver and detachedButton:IsMouseOver()) then
		HideDetachedButton()
	end
end

local function IsAnyMouseButtonDown()
	if not IsMouseButtonDown then
		return false
	end
	return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
end

local function OpenUwULogsForName(name)
	name = CleanPlayerName(name)
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

local function PositionButtonText(button, xOffset, yOffset)
	if not button or not button.text or not button.icon then
		return
	end
	button.text:ClearAllPoints()
	button.text:SetPoint("LEFT", button.icon, "RIGHT", xOffset or 6, yOffset or 0)
	button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
end

local function GetNow()
	return (GetTime and GetTime()) or 0
end

local function RefreshButtonGrace(button)
	if button then
		button.expiresAt = GetNow() + DETACHED_BUTTON_GRACE_SECONDS
	end
end

local function StartDetachedButtonCloseGrace()
	if detachedButton and IsVisibleFrame(detachedButton) and detachedButton.playerName then
		local now = GetNow()
		local mouseOver = detachedButton.IsMouseOver and detachedButton:IsMouseOver()
		if IsMouseButtonDownOnDropdownAction() then
			HideDetachedButton()
			return
		end
		if detachedButton.shownAt and IsAnyMouseButtonDown() and not mouseOver then
			local elapsed = now - detachedButton.shownAt
			if elapsed > DETACHED_BUTTON_DUPLICATE_OPEN_SECONDS then
				SuppressDetachedButtonReopen(detachedButton.playerName)
				HideDetachedButton()
				return
			end
		end
		if detachedButton.sawDropdown and not mouseOver and not UpdateOpenDropdownRegion(detachedButton) then
			HideDetachedButton()
			return
		end
		if detachedButton.openGraceUntil and now <= detachedButton.openGraceUntil then
			detachedButton.closeGraceUntil = nil
			detachedButton.expiresAt = now + DETACHED_BUTTON_GRACE_SECONDS
			return
		end
		if mouseOver then
			detachedButton.closeGraceUntil = now + DETACHED_BUTTON_CLOSE_GRACE_SECONDS
			detachedButton.expiresAt = detachedButton.closeGraceUntil
		elseif not IsAnyMouseButtonDown() then
			detachedButton.closeGraceUntil = nil
			detachedButton.expiresAt = now + DETACHED_BUTTON_GRACE_SECONDS
		else
			HideDetachedButton()
		end
	end
end

local function CreateDetachedButton()
	if detachedButton then
		return detachedButton
	end

	detachedButton = CreateFrame("Button", "coolstatsUnitPopupUwUAction", UIParent)
	detachedButton:SetFrameStrata("TOOLTIP")
	detachedButton:SetSize(132, 24)
	detachedButton:EnableMouse(true)
	detachedButton:RegisterForClicks("LeftButtonUp")
	detachedButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	detachedButton:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	detachedButton:SetBackdropColor(0.02, 0.05, 0.08, 0.98)
	if detachedButton.SetBackdropBorderColor then
		detachedButton:SetBackdropBorderColor(0.0, 0.75, 1.0, 0.95)
	end

	local icon = detachedButton:CreateTexture(nil, "ARTWORK")
	detachedButton.icon = icon
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", detachedButton, "LEFT", 8, 0)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")

	local text = detachedButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detachedButton.text = text
	text:SetJustifyH("LEFT")
	text:SetText("|cff00c0ffUWU Logs|r")
	PositionButtonText(detachedButton, 6, 0)

	detachedButton:SetScript("OnClick", function(self)
		local playerName = self.playerName
		HideDetachedButton()
		if CloseDropDownMenus then
			CloseDropDownMenus()
		end
		OpenUwULogsForName(playerName)
	end)
	detachedButton:SetScript("OnEnter", function(self)
		self.closeGraceUntil = nil
		RefreshButtonGrace(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("UWU Logs", 0.0, 0.75, 1.0)
			GameTooltip:AddLine("Open coolstats logs for this player.", 0.86, 0.86, 0.78, true)
			GameTooltip:Show()
		end
	end)
	detachedButton:SetScript("OnLeave", function(self)
		RefreshButtonGrace(self)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	detachedButton:SetScript("OnMouseDown", function(self)
		PositionButtonText(self, 7, -1)
	end)
	detachedButton:SetScript("OnMouseUp", function(self)
		PositionButtonText(self, 6, 0)
	end)
	detachedButton:SetScript("OnUpdate", function(self)
		local now = GetNow()
		local listShown = UpdateOpenDropdownRegion(self)
		local mouseOver = self.IsMouseOver and self:IsMouseOver()
		local mouseDown = IsAnyMouseButtonDown()
		if listShown then
			self.sawDropdown = true
			self.dropdownLostAt = nil
		elseif self.sawDropdown and not mouseOver and not self.dropdownLostAt then
			self.dropdownLostAt = now
		end
		if not mouseDown then
			self.readyForOutsideClick = true
		elseif self.readyForOutsideClick and not mouseOver then
			SuppressDetachedButtonReopen(self.playerName)
			HideDetachedButton()
			return
		end
		if self.closeGraceUntil then
			if listShown then
				self.closeGraceUntil = nil
				RefreshButtonGrace(self)
				return
			end
			if mouseOver then
				self.closeGraceUntil = nil
				RefreshButtonGrace(self)
			elseif now > self.closeGraceUntil then
				HideDetachedButton()
			end
			return
		end

		if listShown or mouseOver then
			RefreshButtonGrace(self)
			if self.pendingAnchorUntil and now <= self.pendingAnchorUntil then
				if AnchorButtonToDropdown(self) then
					self.pendingAnchorUntil = nil
				end
			end
			return
		end
		if self.dropdownLostAt and now - self.dropdownLostAt > DETACHED_BUTTON_DROPDOWN_LOST_SECONDS then
			HideDetachedButton()
			return
		end
		if self.expiresAt and now > self.expiresAt then
			HideDetachedButton()
		end
	end)
	detachedButton:Hide()
	return detachedButton
end

local function ShowDetachedButton(dropdownMenu, which, unit, name, ...)
	local playerName = CleanPlayerName(GetMenuPlayerName(dropdownMenu, unit, name, ...))
	if not IsPlayerPopup(which, unit, playerName) then
		return
	end
	if IsDetachedButtonReopenSuppressed(playerName) then
		return
	end

	local button = CreateDetachedButton()
	local now = GetNow()
	if IsVisibleFrame(button) and button.playerName == playerName and button.shownAt then
		local elapsed = now - button.shownAt
		if elapsed <= DETACHED_BUTTON_DUPLICATE_OPEN_SECONDS then
			return
		end
		if elapsed <= DETACHED_BUTTON_OPEN_GRACE_SECONDS and IsMouseButtonDown and IsMouseButtonDown("RightButton") then
			SuppressDetachedButtonReopen(playerName)
			HideDetachedButton()
			return
		end
	end
	button.playerName = playerName
	button.shownAt = now
	button.readyForOutsideClick = false
	button.sawDropdown = false
	button.dropdownLostAt = nil
	button.pendingAnchorUntil = now + 0.5
	button.openGraceUntil = now + DETACHED_BUTTON_OPEN_GRACE_SECONDS
	button.closeGraceUntil = nil
	RefreshButtonGrace(button)
	button:ClearAllPoints()
	button:SetSize(132, 24)

	if not AnchorButtonToDropdown(button) then
		ClearButtonTravelRegion(button)
		AnchorButtonNearCursor(button)
	else
		UpdateOpenDropdownRegion(button)
	end
	button:Show()
end

local function GetDropdownLevel(level)
	local numericLevel = tonumber(level)
	if not numericLevel and UIDROPDOWNMENU_MENU_LEVEL then
		numericLevel = tonumber(UIDROPDOWNMENU_MENU_LEVEL)
	end
	return numericLevel or 1
end

local function ShowDetachedButtonForOpenDropdown(level, value, dropdownFrame, ...)
	if GetDropdownLevel(level) ~= 1 then
		return
	end

	local menu = dropdownFrame or UIDROPDOWNMENU_INIT_MENU
	local which = menu and menu.which or nil
	local unit = menu and menu.unit or nil
	local name = menu and menu.name or nil
	ShowDetachedButton(menu, which, unit, name, value, ...)
end

local function InitializeDetachedUnitPopupAction()
	RemoveLegacyUnitPopupActions()
	if hooked then
		return
	end
	if type(hooksecurefunc) ~= "function" then
		return
	end
	if type(UnitPopup_ShowMenu) ~= "function" and type(ToggleDropDownMenu) ~= "function" then
		return
	end

	hooked = true
	coolstats.__unitPopupIntegrationMode = "detached"
	CreateDetachedButton()
	if type(UnitPopup_ShowMenu) == "function" then
		hooksecurefunc("UnitPopup_ShowMenu", ShowDetachedButton)
	end
	if type(ToggleDropDownMenu) == "function" then
		hooksecurefunc("ToggleDropDownMenu", ShowDetachedButtonForOpenDropdown)
	end
	if type(CloseDropDownMenus) == "function" then
		hooksecurefunc("CloseDropDownMenus", StartDetachedButtonCloseGrace)
	end
	if type(UIDropDownMenuButton_OnClick) == "function" then
		hooksecurefunc("UIDropDownMenuButton_OnClick", HideDetachedButtonForDropdownAction)
	end
end

RemoveLegacyUnitPopupActions()

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, addonName)
	if event == "ADDON_LOADED" and addonName ~= "coolstats" then
		return
	end
	InitializeDetachedUnitPopupAction()
end)

InitializeDetachedUnitPopupAction()
