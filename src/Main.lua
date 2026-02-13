local addonName, PIL = ...

-- Check for PeaversCommons
local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r " .. addonName .. " requires PeaversCommons to work properly.")
    return
end

local AddonInit = PeaversCommons.AddonInit

-- Setup addon using AddonInit helper
local success = AddonInit:Setup(PIL, addonName, {
    modules = {"Core", "UI", "Utils", "Config", "Players"},
    slashCommand = "pil",
    toggleFunctionName = "ToggleItemLevelDisplay",
    extraSlashCommands = {}
})

if not success then return end

-- Expose addon namespace globally for PeaversUISetup integration
_G.PeaversItemLevel = PIL

-- Initialize addon using the PeaversCommons Events module
PeaversCommons.Events:Init(addonName, function()
    -- Initialize configuration
    PIL.Config:Initialize()

    -- Register with GlobalAppearance if using global appearance
    if PIL.Config.useGlobalAppearance and PeaversCommons.GlobalAppearance then
        PeaversCommons.GlobalAppearance:RegisterAddon("PeaversItemLevel", PIL.Config, function(key, value)
            -- Refresh UI when global appearance changes
            if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
                PIL.BarManager:CreateBars(PIL.Core.contentFrame)
                PIL.Core:AdjustFrameHeight()
            end
            -- Update frame background
            if PIL.Core and PIL.Core.frame then
                PIL.Core.frame:SetBackdropColor(
                    PIL.Config.bgColor.r,
                    PIL.Config.bgColor.g,
                    PIL.Config.bgColor.b,
                    PIL.Config.bgAlpha
                )
            end
        end)
    end

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

    -- Register common events (logout save, combat visibility, group updates)
    AddonInit:RegisterCommonEvents(PIL)

    -- Register PIL-specific event handlers
    PeaversCommons.Events:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        PIL.Players:ScanGroup()
        PIL.BarManager:UpdateBarsWithSorting()
    end)

    PeaversCommons.Events:RegisterEvent("UNIT_NAME_UPDATE", function(event, unit)
        if unit and (UnitInParty(unit) or UnitInRaid(unit)) then
            PIL.BarManager:UpdateBarsWithSorting(true)
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

    PeaversCommons.Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        -- Additional PIL-specific: refresh combat cache after combat
        PIL.Players:UpdateCombatCache()
        PIL.BarManager:UpdateBarsWithSorting(true)
    end)

    -- Set up OnUpdate handler
    PeaversCommons.Events:RegisterOnUpdate(1.0, function(elapsed)
        local interval = PIL.Core.inCombat and PIL.Config.combatUpdateInterval or 3.0
        PIL.BarManager:UpdateAllBars(false, not PIL.Core.inCombat)
    end, "PIL_Update")

    -- Create settings pages
    AddonInit:CreateSettingsPages(
        PIL,
        "PeaversItemLevel",
        "Peavers Item Level",
        "Tracks and displays item levels for group members.",
        {"/pil - Toggle display", "/pil config - Open settings"}
    )
end, {
    suppressAnnouncement = true
})
