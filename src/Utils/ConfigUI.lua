local _, PIL = ...
local Config = PIL.Config
local UI = PIL.UI

-- Initialize ConfigUI.lua namespace
local ConfigUI = {}
PIL.ConfigUI = ConfigUI

-- Access PeaversCommons utilities
local PeaversCommons = _G.PeaversCommons
-- Ensure PeaversCommons is loaded
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found. Please ensure it is installed and enabled.")
    return
end

-- Creates and initializes the options panel
function ConfigUI:InitializeOptions()
	if not UI then
		print("ERROR: UI module not loaded. Cannot initialize options.")
		return
	end

	local panel = CreateFrame("Frame")
	panel.name = "Settings"

	local scrollFrame, content = UI:CreateScrollFrame(panel)
	local yPos = 0

	-- Golden ratio for spacing (approximately 1.618)
	local goldenRatio = 1.618
	local baseSpacing = 25
	local sectionSpacing = baseSpacing * goldenRatio -- ~40px

	-- Create header and description
	local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", baseSpacing, yPos)
	title:SetText("Peavers Item Level")
	title:SetTextColor(1, 0.84, 0) -- Gold color for main title
	title:SetFont(title:GetFont(), 24, "OUTLINE")
	yPos = yPos - (baseSpacing * goldenRatio)

	local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	subtitle:SetPoint("TOPLEFT", baseSpacing, yPos)
	subtitle:SetText("Configuration options for the item level display")
	subtitle:SetFont(subtitle:GetFont(), 14)
	yPos = yPos - sectionSpacing

	-- Add a separator after the header
	local _, newY = UI:CreateSeparator(content, baseSpacing, yPos)
	yPos = newY - baseSpacing

	-- 1. DISPLAY SETTINGS SECTION
	yPos = self:CreateDisplayOptions(content, yPos, baseSpacing, sectionSpacing)

	-- Add a separator between major sections
	local _, newY = UI:CreateSeparator(content, baseSpacing, yPos)
	yPos = newY - baseSpacing

	-- 2. BAR APPEARANCE SECTION
	yPos = self:CreateBarAppearanceOptions(content, yPos, baseSpacing, sectionSpacing)

	-- Add a separator between major sections
	local _, newY = UI:CreateSeparator(content, baseSpacing, yPos)
	yPos = newY - baseSpacing

	-- 3. TEXT SETTINGS SECTION
	yPos = self:CreateTextOptions(content, yPos, baseSpacing, sectionSpacing)

	-- Add a separator between major sections
	local _, newY = UI:CreateSeparator(content, baseSpacing, yPos)
	yPos = newY - baseSpacing

	-- 4. BEHAVIOR SETTINGS SECTION
	yPos = self:CreateBehaviorOptions(content, yPos, baseSpacing, sectionSpacing)

	-- Update content height based on the last element position
	content:SetHeight(math.abs(yPos) + 50)

	-- Let PeaversCommons handle category registration
	-- The panel will be added as the first subcategory automatically
	
	-- Add these callback functions
	panel.OnRefresh = function() end
	panel.OnCommit = function() end
	panel.OnDefault = function() end

	return panel
end

