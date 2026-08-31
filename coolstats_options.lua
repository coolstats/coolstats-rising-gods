local coolstats = _G.coolstats or {}

local QUALITY_LABELS = {
	[2] = "Uncommon",
	[3] = "Rare",
	[4] = "Epic",
	[5] = "Legendary",
}

local CHARACTER_PANEL_CATEGORY_NAME = "Character Panel"
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

local function GetItemLevelBadgeColorMode()
	if coolstats.GetItemLevelBadgeColorMode then
		return coolstats.GetItemLevelBadgeColorMode()
	end
	local options = GetItemLevelBadgeOptions()
	if options.colorMode == "quality" then
		return "quality"
	end
	return "score"
end

local function GetItemLevelBadgePositions()
	if coolstats.GetItemLevelBadgePositions then
		return coolstats.GetItemLevelBadgePositions()
	end
	return {
		{ key = "default", label = "Default" },
		{ key = "upperLeft", label = "Upper left" },
		{ key = "upperRight", label = "Upper right" },
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

local function GetPaperDollGemOptions()
	local db = GetDB()
	local defaults = GetDefaults()
	if db then
		db.paperDollGems = db.paperDollGems or {}
		if defaults and defaults.paperDollGems then
			for key, value in pairs(defaults.paperDollGems) do
				if db.paperDollGems[key] == nil then
					db.paperDollGems[key] = value
				end
			end
		end
		return db.paperDollGems
	end
	return defaults and defaults.paperDollGems or { size = 14, iconScale = 1, spacing = 7, circleScale = 1, prongScale = 0.82 }
end

local function GetPaperDollGemDefaultValue(key, fallback)
	local defaults = GetDefaults()
	if defaults and defaults.paperDollGems and defaults.paperDollGems[key] ~= nil then
		return defaults.paperDollGems[key]
	end
	return fallback
end

local function GetModelScoreOptions()
	local db = GetDB()
	local defaults = GetDefaults()
	if db then
		db.modelScore = db.modelScore or {}
		if defaults and defaults.modelScore then
			for key, value in pairs(defaults.modelScore) do
				if db.modelScore[key] == nil then
					db.modelScore[key] = value
				end
			end
		end
		return db.modelScore
	end
	return defaults and defaults.modelScore or { x = 22, y = 7 }
end

local function GetModelScoreDefaultValue(key, fallback)
	local defaults = GetDefaults()
	if defaults and defaults.modelScore and defaults.modelScore[key] ~= nil then
		return defaults.modelScore[key]
	end
	return fallback
end

local function GetPaperDollModelOptions()
	local db = GetDB()
	local defaults = GetDefaults()
	if db then
		db.paperDollModel = db.paperDollModel or {}
		if defaults and defaults.paperDollModel then
			for key, value in pairs(defaults.paperDollModel) do
				if db.paperDollModel[key] == nil then
					db.paperDollModel[key] = value
				end
			end
		end
		return db.paperDollModel
	end
	return defaults and defaults.paperDollModel or { rotation = 0 }
end

local function GetPaperDollModelDefaultValue(key, fallback)
	local defaults = GetDefaults()
	if defaults and defaults.paperDollModel and defaults.paperDollModel[key] ~= nil then
		return defaults.paperDollModel[key]
	end
	return fallback
end

local function RefreshAddon(scope)
	scope = scope or "all"
	local refreshAll = scope == "all"
	local refreshCharacter = refreshAll or scope == "character" or scope == "itemLevels" or scope == "paperDoll" or scope == "modelScore" or scope == "background"
	local refreshBackground = refreshAll or scope == "background" or scope == "character"
	local refreshBrowser = refreshAll or scope == "tooltip" or scope == "browser"

	if refreshBackground and coolstats.ApplyBackgroundOptions then
		coolstats.ApplyBackgroundOptions()
	end
	if refreshCharacter and (scope == "itemLevels" or scope == "paperDoll" or scope == "modelScore") and coolstats.RunCharacterPanelUpdateCategories then
		coolstats.RunCharacterPanelUpdateCategories({ gear = true, layout = true })
	elseif refreshCharacter and scope == "background" and coolstats.RunCharacterPanelUpdateCategories then
		coolstats.RunCharacterPanelUpdateCategories({ stats = true, layout = true })
	elseif refreshCharacter and coolstats.RefreshAll then
		coolstats.RefreshAll()
	end
	if refreshAll and coolstats.RefreshOptionsPanel then
		coolstats.RefreshOptionsPanel()
	end
	if refreshCharacter and coolstats.RefreshCharacterPanelOptionsPanel then
		coolstats.RefreshCharacterPanelOptionsPanel()
	end
	if refreshBackground and coolstats.RefreshBackgroundOptionsPanel then
		coolstats.RefreshBackgroundOptionsPanel()
	end
	if (refreshAll or scope == "itemLevels") and coolstats.RefreshItemLevelOptionsPanel then
		coolstats.RefreshItemLevelOptionsPanel()
	end
	if (refreshAll or scope == "loot") and coolstats.RefreshLootToastOptionsPanel then
		coolstats.RefreshLootToastOptionsPanel()
	end
	if (refreshAll or scope == "tooltip" or scope == "browser") and coolstats.RefreshTooltipOptionsPanel then
		coolstats.RefreshTooltipOptionsPanel()
	end
	if refreshBrowser and coolstats.cachedPlayerBrowser and coolstats.cachedPlayerBrowser.IsShown
		and coolstats.cachedPlayerBrowser:IsShown()
		and coolstats.RefreshCachedPlayerBrowser then
		coolstats.RefreshCachedPlayerBrowser(true)
	elseif refreshBrowser and coolstats.InvalidateCachedPlayerBrowserIndex then
		coolstats.InvalidateCachedPlayerBrowserIndex("options")
	end
end

local function SetCheckText(button, label)
	local text = button and button:GetName() and _G[button:GetName() .. "Text"]
	if text then
		if text.SetFontObject then
			text:SetFontObject(GameFontHighlightSmall)
		end
		local parent = button:GetParent()
		local width = button.checkTextWidth or (parent and parent.checkTextWidth)
		if width then
			text:SetWidth(width)
			text:SetJustifyH("LEFT")
		end
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
	description:SetWidth(parent.descriptionWidth or 520)
	description:SetJustifyH("LEFT")
	description:SetText(text)
	description:SetTextColor(0.78, 0.78, 0.72)
	parent.descriptions = parent.descriptions or {}
	parent.descriptions[#parent.descriptions + 1] = description
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

local function SetOptionsContentWidth(content, width)
	if content and width then
		content:SetWidth(width)
		content.descriptionWidth = width - 32
	end
end

local function CreateOptionsColumn(parent, name, xOffset, yOffset, width, height)
	local column = CreateFrame("Frame", name, parent)
	column:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	column:SetWidth(width)
	column:SetHeight(height)
	column.controls = parent.controls
	column.descriptionWidth = width - 24
	column.checkTextWidth = width - 54
	return column
end

local function GetShortUwURaidLayerName(name)
	name = tostring(name or "")
	if string.find(name, "Icecrown", 1, true) then
		return "ICC"
	elseif string.find(name, "Ruby", 1, true) then
		return "RS"
	elseif string.find(name, "Trial", 1, true) then
		return "TOGC"
	elseif string.find(name, "Vault", 1, true) then
		return "VoA"
	end
	return name
end

local function FormatCompactPlayerCount(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	if value < 1000 then
		return tostring(value)
	end
	local tenths = math.floor((value + 50) / 100)
	local whole = math.floor(tenths / 10)
	local fraction = tenths - (whole * 10)
	if fraction <= 0 or whole >= 100 then
		return tostring(whole) .. "k"
	end
	return tostring(whole) .. "." .. tostring(fraction) .. "k"
end

local function CreateCheck(parent, name, label, yOffset, getter, setter, tooltip, refreshScope)
	local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	check.getter = getter
	check.setter = setter
	check.tooltip = tooltip
	check.refreshScope = refreshScope
	check.labelText = label
	SetCheckText(check, label)
	check:SetScript("OnClick", function(self)
		local checked = self:GetChecked() == 1 or self:GetChecked() == true
		if self.setter then
			self.setter(checked)
		end
		RefreshAddon(self.refreshScope)
	end)
	check:SetScript("OnEnter", function(self)
		if not self.tooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipTitle or label, 1, 0.82, 0.16)
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

local function GetRealmPlayerLimitTotal()
	local total = coolstats.GetRealmDataTotalPlayerCount and coolstats.GetRealmDataTotalPlayerCount() or nil
	total = math.floor((tonumber(total) or 0) + 0.5)
	if total < 0 then
		total = 0
	end
	return total
end

local function GetDefaultPlayerLimitChunkCount(total)
	total = math.floor((tonumber(total) or 0) + 0.5)
	if total <= 0 then
		return 1
	end
	local chunkCount = math.ceil(total / 3000)
	if total >= 6000 and chunkCount < 6 then
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

local function GetRealmPlayerLimitSteps()
	if coolstats.GetRealmDataPlayerLoadSteps then
		local steps = coolstats.GetRealmDataPlayerLoadSteps()
		if type(steps) == "table" and #steps > 0 then
			return steps
		end
	end
	local total = GetRealmPlayerLimitTotal()
	if total <= 0 then
		return { 0 }
	end
	local steps = { 0 }
	local chunkCount = GetDefaultPlayerLimitChunkCount(total)
	local chunkSize = math.ceil(total / chunkCount)
	for index = 1, chunkCount do
		local value = math.min(total, index * chunkSize)
		if value > steps[#steps] then
			steps[#steps + 1] = value
		end
	end
	if steps[#steps] ~= total then
		steps[#steps + 1] = total
	end
	return steps
end

local function RoundUwUPlayerLoadLimit(value, total)
	total = math.floor((tonumber(total) or GetRealmPlayerLimitTotal()) + 0.5)
	value = tonumber(value) or total
	if total <= 0 then
		return 0
	end
	local steps = GetRealmPlayerLimitSteps()
	local best = steps[#steps] or total
	local bestDistance = math.abs(value - best)
	for index = 1, #steps do
		local stepValue = math.floor((tonumber(steps[index]) or 0) + 0.5)
		local distance = math.abs(value - stepValue)
		if distance < bestDistance then
			best = stepValue
			bestDistance = distance
		end
	end
	return math.max(0, math.min(total, best))
end

local function GetUwUPlayerLoadStepIndexForLimit(limit, total, steps)
	steps = type(steps) == "table" and steps or GetRealmPlayerLimitSteps()
	local chunkCount = math.max(0, #steps - 1)
	if limit == nil then
		return chunkCount
	end
	limit = RoundUwUPlayerLoadLimit(limit, total)
	local bestIndex = chunkCount
	local bestDistance = math.huge
	for index = 0, chunkCount do
		local stepValue = math.floor((tonumber(steps[index + 1]) or 0) + 0.5)
		local distance = math.abs(limit - stepValue)
		if distance < bestDistance then
			bestIndex = index
			bestDistance = distance
		end
	end
	return bestIndex
end

local function ClampUwUPlayerLoadStepIndex(value, steps)
	steps = type(steps) == "table" and steps or GetRealmPlayerLimitSteps()
	local chunkCount = math.max(0, #steps - 1)
	local index = math.floor((tonumber(value) or chunkCount) + 0.5)
	if index < 0 then
		return 0
	elseif index > chunkCount then
		return chunkCount
	end
	return index
end

local function GetUwUPlayerLoadLimitForStepIndex(index, steps, total)
	steps = type(steps) == "table" and steps or GetRealmPlayerLimitSteps()
	total = math.floor((tonumber(total) or GetRealmPlayerLimitTotal()) + 0.5)
	index = ClampUwUPlayerLoadStepIndex(index, steps)
	local value = math.floor((tonumber(steps[index + 1]) or 0) + 0.5)
	if total > 0 and value > total then
		return total
	end
	return value
end

local function GetUwUPlayerLoadSliderValue()
	local total = GetRealmPlayerLimitTotal()
	local raw = tonumber(GetTooltipOptions().uwuPlayerLoadLimit)
	local steps = GetRealmPlayerLimitSteps()
	if raw == nil then
		return math.max(0, #steps - 1)
	end
	return GetUwUPlayerLoadStepIndexForLimit(raw, total, steps)
end

local function GetUwUPlayerLoadChunkText(loadedChunks, steps)
	steps = type(steps) == "table" and steps or GetRealmPlayerLimitSteps()
	local chunkCount = math.max(0, #steps - 1)
	if chunkCount <= 0 then
		return nil
	end
	loadedChunks = ClampUwUPlayerLoadStepIndex(loadedChunks, steps)
	return string.format(" (%d/%d chunks)", loadedChunks, chunkCount)
end

local function GetUwUPlayerLoadReloadText(limit, total, compact)
	local loaded = coolstats.GetRealmDataLoadedPlayerCount and coolstats.GetRealmDataLoadedPlayerCount() or nil
	loaded = loaded and math.floor((tonumber(loaded) or 0) + 0.5) or nil
	total = math.floor((tonumber(total) or 0) + 0.5)
	limit = math.floor((tonumber(limit) or total) + 0.5)
	if loaded and total > 0 and loaded < total and limit > loaded then
		if compact then
			return " /reload"
		end
		return string.format(" after /reload (%d loaded now)", loaded)
	end
	return ""
end

local function UpdateUwUPlayerLoadLimitSliderRange(slider)
	if not slider then
		return
	end
	local total = GetRealmPlayerLimitTotal()
	local steps = GetRealmPlayerLimitSteps()
	local chunkCount = math.max(0, #steps - 1)
	local maxValue = chunkCount > 0 and chunkCount or 1
	slider.totalPlayers = total
	slider.playerLoadSteps = steps
	slider.playerLoadChunkCount = chunkCount
	slider:SetMinMaxValues(0, maxValue)
	slider:SetValueStep(1)
	_G[slider:GetName() .. "Low"]:SetText("0")
	_G[slider:GetName() .. "High"]:SetText(tostring(total))
	local lowLabel = _G[slider:GetName() .. "Low"]
	if lowLabel then
		lowLabel:ClearAllPoints()
		lowLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -2, -7)
		lowLabel:SetWidth(72)
		lowLabel:SetJustifyH("LEFT")
	end
	local highLabel = _G[slider:GetName() .. "High"]
	if highLabel then
		highLabel:ClearAllPoints()
		highLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 2, -7)
		highLabel:SetWidth(86)
		highLabel:SetJustifyH("RIGHT")
	end
end

local function UpdateUwUPlayerLoadLimitSliderText(slider)
	if not slider then
		return
	end
	local total = slider.totalPlayers or GetRealmPlayerLimitTotal()
	local steps = slider.playerLoadSteps or GetRealmPlayerLimitSteps()
	local chunkCount = math.max(0, #steps - 1)
	local stepIndex = ClampUwUPlayerLoadStepIndex(slider:GetValue(), steps)
	local limit = GetUwUPlayerLoadLimitForStepIndex(stepIndex, steps, total)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		if total <= 0 then
			text:SetText(slider.compactLabel and "Load: no data" or "UwU data load: no realm data found")
		elseif stepIndex >= chunkCount then
			if slider.compactLabel then
				text:SetText("Load: all " .. FormatCompactPlayerCount(total) .. GetUwUPlayerLoadReloadText(total, total, true))
			else
				text:SetText("UwU data load: All " .. tostring(total) .. " players" .. GetUwUPlayerLoadReloadText(total, total))
			end
		else
			if slider.compactLabel then
				text:SetText("Load: " .. FormatCompactPlayerCount(limit) .. "/" .. FormatCompactPlayerCount(total) .. GetUwUPlayerLoadReloadText(limit, total, true))
			else
				text:SetText("UwU data load: Top " .. tostring(limit) .. " / " .. tostring(total) .. " players" .. (GetUwUPlayerLoadChunkText(stepIndex, steps) or "") .. GetUwUPlayerLoadReloadText(limit, total))
			end
		end
	end
end

local function CreateSliderResetButton(parent, slider, yOffset, defaultValue, onReset, refreshScope)
	if not slider then
		return nil
	end
	local button = CreateFrame("Button", slider:GetName() .. "ResetButton", parent, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.sliderResetX or 286, yOffset - 3)
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
		RefreshAddon(refreshScope)
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
	slider.resetButton = button
	return button
end

local function CreateQualitySlider(parent, yOffset)
	local slider = CreateFrame("Slider", "coolstatsLootQualitySlider", parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(parent.sliderWidth or 240)
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
		RefreshAddon("loot")
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
	end, "loot")
	return slider
end

local function CreateUwUPlayerLoadLimitSlider(parent, yOffset)
	local slider = CreateFrame("Slider", "coolstatsUwUPlayerLoadLimitSlider", parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(parent.sliderWidth or 240)
	slider.controlType = "uwuPlayerLoadLimit"
	slider.layoutYOffset = yOffset
	UpdateUwUPlayerLoadLimitSliderRange(slider)
	local label = _G[slider:GetName() .. "Text"]
	if label then
		label:ClearAllPoints()
		label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 8)
		label:SetWidth(parent.sliderLabelWidth or 510)
		label:SetJustifyH("LEFT")
	end
	slider:SetScript("OnValueChanged", function(self, value)
		local total = self.totalPlayers or GetRealmPlayerLimitTotal()
		local steps = self.playerLoadSteps or GetRealmPlayerLimitSteps()
		local chunkCount = math.max(0, #steps - 1)
		local rounded = ClampUwUPlayerLoadStepIndex(value, steps)
		if self.updating then
			UpdateUwUPlayerLoadLimitSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		local options = GetTooltipOptions()
		local previous = tonumber(options.uwuPlayerLoadLimit)
		local limit = GetUwUPlayerLoadLimitForStepIndex(rounded, steps, total)
		if total > 0 and rounded >= chunkCount then
			options.uwuPlayerLoadLimit = nil
		else
			options.uwuPlayerLoadLimit = limit
		end
		if previous ~= tonumber(options.uwuPlayerLoadLimit) then
			self.pendingReloadPrompt = true
		end
		UpdateUwUPlayerLoadLimitSliderText(self)
	end)
	slider:SetScript("OnMouseUp", function(self)
		RefreshAddon("browser")
		if self.pendingReloadPrompt and coolstats.ShowUwUDataReloadPrompt then
			self.pendingReloadPrompt = nil
			coolstats.ShowUwUDataReloadPrompt()
		end
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("UwU Data Player Limit", 1, 0.82, 0.16)
		GameTooltip:AddLine("Snaps to generated data chunks. Lowering updates the browser immediately. Increasing above loaded chunks needs /reload.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.uwuPlayerLoadLimitSlider = slider
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return math.max(0, #GetRealmPlayerLimitSteps() - 1)
	end, function(self, value)
		GetTooltipOptions().uwuPlayerLoadLimit = nil
		UpdateUwUPlayerLoadLimitSliderRange(self)
		UpdateUwUPlayerLoadLimitSliderText(self)
		if coolstats.ShowUwUDataReloadPrompt then
			coolstats.ShowUwUDataReloadPrompt()
		end
	end, "browser")
	return slider
end

local function GetUwURaidLayerChoices()
	if coolstats.GetUwUDataRaidLayerChoices then
		return coolstats.GetUwUDataRaidLayerChoices()
	end
	return {}
end

local function UpdateUwURaidLayerCheck(check)
	if not check then
		return
	end
	local choices = GetUwURaidLayerChoices()
	local choice = choices[check.layerIndex]
	if not choice then
		check.raidLayerKey = nil
		check:Hide()
		return
	end
	check.raidLayerKey = choice.key
	check.raidLayerName = choice.name
	local parent = check:GetParent()
	local layerName = parent and parent.shortRaidLayerLabels and GetShortUwURaidLayerName(choice.name) or tostring(choice.name)
	SetCheckText(check, "Load " .. layerName)
	check.tooltipTitle = tostring(choice.name) .. " Logs"
	check.tooltip = "When unchecked, this current-realm raid's boss parse payload is not loaded after /reload. The raid is also hidden from boss dropdowns and log panels."
	check:SetChecked(choice.enabled ~= false)
	check:Show()
end

local function CreateUwURaidLayerCheck(parent, index, yOffset)
	local check = CreateCheck(parent, "coolstatsTooltipRaidLayer" .. tostring(index), "Load raid boss logs", yOffset, function()
		local choices = GetUwURaidLayerChoices()
		local choice = choices[index]
		return not choice or choice.enabled ~= false
	end, function(value)
		local choices = GetUwURaidLayerChoices()
		local choice = choices[index]
		if choice and coolstats.SetUwURaidLayerEnabled then
			local data = coolstatsUwUData
			coolstats.SetUwURaidLayerEnabled(data and data.realm, data and data.phaseId, choice.key, value)
			if coolstats.ShowUwUDataReloadPrompt then
				coolstats.ShowUwUDataReloadPrompt()
			end
		end
	end, "When unchecked, this current-realm raid's boss parse payload is not loaded after /reload.", "browser")
	check.controlType = "uwuRaidLayer"
	check.layerIndex = index
	UpdateUwURaidLayerCheck(check)
	return check
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
					RefreshAddon("background")
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
		RefreshAddon("background")
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
	end, "background")
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
		RefreshAddon("background")
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
	end, "background")
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
		RefreshAddon("background")
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
	end, "background")
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
		RefreshAddon("background")
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
	end, "background")
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
					RefreshAddon("background")
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
					RefreshAddon("itemLevels")
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
		if position == "upperLeft" or position == "upperRight" or position == "lowerLeft" or position == "lowerRight" then
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
		RefreshAddon("itemLevels")
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Item Level Font Size", 1, 0.82, 0.16)
		GameTooltip:AddLine("Corner positions automatically use half of this size.", 0.86, 0.86, 0.78, true)
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
	end, "itemLevels")
	return slider
end

local function UpdatePaperDollGemSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 0) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Gem option") .. ": " .. tostring(value) .. (slider.valueSuffix or ""))
	end
end

local function CreatePaperDollGemSlider(parent, name, labelText, yOffset, optionKey, minValue, maxValue, step, valueSuffix)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider.controlType = "paperDollGemSlider"
	slider.optionKey = optionKey
	slider.labelText = labelText
	slider.valueSuffix = valueSuffix or ""
	_G[slider:GetName() .. "Low"]:SetText(tostring(minValue) .. slider.valueSuffix)
	_G[slider:GetName() .. "High"]:SetText(tostring(maxValue) .. slider.valueSuffix)
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = value
		if self.step and self.step > 0 then
			rounded = math.floor((value / self.step) + 0.5) * self.step
		end
		rounded = math.max(minValue, math.min(maxValue, rounded))
		if self.updating then
			UpdatePaperDollGemSliderText(self)
			return
		end
		if math.abs(self:GetValue() - rounded) > 0.001 then
			self:SetValue(rounded)
			return
		end
		GetPaperDollGemOptions()[optionKey] = rounded / (valueSuffix == "%" and 100 or 1)
		UpdatePaperDollGemSliderText(self)
		RefreshAddon("paperDoll")
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(labelText, 1, 0.82, 0.16)
		GameTooltip:AddLine("Adjust paperdoll gem icon visuals.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		local value = GetPaperDollGemDefaultValue(optionKey, minValue)
		if valueSuffix == "%" then
			value = value * 100
		end
		return value
	end, function(self, value)
		GetPaperDollGemOptions()[optionKey] = value / (valueSuffix == "%" and 100 or 1)
		UpdatePaperDollGemSliderText(self)
	end, "paperDoll")
	return slider
end

local function UpdateModelScoreSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 0) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Model score") .. ": " .. tostring(value) .. "px")
	end
end

local function CreateModelScoreSlider(parent, name, labelText, yOffset, optionKey, minValue, maxValue)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(1)
	slider.controlType = "modelScoreSlider"
	slider.optionKey = optionKey
	slider.labelText = labelText
	_G[slider:GetName() .. "Low"]:SetText(tostring(minValue))
	_G[slider:GetName() .. "High"]:SetText(tostring(maxValue))
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor((value or 0) + 0.5)
		rounded = math.max(minValue, math.min(maxValue, rounded))
		if self.updating then
			UpdateModelScoreSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetModelScoreOptions()[optionKey] = rounded
		UpdateModelScoreSliderText(self)
		RefreshAddon("modelScore")
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(labelText, 1, 0.82, 0.16)
		GameTooltip:AddLine("Move the GearScore and Item Level text on the paperdoll model.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return GetModelScoreDefaultValue(optionKey, optionKey == "x" and 22 or 7)
	end, function(self, value)
		GetModelScoreOptions()[optionKey] = value
		UpdateModelScoreSliderText(self)
	end, "modelScore")
	return slider
end

local function UpdatePaperDollModelRotationSliderText(slider)
	if not slider then
		return
	end
	local value = math.floor((slider:GetValue() or 0) + 0.5)
	local text = _G[slider:GetName() .. "Text"]
	if text then
		text:SetText((slider.labelText or "Model rotation") .. ": " .. tostring(value) .. " deg")
	end
end

local function CreatePaperDollModelRotationSlider(parent, name, yOffset)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, yOffset)
	slider:SetWidth(240)
	slider:SetMinMaxValues(0, 360)
	slider:SetValueStep(5)
	slider.controlType = "paperDollModelRotation"
	slider.labelText = "Model rotation"
	_G[slider:GetName() .. "Low"]:SetText("0")
	_G[slider:GetName() .. "High"]:SetText("360")
	slider:SetScript("OnValueChanged", function(self, value)
		local rounded = math.floor(((value or 0) / 5) + 0.5) * 5
		rounded = math.max(0, math.min(360, rounded))
		if self.updating then
			UpdatePaperDollModelRotationSliderText(self)
			return
		end
		if self:GetValue() ~= rounded then
			self:SetValue(rounded)
			return
		end
		GetPaperDollModelOptions().rotation = rounded
		UpdatePaperDollModelRotationSliderText(self)
		RefreshAddon("paperDoll")
	end)
	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Model Rotation", 1, 0.82, 0.16)
		GameTooltip:AddLine("Adjusts the paperdoll model facing when the client exposes model rotation support.", 0.86, 0.86, 0.78, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	parent.controls[#parent.controls + 1] = slider
	CreateSliderResetButton(parent, slider, yOffset, function()
		return GetPaperDollModelDefaultValue("rotation", 0) or 0
	end, function(self, value)
		GetPaperDollModelOptions().rotation = value
		UpdatePaperDollModelRotationSliderText(self)
	end, "paperDoll")
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

function coolstats.RefreshCharacterPanelOptionsPanel()
	local panel = coolstats.characterPanelOptionsPanel
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
		elseif control.controlType == "paperDollGemSlider" then
			local value = tonumber(GetPaperDollGemOptions()[control.optionKey]) or GetPaperDollGemDefaultValue(control.optionKey, 1)
			if control.valueSuffix == "%" then
				value = value * 100
			end
			control.updating = true
			control:SetValue(math.floor(value + 0.5))
			control.updating = nil
			UpdatePaperDollGemSliderText(control)
		elseif control.controlType == "modelScoreSlider" then
			local value = tonumber(GetModelScoreOptions()[control.optionKey]) or GetModelScoreDefaultValue(control.optionKey, 0)
			control.updating = true
			control:SetValue(math.floor(value + 0.5))
			control.updating = nil
			UpdateModelScoreSliderText(control)
		elseif control.controlType == "paperDollModelRotation" then
			local value = tonumber(GetPaperDollModelOptions().rotation) or GetPaperDollModelDefaultValue("rotation", 0)
			control.updating = true
			control:SetValue(math.floor(value + 0.5))
			control.updating = nil
			UpdatePaperDollModelRotationSliderText(control)
		elseif control.controlType == "backgroundDropdown" then
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
		elseif control.getter then
			control:SetChecked(control.getter())
		end
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
	db.showPaperDollGems = defaults.showPaperDollGems
	db.hidePaperDollResistances = defaults.hidePaperDollResistances
	db.hidePaperDollRotateButtons = defaults.hidePaperDollRotateButtons
	db.cleanGearScoreTooltips = defaults.cleanGearScoreTooltips
	db.tooltip = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.tooltip) or {
		guildRank = true,
		classLine = true,
		target = true,
		raidProgressFallback = true,
		logsSummary = true,
		logsBossDetails = true,
		cacheOnHover = true,
		cacheInspectGear = true,
		cacheInspectTalents = true,
		uwuRaidLayers = {},
	}
	db.tooltip.uwuPlayerLoadLimit = nil
	db.itemLevelBadges = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.itemLevelBadges) or {
		position = "default",
		fontSize = 15,
		colorMode = "score",
	}
	db.paperDollGems = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.paperDollGems) or {
		size = 14,
		iconScale = 1,
		spacing = 7,
		circleScale = 1,
		prongScale = 0.82,
	}
	db.modelScore = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.modelScore) or {
		x = 120,
		y = 30,
	}
	db.paperDollModel = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.paperDollModel) or {
		rotation = 0,
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

function coolstats.ResetCharacterPanelOptionsPanelDefaults()
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
	db.showPaperDollGems = defaults.showPaperDollGems
	db.hidePaperDollResistances = defaults.hidePaperDollResistances
	db.hidePaperDollRotateButtons = defaults.hidePaperDollRotateButtons
	db.cleanGearScoreTooltips = defaults.cleanGearScoreTooltips
	db.itemLevelBadges = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.itemLevelBadges) or {
		position = "default",
		fontSize = 15,
		colorMode = "score",
	}
	db.paperDollGems = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.paperDollGems) or {
		size = 14,
		iconScale = 1,
		spacing = 7,
		circleScale = 1,
		prongScale = 0.82,
	}
	db.modelScore = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.modelScore) or {
		x = 120,
		y = 30,
	}
	db.paperDollModel = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.paperDollModel) or {
		rotation = 0,
	}
	db.backgrounds = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.backgrounds) or {
		stats = { texture = "default", alpha = 1, contrast = 0, zoom = 1.6, panX = 1, panY = 0, palette = "classic" },
	}
	RefreshAddon("character")
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
		elseif control.controlType == "itemLevelColorMode" then
			control:SetChecked(GetItemLevelBadgeColorMode() == "quality")
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
		colorMode = "score",
	}
	RefreshAddon("itemLevels")
