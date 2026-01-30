local addonName, PIL = ...

-- Initialize PlayerData namespace for unified data cache
PIL.PlayerData = {
    cache = {},              -- unit -> {name, class, role, itemLevel}
    playerOrder = {},        -- Sorted unit list
    highestItemLevel = 0,
    combatSnapshot = {},     -- Frozen during combat

    -- Inspection state
    inspectQueue = {},
    inspectQueueSet = {},
    inspectTimerRunning = false,
    lastInspect = nil,
    inspectFrame = nil,
    inspectEventRegistered = false,
}

local PlayerData = PIL.PlayerData

-- Class colors for UI purposes
PlayerData.CLASS_COLORS = {
    ["WARRIOR"] = { 0.78, 0.61, 0.43 },
    ["PALADIN"] = { 0.96, 0.55, 0.73 },
    ["HUNTER"] = { 0.67, 0.83, 0.45 },
    ["ROGUE"] = { 1.00, 0.96, 0.41 },
    ["PRIEST"] = { 1.00, 1.00, 1.00 },
    ["DEATHKNIGHT"] = { 0.77, 0.12, 0.23 },
    ["SHAMAN"] = { 0.00, 0.44, 0.87 },
    ["MAGE"] = { 0.25, 0.78, 0.92 },
    ["WARLOCK"] = { 0.53, 0.53, 0.93 },
    ["MONK"] = { 0.00, 1.00, 0.59 },
    ["DRUID"] = { 1.00, 0.49, 0.04 },
    ["DEMONHUNTER"] = { 0.64, 0.19, 0.79 },
    ["EVOKER"] = { 0.20, 0.58, 0.50 }
}

-- Helper function to get effective item level with backward compatibility
function PlayerData:GetEffectiveItemLevel(itemLink)
    if not itemLink then return nil end

    -- Try the newer C_Item namespace first (preferred for TWW+)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local effectiveILvl = C_Item.GetDetailedItemLevelInfo(itemLink)
        if effectiveILvl and effectiveILvl > 0 then
            return effectiveILvl
        end
    end

    -- Fallback to the older global function
    if GetDetailedItemLevelInfo then
        local effectiveILvl = GetDetailedItemLevelInfo(itemLink)
        if effectiveILvl and effectiveILvl > 0 then
            return effectiveILvl
        end
    end

    -- Final fallback to GetItemInfo base item level (legacy compatibility)
    local _, _, _, itemLevel = GetItemInfo(itemLink)
    return itemLevel
end

-- Get item level for a unit (combat-safe)
function PlayerData:GetItemLevel(unit)
    if not unit then return 0 end

    -- During combat, return cached values only to avoid secret value comparison errors
    if InCombatLockdown() then
        return self.combatSnapshot[unit] or 0
    end

    -- Return from cache if available
    if self.cache[unit] and self.cache[unit].itemLevel then
        return self.cache[unit].itemLevel
    end

    return 0
end

-- Set item level for a unit
function PlayerData:SetItemLevel(unit, itemLevel)
    if not self.cache[unit] then
        self.cache[unit] = {}
    end
    self.cache[unit].itemLevel = itemLevel
    self.combatSnapshot[unit] = itemLevel
end

-- Get player name
function PlayerData:GetName(unit)
    if not unit then return "Unknown" end

    -- Check cache first
    if self.cache[unit] and self.cache[unit].name then
        return self.cache[unit].name
    end

    local name = UnitName(unit)
    if not name then return "Unknown" end

    -- Add (You) to the player's own character name
    if UnitIsUnit(unit, "player") then
        name = name .. " (You)"
    end

    -- Cache the name
    if not self.cache[unit] then
        self.cache[unit] = {}
    end
    self.cache[unit].name = name

    return name
end

-- Get player class
function PlayerData:GetClass(unit)
    if not unit then return "WARRIOR" end

    -- Check cache first
    if self.cache[unit] and self.cache[unit].class then
        return self.cache[unit].class
    end

    local _, class = UnitClass(unit)
    class = class or "WARRIOR"

    -- Cache the class
    if not self.cache[unit] then
        self.cache[unit] = {}
    end
    self.cache[unit].class = class

    return class
end

-- Get player role
function PlayerData:GetRole(unit)
    if not unit then return "DAMAGER" end

    local role = UnitGroupRolesAssigned(unit)

    -- If no role is assigned or it's "NONE", default to DAMAGER
    if not role or role == "NONE" then
        return "DAMAGER"
    end

    return role
end

-- Returns the color for a specific player class
function PlayerData:GetColor(unit)
    local class = self:GetClass(unit)

    if self.CLASS_COLORS[class] then
        return unpack(self.CLASS_COLORS[class])
    else
        return 0.8, 0.8, 0.8 -- Default to white/grey
    end
