local coolstats = _G.coolstats or {}

local ASSETS = [[Interface\AddOns\coolstats\assets\]]
local SOUND_EPIC = ASSETS .. "ui_epicloot_toast_01.ogg"
local SOUND_LEGENDARY = ASSETS .. "ui_legendary_item_toast.ogg"
local SOUND_LESSER = ASSETS .. "ui_loot_toast_lesser_item_won_01.ogg"

local LOOT_ALERT_NUM_BUTTONS = 4
local LOOT_ALERT_UPDATE_TIME = 0.30
local LOOT_ALERT_SCALE = 1
local LOOT_ALERT_OFFSET = 4
local LOOT_ALERT_POINT_X = 0
local LOOT_ALERT_POINT_Y = 0

local QUALITY_UNCOMMON = 2
local QUALITY_RARE = 3
local QUALITY_EPIC = 4
local QUALITY_LEGENDARY = 5
local QUALITY_ARTIFACT = 6
local QUALITY_HEIRLOOM = 7

local ROLL_NEED = 1
local ROLL_GREED = 2
local ROLL_DISENCHANT = 3
local ROLL_EXPECTATION_SECONDS = 60

local LOOT_BORDER_BY_QUALITY = {
	[QUALITY_UNCOMMON] = {0.34082, 0.397461, 0.53125, 0.644531},
	[QUALITY_RARE] = {0.272461, 0.329102, 0.785156, 0.898438},
	[QUALITY_EPIC] = {0.34082, 0.397461, 0.882812, 0.996094},
	[QUALITY_LEGENDARY] = {0.34082, 0.397461, 0.765625, 0.878906},
	[QUALITY_ARTIFACT] = {0.272461, 0.329102, 0.667969, 0.78125},
	[QUALITY_HEIRLOOM] = {0.34082, 0.397461, 0.648438, 0.761719},
}

local alertQueue = {}
local alertButtons = {}
local rollExpectations = {}
local recentRollWins = {}
local sanitizeCache = {}
local captureCache = {}
local StartLootAlertTicker

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

local function WipeTable(tbl)
	if not tbl then
		return
	end
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

local function SanitizePattern(pattern)
	if not pattern then
		return nil
	end
	if not sanitizeCache[pattern] then
		local ret = pattern
		ret = ret:gsub("([%+%-%*%(%)%?%[%]%^])", "%%%1")
		ret = ret:gsub("%d%$", "")
		ret = ret:gsub("(%%%a)", "%(%1+%)")
		ret = ret:gsub("%%s%+", ".+")
		ret = ret:gsub("%(.%+%)%(%%d%+%)", "%(.-%)%(%%d%+%)")
		sanitizeCache[pattern] = ret
	end
	return sanitizeCache[pattern]
end

