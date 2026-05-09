--------------------------------------------------------------------------------
-- PeaversItemLevel Configuration
-- Uses PeaversCommons.ConfigManager with AceDB-3.0 for profile management
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

-- Create the AceDB-backed config
PIL.Config = ConfigManager:NewWithAceDB(
    PIL,
    PIL_DEFAULTS,
    {
        savedVariablesName = "PeaversItemLevelDB",
        profileType = "shared",
        onProfileChanged = function()
            if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
                PIL.BarManager:CreateBars(PIL.Core.contentFrame)
                PIL.Core:AdjustFrameHeight()
            end
        end,
    }
)

local Config = PIL.Config

--------------------------------------------------------------------------------
-- PIL-Specific Methods
--------------------------------------------------------------------------------

function Config:InitializeStatSettings()
    if not self.showStats then
        self.showStats = {}
    end
    if self.showStats["ITEM_LEVEL"] == nil then
        self.showStats["ITEM_LEVEL"] = true
    end
end

return PIL.Config