end

function coolstats.RefreshTooltipOptionsPanel()
	local panel = coolstats.tooltipOptionsPanel
	if not panel then
		return
	end
	if coolstats.LayoutTooltipOptionsPanel then
		coolstats.LayoutTooltipOptionsPanel()
	end
	for index = 1, #panel.controls do
		local control = panel.controls[index]
		if control.controlType == "uwuRaidLayer" then
			UpdateUwURaidLayerCheck(control)
		elseif control.getter then
			control:SetChecked(control.getter())
		elseif control.controlType == "uwuPlayerLoadLimit" then
			control.updating = true
			UpdateUwUPlayerLoadLimitSliderRange(control)
			control:SetValue(GetUwUPlayerLoadSliderValue())
			control.updating = nil
			UpdateUwUPlayerLoadLimitSliderText(control)
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
		cacheInspectGear = true,
		cacheInspectTalents = true,
		uwuRaidLayers = {},
	}
	db.tooltip.uwuPlayerLoadLimit = nil
	RefreshAddon("browser")
end

local function UpdateOptionsColumnLayout(column, parent, xOffset, yOffset, width, height)
	if not column then
		return
	end
	column:ClearAllPoints()
	column:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	column:SetWidth(width)
	column:SetHeight(height)
	column.descriptionWidth = math.max(120, width - 36)
	column.checkTextWidth = math.max(96, width - 68)
	if column.descriptions then
		for index = 1, #column.descriptions do
			column.descriptions[index]:SetWidth(column.descriptionWidth)
		end
	end
