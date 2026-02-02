local addonName, PIL = ...

--[[
    PIL UpdateCoordinator - Now uses PeaversCommons.UpdateCoordinator as base

    This file creates a PIL-specific coordinator that wraps PeaversCommons.UpdateCoordinator
    with PIL-specific update handlers and event registration.
]]

local PeaversCommons = _G.PeaversCommons

-- Create PIL's update coordinator using Commons
PIL.UpdateCoordinator = PeaversCommons.UpdateCoordinator:New({
    debounceInterval = 0.1,
    combatBehavior = "dataRefreshOnly",

    updateHandlers = {
        fullRebuild = function()
            PIL.PlayerData:ScanGroup()
            PIL.PlayerData:CleanupCache()
            PIL.BarManager:RebuildBars()
        end,

        sortRequired = function()
            PIL.PlayerData:SortPlayerOrder()
            PIL.BarManager:ReorderBars()
        end,

        dataRefresh = function()
            PIL.BarManager:UpdateAllBars()
        end,
    },
})

-- Initialize event handlers for PIL
function PIL.UpdateCoordinator:Initialize()
    local Events = PeaversCommons.Events

    -- Group composition changed
    Events:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        self:ScheduleUpdate("fullRebuild")
        -- Update frame visibility based on new group state
        PIL.Core:UpdateFrameVisibility()
    end)

    -- Player name updated (rare but handle it)
    Events:RegisterEvent("UNIT_NAME_UPDATE", function(event, unit)
        if unit and (UnitInParty(unit) or UnitInRaid(unit)) then
            local bar = PIL.BarPool:GetBar(unit)
            if bar then
                local playerName = PIL.PlayerData:GetName(unit)
                if bar.name ~= playerName then
                    bar.name = playerName
                    bar:UpdateNameText()
                end
            end
        end
    end)

    -- Equipment changed
    Events:RegisterEvent("UNIT_INVENTORY_CHANGED", function()
        self:ScheduleUpdate("dataRefresh")
    end)

    Events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
        self:ScheduleUpdate("dataRefresh")
    end)

    -- Inspection completed
    Events:RegisterEvent("INSPECT_READY", function()
        self:ScheduleUpdate("sortRequired")
    end)

    -- Combat state changes
    Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        PIL.Core.inCombat = true
        self:SetCombatState(true)
        PIL.Core:UpdateFrameVisibility()
    end)

    Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        PIL.Core.inCombat = false
        self:SetCombatState(false)
        PIL.Core:UpdateFrameVisibility()

        -- Refresh combat cache and process any pending updates
        PIL.PlayerData:RefreshCombatCache()
        self:ProcessUpdates()

        -- Force a full update after combat
        self:ScheduleUpdate("sortRequired")
    end)

    -- Save config on logout
    Events:RegisterEvent("PLAYER_LOGOUT", function()
        PIL.Config:Save()
    end)

    -- Periodic update for continuous data refresh
    Events:RegisterOnUpdate(1.0, function(elapsed)
        self:ScheduleUpdate("dataRefresh")
    end, "PIL_Update")
end

return PIL.UpdateCoordinator
