local _, PIL = ...
local Players = PIL.Players

-- Class colors for UI purposes
Players.CLASS_COLORS = {
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

-- Player order (will be sorted by item level)
Players.PLAYER_ORDER = {}

-- Combat cache for handling WoW 12.0.1 "secrets" system
-- Item level APIs may return secret values during combat that cannot be compared
Players.combatCache = {
    itemLevels = {},
    highestItemLevel = 0,
    playerItemLevel = 0,
}

-- Helper function to get effective item level with backward compatibility
function Players:GetEffectiveItemLevel(itemLink)
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

-- Initialize player tracking
function Players:Initialize()
    -- Clear the player order
    self.PLAYER_ORDER = {}

    -- Scan for players in group/raid
    self:ScanGroup()
end

-- Scan for players in group/raid
function Players:ScanGroup()
    -- Clear existing players
    self.PLAYER_ORDER = {}

    -- Always add the player
    local playerName = UnitName("player")
    table.insert(self.PLAYER_ORDER, "player")

    -- Check if in a group
    if IsInGroup() then
        -- Check if in a raid
        if IsInRaid() then
            for i = 1, 40 do
                local unit = "raid" .. i
                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                    table.insert(self.PLAYER_ORDER, unit)
                end
            end
        else
            -- In a party
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    table.insert(self.PLAYER_ORDER, unit)
                end
            end
        end
    end

    -- Sort players based on configuration
    -- Skip sorting during combat to avoid secret value comparison errors (WoW 12.0.1)
    if not InCombatLockdown() then
        if PIL.Config.sortOption == "ILVL_DESC" or PIL.Config.sortOption == "ILVL_ASC" then
            -- Pre-cache item levels to avoid repeated API calls during sort
            -- This reduces GetItemLevel calls from O(n log n) to O(n)
            local cachedLevels = {}
            for _, unit in ipairs(self.PLAYER_ORDER) do
                cachedLevels[unit] = self:GetItemLevel(unit)
            end

            if PIL.Config.sortOption == "ILVL_DESC" then
                -- Sort by item level (highest to lowest)
                table.sort(self.PLAYER_ORDER, function(a, b)
                    return (cachedLevels[a] or 0) > (cachedLevels[b] or 0)
                end)
            else
                -- Sort by item level (lowest to highest)
                table.sort(self.PLAYER_ORDER, function(a, b)
                    return (cachedLevels[a] or 0) < (cachedLevels[b] or 0)
                end)
            end
        elseif PIL.Config.sortOption == "NAME_DESC" then
            -- Sort alphabetically by name (Z to A)
            table.sort(self.PLAYER_ORDER, function(a, b)
                return UnitName(a) > UnitName(b)
            end)
        else
            -- Default: Sort alphabetically by name (A to Z)
            table.sort(self.PLAYER_ORDER, function(a, b)
                return UnitName(a) < UnitName(b)
            end)
        end
    end

    -- Queue all players for inspection to ensure item levels are updated
    for _, unit in ipairs(self.PLAYER_ORDER) do
        if not UnitIsUnit(unit, "player") and CanInspect(unit) then
            self:QueueInspect(unit)
        end
    end
end

-- Get player name
function Players:GetName(unit)
    if not unit then return "Unknown" end

    local name = UnitName(unit)
    if not name then return "Unknown" end

    -- Add (You) to the player's own character name
    if UnitIsUnit(unit, "player") then
        name = name .. " (You)"
    end

    return name
end

-- Get player class
function Players:GetClass(unit)
    if not unit then return "WARRIOR" end

    local _, class = UnitClass(unit)
    return class or "WARRIOR"
end

-- Get player item level
function Players:GetItemLevel(unit)
    if not unit then return 0 end

    -- During combat, return cached values only to avoid secret value comparison errors
    if InCombatLockdown() then
        if UnitIsUnit(unit, "player") then
            return self.combatCache.playerItemLevel or 0
        end
        return self.combatCache.itemLevels[unit] or 0
    end

    -- For the player, use the GetAverageItemLevel API
    if UnitIsUnit(unit, "player") then
        local _, equipped = GetAverageItemLevel()
        -- Cache for combat use
        self.combatCache.playerItemLevel = equipped
        return equipped
    end

    -- For other players, we need to use the inspect system
    -- Check if we have cached data
    if self.cachedItemLevels and self.cachedItemLevels[unit] then
        -- Also update combat cache
        self.combatCache.itemLevels[unit] = self.cachedItemLevels[unit]
        return self.cachedItemLevels[unit]
    else
        -- Request inspect if possible
        if CanInspect(unit) and (not InspectFrame or (InspectFrame and not InspectFrame:IsShown())) then
            -- Queue this unit for inspection
            self:QueueInspect(unit)

            -- Return 0 until we get data from inspection
            return 0
        end
    end

    -- Fallback
    return 0
end

-- Queue a unit for inspection
function Players:QueueInspect(unit)
    if not self.inspectQueue then
        self.inspectQueue = {}
        self.inspectQueueSet = {}  -- Hash set for O(1) lookup
    end

    -- O(1) lookup instead of O(n) linear search
    if self.inspectQueueSet[unit] then
        return
    end

    table.insert(self.inspectQueue, unit)
    self.inspectQueueSet[unit] = true

    -- Create the event frame if it doesn't exist (for INSPECT_READY)
    if not self.inspectFrame then
        self.inspectFrame = CreateFrame("Frame")
    end

    -- Start processing queue with C_Timer (more efficient than OnUpdate)
    if not self.inspectTimerRunning then
        self.inspectTimerRunning = true
        self:ScheduleNextInspect()
    end
end

-- Schedule the next inspection using C_Timer (avoids OnUpdate overhead)
function Players:ScheduleNextInspect()
    -- Calculate delay: 1.5s between inspects, or immediate if enough time passed
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
function Players:ProcessNextInspect()
    -- Skip inspections during combat
    if InCombatLockdown() then
        -- Retry after combat
        C_Timer.After(1.0, function()
            if self.inspectQueue and #self.inspectQueue > 0 then
                self:ProcessNextInspect()
            else
                self.inspectTimerRunning = false
            end
        end)
        return
    end

    -- Check if queue is empty
    if not self.inspectQueue or #self.inspectQueue == 0 then
        self.inspectTimerRunning = false
        return
    end

    -- Get next unit
    local unit = self.inspectQueue[1]
    table.remove(self.inspectQueue, 1)
    if self.inspectQueueSet then
        self.inspectQueueSet[unit] = nil
    end

    -- Process this unit if valid
    if UnitExists(unit) and CanInspect(unit) and (not InspectFrame or not InspectFrame:IsShown()) then
        NotifyInspect(unit)

        -- Register for INSPECT_READY event if not already registered
        if not self.inspectEventRegistered then
            self.inspectEventRegistered = true
            self.inspectFrame:RegisterEvent("INSPECT_READY")
            self.inspectFrame:SetScript("OnEvent", function(frame, event, guid)
                Players:OnInspectReady(event, guid)
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
function Players:OnInspectReady(event, guid)
    if event ~= "INSPECT_READY" then return end

    -- Skip processing during combat to avoid secret value errors (WoW 12.0.1)
    if InCombatLockdown() then
        return
    end

    -- Find the unit with this GUID
    local unit = nil
    for _, u in ipairs(self.PLAYER_ORDER) do
        if UnitGUID(u) == guid then
            unit = u
            break
        end
    end

    if unit then
        local equipped = 0

        -- Use the official API for inspected unit item level (TWW+)
        -- This properly handles 2H weapons, empty slots, etc.
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            equipped = C_PaperDollInfo.GetInspectItemLevel(unit) or 0
        end

        -- Fallback: manual calculation if API unavailable or returns 0
        if equipped == 0 then
            local totalIlvl = 0
            local itemCount = 0

            -- Equipment slots: 1-3 (head, neck, shoulder), 5-17 (chest through offhand)
            -- Skip slot 4 (shirt) as it doesn't contribute to item level
            for i = 1, 17 do
                if i ~= 4 then
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

            -- Calculate average if we found any items
            if itemCount > 0 then
                equipped = totalIlvl / itemCount
            end
        end

        -- Initialize cache table if needed
        if not self.cachedItemLevels then
            self.cachedItemLevels = {}
        end

        -- Only cache if we got valid data
        -- This prevents overwriting good cached data with 0
        if equipped > 0 then
            self.cachedItemLevels[unit] = equipped
            -- Also update combat cache
            self.combatCache.itemLevels[unit] = equipped

            -- Update just this specific bar (fast path)
            local bar = PIL.BarManager:GetBar(unit)
            if bar then
                bar:Update(equipped, nil, nil, true)
            end

            -- Schedule a debounced full sort update
            -- This batches multiple inspections into one sort operation
            self:ScheduleDebouncedSort()
        end
    end
end

-- Debounced sort update - batches multiple inspection results
function Players:ScheduleDebouncedSort()
    if self.pendingSortUpdate then return end
    self.pendingSortUpdate = true

    -- Wait for inspections to settle before sorting (1 second debounce)
    C_Timer.After(1.0, function()
        self.pendingSortUpdate = false
        if not InCombatLockdown() then
            PIL.BarManager:UpdateBarsWithSorting()
        end
    end)
end

-- Returns the color for a specific player class
function Players:GetColor(unit)
    local class = self:GetClass(unit)

    if self.CLASS_COLORS[class] then
        return unpack(self.CLASS_COLORS[class])
    else
        return 0.8, 0.8, 0.8 -- Default to white/grey
    end
end

-- Gets the formatted display value for an item level
function Players:GetDisplayValue(unit)
    local itemLevel = self:GetItemLevel(unit)

    -- Format the item level as a whole number
    local displayValue = string.format("%.0f", itemLevel)

    return displayValue
end


-- Get player role
function Players:GetRole(unit)
    if not unit then return "DAMAGER" end

    local role = UnitGroupRolesAssigned(unit)

    -- If no role is assigned or it's "NONE", default to DAMAGER
    if not role or role == "NONE" then
        return "DAMAGER"
    end

    return role
end

-- Calculate average item level for a group of players
function Players:CalculateAverageItemLevel(units)
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

-- Gets the highest item level in the group
function Players:GetHighestItemLevel()
    -- During combat, return cached highest item level to avoid secret value errors
    if InCombatLockdown() then
        return math.max(1, self.combatCache.highestItemLevel or 0)
    end

    local highestItemLevel = 0

    -- Check all players in the group
    for _, unit in ipairs(self.PLAYER_ORDER) do
        local itemLevel = self:GetItemLevel(unit)
        if itemLevel > highestItemLevel then
            highestItemLevel = itemLevel
        end
    end

    -- Update combat cache
    self.combatCache.highestItemLevel = highestItemLevel

    -- Ensure we always return at least 1 to avoid division by zero
    return math.max(1, highestItemLevel)
end

-- Calculates the bar values for display
function Players:CalculateBarValues(value)
    -- Get the highest item level in the group
    local highestItemLevel = self:GetHighestItemLevel()

    -- Calculate the item level difference from the highest
    local ilvlDifference = highestItemLevel - value

    -- Use the configurable step between item levels
    -- Each item level difference equals PIL.Config.ilvlStepPercentage% of the bar
    local percentValue = 100 - (ilvlDifference * PIL.Config.ilvlStepPercentage)

    -- Ensure the percentage value is at most 100% and at least 1%
    percentValue = math.min(percentValue, 100)
    percentValue = math.max(percentValue, 1)

    return percentValue
end

-- Updates the combat cache with fresh values (called after combat ends)
function Players:UpdateCombatCache()
    -- Refresh player's own item level
    local _, equipped = GetAverageItemLevel()
    self.combatCache.playerItemLevel = equipped

    -- Refresh cached item levels for all group members
    self.combatCache.itemLevels = {}
    for _, unit in ipairs(self.PLAYER_ORDER) do
        if self.cachedItemLevels and self.cachedItemLevels[unit] then
            self.combatCache.itemLevels[unit] = self.cachedItemLevels[unit]
        end
    end

    -- Refresh highest item level
    local highestItemLevel = 0
    for _, unit in ipairs(self.PLAYER_ORDER) do
        local itemLevel = self:GetItemLevel(unit)
        if itemLevel > highestItemLevel then
            highestItemLevel = itemLevel
        end
    end
    self.combatCache.highestItemLevel = highestItemLevel
end

return Players
