local addonName, PIL = ...

-- Access PeaversCommons
local PeaversCommons = _G.PeaversCommons
local DefaultConfig = PeaversCommons and PeaversCommons.DefaultConfig

-- Get defaults from PeaversCommons preset or use fallback
local defaults
if DefaultConfig then
	defaults = DefaultConfig.FromPreset("PlayerBars")
else
	-- Fallback defaults if PeaversCommons not loaded yet
	defaults = {
		frameWidth = 250,
		frameHeight = 300,
		framePoint = "RIGHT",
		frameX = -20,
		frameY = 0,
		lockPosition = false,
		barWidth = 230,
		barHeight = 20,
		barSpacing = 2,
		barBgAlpha = 0.7,
		barAlpha = 1.0,
		fontFace = "Fonts\\FRIZQT__.TTF",
		fontSize = 8,
		fontOutline = "OUTLINE",
		fontShadow = false,
		barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
		bgAlpha = 0.8,
		bgColor = { r = 0, g = 0, b = 0 },
		updateInterval = 0.5,
		combatUpdateInterval = 0.2,
		showOnLogin = true,
		showTitleBar = true,
		showStats = { ["ITEM_LEVEL"] = true },
		customColors = {},
		hideOutOfCombat = false,
		ilvlStepPercentage = 2.0,
		sortOption = "NAME_ASC",
		groupByRole = false,
		displayMode = "ALWAYS",
	}
end

-- Initialize Config namespace with default values from preset
PIL.Config = {}
for key, value in pairs(defaults) do
	if type(value) == "table" then
		PIL.Config[key] = {}
		for k, v in pairs(value) do
			PIL.Config[key][k] = v
		end
	else
		PIL.Config[key] = value
	end
end

local Config = PIL.Config

-- Saves all configuration values to the SavedVariables database
function Config:Save()
	if not PeaversItemLevelDB then
		PeaversItemLevelDB = {}
	end


	-- Create data to save
	local saveData = {
		fontFace = self.fontFace,
		fontSize = self.fontSize,
		fontOutline = self.fontOutline,
		fontShadow = self.fontShadow,
		framePoint = self.framePoint,
		frameX = self.frameX,
		frameY = self.frameY,
		frameWidth = self.frameWidth,
		barWidth = self.barWidth,
		barHeight = self.barHeight,
		barTexture = self.barTexture,
		barBgAlpha = self.barBgAlpha,
		barAlpha = self.barAlpha,
		bgAlpha = self.bgAlpha,
		bgColor = self.bgColor,
		showStats = self.showStats,
		barSpacing = self.barSpacing,
		showTitleBar = self.showTitleBar,
		lockPosition = self.lockPosition,
		customColors = self.customColors,
		hideOutOfCombat = self.hideOutOfCombat,
		ilvlStepPercentage = self.ilvlStepPercentage,
		sortOption = self.sortOption,
		groupByRole = self.groupByRole,
		displayMode = self.displayMode
	}

	-- Save data to the database
	for key, value in pairs(saveData) do
		PeaversItemLevelDB[key] = value
	end
end

