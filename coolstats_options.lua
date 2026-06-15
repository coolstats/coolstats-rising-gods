local coolstats = _G.coolstats or {}

local QUALITY_LABELS = {
	[2] = "Uncommon",
	[3] = "Rare",
	[4] = "Epic",
	[5] = "Legendary",
}

local function GetDB()
	if coolstats.EnsureOptions then
		coolstats.EnsureOptions()
	end
	return coolstats.GetDB and coolstats.GetDB() or coolstatsDB
end

local function GetDefaults()
	return coolstats.GetDefaults and coolstats.GetDefaults() or nil
end

local function IsCharacterPanelEnabled()
	if coolstats.IsCharacterPanelEnabled then
		return coolstats.IsCharacterPanelEnabled()
	end
	local db = GetDB()
	return not db or db.enableCharacterPanel ~= false
end

local function SetCharacterPanelEnabled(value)
	if coolstats.SetCharacterPanelEnabled then
		coolstats.SetCharacterPanelEnabled(value, true)
		return
	end
	local db = GetDB()
	if db then
		db.enableCharacterPanel = value ~= false
	end
end

local function GetLootOptions()
	if coolstats.GetLootAlertOptions then
		return coolstats.GetLootAlertOptions()
	end
	local db = GetDB()
	if db then
		db.lootAlerts = db.lootAlerts or {}
		return db.lootAlerts
	end
	return {}
end

local function GetTooltipOptions()
	if coolstats.GetTooltipOptions then
		return coolstats.GetTooltipOptions()
	end
	local db = GetDB()
	if db then
		db.tooltip = db.tooltip or {}
		return db.tooltip
	end
	return {}
end

local function GetBackgroundOptions()
	if coolstats.GetBackgroundOptions then
		return coolstats.GetBackgroundOptions()
	end
	local db = GetDB()
	if db then
		db.backgrounds = db.backgrounds or {}
		db.backgrounds.stats = db.backgrounds.stats or { texture = "default", alpha = 1, contrast = 0, zoom = 1.6, panX = 1, panY = 0, palette = "classic" }
		return db.backgrounds
	end
	return {
		stats = { texture = "default", alpha = 1, contrast = 0, zoom = 1.6, panX = 1, panY = 0, palette = "classic" },
	}
end

local function GetBackgroundGroupOptions(groupKey)
	local options = GetBackgroundOptions()
	options[groupKey] = options[groupKey] or { texture = "default", alpha = 1, contrast = 0, zoom = 1.6, panX = 1, panY = 0, palette = "classic" }
	return options[groupKey]
end

local function GetBackgroundDefaultValue(groupKey, optionKey, fallback)
	local defaults = GetDefaults()
	if defaults and defaults.backgrounds and defaults.backgrounds[groupKey] and defaults.backgrounds[groupKey][optionKey] ~= nil then
		return defaults.backgrounds[groupKey][optionKey]
	end
	return fallback
end

local function GetBackgroundTextureList()
	if coolstats.GetBackgroundTextures then
		return coolstats.GetBackgroundTextures()
	end
	return { { key = "default", label = "Default" } }
end

local function GetBackgroundTextureLabel(key)
	if coolstats.GetBackgroundTextureLabel then
		return coolstats.GetBackgroundTextureLabel(key)
	end
	local textures = GetBackgroundTextureList()
	for index = 1, #textures do
		if textures[index].key == key then
			return textures[index].label
		end
	end
	return "Default"
end

local function GetStatTextPaletteList()
	if coolstats.GetStatTextPalettes then
		return coolstats.GetStatTextPalettes()
	end
	return { { key = "classic", label = "Classic Gold" } }
end

local function GetStatTextPaletteLabel(key)
	if coolstats.GetStatTextPaletteLabel then
		return coolstats.GetStatTextPaletteLabel(key)
	end
	local palettes = GetStatTextPaletteList()
	for index = 1, #palettes do
		if palettes[index].key == key then
			return palettes[index].label
		end
	end
	return "Classic Gold"
end

local function GetItemLevelBadgeOptions()
	if coolstats.GetItemLevelBadgeOptions then
		return coolstats.GetItemLevelBadgeOptions()
	end
	local db = GetDB()
	if db then
		db.itemLevelBadges = db.itemLevelBadges or { position = "default", fontSize = 15 }
		return db.itemLevelBadges
	end
	return { position = "default", fontSize = 15 }
end

local function GetItemLevelBadgePositions()
	if coolstats.GetItemLevelBadgePositions then
		return coolstats.GetItemLevelBadgePositions()
	end
	return {
		{ key = "default", label = "Default" },
		{ key = "lowerLeft", label = "Lower left" },
		{ key = "lowerRight", label = "Lower right" },
		{ key = "off", label = "Off" },
	}