end

local function UpdateOptionsCheckWidths(panel)
	if not panel or not panel.controls then
		return
	end
	for index = 1, #panel.controls do
		local control = panel.controls[index]
		if control and control.labelText and control.controlType ~= "uwuRaidLayer" then
			SetCheckText(control, control.labelText)
		end
	end
end

local function UpdateOptionsSliderLayout(slider, parent)
	if not slider or not parent then
		return
	end
	local sliderWidth = parent.sliderWidth or 240
	slider:SetWidth(sliderWidth)
	local label = slider:GetName() and _G[slider:GetName() .. "Text"]
	if label then
		if label.SetFontObject then
			label:SetFontObject(GameFontHighlightSmall)
		end
		label:SetWidth(parent.sliderLabelWidth or math.max(120, sliderWidth))
	end
	local resetButton = slider.resetButton
	if resetButton then
		resetButton:ClearAllPoints()
		resetButton:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.sliderResetX or 286, (slider.layoutYOffset or -36) - 3)
	end
end

function coolstats.LayoutTooltipOptionsPanel()
	local panel = coolstats.tooltipOptionsPanel
	if not panel or not panel.content or not panel.scrollFrame or not panel.tooltipLeftColumn or not panel.tooltipRightColumn then
		return
	end
	local content = panel.content
	local visibleWidth = panel.scrollFrame.GetWidth and panel.scrollFrame:GetWidth() or 0
	visibleWidth = math.floor((tonumber(visibleWidth) or 0) + 0.5)
	if visibleWidth <= 0 then
		visibleWidth = content.GetWidth and math.floor((content:GetWidth() or 520) + 0.5) or 520
	end
	visibleWidth = math.max(320, math.min(680, visibleWidth - 36))
	SetOptionsContentWidth(content, visibleWidth)
	if content.descriptions then
		for index = 1, #content.descriptions do
			content.descriptions[index]:SetWidth(content.descriptionWidth or visibleWidth - 32)
		end
	end

	local leftColumn = panel.tooltipLeftColumn
	local rightColumn = panel.tooltipRightColumn
	if visibleWidth >= 580 then
		local gap = 24
		local leftWidth = math.floor((visibleWidth - gap) * 0.5)
		local rightX = leftWidth + gap
		local rightWidth = visibleWidth - rightX
		UpdateOptionsColumnLayout(leftColumn, content, 0, -72, leftWidth, 370)
		UpdateOptionsColumnLayout(rightColumn, content, rightX, -72, rightWidth, 370)
		rightColumn.sliderWidth = math.max(140, math.min(190, rightWidth - 120))
		rightColumn.sliderResetX = math.min(rightWidth - 64, rightColumn.sliderWidth + 50)
		rightColumn.sliderLabelWidth = math.max(140, math.min(rightWidth - 34, rightColumn.sliderWidth + 70))
		rightColumn.checkTextWidth = math.max(120, rightWidth - 86)
		rightColumn.descriptionWidth = math.max(150, rightWidth - 34)
		rightColumn.shortRaidLayerLabels = true
		if panel.uwuPlayerLoadLimitSlider then
			panel.uwuPlayerLoadLimitSlider.compactLabel = true
		end
		if panel.uwuPlayerLoadDescription then
			panel.uwuPlayerLoadDescription:SetText("Fewer players after /reload.")
		end
		if panel.raidLayerDescription then
			panel.raidLayerDescription:SetText("Hide raids now; save memory after /reload.")
		end
		content:SetHeight(470)
	else
		local columnWidth = visibleWidth
		UpdateOptionsColumnLayout(leftColumn, content, 0, -72, columnWidth, 330)
		UpdateOptionsColumnLayout(rightColumn, content, 0, -414, columnWidth, 330)
		rightColumn.sliderWidth = math.max(150, math.min(260, columnWidth - 120))
		rightColumn.sliderResetX = math.min(columnWidth - 62, rightColumn.sliderWidth + 54)
		rightColumn.sliderLabelWidth = math.max(180, columnWidth - 48)
		rightColumn.checkTextWidth = math.max(160, columnWidth - 68)
		rightColumn.descriptionWidth = math.max(180, columnWidth - 36)
		rightColumn.shortRaidLayerLabels = true
		if panel.uwuPlayerLoadLimitSlider then
			panel.uwuPlayerLoadLimitSlider.compactLabel = false
		end
		if panel.uwuPlayerLoadDescription then
			panel.uwuPlayerLoadDescription:SetText("Lower values use fewer players after /reload. Raising above loaded data also needs /reload.")
		end
		if panel.raidLayerDescription then
			panel.raidLayerDescription:SetText("Unchecked raids hide now; memory savings apply after /reload.")
		end
		content:SetHeight(760)
	end
	if rightColumn.descriptions then
		for index = 1, #rightColumn.descriptions do
			rightColumn.descriptions[index]:SetWidth(rightColumn.descriptionWidth)
		end
	end
	UpdateOptionsCheckWidths(panel)
	UpdateOptionsSliderLayout(panel.uwuPlayerLoadLimitSlider, rightColumn)
	UpdateUwUPlayerLoadLimitSliderText(panel.uwuPlayerLoadLimitSlider)