-- Loads settings from a specific profile or database
function Config:LoadSettings(source)
	if not source then
		return
	end

	if source.fontFace then
		self.fontFace = source.fontFace
	end
	if source.fontSize then
		self.fontSize = source.fontSize
	end
	if source.fontOutline then
		self.fontOutline = source.fontOutline
	end
	if source.fontShadow ~= nil then
		self.fontShadow = source.fontShadow
	end
	if source.framePoint then
		self.framePoint = source.framePoint
	end
	if source.frameX then
		self.frameX = source.frameX
	end
	if source.frameY then
		self.frameY = source.frameY
	end
	if source.frameWidth then
		self.frameWidth = source.frameWidth
	end
	if source.barWidth then
		self.barWidth = source.barWidth
	end
	if source.barHeight then
		self.barHeight = source.barHeight
	end
	if source.barTexture then
		self.barTexture = source.barTexture
	end
	if source.barBgAlpha then
		self.barBgAlpha = source.barBgAlpha
	end
	if source.barAlpha then
		self.barAlpha = source.barAlpha
	end
	if source.bgAlpha then
		self.bgAlpha = source.bgAlpha
	end
	if source.bgColor then
		self.bgColor = source.bgColor
	end
	if source.showStats then
		self.showStats = source.showStats
	end
	if source.barSpacing then
		self.barSpacing = source.barSpacing
	end
	if source.showTitleBar ~= nil then
		self.showTitleBar = source.showTitleBar
	end
	if source.lockPosition ~= nil then
		self.lockPosition = source.lockPosition
	end
	if source.customColors then
		self.customColors = source.customColors
	end
	if source.hideOutOfCombat ~= nil then
		self.hideOutOfCombat = source.hideOutOfCombat
	end
	if source.ilvlStepPercentage ~= nil then
		self.ilvlStepPercentage = source.ilvlStepPercentage
	end
	if source.sortOption ~= nil then
		self.sortOption = source.sortOption
	elseif source.sortByIlvl ~= nil then
		-- Convert old boolean setting to new string setting
		self.sortOption = source.sortByIlvl and "ILVL_DESC" or "NAME_ASC"
	end
	if source.groupByRole ~= nil then
		self.groupByRole = source.groupByRole
	end
	if source.displayMode ~= nil then
		self.displayMode = source.displayMode
	end
end

-- Loads configuration values from the SavedVariables database
function Config:Load()
	if not PeaversItemLevelDB then
		return
	end

	-- Load settings directly from the database
	self:LoadSettings(PeaversItemLevelDB)
end

-- Returns a sorted table of available fonts, including those from LibSharedMedia
function Config:GetFonts()
	local PeaversCommons = _G.PeaversCommons
	if PeaversCommons and PeaversCommons.DefaultConfig then
		return PeaversCommons.DefaultConfig.GetFonts()
	end

	-- Fallback
	local fonts = {
		["Fonts\\ARIALN.TTF"] = "Arial Narrow",
		["Fonts\\FRIZQT__.TTF"] = "Default",
		["Fonts\\MORPHEUS.TTF"] = "Morpheus",
		["Fonts\\SKURRI.TTF"] = "Skurri"
	}
	return fonts
end

-- Returns a sorted table of available statusbar textures from various sources
function Config:GetBarTextures()
	local PeaversCommons = _G.PeaversCommons
	if PeaversCommons and PeaversCommons.DefaultConfig then
		return PeaversCommons.DefaultConfig.GetBarTextures()
	end

	-- Fallback
	local textures = {
		["Interface\\TargetingFrame\\UI-StatusBar"] = "Default",
		["Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"] = "Skill Bar",
		["Interface\\PVPFrame\\UI-PVP-Progress-Bar"] = "PVP Bar",
		["Interface\\RaidFrame\\Raid-Bar-Hp-Fill"] = "Raid"
	}
	return textures
end

-- Initialize the configuration when the addon loads
function Config:Initialize()
    -- Load saved configuration
    self:Load()

    -- Ensure item level stat is in the showStats table
    if self.showStats["ITEM_LEVEL"] == nil then
        -- Enable item level stat by default
        self.showStats["ITEM_LEVEL"] = true
    end


    -- Ensure hideOutOfCombat is disabled by default
    if self.hideOutOfCombat == nil then
        self.hideOutOfCombat = false
    end

    -- Ensure ilvlStepPercentage has a default value
    if self.ilvlStepPercentage == nil then
        self.ilvlStepPercentage = 2.0
    end

    -- Ensure sortOption has a default value
    if self.sortOption == nil then
        self.sortOption = "NAME_ASC"
    end

    -- Ensure groupByRole has a default value
    if self.groupByRole == nil then
        self.groupByRole = false
    end

    -- Ensure displayMode has a default value
    if self.displayMode == nil then
        self.displayMode = "ALWAYS"
    end
end