-- 1. DISPLAY SETTINGS - Frame positioning, visibility, and main dimensions
function ConfigUI:CreateDisplayOptions(content, yPos, baseSpacing, sectionSpacing)
	baseSpacing = baseSpacing or 25
	sectionSpacing = sectionSpacing or 40
	local controlIndent = baseSpacing + 15
	local subControlIndent = controlIndent + 15
	local sliderWidth = 400

	-- Display Settings section header
	local header, newY = UI:CreateSectionHeader(content, "Display Settings", baseSpacing, yPos)
	header:SetFont(header:GetFont(), 18)
	yPos = newY - 10

	-- Frame dimensions subsection
	local dimensionsLabel, newY = UI:CreateLabel(content, "Frame Dimensions:", controlIndent, yPos, "GameFontNormalSmall")
	dimensionsLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Frame width slider
	local widthContainer = CreateFrame("Frame", nil, content)
	widthContainer:SetSize(sliderWidth, 50)
	widthContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local widthLabel = widthContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	widthLabel:SetPoint("TOPLEFT", 0, 0)
	widthLabel:SetText("Frame Width: " .. Config.frameWidth)

	local widthSlider = CreateFrame("Slider", "PeaversWidthSlider", widthContainer, "OptionsSliderTemplate")
	widthSlider:SetPoint("TOPLEFT", 0, -20)
	widthSlider:SetWidth(sliderWidth)
	widthSlider:SetMinMaxValues(50, 400)
	widthSlider:SetValueStep(10)
	widthSlider:SetValue(Config.frameWidth)

	-- Hide default slider text
	local sliderName = widthSlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	widthSlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value / 10 + 0.5) * 10
		widthLabel:SetText("Frame Width: " .. roundedValue)
		Config.frameWidth = roundedValue
		Config.barWidth = roundedValue - 20
		Config:Save()
		if PIL.Core and PIL.Core.frame then
			PIL.Core.frame:SetWidth(roundedValue)
			if PIL.BarManager then
				PIL.BarManager:ResizeBars()
			end
		end
	end)

	yPos = yPos - 55

	-- Background opacity slider
	local opacityContainer = CreateFrame("Frame", nil, content)
	opacityContainer:SetSize(sliderWidth, 50)
	opacityContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local opacityLabel = opacityContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	opacityLabel:SetPoint("TOPLEFT", 0, 0)
	opacityLabel:SetText("Background Opacity: " .. math.floor(Config.bgAlpha * 100) .. "%")

	local opacitySlider = CreateFrame("Slider", "PeaversOpacitySlider", opacityContainer, "OptionsSliderTemplate")
	opacitySlider:SetPoint("TOPLEFT", 0, -20)
	opacitySlider:SetWidth(sliderWidth)
	opacitySlider:SetMinMaxValues(0, 1)
	opacitySlider:SetValueStep(0.05)
	opacitySlider:SetValue(Config.bgAlpha)

	-- Hide default slider text
	local sliderName = opacitySlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	opacitySlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value * 20 + 0.5) / 20
		opacityLabel:SetText("Background Opacity: " .. math.floor(roundedValue * 100) .. "%")
		Config.bgAlpha = roundedValue
		Config:Save()
		if PIL.Core and PIL.Core.frame then
			PIL.Core.frame:SetBackdropColor(
				Config.bgColor.r,
				Config.bgColor.g,
				Config.bgColor.b,
				Config.bgAlpha
			)
			PIL.Core.frame:SetBackdropBorderColor(0, 0, 0, Config.bgAlpha)
			if PIL.Core.titleBar then
				PIL.Core.titleBar:SetBackdropColor(
					Config.bgColor.r,
					Config.bgColor.g,
					Config.bgColor.b,
					Config.bgAlpha
				)
				PIL.Core.titleBar:SetBackdropBorderColor(0, 0, 0, Config.bgAlpha)
			end
		end
	end)

	yPos = yPos - 65

	-- Add a thin separator with more spacing
	local _, newY = UI:CreateSeparator(content, baseSpacing + 15, yPos, 400)
	yPos = newY - 15

	-- Visibility options subsection
	local visibilityLabel, newY = UI:CreateLabel(content, "Visibility Options:", controlIndent, yPos, "GameFontNormalSmall")
	visibilityLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Show title bar checkbox
	local titleBarCheckbox, newY = UI:CreateCheckbox(
		content,
		"PeaversTitleBarCheckbox",
		"Show Title Bar",
		subControlIndent,
		yPos,
		Config.showTitleBar,
		{ 1, 1, 1 },
		function(self)
			Config.showTitleBar = self:GetChecked()
			Config:Save()
			if PIL.Core then
				PIL.Core:UpdateTitleBarVisibility()
			end
		end
	)
	yPos = newY - 8

	-- Lock position checkbox
	local lockPositionCheckbox, newY = UI:CreateCheckbox(
		content,
		"PeaversLockPositionCheckbox",
		"Lock Frame Position",
		subControlIndent,
		yPos,
		Config.lockPosition,
		{ 1, 1, 1 },
		function(self)
			Config.lockPosition = self:GetChecked()
			Config:Save()
			if PIL.Core then
				PIL.Core:UpdateFrameLock()
			end
		end
	)
	yPos = newY - 8

	-- Hide out of combat checkbox
	local hideOutOfCombatCheckbox, newY = UI:CreateCheckbox(
		content,
		"PeaversHideOutOfCombatCheckbox",
		"Hide When Out of Combat",
		subControlIndent,
		yPos,
		Config.hideOutOfCombat,
		{ 1, 1, 1 },
		function(self)
			Config.hideOutOfCombat = self:GetChecked()
			Config:Save()
			-- Apply the change immediately if out of combat
			if PIL.Core and PIL.Core.frame then
				local inCombat = InCombatLockdown()
				if self:GetChecked() and not inCombat then
					PIL.Core.frame:Hide()
				elseif not self:GetChecked() and not PIL.Core.frame:IsShown() then
					PIL.Core.frame:Show()
				end
			end
		end
	)
	yPos = newY - 12

	-- Display mode dropdown container
	local displayModeContainer = CreateFrame("Frame", nil, content)
	displayModeContainer:SetSize(sliderWidth, 60)
	displayModeContainer:SetPoint("TOPLEFT", subControlIndent, yPos)

	local displayModeLabel = displayModeContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	displayModeLabel:SetPoint("TOPLEFT", 0, 0)
	displayModeLabel:SetText("Display Mode")

	local displayModeOptions = {
		["ALWAYS"] = "Always Show",
		["PARTY_ONLY"] = "Show in Party Only",
		["RAID_ONLY"] = "Show in Raid Only"
	}

	local currentDisplayMode = displayModeOptions[Config.displayMode] or "Always Show"

	local displayModeDropdown = CreateFrame("Frame", "PeaversDisplayModeDropdown", displayModeContainer, "UIDropDownMenuTemplate")
	displayModeDropdown:SetPoint("TOPLEFT", 0, -20)
	UIDropDownMenu_SetWidth(displayModeDropdown, 345)
	UIDropDownMenu_SetText(displayModeDropdown, currentDisplayMode)

	UIDropDownMenu_Initialize(displayModeDropdown, function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		for value, text in pairs(displayModeOptions) do
			info.text = text
			info.checked = (value == Config.displayMode)
			info.func = function()
				Config.displayMode = value
				UIDropDownMenu_SetText(displayModeDropdown, text)
				Config:Save()
				-- Apply the change immediately
				if PIL.Core and PIL.Core.frame then
					PIL.Core:UpdateFrameVisibility()
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	yPos = yPos - 65

	return yPos
end

-- 2. BAR APPEARANCE - Everything related to the bars appearance and layout
function ConfigUI:CreateBarAppearanceOptions(content, yPos, baseSpacing, sectionSpacing)
	baseSpacing = baseSpacing or 25
	sectionSpacing = sectionSpacing or 40
	local controlIndent = baseSpacing + 15
	local subControlIndent = controlIndent + 15
	local sliderWidth = 400

	-- Bar Appearance section header
	local header, newY = UI:CreateSectionHeader(content, "Bar Appearance", baseSpacing, yPos)
	header:SetFont(header:GetFont(), 18)
	yPos = newY - 10

	-- Bar dimensions subsection
	local dimensionsLabel, newY = UI:CreateLabel(content, "Bar Dimensions:", controlIndent, yPos, "GameFontNormalSmall")
	dimensionsLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Bar height slider
	local heightContainer = CreateFrame("Frame", nil, content)
	heightContainer:SetSize(sliderWidth, 50)
	heightContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local heightLabel = heightContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	heightLabel:SetPoint("TOPLEFT", 0, 0)
	heightLabel:SetText("Bar Height: " .. Config.barHeight)

	local heightSlider = CreateFrame("Slider", "PeaversHeightSlider", heightContainer, "OptionsSliderTemplate")
	heightSlider:SetPoint("TOPLEFT", 0, -20)
	heightSlider:SetWidth(sliderWidth)
	heightSlider:SetMinMaxValues(10, 40)
	heightSlider:SetValueStep(1)
	heightSlider:SetValue(Config.barHeight)

	-- Hide default slider text
	local sliderName = heightSlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	heightSlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value + 0.5)
		heightLabel:SetText("Bar Height: " .. roundedValue)
		Config.barHeight = roundedValue
		Config:Save()
		if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
			PIL.BarManager:CreateBars(PIL.Core.contentFrame)
			PIL.Core:AdjustFrameHeight()
		end
	end)

	yPos = yPos - 55

	-- Bar spacing slider
	local spacingContainer = CreateFrame("Frame", nil, content)
	spacingContainer:SetSize(sliderWidth, 50)
	spacingContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local spacingLabel = spacingContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	spacingLabel:SetPoint("TOPLEFT", 0, 0)
	spacingLabel:SetText("Bar Spacing: " .. Config.barSpacing)

	local spacingSlider = CreateFrame("Slider", "PeaversSpacingSlider", spacingContainer, "OptionsSliderTemplate")
	spacingSlider:SetPoint("TOPLEFT", 0, -20)
	spacingSlider:SetWidth(sliderWidth)
	spacingSlider:SetMinMaxValues(-5, 10)
	spacingSlider:SetValueStep(1)
	spacingSlider:SetValue(Config.barSpacing)

	-- Hide default slider text
	local sliderName = spacingSlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	spacingSlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value + 0.5)
		spacingLabel:SetText("Bar Spacing: " .. roundedValue)
		Config.barSpacing = roundedValue
		Config:Save()
		if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
			PIL.BarManager:CreateBars(PIL.Core.contentFrame)
			PIL.Core:AdjustFrameHeight()
		end
	end)

	yPos = yPos - 65

	-- Add a thin separator
	local _, newY = UI:CreateSeparator(content, baseSpacing + 15, yPos, 400)
	yPos = newY - 15

	-- Bar style subsection
	local styleLabel, newY = UI:CreateLabel(content, "Bar Style:", controlIndent, yPos, "GameFontNormalSmall")
	styleLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Texture dropdown container
	local textureContainer = CreateFrame("Frame", nil, content)
	textureContainer:SetSize(sliderWidth, 60)
	textureContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local textureLabel = textureContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	textureLabel:SetPoint("TOPLEFT", 0, 0)
	textureLabel:SetText("Bar Texture")

	local textures = Config:GetBarTextures()
	local currentTexture = textures[Config.barTexture] or "Default"

	local textureDropdown = CreateFrame("Frame", "PeaversTextureDropdown", textureContainer, "UIDropDownMenuTemplate")
	textureDropdown:SetPoint("TOPLEFT", 0, -20)
	UIDropDownMenu_SetWidth(textureDropdown, 345)
	UIDropDownMenu_SetText(textureDropdown, currentTexture)

	UIDropDownMenu_Initialize(textureDropdown, function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		for path, name in pairs(textures) do
			info.text = name
			info.checked = (path == Config.barTexture)
			info.func = function()
				Config.barTexture = path
				UIDropDownMenu_SetText(textureDropdown, name)
				Config:Save()
				if PIL.BarManager then
					PIL.BarManager:ResizeBars()
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	yPos = yPos - 65

	-- Bar opacity slider
	local barOpacityContainer = CreateFrame("Frame", nil, content)
	barOpacityContainer:SetSize(sliderWidth, 50)
	barOpacityContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local barOpacityLabel = barOpacityContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	barOpacityLabel:SetPoint("TOPLEFT", 0, 0)
	barOpacityLabel:SetText("Bar Opacity: " .. math.floor(Config.barAlpha * 100) .. "%")

	local barOpacitySlider = CreateFrame("Slider", "PeaversBarOpacitySlider", barOpacityContainer, "OptionsSliderTemplate")
	barOpacitySlider:SetPoint("TOPLEFT", 0, -20)
	barOpacitySlider:SetWidth(sliderWidth)
	barOpacitySlider:SetMinMaxValues(0, 1)
	barOpacitySlider:SetValueStep(0.05)
	barOpacitySlider:SetValue(Config.barAlpha)

	-- Hide default slider text
	local sliderName = barOpacitySlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	barOpacitySlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value * 20 + 0.5) / 20
		barOpacityLabel:SetText("Bar Opacity: " .. math.floor(roundedValue * 100) .. "%")
		Config.barAlpha = roundedValue
		Config:Save()
		if PIL.BarManager then
			PIL.BarManager:UpdateBarsWithSorting(true)
		end
	end)

	yPos = yPos - 55

	-- Bar background opacity slider
	local barBgOpacityContainer = CreateFrame("Frame", nil, content)
	barBgOpacityContainer:SetSize(sliderWidth, 50)
	barBgOpacityContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local barBgOpacityLabel = barBgOpacityContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	barBgOpacityLabel:SetPoint("TOPLEFT", 0, 0)
	barBgOpacityLabel:SetText("Bar Background Opacity: " .. math.floor(Config.barBgAlpha * 100) .. "%")

	local barBgOpacitySlider = CreateFrame("Slider", "PeaversBarBgOpacitySlider", barBgOpacityContainer, "OptionsSliderTemplate")
	barBgOpacitySlider:SetPoint("TOPLEFT", 0, -20)
	barBgOpacitySlider:SetWidth(sliderWidth)
	barBgOpacitySlider:SetMinMaxValues(0, 1)
	barBgOpacitySlider:SetValueStep(0.05)
	barBgOpacitySlider:SetValue(Config.barBgAlpha)

	-- Hide default slider text
	local sliderName = barBgOpacitySlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	barBgOpacitySlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value * 20 + 0.5) / 20
		barBgOpacityLabel:SetText("Bar Background Opacity: " .. math.floor(roundedValue * 100) .. "%")
		Config.barBgAlpha = roundedValue
		Config:Save()
		if PIL.BarManager then
			PIL.BarManager:ResizeBars()
		end
	end)

	yPos = yPos - 65

	-- Add a thin separator
	local _, newY = UI:CreateSeparator(content, baseSpacing + 15, yPos, 400)
	yPos = newY - 15

	-- Item Level progress settings
	local ilvlProgressLabel, newY = UI:CreateLabel(content, "Item Level Progress:", controlIndent, yPos, "GameFontNormalSmall")
	ilvlProgressLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Item level step percentage slider
	local ilvlStepContainer = CreateFrame("Frame", nil, content)
	ilvlStepContainer:SetSize(sliderWidth, 50)
	ilvlStepContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local ilvlStepValueLabel = ilvlStepContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	ilvlStepValueLabel:SetPoint("TOPLEFT", 0, 0)
	ilvlStepValueLabel:SetText("Item Level Step: " .. Config.ilvlStepPercentage .. "% per level")

	local ilvlStepSlider = CreateFrame("Slider", "PeaversIlvlStepSlider", ilvlStepContainer, "OptionsSliderTemplate")
	ilvlStepSlider:SetPoint("TOPLEFT", 0, -20)
	ilvlStepSlider:SetWidth(sliderWidth)
	ilvlStepSlider:SetMinMaxValues(0.5, 5)
	ilvlStepSlider:SetValueStep(0.1)
	ilvlStepSlider:SetValue(Config.ilvlStepPercentage)

	-- Hide default slider text
	local sliderName = ilvlStepSlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	ilvlStepSlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value * 10 + 0.5) / 10
		ilvlStepValueLabel:SetText("Item Level Step: " .. roundedValue .. "% per level")
		Config.ilvlStepPercentage = roundedValue
		Config:Save()
		if PIL.BarManager then
			PIL.BarManager:UpdateBarsWithSorting(true)
		end
	end)

	yPos = yPos - 55

	-- Add explanation for Item Level Step Percentage
	local ilvlStepExplanation = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	ilvlStepExplanation:SetPoint("TOPLEFT", controlIndent, yPos)
	ilvlStepExplanation:SetWidth(sliderWidth)
	ilvlStepExplanation:SetJustifyH("LEFT")
	ilvlStepExplanation:SetText("Controls how much of the progress bar is filled based on item level differences. " ..
		"Higher values make the bars more sensitive to small item level differences, " ..
		"Lower values make the bars more gradual")

	-- Calculate the height of the explanation text
	local explanationHeight = 40
	yPos = yPos - explanationHeight - 15

	return yPos