end

function coolstats.RefreshLootToastOptionsPanel()
	local panel = coolstats.lootToastOptionsPanel
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

function coolstats.ResetLootToastOptionsPanelDefaults()
	local db = GetDB()
	local defaults = GetDefaults()
	if not db or not defaults then
		return
	end
	db.lootAlerts = coolstats.CopyDefaults and coolstats.CopyDefaults({}, defaults.lootAlerts) or {
		enabled = true,
		minQuality = 3,
		selfLoot = true,
		groupRolls = true,
		professions = false,
		sound = true,
		animations = true,
	}
	RefreshAddon("loot")
end

function coolstats.CreateLootToastOptionsPanel()
	if coolstats.lootToastOptionsPanel then
		return coolstats.lootToastOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsLootToastOptionsPanel", UIParent)
	panel.name = "Loot Toasts"
	panel.parent = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshLootToastOptionsPanel
	panel.default = coolstats.ResetLootToastOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.lootToastOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsLootToastOptions", 450)
	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Loot Toasts")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose which loot events create popups and how loud or flashy those popups should be.", -42)

	CreateHeading(content, "Loot Toasts", -78)
	CreateCheck(content, "coolstatsOptionLootEnabled", "Enable loot toasts", -104, function()
		return GetLootOptions().enabled
	end, function(value)
		GetLootOptions().enabled = value
	end, "Show loot popups for items that pass the quality threshold.", "loot")
	CreateQualitySlider(content, -152)

	CreateHeading(content, "Sources", -206)
	CreateCheck(content, "coolstatsOptionLootSelf", "Show items I loot", -232, function()
		return GetLootOptions().selfLoot
	end, function(value)
		GetLootOptions().selfLoot = value
	end, "Show a toast when you personally loot an item.", "loot")
	CreateCheck(content, "coolstatsOptionLootRolls", "Show group-roll wins", -260, function()
		return GetLootOptions().groupRolls
	end, function(value)
		GetLootOptions().groupRolls = value
	end, "Show a single toast when you win a group loot roll; the later looted-item message is suppressed.", "loot")
	CreateCheck(content, "coolstatsOptionLootProfessions", "Show profession crafts", -288, function()
		return GetLootOptions().professions
	end, function(value)
		GetLootOptions().professions = value
	end, "Show loot toasts for items you create with professions.", "loot")

	CreateHeading(content, "Presentation", -332)
	CreateCheck(content, "coolstatsOptionLootSound", "Play loot toast sounds", -358, function()
		return GetLootOptions().sound
	end, function(value)
		GetLootOptions().sound = value
	end, "Play a short sound when a loot toast appears.", "loot")
	CreateCheck(content, "coolstatsOptionLootAnimations", "Play loot toast glows", -386, function()
		return GetLootOptions().animations
	end, function(value)
		GetLootOptions().animations = value
	end, "Play the shine/glow flourish on loot toasts.", "loot")

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	panel:SetScript("OnShow", coolstats.RefreshLootToastOptionsPanel)
	coolstats.RefreshLootToastOptionsPanel()
	return panel