end

local function GetItemLevelBadgePositionLabel(key)
	if coolstats.GetItemLevelBadgePositionLabel then
		return coolstats.GetItemLevelBadgePositionLabel(key)
	end
	local positions = GetItemLevelBadgePositions()
	for index = 1, #positions do
		if positions[index].key == key then
			return positions[index].label
		end
	end
	return "Default"
end

local function RefreshAddon()
	if coolstats.ApplyBackgroundOptions then
		coolstats.ApplyBackgroundOptions()
	end
	if coolstats.RefreshAll then
		coolstats.RefreshAll()
	end
	if coolstats.RefreshOptionsPanel then
		coolstats.RefreshOptionsPanel()
	end
	if coolstats.RefreshBackgroundOptionsPanel then
		coolstats.RefreshBackgroundOptionsPanel()
	end
	if coolstats.RefreshItemLevelOptionsPanel then
		coolstats.RefreshItemLevelOptionsPanel()
	end
	if coolstats.RefreshTooltipOptionsPanel then
		coolstats.RefreshTooltipOptionsPanel()
	end
end

local function SetCheckText(button, label)
	local text = button and button:GetName() and _G[button:GetName() .. "Text"]
	if text then
		text:SetText(label)
		text:SetTextColor(0.86, 0.86, 0.78)
	end
end

local function CreateHeading(parent, text, yOffset)
	local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
	heading:SetText(text)
	heading:SetTextColor(1.0, 0.82, 0.16)
	return heading
end

local function CreateDescription(parent, text, yOffset)
	local description = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	description:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
	description:SetWidth(520)
	description:SetJustifyH("LEFT")
	description:SetText(text)
	description:SetTextColor(0.78, 0.78, 0.72)
	return description
end

local function CreateScrollableOptionsContent(panel, name, contentHeight)
	local scrollFrame = CreateFrame("ScrollFrame", name .. "ScrollFrame", panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 8)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local child = self:GetScrollChild()
		local maxScroll = 0
		if child and self.GetHeight and child.GetHeight then
			maxScroll = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
		end
		local current = self:GetVerticalScroll() or 0
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, current - (delta * 32))))
	end)

	local content = CreateFrame("Frame", name .. "Content", scrollFrame)
	content:SetWidth(560)
	content:SetHeight(contentHeight)
	content.controls = panel.controls
	scrollFrame:SetScrollChild(content)
	panel.scrollFrame = scrollFrame
	panel.content = content
	return content
end

