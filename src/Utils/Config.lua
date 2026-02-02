--------------------------------------------------------------------------------
-- PeaversItemLevel Configuration
-- Uses PeaversCommons.ConfigManager for configuration management
--------------------------------------------------------------------------------

local addonName, PIL = ...

local PeaversCommons = _G.PeaversCommons
local ConfigManager = PeaversCommons.ConfigManager

-- PIL-specific defaults (these extend the common defaults from ConfigManager)
local PIL_DEFAULTS = {
    -- Frame position
    framePoint = "RIGHT",
    frameX = -20,
    frameY = 0,
    frameWidth = 250,
    frameHeight = 300,

    -- Bar settings
    barWidth = 230,
    barBgAlpha = 0.7,
    fontSize = 8,

    -- PIL-specific features
    combatUpdateInterval = 0.2,
    showStats = { ["ITEM_LEVEL"] = true },
    hideOutOfCombat = false,
    displayMode = "ALWAYS",
    ilvlStepPercentage = 2.0,
    sortOption = "NAME_ASC",
    groupByRole = false,
}

-- Create the config using ConfigManager (global settings, not per-character)
PIL.Config = ConfigManager:New(
    PIL,
    PIL_DEFAULTS,
    { savedVariablesName = "PeaversItemLevelDB" }
)

local Config = PIL.Config

--------------------------------------------------------------------------------
-- PIL-Specific Methods
--------------------------------------------------------------------------------

-- Override Initialize to handle PIL-specific defaults
local baseInitialize = Config.Initialize
function Config:Initialize()
    baseInitialize(self)

    -- Ensure item level stat is in the showStats table
    if not self.showStats then
        self.showStats = {}
    end
    if self.showStats["ITEM_LEVEL"] == nil then
        self.showStats["ITEM_LEVEL"] = true
    end

    -- Ensure PIL-specific defaults are set
    if self.ilvlStepPercentage == nil then
        self.ilvlStepPercentage = 2.0
    end
    if self.sortOption == nil then
        self.sortOption = "NAME_ASC"
    end
    if self.groupByRole == nil then
        self.groupByRole = false
    end
    if self.displayMode == nil then
        self.displayMode = "ALWAYS"
    end

    self:Save()
end

-- LoadSettings helper for backwards compatibility (used by some UI code)
function Config:LoadSettings(source)
    if not source then return end

    for k, v in pairs(source) do
        if k ~= "LoadSettings" and type(v) ~= "function" then
            self[k] = v
        end
    end

    -- Handle old sortByIlvl migration
    if source.sortByIlvl ~= nil and source.sortOption == nil then
        self.sortOption = source.sortByIlvl and "ILVL_DESC" or "NAME_ASC"
    end
end

return PIL.Config