end

function coolstats.CreateTooltipOptionsPanel()
	if coolstats.tooltipOptionsPanel then
		return coolstats.tooltipOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsTooltipOptionsPanel", UIParent)
	panel.name = "Tooltip & Cache"
	panel.parent = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshTooltipOptionsPanel
	panel.default = coolstats.ResetTooltipOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.tooltipOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsTooltipOptions", 470)
	SetOptionsContentWidth(content, 520)
	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Tooltip & Cache")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose what appears on player tooltips and how inspect-based caches update.", -42)
	local leftColumn = CreateOptionsColumn(content, "coolstatsTooltipOptionsLeftColumn", 0, -72, 258, 370)
	local rightColumn = CreateOptionsColumn(content, "coolstatsTooltipOptionsRightColumn", 262, -72, 258, 370)
	panel.tooltipLeftColumn = leftColumn
	panel.tooltipRightColumn = rightColumn
	rightColumn.sliderWidth = 142
	rightColumn.sliderResetX = 196
	rightColumn.sliderLabelWidth = 210
	rightColumn.checkTextWidth = 190
	rightColumn.descriptionWidth = 222
	rightColumn.shortRaidLayerLabels = true

	CreateHeading(leftColumn, "Tooltip Lines", 0)
	CreateCheck(leftColumn, "coolstatsTooltipGuildRank", "Show guild rank", -26, function()
		return GetTooltipOptions().guildRank ~= false
	end, function(value)
		GetTooltipOptions().guildRank = value
	end, "Replace the default guild line with the player's guild rank and guild name.", "tooltip")
	CreateCheck(leftColumn, "coolstatsTooltipClassLine", "Show class line", -54, function()
		return GetTooltipOptions().classLine ~= false
	end, function(value)
		GetTooltipOptions().classLine = value
	end, "Add a class-colored class name to player tooltips.", "tooltip")
	CreateCheck(leftColumn, "coolstatsTooltipTarget", "Show current target", -82, function()
		return GetTooltipOptions().target ~= false
	end, function(value)
		GetTooltipOptions().target = value
	end, "Show who the hovered player is currently targeting.", "tooltip")

	CreateHeading(leftColumn, "Inspect Cache", -122)
	CreateCheck(leftColumn, "coolstatsTooltipCacheGear", "Cache inspectable gear", -148, function()
		local options = GetTooltipOptions()
		if options.cacheInspectGear == nil and options.cacheOnHover ~= nil then
			return options.cacheOnHover ~= false
		end
		return options.cacheInspectGear ~= false
	end, function(value)
		local options = GetTooltipOptions()
		options.cacheInspectGear = value
		options.cacheOnHover = value
	end, "Allow inspect, target, hover, and lookup flows to update cached gear snapshots.", "tooltip")
	CreateCheck(leftColumn, "coolstatsTooltipCacheTalents", "Cache inspectable talents", -176, function()
		return GetTooltipOptions().cacheInspectTalents ~= false
	end, function(value)
		GetTooltipOptions().cacheInspectTalents = value
	end, "Allow inspect and talent-panel flows to update cached talent snapshots.", "tooltip")

	CreateHeading(leftColumn, "Logs And Progress", -220)
	CreateCheck(leftColumn, "coolstatsTooltipLogsSummary", "Show logs summary", -246, function()
		return GetTooltipOptions().logsSummary ~= false
	end, function(value)
		GetTooltipOptions().logsSummary = value
	end, "Show the player's best available logs score.", "tooltip")
	CreateCheck(leftColumn, "coolstatsTooltipLogsBosses", "Show boss parses with Alt", -274, function()
		return GetTooltipOptions().logsBossDetails ~= false
	end, function(value)
		GetTooltipOptions().logsBossDetails = value
	end, "Show individual boss parses while Alt is held.", "tooltip")
	CreateCheck(leftColumn, "coolstatsTooltipRaidFallback", "Show raid progress summary", -302, function()
		return GetTooltipOptions().raidProgressFallback ~= false
	end, function(value)
		GetTooltipOptions().raidProgressFallback = value
	end, "Use available logs for raid progress, or request achievement progress as a fallback when logs are missing.", "tooltip")

	CreateHeading(rightColumn, "Player Browser", 0)
	panel.uwuPlayerLoadLimitSlider = CreateUwUPlayerLoadLimitSlider(rightColumn, -36)
	panel.uwuPlayerLoadDescription = CreateDescription(rightColumn, "Lower values use fewer players after /reload. Raising above loaded data also needs /reload.", -70)

	CreateHeading(rightColumn, "Raid Data Layers", -124)
	panel.raidLayerDescription = CreateDescription(rightColumn, "Unchecked raids hide now; memory savings apply after /reload.", -150)
	CreateUwURaidLayerCheck(rightColumn, 1, -194)
	CreateUwURaidLayerCheck(rightColumn, 2, -222)
	CreateUwURaidLayerCheck(rightColumn, 3, -250)
	CreateUwURaidLayerCheck(rightColumn, 4, -278)
	CreateUwURaidLayerCheck(rightColumn, 5, -306)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	panel:SetScript("OnShow", coolstats.RefreshTooltipOptionsPanel)
	if panel.SetScript then
		panel:SetScript("OnSizeChanged", function()
			if coolstats.LayoutTooltipOptionsPanel then
				coolstats.LayoutTooltipOptionsPanel()
			end
		end)
	end
	coolstats.RefreshTooltipOptionsPanel()
	return panel