local function CreateCheck(parent, name, label, yOffset, getter, setter, tooltip)
	local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	check.getter = getter
	check.setter = setter
	check.tooltip = tooltip
	SetCheckText(check, label)
	check:SetScript("OnClick", function(self)
		local checked = self:GetChecked() == 1 or self:GetChecked() == true
		if self.setter then
			self.setter(checked)
		end
		RefreshAddon()
	end)
	check:SetScript("OnEnter", function(self)
		if not self.tooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, 1, 0.82, 0.16)
		GameTooltip:AddLine(self.tooltip, 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	check:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = check
	return check
end

local function UpdateQualitySliderText(slider)
	if not slider then
		return
	end
	local quality = math.floor((slider:GetValue() or 3) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText("Minimum loot quality: " .. (QUALITY_LABELS[quality] or tostring(quality)))
	end
end

local function CreateSliderResetButton(parent, slider, yOffset, defaultValue, onReset)
	if not slider then
		return nil
	end
	local button = CreateFrame("Button", slider:GetName() .. "ResetButton", parent, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", 286, yOffset - 3)
	button:SetWidth(56)
	button:SetHeight(20)
	button:SetText("Reset")
	button:SetScript("OnClick", function()
		local value = defaultValue
		if type(defaultValue) == "function" then
			value = defaultValue()
		end
		if onReset then
			onReset(slider, value)
		end
		slider:SetValue(value)
		RefreshAddon()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Reset", 1, 0.82, 0.16)
		GameTooltip:AddLine("Restore this slider to its default value.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function CreateQualitySlider(parent, yOffset)
	local slider = CreateFrame("Slider", "coolstatsLootQualitySlider", parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(2, 5)
	slider:SetValueStep(1)
	slider.controlType = "lootQuality"
	_G[slider:GetName() .. "Low"]:SetText("Uncommon")
	_G[slider:GetName() .. "High"]:SetText("Legendary")
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 3) + 0.5)
		if self.updating then
			UpdateQualitySliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetLootOptions().minQuality = rounded
		UpdateQualitySliderText(self)
	end)
	slider:SetScript("OnMouseUp", function()
		RefreshAddon()
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Loot Alert Threshold", 1, 0.82, 0.16)
		GameTooltip:AddLine("Only show loot toasts for this quality and above. Poor and common items are always ignored.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.qualitySlider = slider
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		local defaults = GetDefaults()
		return defaults and defaults.lootAlerts and defaults.lootAlerts.minQuality or 3
	end, function(self, value)
		GetLootOptions().minQuality = value
		UpdateQualitySliderText(self)
	end)
	return slider
end

local function SetDropDownText(dropdown, text)
	if UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(dropdown, text)
	end
	local label = dropdown and dropdown:GetName() and _G[dropdown:GetName() .. "Text"]
	if label then
		label:SetText(text)
		if dropdown.centerText then
			label:SetJustifyH("CENTER")
			if label.SetJustifyV then
				label:SetJustifyV("MIDDLE")
			end
			label:ClearAllPoints()
			label:SetPoint("CENTER", dropdown, "CENTER", -12, 3)
			label:SetHeight(18)
			if dropdown.textWidth then
				label:SetWidth(dropdown.textWidth)
			end
		end
	end
end

local function CreateBackgroundDropdown(parent, name, labelText, yOffset, groupKey)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	label:SetText(labelText)
	label:SetTextColor(0.86, 0.86, 0.78)

	local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset - 18)
	dropdown.groupKey = groupKey
	dropdown.controlType = "backgroundDropdown"
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dropdown, 230)
	end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(dropdown, function()
			local selected = GetBackgroundGroupOptions(groupKey).texture or "default"
			local textures = GetBackgroundTextureList()
			for index = 1, #textures do
				local textureKey = textures[index].key
				local textureLabel = textures[index].label
				local info = UIDropDownMenu_CreateInfo()
				info.text = textureLabel
				info.value = textureKey
				info.checked = textureKey == selected
				info.func = function()
					GetBackgroundGroupOptions(groupKey).texture = textureKey
					if UIDropDownMenu_SetSelectedValue then
						UIDropDownMenu_SetSelectedValue(dropdown, textureKey)
					end
					SetDropDownText(dropdown, GetBackgroundTextureLabel(textureKey))
					RefreshAddon()
				end
				UIDropDownMenu_AddButton(info)
			end
		end)
	end
	parent.controls[#parent.controls + 1] = dropdown
	return dropdown
end

local function UpdateBackgroundAlphaSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 100) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Opacity") .. ": " .. value .. "%")
	end
end

local function CreateBackgroundAlphaSlider(parent, name, labelText, yOffset, groupKey)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(0, 100)
	slider:SetValueStep(5)
	slider.groupKey = groupKey
	slider.controlType = "backgroundAlpha"
	slider.labelText = labelText
	_G[slider:GetName() .. "Low"]:SetText("Clear")
	_G[slider:GetName() .. "High"]:SetText("Opaque")
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 100) + 0.5)
		if self.updating then
			UpdateBackgroundAlphaSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetBackgroundGroupOptions(self.groupKey).alpha = rounded / 100
		UpdateBackgroundAlphaSliderText(self)
		RefreshAddon()
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(labelText, 1, 0.82, 0.16)
		GameTooltip:AddLine("Controls how opaque this custom background is. Default is 100%, which preserves the current look unless a custom texture is selected.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return (GetBackgroundDefaultValue(groupKey, "alpha", 1) or 1) * 100
	end, function(self, value)
		GetBackgroundGroupOptions(groupKey).alpha = value / 100
		UpdateBackgroundAlphaSliderText(self)
	end)
	return slider
end

local function UpdateBackgroundContrastSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 0) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Background contrast") .. ": " .. value .. "%")
	end
end

local function CreateBackgroundContrastSlider(parent, name, labelText, yOffset, groupKey)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(-100, 100)
	slider:SetValueStep(5)
	slider.groupKey = groupKey
	slider.controlType = "backgroundContrast"
	slider.labelText = labelText
	_G[slider:GetName() .. "Low"]:SetText("Softer")
	_G[slider:GetName() .. "High"]:SetText("Stronger")
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 0) + 0.5)
		if self.updating then
			UpdateBackgroundContrastSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetBackgroundGroupOptions(self.groupKey).contrast = rounded / 100
		UpdateBackgroundContrastSliderText(self)
		RefreshAddon()
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(labelText, 1, 0.82, 0.16)
		GameTooltip:AddLine("Uses a light or dark overlay to make busy background art easier to read. Default is 0%, which leaves the background unchanged.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return (GetBackgroundDefaultValue(groupKey, "contrast", 0) or 0) * 100
	end, function(self, value)
		GetBackgroundGroupOptions(groupKey).contrast = value / 100
		UpdateBackgroundContrastSliderText(self)
	end)
	return slider
end

local function UpdateBackgroundZoomSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 100) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Background zoom") .. ": " .. value .. "%")
	end