end

-- Scan group and build player order
function PlayerData:ScanGroup()
    -- Clear existing player order
    self.playerOrder = {}

    -- Always add the player
    table.insert(self.playerOrder, "player")

    -- Update player's own item level
    local _, equipped = GetAverageItemLevel()
    self:SetItemLevel("player", equipped)

    -- Check if in a group
    if IsInGroup() then
        -- Check if in a raid
        if IsInRaid() then
            for i = 1, 40 do
                local unit = "raid" .. i
                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                    table.insert(self.playerOrder, unit)
                end
            end
        else
            -- In a party
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    table.insert(self.playerOrder, unit)
                end
            end
        end
    end

    -- Sort players based on configuration (skip during combat)
    if not InCombatLockdown() then
        self:SortPlayerOrder()
    end

    -- Queue all players for inspection to ensure item levels are updated
    for _, unit in ipairs(self.playerOrder) do
        if not UnitIsUnit(unit, "player") and CanInspect(unit) then
            self:QueueInspect(unit)
        end
    end

    -- Recalculate highest item level
    self:RecalculateHighest()
end

-- Sort player order based on configuration
function PlayerData:SortPlayerOrder()
    if PIL.Config.sortOption == "ILVL_DESC" or PIL.Config.sortOption == "ILVL_ASC" then
        -- Pre-cache item levels to avoid repeated API calls during sort
        local cachedLevels = {}
        for _, unit in ipairs(self.playerOrder) do
            cachedLevels[unit] = self:GetItemLevel(unit)
        end

        if PIL.Config.sortOption == "ILVL_DESC" then
            table.sort(self.playerOrder, function(a, b)
                return (cachedLevels[a] or 0) > (cachedLevels[b] or 0)
            end)
        else
            table.sort(self.playerOrder, function(a, b)
                return (cachedLevels[a] or 0) < (cachedLevels[b] or 0)
            end)
        end
    elseif PIL.Config.sortOption == "NAME_DESC" then
        table.sort(self.playerOrder, function(a, b)
            return (UnitName(a) or "") > (UnitName(b) or "")
        end)
    else
        -- Default: Sort alphabetically by name (A to Z)
        table.sort(self.playerOrder, function(a, b)
            return (UnitName(a) or "") < (UnitName(b) or "")
        end)
    end
end

-- Recalculate the highest item level in the group
function PlayerData:RecalculateHighest()
    -- During combat, don't recalculate
    if InCombatLockdown() then
        return
    end

    local highest = 0
    for _, unit in ipairs(self.playerOrder) do
        local itemLevel = self:GetItemLevel(unit)
        if itemLevel > highest then
            highest = itemLevel
        end
    end

    self.highestItemLevel = highest
end

-- Gets the highest item level in the group (combat-safe)
function PlayerData:GetHighestItemLevel()
    -- During combat, return cached highest item level
    if InCombatLockdown() then
        return math.max(1, self.highestItemLevel or 0)
    end

    -- Ensure we always return at least 1 to avoid division by zero
    return math.max(1, self.highestItemLevel)
end

-- Refresh combat cache with fresh values
function PlayerData:RefreshCombatCache()
    -- Refresh player's own item level
    local _, equipped = GetAverageItemLevel()
    self.combatSnapshot["player"] = equipped

    -- Copy all cached item levels to combat snapshot
    for unit, data in pairs(self.cache) do
        if data.itemLevel then
            self.combatSnapshot[unit] = data.itemLevel
        end
    end
end

-- Queue a unit for inspection
function PlayerData:QueueInspect(unit)
    -- O(1) lookup instead of O(n) linear search
    if self.inspectQueueSet[unit] then
        return
    end

    table.insert(self.inspectQueue, unit)
    self.inspectQueueSet[unit] = true

    -- Create the event frame if it doesn't exist
    if not self.inspectFrame then
        self.inspectFrame = CreateFrame("Frame")
    end

    -- Start processing queue with C_Timer
    if not self.inspectTimerRunning then
        self.inspectTimerRunning = true
        self:ScheduleNextInspect()
    end
end

-- Schedule the next inspection using C_Timer
function PlayerData:ScheduleNextInspect()
    local delay = 1.5
    if self.lastInspect then
        local elapsed = GetTime() - self.lastInspect
        delay = math.max(0.1, 1.5 - elapsed)
    end

    C_Timer.After(delay, function()
        self:ProcessNextInspect()
    end)
end