end

function coolstats.CreateItemLevelOptionsPanel()
	if coolstats.CreateCharacterPanelOptionsPanel then
		return coolstats.CreateCharacterPanelOptionsPanel()
	end
	if coolstats.itemLevelOptionsPanel then
		return coolstats.itemLevelOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsItemLevelOptionsPanel", UIParent)
	panel.name = "Item Levels"
	panel.parent = CHARACTER_PANEL_CATEGORY_NAME
	panel.controls = {}
	panel.refresh = coolstats.RefreshItemLevelOptionsPanel
	panel.default = coolstats.ResetItemLevelOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.itemLevelOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsItemLevelOptions", 350)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Item Levels")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose where equipped item levels appear on gear slots, how large the badge text should be, and whether colors use GearScore or item rarity.", -42)
	CreateItemLevelPositionDropdown(content, "coolstatsItemLevelPositionDropdown", -84)
	CreateItemLevelFontSizeSlider(content, "coolstatsItemLevelFontSizeSlider", -158)
	CreateCheck(content, "coolstatsItemLevelRarityColors", "Use item rarity colors", -224, function()
		return GetItemLevelBadgeColorMode() == "quality"
	end, function(value)
		GetItemLevelBadgeOptions().colorMode = value and "quality" or "score"
	end, "Switch item-level badge text and slot-border glow from the coolstats GearScore gradient to Blizzard's uncommon, rare, epic, and legendary item colors. GearScore values are still calculated normally.", "itemLevels")
	CreateDescription(content, "Corner positions automatically render at half the selected font size.", -264)

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
	RefreshAddon("background")