end

local function CreateBackgroundZoomSlider(parent, name, labelText, yOffset, groupKey)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(70, 300)
	slider:SetValueStep(5)
	slider.groupKey = groupKey
	slider.controlType = "backgroundZoom"
	slider.labelText = labelText
	_G[slider:GetName() .. "Low"]:SetText("Fit")
	_G[slider:GetName() .. "High"]:SetText("Max")
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 100) + 0.5)
		if self.updating then
			UpdateBackgroundZoomSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetBackgroundGroupOptions(self.groupKey).zoom = rounded / 100
		UpdateBackgroundZoomSliderText(self)
		RefreshAddon()
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(labelText, 1, 0.82, 0.16)
		GameTooltip:AddLine("Scales talent-tree backgrounds proportionally. Lower values show more of the image; higher values fill the tall panel and crop edges.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return (GetBackgroundDefaultValue(groupKey, "zoom", 1.6) or 1.6) * 100
	end, function(self, value)
		GetBackgroundGroupOptions(groupKey).zoom = value / 100
		UpdateBackgroundZoomSliderText(self)
	end)
	return slider
end

local function UpdateBackgroundPanSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 0) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Image position") .. ": " .. value .. "%")
	end
end

local function CreateBackgroundPanSlider(parent, name, labelText, yOffset, groupKey, optionKey, lowText, highText)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(-100, 100)
	slider:SetValueStep(5)
	slider.groupKey = groupKey
	slider.optionKey = optionKey
	slider.controlType = "backgroundPan"
	slider.labelText = labelText
	_G[slider:GetName() .. "Low"]:SetText(lowText)
	_G[slider:GetName() .. "High"]:SetText(highText)
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 0) + 0.5)
		if self.updating then
			UpdateBackgroundPanSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetBackgroundGroupOptions(self.groupKey)[self.optionKey] = rounded / 100
		UpdateBackgroundPanSliderText(self)
		RefreshAddon()
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(labelText, 1, 0.82, 0.16)
		GameTooltip:AddLine("Moves zoomed talent-tree background art inside the stats panel without stretching it.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return (GetBackgroundDefaultValue(groupKey, optionKey, 0) or 0) * 100
	end, function(self, value)
		GetBackgroundGroupOptions(groupKey)[optionKey] = value / 100
		UpdateBackgroundPanSliderText(self)
	end)
	return slider
end

local function CreateStatTextPaletteDropdown(parent, name, labelText, yOffset, groupKey)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	label:SetText(labelText)
	label:SetTextColor(0.86, 0.86, 0.78)

	local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset - 18)
	dropdown.groupKey = groupKey
	dropdown.controlType = "statTextPalette"
	dropdown.centerText = true
	dropdown.textWidth = 140
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dropdown, 180)
	end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(dropdown, function()
			local selected = GetBackgroundGroupOptions(groupKey).palette or "classic"
			local palettes = GetStatTextPaletteList()
			for index = 1, #palettes do
				local paletteKey = palettes[index].key
				local paletteLabel = palettes[index].label
				local info = UIDropDownMenu_CreateInfo()
				info.text = paletteLabel
				info.value = paletteKey
				info.checked = paletteKey == selected
				info.func = function()
					GetBackgroundGroupOptions(groupKey).palette = paletteKey
					if UIDropDownMenu_SetSelectedValue then
						UIDropDownMenu_SetSelectedValue(dropdown, paletteKey)
					end
					SetDropDownText(dropdown, GetStatTextPaletteLabel(paletteKey))
					RefreshAddon()
				end
				UIDropDownMenu_AddButton(info)
			end
		end)
	end
	parent.controls[#parent.controls + 1] = dropdown
	return dropdown
end

local function CreateItemLevelPositionDropdown(parent, name, yOffset)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	label:SetText("Item level position")
	label:SetTextColor(0.86, 0.86, 0.78)

	local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset - 18)
	dropdown.controlType = "itemLevelPosition"
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dropdown, 180)
	end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(dropdown, function()
			local selected = GetItemLevelBadgeOptions().position or "default"
			local positions = GetItemLevelBadgePositions()
			for index = 1, #positions do
				local positionKey = positions[index].key
				local positionLabel = positions[index].label
				local info = UIDropDownMenu_CreateInfo()
				info.text = positionLabel
				info.value = positionKey
				info.checked = positionKey == selected
				info.func = function()
					local db = GetDB()
					GetItemLevelBadgeOptions().position = positionKey
					if db then
						db.showItemLevels = positionKey ~= "off"
					end
					if UIDropDownMenu_SetSelectedValue then
						UIDropDownMenu_SetSelectedValue(dropdown, positionKey)
					end
					SetDropDownText(dropdown, GetItemLevelBadgePositionLabel(positionKey))
					RefreshAddon()
				end
				UIDropDownMenu_AddButton(info)
			end
		end)
	end
	parent.controls[#parent.controls + 1] = dropdown
	return dropdown
end

local function UpdateItemLevelFontSizeSliderText(slider)
	if not slider then
		return
	end
	local baseSize = math.floor((slider:GetValue() or 15) + 0.5)
	local position = GetItemLevelBadgeOptions().position or "default"
	local text = _G[slider:GetName() .. "Text"]
	if text then
		if position == "lowerLeft" or position == "lowerRight" then
			text:SetText("Item level font size: " .. baseSize .. " (corner: " .. math.max(6, math.floor((baseSize * 0.5) + 0.5)) .. ")")
		else
			text:SetText("Item level font size: " .. baseSize)
		end
	end
end

local function CreateItemLevelFontSizeSlider(parent, name, yOffset)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(0, 30)
	slider:SetValueStep(1)
	slider.controlType = "itemLevelFontSize"
	_G[slider:GetName() .. "Low"]:SetText("0")
	_G[slider:GetName() .. "High"]:SetText("30")
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 15) + 0.5)
		if self.updating then
			UpdateItemLevelFontSizeSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetItemLevelBadgeOptions().fontSize = rounded
		UpdateItemLevelFontSizeSliderText(self)
		RefreshAddon()
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Item Level Font Size", 1, 0.82, 0.16)
		GameTooltip:AddLine("Lower-left and lower-right positions automatically use half of this size.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		local defaults = GetDefaults()
		return defaults and defaults.itemLevelBadges and defaults.itemLevelBadges.fontSize or 15
	end, function(self, value)
		GetItemLevelBadgeOptions().fontSize = value
		UpdateItemLevelFontSizeSliderText(self)
	end)
	return slider
