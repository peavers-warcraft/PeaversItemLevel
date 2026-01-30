local addonName, PIL = ...

-- Check for PeaversCommons
local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r " .. addonName .. " requires PeaversCommons to work properly.")
    return
end

-- Check for required PeaversCommons modules
local requiredModules = {"Events", "SlashCommands", "Utils"}
for _, module in ipairs(requiredModules) do
    if not PeaversCommons[module] then
        print("|cffff0000Error:|r " .. addonName .. " requires PeaversCommons." .. module .. " which is missing.")
        return
    end
end

-- Initialize addon namespace and modules
PIL = PIL or {}

-- Module namespaces
PIL.Core = PIL.Core or {}
PIL.UI = PIL.UI or {}
PIL.Utils = PIL.Utils or {}
PIL.Config = PIL.Config or {}
PIL.Players = PIL.Players or {}

-- Version information
local function getAddOnMetadata(name, key)
    return C_AddOns.GetAddOnMetadata(name, key)
end

PIL.version = getAddOnMetadata(addonName, "Version") or "1.0.5"
PIL.addonName = addonName
PIL.name = addonName

-- Function to toggle the item level display
function ToggleItemLevelDisplay()
    if PIL.Core.frame:IsShown() then
        PIL.Core.frame:Hide()
    else
        PIL.Core.frame:Show()
    end
end

-- Make the function globally accessible
_G.ToggleItemLevelDisplay = ToggleItemLevelDisplay

-- Register slash commands
PeaversCommons.SlashCommands:Register(addonName, "pil", {
    default = function()
        ToggleItemLevelDisplay()
    end,
    config = function()
        -- Use the addon's own OpenOptions function
        if PIL.ConfigUI and PIL.ConfigUI.OpenOptions then
            PIL.ConfigUI:OpenOptions()
        elseif PIL.Config and PIL.Config.OpenOptionsCommand then
            PIL.Config.OpenOptionsCommand()
        end
    end,
})

-- Initialize addon using the PeaversCommons Events module
PeaversCommons.Events:Init(addonName, function()
    -- Initialize configuration
    PIL.Config:Initialize()

    -- Initialize configuration UI
    if PIL.ConfigUI and PIL.ConfigUI.Initialize then
        PIL.ConfigUI:Initialize()
    end

    -- Initialize patrons support
    if PIL.Patrons and PIL.Patrons.Initialize then
        PIL.Patrons:Initialize()
    end

    -- Initialize player data cache
    PIL.PlayerData:ScanGroup()

    -- Initialize core components (creates UI)
    PIL.Core:Initialize()

    -- Initialize the update coordinator (registers all events)
    PIL.UpdateCoordinator:Initialize()

    -- Show frame if configured to show on login
    if PIL.Config.showOnLogin then
        PIL.Core.frame:Show()
    else
        PIL.Core.frame:Hide()
    end

    -- Use the centralized SettingsUI system from PeaversCommons
    C_Timer.After(0.5, function()
        -- Create standardized settings pages
        PeaversCommons.SettingsUI:CreateSettingsPages(
            PIL,                     -- Addon reference
            "PeaversItemLevel",      -- Addon name
            "Peavers Item Level",    -- Display title
            "Tracks and displays item levels for group members.", -- Description
            {   -- Slash commands
                "/pil - Toggle display",
                "/pil config - Open settings"
            }
        )
    end)
end, {
    suppressAnnouncement = true
})
