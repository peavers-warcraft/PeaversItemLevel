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
PIL.Core = {}
PIL.UI = {}
PIL.Utils = {}
PIL.Config = {}
PIL.Players = {}

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

	-- Initialize core components
	PIL.Core:Initialize()

	-- Register event handlers
	PeaversCommons.Events:RegisterEvent("GROUP_ROSTER_UPDATE", function(event, ...)
		-- Group composition changed, rescan group
		PIL.Players:ScanGroup()
		-- Update bars with proper sorting
		PIL.BarManager:UpdateBarsWithSorting()
		-- Update frame visibility based on new group state
		PIL.Core:UpdateFrameVisibility()
	end)

	PeaversCommons.Events:RegisterEvent("UNIT_NAME_UPDATE", function(event, unit)
		if unit and (UnitInParty(unit) or UnitInRaid(unit)) then
			PIL.BarManager:UpdateBarsWithSorting(true) -- Force update to refresh names
		end
	end)

	PeaversCommons.Events:RegisterEvent("UNIT_INVENTORY_CHANGED", function()
		PIL.BarManager:UpdateBarsWithSorting()
	end)

	PeaversCommons.Events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
		PIL.BarManager:UpdateBarsWithSorting()
	end)

	PeaversCommons.Events:RegisterEvent("INSPECT_READY", function()
		PIL.BarManager:UpdateBarsWithSorting()
	end)

	PeaversCommons.Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		PIL.Core.inCombat = true
		PIL.Core:UpdateFrameVisibility()
	end)

	PeaversCommons.Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		PIL.Core.inCombat = false
		PIL.Core:UpdateFrameVisibility()
		-- Refresh combat cache and trigger full bar update with sorting after combat ends
		PIL.Players:UpdateCombatCache()
		PIL.BarManager:UpdateBarsWithSorting(true)
	end)

	PeaversCommons.Events:RegisterEvent("PLAYER_LOGOUT", function()
		PIL.Config:Save()
	end)

	-- Set up OnUpdate handler
	PeaversCommons.Events:RegisterOnUpdate(1.0, function(elapsed)
		local interval = PIL.Core.inCombat and PIL.Config.combatUpdateInterval or 3.0
		PIL.BarManager:UpdateAllBars(false, not PIL.Core.inCombat)
	end, "PIL_Update")

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