end

function coolstats.RefreshOptionsPanel()
	local panel = coolstats.optionsPanel
	if not panel then
		return
	end
	for index = 1, #panel.controls do
		local control = panel.controls[index]
		if control.getter then
			control:SetChecked(control.getter())
		elseif control.controlType == "lootQuality" then
			control.updating = true
			control:SetValue(math.floor((GetLootOptions().minQuality or 3) + 0.5))
			control.updating = nil
			UpdateQualitySliderText(control)
		end
	end
	if panel.qualitySlider then
		panel.qualitySlider.updating = true
		panel.qualitySlider:SetValue(math.floor((GetLootOptions().minQuality or 3) + 0.5))
		panel.qualitySlider.updating = nil
		UpdateQualitySliderText(panel.qualitySlider)
	end
end

function coolstats.ResetOptionsPanelDefaults()
	local db = GetDB()
	local defaults = GetDefaults()
	if not db or not defaults then
		return
	end
	local oldCharacterPanelEnabled = db.enableCharacterPanel ~= false
	db.enableCharacterPanel = defaults.enableCharacterPanel
	db.showStatsPanel = defaults.showStatsPanel
	db.showItemLevels = defaults.showItemLevels
	db.showSlotBorders = defaults.showSlotBorders
	db.cleanGearScoreTooltips = defaults.cleanGearScoreTooltips
	db.tooltip = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.tooltip) or {
		guildRank = true,
		classLine = true,
		target = true,
		raidProgressFallback = true,
		logsSummary = true,
		logsBossDetails = true,
		cacheOnHover = true,
	}
	db.itemLevelBadges = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.itemLevelBadges) or {
		position = "default",
		fontSize = 15,
	}
	db.lootAlerts = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.lootAlerts) or {
		enabled = true,
		minQuality = 3,
		selfLoot = true,
		groupRolls = true,
		professions = false,
		sound = true,
		animations = true,
	}
	RefreshAddon()
	if oldCharacterPanelEnabled ~= (db.enableCharacterPanel ~= false) and coolstats.ShowCharacterPanelReloadPrompt then
		coolstats.ShowCharacterPanelReloadPrompt()
	end
end

function coolstats.RefreshItemLevelOptionsPanel()
	local panel = coolstats.itemLevelOptionsPanel
	if not panel then
		return
	end
	for index = 1, #panel.controls do
		local control = panel.controls[index]
		if control.controlType == "itemLevelPosition" then
			local position = GetItemLevelBadgeOptions().position or "default"
			if UIDropDownMenu_SetSelectedValue then
				UIDropDownMenu_SetSelectedValue(control, position)
			end
			SetDropDownText(control, GetItemLevelBadgePositionLabel(position))
		elseif control.controlType == "itemLevelFontSize" then
			local fontSize = tonumber(GetItemLevelBadgeOptions().fontSize) or 15
			control.updating = true
			control:SetValue(math.floor(fontSize + 0.5))
			control.updating = nil
			UpdateItemLevelFontSizeSliderText(control)
		end
	end