local function GetCaptures(pattern)
	if not pattern then
		return nil
	end
	if not captureCache[pattern] then
		local result = {}
		for captureIndex in pattern:gmatch("%%(%d)%$") do
			result[#result + 1] = tonumber(captureIndex)
		end
		captureCache[pattern] = #result > 0 and result or false
	end
	return captureCache[pattern] ~= false and captureCache[pattern] or nil
end

local function CMatch(text, pattern)
	if not text or not pattern then
		return nil
	end
	local captureIndexes = GetCaptures(pattern)
	local sanitized = SanitizePattern(pattern)
	if not sanitized then
		return nil
	end
	if not captureIndexes then
		return text:match(sanitized)
	end
	local captures = { text:match(sanitized) }
	if #captures == 0 then
		return nil
	end
	local result = {}
	for index = 1, #captures do
		result[captureIndexes[index]] = captures[index]
	end
	return unpack(result)
end

local function GetOptions()
	if coolstats.GetLootAlertOptions then
		return coolstats.GetLootAlertOptions()
	end
	return {
		enabled = true,
		minQuality = QUALITY_RARE,
		selfLoot = true,
		groupRolls = true,
		professions = false,
		sound = true,
		animations = true,
	}
end

local function GetMinimumQuality()
	local options = GetOptions()
	local quality = math.floor(tonumber(options.minQuality or QUALITY_RARE) + 0.5)
	if quality < QUALITY_UNCOMMON then
		quality = QUALITY_UNCOMMON
	elseif quality > QUALITY_HEIRLOOM then
		quality = QUALITY_HEIRLOOM
	end
	return quality
end

local function QualityAllowed(quality)
	local options = GetOptions()
	if not options.enabled then
		return false
	end
	quality = tonumber(quality) or 0
	if quality < QUALITY_UNCOMMON then
		return false
	end
	return quality >= GetMinimumQuality()
end

local function AddAlert(name, link, quality, texture, count, label, toast, rollType, rollLink)
	if not QualityAllowed(quality) then
		return false
	end
	alertQueue[#alertQueue + 1] = {
		name = name,
		link = link,
		quality = quality,
		texture = texture,
		count = count,
		label = label,
		toast = toast,
		rollType = rollType,
		rollLink = rollLink,
	}
	if StartLootAlertTicker then
		StartLootAlertTicker()
	end
	return true
end

local function GetItemToast(link, fallbackLabel, rollType, roll)
	local name, itemLink, quality, itemLevel, _, _, subType, _, _, texture = GetItemInfo(link)
	if not itemLink then
		return false
	end

	local toast = "defaulttoast"
	if quality == QUALITY_LEGENDARY then
		toast = "legendarytoast"
		fallbackLabel = "Legendary!"
	elseif itemLevel and itemLevel >= 271 then
		toast = "heroictoast"
	end

	local mountText = ITEM_TYPE_MOUNT or ITEM_TYPE_MOUNTS
	local petText = PETS or PET
	if mountText and subType == mountText then
		toast = "mounttoast"
	elseif petText and subType == petText then
		toast = "pettoast"
	end

	return AddAlert(name or link, itemLink, quality or 0, texture, nil, fallbackLabel, toast, rollType, roll)
end

local function ExpireRollWins()
	local now = GetTime and GetTime() or 0
	for link, expiresAt in pairs(recentRollWins) do
		if expiresAt <= now then
			recentRollWins[link] = nil
		end
	end
end

local function PruneRollState()
	local now = GetTime and GetTime() or 0
	for link, entry in pairs(rollExpectations) do
		local expiresAt = type(entry) == "table" and tonumber(entry[3]) or 0
		if expiresAt <= now then
			rollExpectations[link] = nil
		end
	end
	ExpireRollWins()
end

local function HandleRollMessage(message)
	PruneRollState()
	local playerName = UnitName("player")
	if not playerName then
		return nil
	end

	if LOOT_ROLL_YOU_WON then
		local link = CMatch(message, LOOT_ROLL_YOU_WON)
		if link and rollExpectations[link] then
			local rollType, roll = rollExpectations[link][1], rollExpectations[link][2]
			rollExpectations[link] = nil
			return link, rollType, roll
		end
	end

	local rolledPatterns = {
		[ROLL_NEED] = LOOT_ROLL_ROLLED_NEED,
		[ROLL_GREED] = LOOT_ROLL_ROLLED_GREED,
		[ROLL_DISENCHANT] = LOOT_ROLL_ROLLED_DE,
	}
	for rollType, pattern in pairs(rolledPatterns) do
		local roll, link, player = CMatch(message, pattern)
		if roll and link and player == playerName then
			rollExpectations[link] = { rollType, roll, (GetTime and GetTime() or 0) + ROLL_EXPECTATION_SECONDS }
			return nil
		end
	end

	local wonPatterns = {
		[ROLL_NEED] = LOOT_ROLL_YOU_WON_NO_SPAM_NEED,
		[ROLL_GREED] = LOOT_ROLL_YOU_WON_NO_SPAM_GREED,
		[ROLL_DISENCHANT] = LOOT_ROLL_YOU_WON_NO_SPAM_DE,
	}
	for rollType, pattern in pairs(wonPatterns) do
		local roll, link = CMatch(message, pattern)
		if roll and link then
			return link, rollType, roll
		end
	end

	return nil
end

local function GetSelfLoot(message)
	local link, count = CMatch(message, LOOT_ITEM_SELF_MULTIPLE)
	if link then
		return link, tonumber(count) or 1
	end
	link = CMatch(message, LOOT_ITEM_SELF)
	if link then
		return link, 1
	end
	return nil
end

local function GetProfessionLoot(message)
	local link, count = CMatch(message, LOOT_ITEM_CREATED_SELF_MULTIPLE)
	if link then
		return link, tonumber(count) or 1
	end
	link = CMatch(message, LOOT_ITEM_CREATED_SELF)
	if link then
		return link, 1
	end
	return nil
end

local function AlertSelfLoot(link, count, label)
	PruneRollState()
	if recentRollWins[link] then
		return
	end

	local name, itemLink, quality, itemLevel, _, _, subType, _, _, texture = GetItemInfo(link)
	if not itemLink then
		return
	end
	local toast = "defaulttoast"
	if quality == QUALITY_LEGENDARY then
		toast = "legendarytoast"
	elseif itemLevel and itemLevel >= 271 then
		toast = "heroictoast"
	end

	local mountText = ITEM_TYPE_MOUNT or ITEM_TYPE_MOUNTS
	local petText = PETS or PET
	if mountText and subType == mountText then
		toast = "mounttoast"
	elseif petText and subType == petText then
		toast = "pettoast"
	end

	AddAlert(name or link, itemLink, quality or 0, texture, count and count > 1 and count or nil, label or "You received", toast)
end

function CoolstatsLootAlertFrame_OnLoad(self)
	self.updateTime = LOOT_ALERT_UPDATE_TIME
	self:SetScript("OnUpdate", nil)
	self:RegisterEvent("CHAT_MSG_LOOT")
end

function CoolstatsLootAlertFrame_OnEvent(self, event, ...)
	if event ~= "CHAT_MSG_LOOT" then
		return
	end

	local options = GetOptions()
	if not options.enabled then
		return
	end

	local message = arg1 or select(1, ...)
	if not message then
		return
	end
	PruneRollState()

	if options.professions then
		local craftedLink, craftedCount = GetProfessionLoot(message)
		if craftedLink then
			AlertSelfLoot(craftedLink, craftedCount, "You created")
			return
		end
	end

	local rollLink, rollType, roll = HandleRollMessage(message)
	if rollLink and options.groupRolls then
		if GetItemToast(rollLink, "You won", rollType, roll) then
			recentRollWins[rollLink] = (GetTime and GetTime() or 0) + 8
		end
		return
	end

	if options.selfLoot then
		local lootLink, count = GetSelfLoot(message)
		if lootLink then
			AlertSelfLoot(lootLink, count)
		end
	end
end

function CoolstatsLootAlertFrame_OnUpdate(self, elapsed)
	self.updateTime = (self.updateTime or LOOT_ALERT_UPDATE_TIME) - (elapsed or 0)
	if self.updateTime > 0 then
		return
	end

	if #alertQueue > 0 then
		for index = 1, LOOT_ALERT_NUM_BUTTONS do
			local button = alertButtons[index]
			if button and not button:IsShown() then
				button.data = table.remove(alertQueue, 1)
				button:SetScale(LOOT_ALERT_SCALE)
				button:ClearAllPoints()
				button:Show()
				if button.animIn then
					button.animIn:Play()
				end
				CoolstatsLootAlertFrame_AdjustAnchors()
				break
			end
		end
	end
	self.updateTime = LOOT_ALERT_UPDATE_TIME
	if #alertQueue == 0 then
		self:SetScript("OnUpdate", nil)
	end
end

StartLootAlertTicker = function()
	local frame = _G.CoolstatsLootAlertFrame
	if frame and CoolstatsLootAlertFrame_OnUpdate then
		frame.updateTime = 0
		frame:SetScript("OnUpdate", CoolstatsLootAlertFrame_OnUpdate)
	end
end

function CoolstatsLootAlertButtonTemplate_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	alertButtons[self:GetID() or (#alertButtons + 1)] = self
end

function CoolstatsLootAlertFrame_AdjustAnchors()
	local previousButton
	for index = 1, LOOT_ALERT_NUM_BUTTONS do
		local button = alertButtons[index]
		if button then
			button:ClearAllPoints()
			if button:IsShown() then
				if not previousButton then
					local dungeonAlert = _G.DungeonCompletionAlertFrame1
					if dungeonAlert and dungeonAlert:IsShown() then
						button:SetPoint("BOTTOM", dungeonAlert, "TOP", LOOT_ALERT_POINT_X, LOOT_ALERT_POINT_Y)
					elseif dungeonAlert then
						button:SetPoint("CENTER", dungeonAlert, "CENTER", LOOT_ALERT_POINT_X, LOOT_ALERT_POINT_Y)
					else
						button:SetPoint("CENTER", UIParent, "CENTER", LOOT_ALERT_POINT_X, LOOT_ALERT_POINT_Y)
					end
				else
					button:SetPoint("BOTTOM", previousButton, "TOP", 0, LOOT_ALERT_OFFSET)
				end
				previousButton = button
			end
		end
	end
end

function CoolstatsLootAlertButtonTemplate_OnShow(self)
	local data = self.data
	if not data then
		self:Hide()
		return
	end

	local legendaryToast = data.toast == "legendarytoast"
	local defaultToast = data.toast == "defaulttoast"
	local heroicToast = data.toast == "heroictoast"
	local averageToast = defaultToast or heroicToast or legendaryToast or data.toast == "mounttoast" or data.toast == "pettoast"
	local qualityColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[data.quality]

	self.Count:SetText(data.count or " ")
	self.Icon:SetTexture(data.texture)
	self.LessIcon:SetTexture(data.texture)
	self.ItemName:SetText(data.name or "")
	self.LessItemName:SetText(data.name or "")
	self.Label:SetText(data.label or "You received")

	SetVisible(self.Icon, averageToast)
	SetVisible(self.IconBorder, averageToast)
	SetVisible(self.ItemName, averageToast)
	SetVisible(self.Label, averageToast)
	SetVisible(self.Background, defaultToast)
	SetVisible(self.HeroicBackground, heroicToast)
	SetVisible(self.LegendaryBackground, legendaryToast)
	SetVisible(self.MountToastBackground, data.toast == "mounttoast")
	SetVisible(self.PetToastBackground, data.toast == "pettoast")
	SetVisible(self.LessBackground, false)
	SetVisible(self.LessItemName, false)
	SetVisible(self.LessIcon, false)
	SetVisible(self.PvPBackground, false)
	SetVisible(self.RecipeBackground, false)
	SetVisible(self.RecipeTitle, false)
	SetVisible(self.RecipeName, false)
	SetVisible(self.RecipeIcon, false)
	SetVisible(self.MoneyBackground, false)
	SetVisible(self.MoneyLabel, false)
	SetVisible(self.MoneyIconBorder, false)
	SetVisible(self.MoneyIcon, false)
	SetVisible(self.Amount, false)

	SetVisible(self.RollWon, data.rollLink)
	SetVisible(self.RollWonTitle, data.rollLink)
	if data.rollLink then
		if data.rollType == ROLL_NEED then
			self.RollWonTitle:SetTexture([[Interface\Buttons\UI-GroupLoot-Dice-Up]])
		elseif data.rollType == ROLL_GREED then
			self.RollWonTitle:SetTexture([[Interface\Buttons\UI-GroupLoot-Coin-Up]])
		else
			self.RollWonTitle:Hide()
		end
		self.RollWon:SetText(data.rollLink)
	end

	if qualityColor then
		self.ItemName:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
		self.LessItemName:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
	else
		self.ItemName:SetTextColor(1, 1, 1)
		self.LessItemName:SetTextColor(1, 1, 1)
	end

	if LOOT_BORDER_BY_QUALITY[data.quality] then
		self.IconBorder:SetTexCoord(unpack(LOOT_BORDER_BY_QUALITY[data.quality]))
	end

	local options = GetOptions()
	if options.sound then
		if legendaryToast then
			PlaySoundFile(SOUND_LEGENDARY)
		elseif data.quality == QUALITY_UNCOMMON then
			PlaySoundFile(SOUND_LESSER)
		else
			PlaySoundFile(SOUND_EPIC)
		end
	end

	if options.animations then
		if legendaryToast then
			if self.legendaryGlow and self.legendaryGlow.animIn then
				self.legendaryGlow.animIn:Play()
			end
			if self.legendaryShine and self.legendaryShine.animIn then
				self.legendaryShine.animIn:Play()
			end
		else
			if self.glow and self.glow.animIn then
				self.glow.animIn:Play()
			end
			if self.shine and self.shine.animIn then
				self.shine.animIn:Play()
			end
		end
	end

	self.hyperLink = data.link
	self.name = data.name
end

function CoolstatsLootAlertButtonTemplate_OnHide(self)
	if self.animIn then
		self.animIn:Stop()
	end
	if self.waitAndAnimOut then
		self.waitAndAnimOut:Stop()
	end
	if self.data then
		WipeTable(self.data)
		self.data = nil
	end
	CoolstatsLootAlertFrame_AdjustAnchors()
end

function CoolstatsLootAlertButtonTemplate_OnClick(self, button)
	if button == "RightButton" then
		self:Hide()
	elseif self.hyperLink and HandleModifiedItemClick then
		HandleModifiedItemClick(self.hyperLink)
	end
end

function CoolstatsLootAlertButtonTemplate_OnEnter(self)
	if not self.hyperLink then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(self.hyperLink)
	GameTooltip:Show()
end
