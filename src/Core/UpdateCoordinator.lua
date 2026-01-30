local addonName, PIL = ...

-- Initialize UpdateCoordinator namespace for event batching
PIL.UpdateCoordinator = {
    pendingUpdates = {
        fullRebuild = false,
        sortRequired = false,
        dataRefresh = false,
    },
    updateTimer = nil,
    debounceInterval = 0.1,
}

local UpdateCoordinator = PIL.UpdateCoordinator

-- Schedule an update of the specified type
function UpdateCoordinator:ScheduleUpdate(updateType)
    self.pendingUpdates[updateType] = true

    -- Cancel existing timer if any
    if self.updateTimer then
        self.updateTimer:Cancel()
    end

    -- Schedule new debounced update
    self.updateTimer = C_Timer.NewTimer(self.debounceInterval, function()
        self:ProcessUpdates()
    end)
end

-- Process all pending updates in priority order
function UpdateCoordinator:ProcessUpdates()
    self.updateTimer = nil

    -- During combat, only allow data refresh
    if InCombatLockdown() then
        if self.pendingUpdates.dataRefresh then
            PIL.BarManager:UpdateAllBars(false, true)
            self.pendingUpdates.dataRefresh = false
        end
        return
    end

    -- Priority order: rebuild > sort > data
    if self.pendingUpdates.fullRebuild then
        PIL.PlayerData:ScanGroup()
        PIL.PlayerData:CleanupCache()
        PIL.BarManager:RebuildBars()
        self:ClearAll()
        return
    end

    if self.pendingUpdates.sortRequired then
        PIL.PlayerData:SortPlayerOrder()
        PIL.BarManager:ReorderBars()
        self.pendingUpdates.sortRequired = false
    end

    if self.pendingUpdates.dataRefresh then
        PIL.BarManager:UpdateAllBars()
        self.pendingUpdates.dataRefresh = false
    end
end

-- Clear all pending updates
function UpdateCoordinator:ClearAll()
    self.pendingUpdates.fullRebuild = false
    self.pendingUpdates.sortRequired = false
    self.pendingUpdates.dataRefresh = false
end

-- Initialize the event coordinator and register event handlers
function UpdateCoordinator:Initialize()
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

    -- Inspection completed (handled primarily by PlayerData, but trigger sort)
    Events:RegisterEvent("INSPECT_READY", function()
        -- PlayerData handles the actual data update
        -- We just schedule a sort if needed
        self:ScheduleUpdate("sortRequired")
    end)

    -- Combat state changes
    Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        PIL.Core.inCombat = true
        PIL.Core:UpdateFrameVisibility()
    end)

    Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        PIL.Core.inCombat = false
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

return UpdateCoordinator