end

function coolstats.ResetItemLevelOptionsPanelDefaults()
	local db = GetDB()
	local defaults = GetDefaults()
	if not db or not defaults then
		return
	end
	db.showItemLevels = defaults.showItemLevels
	db.itemLevelBadges = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.itemLevelBadges) or {
		position = "default",
		fontSize = 15,
	}
	RefreshAddon()
end

function coolstats.RefreshTooltipOptionsPanel()
	local panel = coolstats.tooltipOptionsPanel
	if not panel then
		return
	end
	for index = 1, #panel.controls do
		local control = panel.controls[index]
		if control.getter then
			control:SetChecked(control.getter())
		end
	end
end

function coolstats.ResetTooltipOptionsPanelDefaults()
	local db = GetDB()
	local defaults = GetDefaults()
	if not db or not defaults then
		return
	end
	db.tooltip = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.tooltip) or {
		guildRank = true,
		classLine = true,
		target = true,
		raidProgressFallback = true,
		logsSummary = true,
		logsBossDetails = true,
		cacheOnHover = true,
	}
	RefreshAddon()
end

function coolstats.CreateTooltipOptionsPanel()
	if coolstats.tooltipOptionsPanel then
		return coolstats.tooltipOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsTooltipOptionsPanel", UIParent)
	panel.name = "Tooltip"
	panel.parent = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshTooltipOptionsPanel
	panel.default = coolstats.ResetTooltipOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.tooltipOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsTooltipOptions", 410)
	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Tooltip")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose each coolstats feature that appears when hovering over players.", -42)
	CreateHeading(content, "Player Details", -78)
	CreateCheck(content, "coolstatsTooltipGuildRank", "Show guild rank", -104, function()
		return GetTooltipOptions().guildRank ~= false
	end, function(value)
		GetTooltipOptions().guildRank = value
	end, "Replace the default guild line with the player's guild rank and guild name.")
	CreateCheck(content, "coolstatsTooltipClassLine", "Show class line", -132, function()
		return GetTooltipOptions().classLine ~= false
	end, function(value)
		GetTooltipOptions().classLine = value
	end, "Add a class-colored class name to player tooltips.")
	CreateCheck(content, "coolstatsTooltipTarget", "Show current target", -160, function()
		return GetTooltipOptions().target ~= false
	end, function(value)
		GetTooltipOptions().target = value
	end, "Show who the hovered player is currently targeting.")
	CreateCheck(content, "coolstatsTooltipCacheHover", "Cache inspectable gear on hover", -188, function()
		return GetTooltipOptions().cacheOnHover ~= false
	end, function(value)
		GetTooltipOptions().cacheOnHover = value
	end, "Allow hovering an inspectable player to update their cached gear.")

	CreateHeading(content, "Logs And Progress", -232)
	CreateCheck(content, "coolstatsTooltipLogsSummary", "Show logs summary", -258, function()
		return GetTooltipOptions().logsSummary ~= false
	end, function(value)
		GetTooltipOptions().logsSummary = value
	end, "Show the player's best available logs score.")
	CreateCheck(content, "coolstatsTooltipLogsBosses", "Show boss parses while holding Alt", -286, function()
		return GetTooltipOptions().logsBossDetails ~= false
	end, function(value)
		GetTooltipOptions().logsBossDetails = value
	end, "Show individual boss parses while Alt is held.")
	CreateCheck(content, "coolstatsTooltipRaidFallback", "Show raid progress summary", -314, function()
		return GetTooltipOptions().raidProgressFallback ~= false
	end, function(value)
		GetTooltipOptions().raidProgressFallback = value
	end, "Use available logs for raid progress, or request achievement progress as a fallback when logs are missing.")

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	panel:SetScript("OnShow", coolstats.RefreshTooltipOptionsPanel)
	coolstats.RefreshTooltipOptionsPanel()
	return panel
end

function coolstats.CreateItemLevelOptionsPanel()
	if coolstats.itemLevelOptionsPanel then
		return coolstats.itemLevelOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsItemLevelOptionsPanel", UIParent)
	panel.name = "Item Levels"
	panel.parent = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshItemLevelOptionsPanel
	panel.default = coolstats.ResetItemLevelOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.itemLevelOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsItemLevelOptions", 300)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Item Levels")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose where equipped item levels appear on gear slots and how large the badge text should be.", -42)
	CreateItemLevelPositionDropdown(content, "coolstatsItemLevelPositionDropdown", -84)
	CreateItemLevelFontSizeSlider(content, "coolstatsItemLevelFontSizeSlider", -158)
	CreateDescription(content, "Corner positions automatically render at half the selected font size.", -212)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	panel:SetScript("OnShow", coolstats.RefreshItemLevelOptionsPanel)
	coolstats.RefreshItemLevelOptionsPanel()
	return panel