end

-- 3. TEXT SETTINGS - Font and text appearance settings
function ConfigUI:CreateTextOptions(content, yPos, baseSpacing, sectionSpacing)
	baseSpacing = baseSpacing or 25
	sectionSpacing = sectionSpacing or 40
	local controlIndent = baseSpacing + 15
	local subControlIndent = controlIndent + 15
	local sliderWidth = 400

	-- Text Settings section header
	local header, newY = UI:CreateSectionHeader(content, "Text Settings", baseSpacing, yPos)
	header:SetFont(header:GetFont(), 18)
	yPos = newY - 10

	-- Font selection subsection
	local fontSelectLabel, newY = UI:CreateLabel(content, "Font Selection:", controlIndent, yPos, "GameFontNormalSmall")
	fontSelectLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Font dropdown container
	local fontContainer = CreateFrame("Frame", nil, content)
	fontContainer:SetSize(sliderWidth, 60)
	fontContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local fontLabel = fontContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fontLabel:SetPoint("TOPLEFT", 0, 0)
	fontLabel:SetText("Font")

	local fonts = Config:GetFonts()
	local currentFont = fonts[Config.fontFace] or "Default"

	local fontDropdown = CreateFrame("Frame", "PeaversFontDropdown", fontContainer, "UIDropDownMenuTemplate")
	fontDropdown:SetPoint("TOPLEFT", 0, -20)
	UIDropDownMenu_SetWidth(fontDropdown, 345)
	UIDropDownMenu_SetText(fontDropdown, currentFont)

	UIDropDownMenu_Initialize(fontDropdown, function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		for path, name in pairs(fonts) do
			info.text = name
			info.checked = (path == Config.fontFace)
			info.func = function()
				Config.fontFace = path
				UIDropDownMenu_SetText(fontDropdown, name)
				Config:Save()
				if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
					PIL.BarManager:CreateBars(PIL.Core.contentFrame)
					PIL.Core:AdjustFrameHeight()
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	yPos = yPos - 65

	-- Font size slider
	local fontSizeContainer = CreateFrame("Frame", nil, content)
	fontSizeContainer:SetSize(sliderWidth, 50)
	fontSizeContainer:SetPoint("TOPLEFT", controlIndent, yPos)

	local fontSizeLabel = fontSizeContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fontSizeLabel:SetPoint("TOPLEFT", 0, 0)
	fontSizeLabel:SetText("Font Size: " .. Config.fontSize)

	local fontSizeSlider = CreateFrame("Slider", "PeaversFontSizeSlider", fontSizeContainer, "OptionsSliderTemplate")
	fontSizeSlider:SetPoint("TOPLEFT", 0, -20)
	fontSizeSlider:SetWidth(sliderWidth)
	fontSizeSlider:SetMinMaxValues(6, 18)
	fontSizeSlider:SetValueStep(1)
	fontSizeSlider:SetValue(Config.fontSize)

	-- Hide default slider text
	local sliderName = fontSizeSlider:GetName()
	if sliderName then
		local lowText = _G[sliderName .. "Low"]
		local highText = _G[sliderName .. "High"]
		local valueText = _G[sliderName .. "Text"]

		if lowText then
			lowText:SetText("")
		end
		if highText then
			highText:SetText("")
		end
		if valueText then
			valueText:SetText("")
		end
	end

	fontSizeSlider:SetScript("OnValueChanged", function(self, value)
		local roundedValue = math.floor(value + 0.5)
		fontSizeLabel:SetText("Font Size: " .. roundedValue)
		Config.fontSize = roundedValue
		Config:Save()
		if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
			PIL.BarManager:CreateBars(PIL.Core.contentFrame)
			PIL.Core:AdjustFrameHeight()
		end
	end)

	yPos = yPos - 55

	-- Font style options
	local fontStyleLabel, newY = UI:CreateLabel(content, "Font Style:", controlIndent, yPos, "GameFontNormalSmall")
	fontStyleLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Font outline checkbox
	local outlineCheckbox, newY = UI:CreateCheckbox(
		content,
		"PeaversFontOutlineCheckbox",
		"Outlined Font",
		subControlIndent,
		yPos,
		Config.fontOutline == "OUTLINE",
		{ 1, 1, 1 },
		function(self)
			Config.fontOutline = self:GetChecked() and "OUTLINE" or ""
			Config:Save()
			if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
				PIL.BarManager:CreateBars(PIL.Core.contentFrame)
				PIL.Core:AdjustFrameHeight()
			end
		end
	)
	yPos = newY - 8

	-- Font shadow checkbox
	local shadowCheckbox, newY = UI:CreateCheckbox(
		content,
		"PeaversFontShadowCheckbox",
		"Font Shadow",
		subControlIndent,
		yPos,
		Config.fontShadow,
		{ 1, 1, 1 },
		function(self)
			Config.fontShadow = self:GetChecked()
			Config:Save()
			if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
				PIL.BarManager:CreateBars(PIL.Core.contentFrame)
				PIL.Core:AdjustFrameHeight()
			end
		end
	)
	yPos = newY - 15

	return yPos
end

-- 4. BEHAVIOR SETTINGS - Sorting, grouping, and other behavioral settings
function ConfigUI:CreateBehaviorOptions(content, yPos, baseSpacing, sectionSpacing)
	baseSpacing = baseSpacing or 25
	sectionSpacing = sectionSpacing or 40
	local controlIndent = baseSpacing + 15
	local subControlIndent = controlIndent + 15
	local sliderWidth = 400

	-- Behavior Settings section header
	local header, newY = UI:CreateSectionHeader(content, "Behavior Settings", baseSpacing, yPos)
	header:SetFont(header:GetFont(), 18)
	yPos = newY - 10

	-- Sorting subsection
	local sortingLabel, newY = UI:CreateLabel(content, "Sorting and Grouping:", controlIndent, yPos, "GameFontNormalSmall")
	sortingLabel:SetTextColor(0.9, 0.9, 0.9)
	yPos = newY - 8

	-- Group by role checkbox
	local groupByRoleCheckbox, newY = UI:CreateCheckbox(
		content,
		"PeaversGroupByRoleCheckbox",
		"Group Players by Role",
		subControlIndent,
		yPos,
		Config.groupByRole,
		{ 1, 1, 1 },
		function(self)
			Config.groupByRole = self:GetChecked()
			Config:Save()
			if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
				PIL.BarManager:CreateBars(PIL.Core.contentFrame)
				PIL.Core:AdjustFrameHeight()
			end
		end
	)
	yPos = newY - 15

	-- Sort options dropdown
	local sortContainer = CreateFrame("Frame", nil, content)
	sortContainer:SetSize(sliderWidth, 60)
	sortContainer:SetPoint("TOPLEFT", subControlIndent, yPos)

	local sortLabel = sortContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sortLabel:SetPoint("TOPLEFT", 0, 0)
	sortLabel:SetText("Sort Players By")

	local sortOptions = {
		["ILVL_DESC"] = "Item Level (Highest to Lowest)",
		["ILVL_ASC"] = "Item Level (Lowest to Highest)",
		["NAME_ASC"] = "Name (A to Z)",
		["NAME_DESC"] = "Name (Z to A)"
	}

	local currentOption = sortOptions[Config.sortOption] or "Name (A to Z)"

	local sortDropdown = CreateFrame("Frame", "PeaversSortDropdown", sortContainer, "UIDropDownMenuTemplate")
	sortDropdown:SetPoint("TOPLEFT", 0, -20)
	UIDropDownMenu_SetWidth(sortDropdown, 345)
	UIDropDownMenu_SetText(sortDropdown, currentOption)

	UIDropDownMenu_Initialize(sortDropdown, function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		for value, text in pairs(sortOptions) do
			info.text = text
			info.checked = (value == Config.sortOption)
			info.func = function()
				Config.sortOption = value
				UIDropDownMenu_SetText(sortDropdown, text)
				Config:Save()
				-- Update player order and refresh bars
				if PIL.Players then
					PIL.Players:ScanGroup()
					if PIL.BarManager then
						PIL.BarManager:UpdateBarsWithSorting(true)
					end
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	yPos = yPos - 65

	return yPos
end

-- Opens the configuration panel
function ConfigUI:OpenOptions()
    -- Ensure settings are saved before opening
    PIL.Config:Save()

    if Settings and Settings.OpenToCategory then
        -- Try using the category ID stored by PeaversCommons.SettingsUI
        -- Prefer opening to the settings subcategory if available
        if PIL.directSettingsCategoryID then
            local success = pcall(Settings.OpenToCategory, PIL.directSettingsCategoryID)
            if success then return end
        end

        -- Fallback to main category ID
        if PIL.directCategoryID then
            local success = pcall(Settings.OpenToCategory, PIL.directCategoryID)
            if success then return end
        end

        -- Try with category objects as fallback
        if PIL.directSettingsCategory then
            local success = pcall(Settings.OpenToCategory, PIL.directSettingsCategory)
            if success then return end
        end

        if PIL.directCategory then
            local success = pcall(Settings.OpenToCategory, PIL.directCategory)
            if success then return end
        end
    end

    -- Fallback: just open the Settings panel
    if SettingsPanel then
        ShowUIPanel(SettingsPanel)
        return
    end

    -- Legacy fallback for older clients
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("PeaversItemLevel")
        InterfaceOptionsFrame_OpenToCategory("PeaversItemLevel")
    end
end

-- Handler for the /pil config command
PIL.Config.OpenOptionsCommand = function()
	ConfigUI:OpenOptions()
end

-- Initialize the configuration UI when called
function ConfigUI:Initialize()
    self.panel = self:InitializeOptions()
end

return ConfigUI
