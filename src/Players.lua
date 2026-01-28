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
        if PIL.Config.sortOption == "ILVL_DESC" then
            -- Sort by item level (highest to lowest)
            table.sort(self.PLAYER_ORDER, function(a, b)
                return self:GetItemLevel(a) > self:GetItemLevel(b)
            end)
        elseif PIL.Config.sortOption == "ILVL_ASC" then
            -- Sort by item level (lowest to highest)
            table.sort(self.PLAYER_ORDER, function(a, b)
                return self:GetItemLevel(a) < self:GetItemLevel(b)
            end)
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
    end

    -- Add to queue if not already queued
    local alreadyQueued = false
    for _, queuedUnit in ipairs(self.inspectQueue) do
        if queuedUnit == unit then
            alreadyQueued = true
            break
        end
    end

    if not alreadyQueued then
        table.insert(self.inspectQueue, unit)
    end

    -- Start the inspection process if not already running
    if not self.inspectFrame then
        self.inspectFrame = CreateFrame("Frame")
        self.inspectFrame:SetScript("OnUpdate", function(self, elapsed)
            Players:ProcessInspectQueue(elapsed)
        end)
    end
end

-- Process the inspect queue
function Players:ProcessInspectQueue(elapsed)
    -- Skip inspections during combat to avoid secret value errors (WoW 12.0.1)
    if InCombatLockdown() then
        return
    end

    if not self.inspectQueue or #self.inspectQueue == 0 then
        -- No more units to inspect, stop the process
        self.inspectFrame:SetScript("OnUpdate", nil)
        return
    end

    -- Check if we're ready to inspect
    if not self.lastInspect or GetTime() - self.lastInspect > 1.5 then
        local unit = self.inspectQueue[1]

        -- Remove from queue
        table.remove(self.inspectQueue, 1)

        -- Check if unit still exists
        if UnitExists(unit) and CanInspect(unit) and (not InspectFrame or (InspectFrame and not InspectFrame:IsShown())) then
            -- Inspect the unit
            NotifyInspect(unit)

            -- Register for INSPECT_READY event if not already registered
            if not self.inspectEventRegistered then
                self.inspectEventRegistered = true
                self.inspectFrame:RegisterEvent("INSPECT_READY")
                self.inspectFrame:SetScript("OnEvent", function(self, event, guid)
                    Players:OnInspectReady(event, guid)
                end)
            end

            -- Record the time
            self.lastInspect = GetTime()
        end
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
        -- Get the item level for the inspected unit
        local equipped = 0

        -- Use the inspect API to get item levels
        -- Loop through all equipped items and calculate average
        local totalIlvl = 0
        local itemCount = 0

        for i = 1, 17 do  -- Check all equipment slots
            if i ~= 4 then  -- Skip shirt slot
                local itemLink = GetInventoryItemLink(unit, i)
                if itemLink then
                    local _, _, _, itemLevel = GetItemInfo(itemLink)
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

        -- Cache the item level
        if not self.cachedItemLevels then
            self.cachedItemLevels = {}
        end
        self.cachedItemLevels[unit] = equipped

        -- Also update combat cache
        self.combatCache.itemLevels[unit] = equipped

        -- Update bars with proper sorting
        PIL.BarManager:UpdateBarsWithSorting()
    end
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