end

function coolstats.RefreshBackgroundOptionsPanel()
	local panel = coolstats.backgroundOptionsPanel
	if not panel then
		return
	end
	for index = 1, #panel.controls do
		local control = panel.controls[index]
		if control.controlType == "backgroundDropdown" then
			local options = GetBackgroundGroupOptions(control.groupKey)
			local textureKey = options.texture or "default"
			if UIDropDownMenu_SetSelectedValue then
				UIDropDownMenu_SetSelectedValue(control, textureKey)
			end
			SetDropDownText(control, GetBackgroundTextureLabel(textureKey))
		elseif control.controlType == "backgroundAlpha" then
			local options = GetBackgroundGroupOptions(control.groupKey)
			local alpha = tonumber(options.alpha) or 1
			control.updating = true
			control:SetValue(math.floor((alpha * 100) + 0.5))
			control.updating = nil
			UpdateBackgroundAlphaSliderText(control)
		elseif control.controlType == "backgroundContrast" then
			local options = GetBackgroundGroupOptions(control.groupKey)
			local contrast = tonumber(options.contrast) or 0
			control.updating = true
			control:SetValue(math.floor((contrast * 100) + 0.5))
			control.updating = nil
			UpdateBackgroundContrastSliderText(control)
		elseif control.controlType == "backgroundZoom" then
			local options = GetBackgroundGroupOptions(control.groupKey)
			local zoom = tonumber(options.zoom) or 1.6
			control.updating = true
			control:SetValue(math.floor((zoom * 100) + 0.5))
			control.updating = nil
			UpdateBackgroundZoomSliderText(control)
		elseif control.controlType == "backgroundPan" then
			local options = GetBackgroundGroupOptions(control.groupKey)
			local pan = tonumber(options[control.optionKey]) or GetBackgroundDefaultValue(control.groupKey, control.optionKey, 0) or 0
			control.updating = true
			control:SetValue(math.floor((pan * 100) + 0.5))
			control.updating = nil
			UpdateBackgroundPanSliderText(control)
		elseif control.controlType == "statTextPalette" then
			local options = GetBackgroundGroupOptions(control.groupKey)
			local paletteKey = options.palette or "classic"
			if UIDropDownMenu_SetSelectedValue then
				UIDropDownMenu_SetSelectedValue(control, paletteKey)
			end
			SetDropDownText(control, GetStatTextPaletteLabel(paletteKey))
		end
	end
end

function coolstats.ResetBackgroundOptionsPanelDefaults()
	local db = GetDB()
	local defaults = GetDefaults()
	if not db or not defaults then
		return
	end
	db.backgrounds = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.backgrounds) or {
		stats = { texture = "default", alpha = 1, contrast = 0, zoom = 1.6, panX = 1, panY = 0, palette = "classic" },
	}
	RefreshAddon()
end

function coolstats.CreateBackgroundOptionsPanel()
	if coolstats.backgroundOptionsPanel then
		return coolstats.backgroundOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsBackgroundOptionsPanel", UIParent)
	panel.name = "Backgrounds"
	panel.parent = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshBackgroundOptionsPanel
	panel.default = coolstats.ResetBackgroundOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.backgroundOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsBackgroundOptions", 650)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Backgrounds")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose the background texture, readability, zoom, image position, and stat text colors for the coolstats side panel.", -42)

	CreateHeading(content, "Additional Stats", -78)
	CreateDescription(content, "Controls the background texture, opacity, contrast overlay, talent-art zoom, image position, and text palette of the coolstats side panel.", -104)
	CreateBackgroundDropdown(content, "coolstatsStatsBackgroundDropdown", "Stats panel texture", -140, "stats")
	CreateBackgroundAlphaSlider(content, "coolstatsStatsBackgroundAlphaSlider", "Stats panel opacity", -212, "stats")
	CreateBackgroundContrastSlider(content, "coolstatsStatsBackgroundContrastSlider", "Stats panel contrast", -276, "stats")
	CreateBackgroundZoomSlider(content, "coolstatsStatsBackgroundZoomSlider", "Stats panel zoom", -340, "stats")
	CreateBackgroundPanSlider(content, "coolstatsStatsBackgroundPanXSlider", "Image horizontal position", -404, "stats", "panX", "Left", "Right")
	CreateBackgroundPanSlider(content, "coolstatsStatsBackgroundPanYSlider", "Image vertical position", -468, "stats", "panY", "Up", "Down")
	CreateStatTextPaletteDropdown(content, "coolstatsStatsTextPaletteDropdown", "Stats text palette", -532, "stats")

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	panel:SetScript("OnShow", coolstats.RefreshBackgroundOptionsPanel)
	coolstats.RefreshBackgroundOptionsPanel()
	return panel