-- Process the next unit in the inspect queue
function PlayerData:ProcessNextInspect()
    -- Skip inspections during combat
    if InCombatLockdown() then
        C_Timer.After(1.0, function()
            if #self.inspectQueue > 0 then
                self:ProcessNextInspect()
            else
                self.inspectTimerRunning = false
            end
        end)
        return
    end

    -- Check if queue is empty
    if #self.inspectQueue == 0 then
        self.inspectTimerRunning = false
        return
    end

    -- Get next unit
    local unit = self.inspectQueue[1]
    table.remove(self.inspectQueue, 1)
    self.inspectQueueSet[unit] = nil

    -- Process this unit if valid
    if UnitExists(unit) and CanInspect(unit) and (not InspectFrame or not InspectFrame:IsShown()) then
        NotifyInspect(unit)

        -- Register for INSPECT_READY event if not already registered
        if not self.inspectEventRegistered then
            self.inspectEventRegistered = true
            self.inspectFrame:RegisterEvent("INSPECT_READY")
            self.inspectFrame:SetScript("OnEvent", function(frame, event, guid)
                PlayerData:OnInspectReady(event, guid)
            end)
        end

        self.lastInspect = GetTime()
    end

    -- Schedule next inspection if queue not empty
    if #self.inspectQueue > 0 then
        self:ScheduleNextInspect()
    else
        self.inspectTimerRunning = false
    end
end

-- Handle INSPECT_READY event
function PlayerData:OnInspectReady(event, guid)
    if event ~= "INSPECT_READY" then return end

    -- Skip processing during combat
    if InCombatLockdown() then
        return
    end

    -- Find the unit with this GUID
    local unit = nil
    for _, u in ipairs(self.playerOrder) do
        if UnitGUID(u) == guid then
            unit = u
            break
        end
    end

    if unit then
        local equipped = 0

        -- Use the official API for inspected unit item level (TWW+)
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            equipped = C_PaperDollInfo.GetInspectItemLevel(unit) or 0
        end

        -- Fallback: manual calculation if API unavailable or returns 0
        if equipped == 0 then
            local totalIlvl = 0
            local itemCount = 0

            for i = 1, 17 do
                if i ~= 4 then -- Skip shirt slot
                    local itemLink = GetInventoryItemLink(unit, i)
                    if itemLink then
                        local itemLevel = self:GetEffectiveItemLevel(itemLink)
                        if itemLevel and itemLevel > 0 then
                            totalIlvl = totalIlvl + itemLevel
                            itemCount = itemCount + 1
                        end
                    end
                end
            end

            if itemCount > 0 then
                equipped = totalIlvl / itemCount
            end
        end

        -- Only update if we got valid data
        if equipped > 0 then
            self:SetItemLevel(unit, equipped)

            -- Update just this specific bar (fast path)
            local bar = PIL.BarPool:GetBar(unit)
            if bar then
                bar:Update(equipped, nil, nil, true)
            end

            -- Recalculate highest and schedule sort update
            self:RecalculateHighest()

            if PIL.UpdateCoordinator then
                PIL.UpdateCoordinator:ScheduleUpdate("sortRequired")
            end
        end
    end
end

-- Calculate average item level for a group of players
function PlayerData:CalculateAverageItemLevel(units)
    if not units or #units == 0 then
        return 0
    end

    local totalItemLevel = 0
    local validPlayers = 0

    for _, unit in ipairs(units) do
        local itemLevel = self:GetItemLevel(unit)
        if itemLevel and itemLevel > 0 then
            totalItemLevel = totalItemLevel + itemLevel
            validPlayers = validPlayers + 1
        end
    end

    if validPlayers > 0 then
        return totalItemLevel / validPlayers
    else
        return 0
    end
end

-- Calculates the bar values for display
function PlayerData:CalculateBarValues(value)
    local highestItemLevel = self:GetHighestItemLevel()
    local ilvlDifference = highestItemLevel - value
    local percentValue = 100 - (ilvlDifference * PIL.Config.ilvlStepPercentage)

    percentValue = math.min(percentValue, 100)
    percentValue = math.max(percentValue, 1)

    return percentValue
end

-- Gets the formatted display value for an item level
function PlayerData:GetDisplayValue(unit)
    local itemLevel = self:GetItemLevel(unit)
    return string.format("%.0f", itemLevel)
end

-- Clean up stale cache entries for units no longer in group
function PlayerData:CleanupCache()
    local validUnits = {}
    for _, unit in ipairs(self.playerOrder) do
        validUnits[unit] = true
    end

    for unit in pairs(self.cache) do
        if not validUnits[unit] then
            self.cache[unit] = nil
            self.combatSnapshot[unit] = nil
        end
    end
end

return PlayerData