end

function coolstats.CreateBackgroundOptionsPanel()
	if coolstats.CreateCharacterPanelOptionsPanel then
		return coolstats.CreateCharacterPanelOptionsPanel()
	end
	if coolstats.backgroundOptionsPanel then
		return coolstats.backgroundOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsBackgroundOptionsPanel", UIParent)
	panel.name = "Backgrounds"
	panel.parent = CHARACTER_PANEL_CATEGORY_NAME
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

function coolstats.CreateCharacterPanelOptionsPanel()
	if coolstats.characterPanelOptionsPanel then
		return coolstats.characterPanelOptionsPanel
	end

	local panel = CreateFrame("Frame", "coolstatsCharacterPanelOptionsPanel", UIParent)
	panel.name = CHARACTER_PANEL_CATEGORY_NAME
	panel.parent = "coolstats"
	panel.controls = {}
	panel.refresh = coolstats.RefreshCharacterPanelOptionsPanel
	panel.default = coolstats.ResetCharacterPanelOptionsPanelDefaults
	panel.okay = function() end
	panel.cancel = function() end
	coolstats.characterPanelOptionsPanel = panel

	local content = CreateScrollableOptionsContent(panel, "coolstatsCharacterPanelOptions", 1784)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats Character Panel")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Control the replacement character panel, its gear overlays, and compatibility behavior.", -42)

	CreateHeading(content, "Main Controls", -78)
	CreateCheck(content, "coolstatsCharacterPanelEnable", "Enable character panel features", -104, function()
		return IsCharacterPanelEnabled()
	end, function(value)
		SetCharacterPanelEnabled(value)
	end, "Requires a UI reload. Disable this to keep UwU Logs features without loading the coolstats character-panel replacement, item badges, slot coloring, or GearScore tooltip cleanup.", "character")
	CreateCheck(content, "coolstatsCharacterPanelStats", "Show side stats panel", -132, function()
		return GetDB() and GetDB().showStatsPanel
	end, function(value)
		GetDB().showStatsPanel = value
	end, "Show the extended stats panel next to the character frame.", "character")

	CreateHeading(content, "Gear Overlays", -176)
	CreateCheck(content, "coolstatsCharacterPanelItemLevels", "Show item level badges", -202, function()
		return GetDB() and GetDB().showItemLevels
	end, function(value)
		local db = GetDB()
		db.showItemLevels = value
		if value and GetItemLevelBadgeOptions().position == "off" then
			GetItemLevelBadgeOptions().position = "default"
		end
	end, "Show item level labels on equipped gear slots.", "itemLevels")
	CreateCheck(content, "coolstatsCharacterPanelSlotBorders", "Show colored slot borders", -230, function()
		return GetDB() and GetDB().showSlotBorders
	end, function(value)
		GetDB().showSlotBorders = value
	end, "Color equipment slot borders using the selected Item Levels color mode.", "itemLevels")

	CreateHeading(content, "Paperdoll Gems", -274)
	CreateCheck(content, "coolstatsCharacterPanelPaperDollGems", "Show paperdoll gems", -300, function()
		return GetDB() and GetDB().showPaperDollGems
	end, function(value)
		GetDB().showPaperDollGems = value
	end, "Show socketed gem icons around equipped gear slots.", "paperDoll")
	CreatePaperDollGemSlider(content, "coolstatsCharacterPanelGemSizeSlider", "Gem icon size", -356, "size", 10, 24, 1, "px")
	CreatePaperDollGemSlider(content, "coolstatsCharacterPanelGemArtSlider", "Gem art size", -420, "iconScale", 60, 115, 5, "%")
	CreatePaperDollGemSlider(content, "coolstatsCharacterPanelGemSpacingSlider", "Gem slot gap", -484, "spacing", 3, 14, 1, "px")
	CreatePaperDollGemSlider(content, "coolstatsCharacterPanelGemCircleSlider", "Gem circle size", -548, "circleScale", 75, 145, 5, "%")
	CreatePaperDollGemSlider(content, "coolstatsCharacterPanelGemProngSlider", "Gem prong size", -612, "prongScale", 55, 125, 5, "%")

	CreateHeading(content, "Model Score Text", -676)
	CreateModelScoreSlider(content, "coolstatsCharacterPanelModelScoreXSlider", "Horizontal offset", -702, "x", -160, 160)
	CreateModelScoreSlider(content, "coolstatsCharacterPanelModelScoreYSlider", "Vertical offset", -766, "y", -40, 180)
	CreatePaperDollModelRotationSlider(content, "coolstatsCharacterPanelModelRotationSlider", -830)

	CreateHeading(content, "Item Level Details", -894)
	CreateItemLevelPositionDropdown(content, "coolstatsCharacterPanelItemLevelPositionDropdown", -920)
	CreateItemLevelFontSizeSlider(content, "coolstatsCharacterPanelItemLevelFontSizeSlider", -994)
	CreateHeading(content, "Item Level Colors", -1044)
	CreateCheck(content, "coolstatsCharacterPanelRarityColors", "Use item rarity colors", -1076, function()
		return GetItemLevelBadgeColorMode() == "quality"
	end, function(value)
		GetItemLevelBadgeOptions().colorMode = value and "quality" or "score"
	end, "Switch item-level badge text and slot-border glow from the coolstats GearScore gradient to Blizzard's uncommon, rare, epic, and legendary item colors. GearScore values are still calculated normally.", "itemLevels")
	CreateDescription(content, "Corner positions automatically render at half the selected font size.", -1110)

	CreateHeading(content, "Compatibility", -1160)
	CreateCheck(content, "coolstatsCharacterPanelHideResistances", "Hide paperdoll resistances", -1186, function()
		return GetDB() and GetDB().hidePaperDollResistances ~= false
	end, function(value)
		GetDB().hidePaperDollResistances = value
	end, "Hide Blizzard's resistance buttons on the paperdoll. Disable this to show them again.", "paperDoll")
	CreateCheck(content, "coolstatsCharacterPanelHideRotateButtons", "Hide model rotate buttons", -1214, function()
		return GetDB() and GetDB().hidePaperDollRotateButtons ~= false
	end, function(value)
		GetDB().hidePaperDollRotateButtons = value
	end, "Hide Blizzard's character model rotation buttons. Disable this to show them again.", "paperDoll")
	CreateCheck(content, "coolstatsCharacterPanelTooltipCleanup", "Clean GearScore tooltip spam", -1242, function()
		return GetDB() and GetDB().cleanGearScoreTooltips
	end, function(value)
		GetDB().cleanGearScoreTooltips = value
	end, "Hide noisy GearScore lines from item tooltips.", "character")

	CreateHeading(content, "Side Panel Visuals", -1292)
	CreateDescription(content, "Controls the background texture, opacity, contrast overlay, talent-art zoom, image position, and stat text colors of the coolstats side panel.", -1318)
	CreateBackgroundDropdown(content, "coolstatsCharacterPanelStatsBackgroundDropdown", "Stats panel texture", -1354, "stats")
	CreateBackgroundAlphaSlider(content, "coolstatsCharacterPanelStatsBackgroundAlphaSlider", "Stats panel opacity", -1426, "stats")
	CreateBackgroundContrastSlider(content, "coolstatsCharacterPanelStatsBackgroundContrastSlider", "Stats panel contrast", -1490, "stats")
	CreateBackgroundZoomSlider(content, "coolstatsCharacterPanelStatsBackgroundZoomSlider", "Stats panel zoom", -1554, "stats")
	CreateBackgroundPanSlider(content, "coolstatsCharacterPanelStatsBackgroundPanXSlider", "Image horizontal position", -1618, "stats", "panX", "Left", "Right")
	CreateBackgroundPanSlider(content, "coolstatsCharacterPanelStatsBackgroundPanYSlider", "Image vertical position", -1682, "stats", "panY", "Up", "Down")
	CreateStatTextPaletteDropdown(content, "coolstatsCharacterPanelStatsTextPaletteDropdown", "Stats text palette", -1746, "stats")

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	panel:SetScript("OnShow", coolstats.RefreshCharacterPanelOptionsPanel)
	coolstats.RefreshCharacterPanelOptionsPanel()
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

	local content = CreateScrollableOptionsContent(panel, "coolstatsMainOptions", 260)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
	title:SetText("coolstats")
	title:SetTextColor(0.0, 0.75, 1.0)

	CreateDescription(content, "Choose a settings section on the left. Character Panel contains the replacement character sheet, gear overlays, item-level controls, and side-panel visuals.", -42)

	CreateHeading(content, "Sections", -92)
	CreateDescription(content, "Character Panel houses the main character-frame toggles first, then item-level placement, size, colors, side-panel visuals, and compatibility settings below them.\nTooltip & Cache controls player tooltips, UwU summary lines, inspect cache, player data, and raid layers.\nLoot Toasts controls loot popups, quality threshold, sources, sound, and glow.", -118)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	coolstats.CreateCharacterPanelOptionsPanel()
	coolstats.CreateTooltipOptionsPanel()
	coolstats.CreateLootToastOptionsPanel()
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

function coolstats.OpenTooltipOptionsPanel()
	coolstats.CreateOptionsPanel()
	local panel = coolstats.CreateTooltipOptionsPanel and coolstats.CreateTooltipOptionsPanel() or coolstats.tooltipOptionsPanel
	if InterfaceOptionsFrame_OpenToCategory and panel then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

function coolstats.OpenLootToastOptionsPanel()
	coolstats.CreateOptionsPanel()
	local panel = coolstats.CreateLootToastOptionsPanel and coolstats.CreateLootToastOptionsPanel() or coolstats.lootToastOptionsPanel
	if InterfaceOptionsFrame_OpenToCategory and panel then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

function coolstats.OpenBackgroundOptionsPanel()
	coolstats.CreateOptionsPanel()
	local panel = coolstats.CreateCharacterPanelOptionsPanel()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

function coolstats.OpenItemLevelOptionsPanel()
	coolstats.CreateOptionsPanel()
	local panel = coolstats.CreateCharacterPanelOptionsPanel()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	elseif InterfaceOptionsFrame_Show then
		InterfaceOptionsFrame_Show()
	end
end

coolstats.CreateOptionsPanel()