end

function coolstats.CreateOptionsPanel()
	if coolstats.optionsPanel then
		return coolstats.optionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsOptionsPanel", UIParent)
	panel.name = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshOptionsPanel
	panel.default = coolstats.ResetOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.optionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsMainOptions", 620)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Character panel, stat popouts, favourites, and loot alert settings.", -42)

	CreateHeading(content, "Character Panel", -78)
	CreateCheck(content, "coolstatsOptionCharacterPanel", "Enable character panel features", -104, function()
		return IsCharacterPanelEnabled()
	end, function(value)
		SetCharacterPanelEnabled(value)
	end, "Requires a UI reload. Disable this to keep UwU Logs features without loading the coolstats character-panel replacement, item badges, slot coloring, or GearScore tooltip cleanup.")
	CreateCheck(content, "coolstatsOptionShowPanel", "Show side stats panel", -132, function()
		return GetDB() and GetDB().showStatsPanel
	end, function(value)
		GetDB().showStatsPanel = value
	end, "Show the extended stats panel next to the character frame.")
	CreateCheck(content, "coolstatsOptionItemLevels", "Show item level badges", -160, function()
		return GetDB() and GetDB().showItemLevels
	end, function(value)
		local db = GetDB()
		db.showItemLevels = value
		if value and GetItemLevelBadgeOptions().position == "off" then
			GetItemLevelBadgeOptions().position = "default"
		end
	end, "Show item level labels on equipped gear slots.")
	CreateCheck(content, "coolstatsOptionSlotBorders", "Color slot borders by GearScore", -188, function()
		return GetDB() and GetDB().showSlotBorders
	end, function(value)
		GetDB().showSlotBorders = value
	end, "Color equipment slot borders using the item's score color.")
	CreateCheck(content, "coolstatsOptionTooltipCleanup", "Clean GearScore tooltip spam", -216, function()
		return GetDB() and GetDB().cleanGearScoreTooltips
	end, function(value)
		GetDB().cleanGearScoreTooltips = value
	end, "Hide noisy GearScore lines from item tooltips.")

	CreateHeading(content, "Loot Alerts", -264)
	CreateCheck(content, "coolstatsOptionLootEnabled", "Enable loot alerts", -290, function()
		return GetLootOptions().enabled
	end, function(value)
		GetLootOptions().enabled = value
	end, "Show pretty loot popups for items that pass the quality threshold.")
	CreateQualitySlider(content, -338)
	CreateCheck(content, "coolstatsOptionLootSelf", "Show items I loot", -392, function()
		return GetLootOptions().selfLoot
	end, function(value)
		GetLootOptions().selfLoot = value
	end, "Show a toast when you personally loot an item.")
	CreateCheck(content, "coolstatsOptionLootRolls", "Show group-roll wins", -420, function()
		return GetLootOptions().groupRolls
	end, function(value)
		GetLootOptions().groupRolls = value
	end, "Show a single toast when you win a group loot roll; the later looted-item message is suppressed.")
	CreateCheck(content, "coolstatsOptionLootProfessions", "Show profession crafts", -448, function()
		return GetLootOptions().professions
	end, function(value)
		GetLootOptions().professions = value
	end, "Show loot toasts for items you create with professions.")
	CreateCheck(content, "coolstatsOptionLootSound", "Play loot alert sounds", -476, function()
		return GetLootOptions().sound
	end, function(value)
		GetLootOptions().sound = value
	end, "Play a short sound when a loot alert appears.")
	CreateCheck(content, "coolstatsOptionLootAnimations", "Play loot alert glows", -504, function()
		return GetLootOptions().animations
	end, function(value)
		GetLootOptions().animations = value
	end, "Play the shine/glow flourish on loot alerts.")

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	coolstats.CreateItemLevelOptionsPanel()
	coolstats.CreateBackgroundOptionsPanel()
	coolstats.CreateTooltipOptionsPanel()
	panel:SetScript("OnShow", coolstats.RefreshOptionsPanel)
	coolstats.RefreshOptionsPanel()
	return panel
end

function coolstats.OpenOptionsPanel()
	local panel = coolstats.CreateOptionsPanel()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

function coolstats.OpenBackgroundOptionsPanel()
	coolstats.CreateOptionsPanel()
	local panel = coolstats.CreateBackgroundOptionsPanel()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

function coolstats.OpenItemLevelOptionsPanel()
	coolstats.CreateOptionsPanel()
	local panel = coolstats.CreateItemLevelOptionsPanel()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

coolstats.CreateOptionsPanel()
