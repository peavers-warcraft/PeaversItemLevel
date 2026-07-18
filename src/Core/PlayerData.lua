local addonName, PIL = ...

-- Initialize PlayerData namespace for unified data cache
PIL.PlayerData = {
    cache = {},              -- unit -> {name, class, role, itemLevel}
    guidCache = {},          -- guid -> {itemLevel, scannedAt} - survives roster changes
    unitGuids = {},          -- unit -> guid, to detect a token changing occupant
    playerOrder = {},        -- Sorted unit list
    highestItemLevel = 0,
    combatSnapshot = {},     -- Frozen during combat

    -- Inspection state
    inspectQueue = {},       -- Array of {guid, unit, attempts}
    inspectDeferred = {},    -- Entries awaiting a retry pass
    inspectQueueSet = {},    -- guid -> queue entry (live or deferred), for O(1) dedupe
    inspectTimerRunning = false,
    pendingInspect = nil,    -- The inspect we are currently awaiting a reply for
    inspectFrame = nil,
    inspectEventRegistered = false,
}

local PlayerData = PIL.PlayerData

-- Inspect pacing. Blizzard throttles NotifyInspect at roughly 0.3s; anything
-- slower just adds dead air. A 20-man raid fills in ~7s instead of ~30s.
local INSPECT_THROTTLE = 0.35
-- How long to wait for INSPECT_READY before assuming the request was dropped
-- (out of range, loading screen, phased) and retrying.
local INSPECT_TIMEOUT = 2.0
local INSPECT_MAX_ATTEMPTS = 3
-- Pause before retrying units that were unreachable, so a raid-wide out-of-range
-- burst doesn't consume every attempt in a single frame.
local INSPECT_RETRY_DELAY = 3.0
-- Cached item levels older than this get a background refresh, but are shown
-- immediately in the meantime rather than rendering a 0.
local CACHE_STALE_AFTER = 900

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

-- Drop unit-scoped data when a token changes occupant. Raid tokens are
-- positional: someone joining or leaving shifts everyone below them, so
-- "raid5" routinely becomes a different player. Without this, that player
-- inherits the previous occupant's name, class and item level until their
-- own inspect lands.
function PlayerData:SyncUnitIdentity(unit)
    local guid = UnitGUID(unit)

    if self.unitGuids[unit] ~= guid then
        self.unitGuids[unit] = guid
        self.cache[unit] = nil
        self.combatSnapshot[unit] = nil
    end

    return guid
end

-- Look up a previously inspected item level by player identity. This is what
-- makes a roster change cheap: someone we have seen before renders instantly
-- instead of waiting behind the whole inspect queue.
function PlayerData:GetCachedItemLevel(guid)
    local entry = guid and self.guidCache[guid]
    return entry and entry.itemLevel or nil
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

    -- Fall back to what we know about this player from a previous group
    local cached = self:GetCachedItemLevel(UnitGUID(unit))
    if cached then
        self:SetItemLevel(unit, cached)
        return cached
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

    -- Record against player identity so the value survives roster shuffles,
    -- leaving and rejoining, and zoning between instances.
    local guid = UnitGUID(unit)
    if guid then
        self.guidCache[guid] = {
            itemLevel = itemLevel,
            scannedAt = GetTime(),
        }
        self.unitGuids[unit] = guid
    end
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

    -- Reconcile tokens against player identity, then seed each player from the
    -- identity cache so known players render immediately on join.
    for _, unit in ipairs(self.playerOrder) do
        if not UnitIsUnit(unit, "player") then
            local guid = self:SyncUnitIdentity(unit)
            local cached = self:GetCachedItemLevel(guid)
            if cached then
                self:SetItemLevel(unit, cached)
            end
        end
    end

    -- Sort players based on configuration (skip during combat)
    if not InCombatLockdown() then
        self:SortPlayerOrder()
    end

    -- Queue inspections. Players we have never seen go to the front so a
    -- single person joining a full raid resolves in well under a second
    -- instead of queueing behind 39 pointless re-inspects.
    for _, unit in ipairs(self.playerOrder) do
        if not UnitIsUnit(unit, "player") and CanInspect(unit) then
            local guid = UnitGUID(unit)
            local entry = guid and self.guidCache[guid]

            if not entry then
                self:QueueInspect(unit, true)
            elseif (GetTime() - entry.scannedAt) > CACHE_STALE_AFTER then
                self:QueueInspect(unit, false)
            end
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

-- Queue a unit for inspection. Pass priority=true to jump the queue, which is
-- what a newly joined player gets.
function PlayerData:QueueInspect(unit, priority)
    local guid = UnitGUID(unit)
    if not guid then return end

    -- Dedupe on identity, not token, so a shuffled roster can't double-queue
    -- the same player under two names.
    local existing = self.inspectQueueSet[guid]
    if existing then
        -- Keep the token current; the old one may now point at someone else
        existing.unit = unit
        return
    end

    local entry = { guid = guid, unit = unit, attempts = 0 }
    self.inspectQueueSet[guid] = entry

    if priority then
        table.insert(self.inspectQueue, 1, entry)
    else
        table.insert(self.inspectQueue, entry)
    end

    -- Create the event frame if it doesn't exist
    if not self.inspectFrame then
        self.inspectFrame = CreateFrame("Frame")
    end

    -- Register for INSPECT_READY up front, so a reply can never arrive before
    -- we are listening for it
    if not self.inspectEventRegistered then
        self.inspectEventRegistered = true
        self.inspectFrame:RegisterEvent("INSPECT_READY")
        self.inspectFrame:SetScript("OnEvent", function(frame, event, readyGuid)
            PlayerData:OnInspectReady(event, readyGuid)
        end)
    end

    self:EnsureInspectEngine()
end

-- Start the tick chain if it isn't already running. Exactly one chain may be
-- live at a time, otherwise the throttle no longer bounds the request rate.
function PlayerData:EnsureInspectEngine()
    if self.inspectTimerRunning then return end
    self.inspectTimerRunning = true
    self:ScheduleInspectTick(0)
end

function PlayerData:ScheduleInspectTick(delay)
    C_Timer.After(delay, function()
        self:InspectTick()
    end)
end

-- Hold a failed request for a later pass so out-of-range or phased players
-- resolve when they become inspectable, instead of showing 0 forever.
--
-- Deferred entries deliberately do NOT go straight back onto inspectQueue:
-- the drain loop below would pop them again in the same frame and burn every
-- retry instantly, which is exactly what a retry is meant to avoid.
function PlayerData:RetryInspect(entry)
    if entry.attempts >= INSPECT_MAX_ATTEMPTS then
        self.inspectQueueSet[entry.guid] = nil
        return
    end

    table.insert(self.inspectDeferred, entry)
    self.inspectQueueSet[entry.guid] = entry
end

-- Move deferred retries back onto the live queue
function PlayerData:PromoteDeferredInspects()
    if #self.inspectDeferred == 0 then return false end

    for _, entry in ipairs(self.inspectDeferred) do
        table.insert(self.inspectQueue, entry)
    end
    self.inspectDeferred = {}

    return true
end

-- Drives the inspect queue: one outstanding request at a time, with a timeout
-- so a dropped reply can't wedge the engine.
function PlayerData:InspectTick()
    -- Still waiting on a reply?
    if self.pendingInspect then
        if (GetTime() - self.pendingInspect.startedAt) < INSPECT_TIMEOUT then
            return self:ScheduleInspectTick(0.2)
        end

        -- Timed out. Release Blizzard's inspect slot and retry this player.
        ClearInspectPlayer()
        local timedOut = self.pendingInspect
        self.pendingInspect = nil
        self:RetryInspect(timedOut)
    end

    if InCombatLockdown() then
        return self:ScheduleInspectTick(1.0)
    end

    -- Don't fight the user's own inspect window for the shared inspect slot
    if InspectFrame and InspectFrame:IsShown() then
        return self:ScheduleInspectTick(1.0)
    end

    -- Find the next inspectable entry
    while true do
        local entry = table.remove(self.inspectQueue, 1)

        if not entry then
            -- Live queue drained. If anything is waiting on a retry, come back
            -- for it after a pause rather than spinning on it now.
            if #self.inspectDeferred > 0 then
                self:PromoteDeferredInspects()
                return self:ScheduleInspectTick(INSPECT_RETRY_DELAY)
            end

            self.inspectTimerRunning = false
            return
        end

        self.inspectQueueSet[entry.guid] = nil
        entry.attempts = entry.attempts + 1

        -- Resolve the token again: it may have shifted since we queued
        local unit = self:ResolveUnitForGuid(entry.guid) or entry.unit

        if UnitGUID(unit) ~= entry.guid then
            -- Player left the group; drop them
        elseif not (UnitExists(unit) and UnitIsConnected(unit) and CanInspect(unit)) then
            self:RetryInspect(entry)
        elseif not UnitIsVisible(unit) then
            -- Inspect only works within ~100 yards. Requesting anyway would
            -- burn the throttle window on a request that can never reply.
            self:RetryInspect(entry)
        else
            entry.unit = unit
            entry.startedAt = GetTime()
            self.pendingInspect = entry
            NotifyInspect(unit)
            return self:ScheduleInspectTick(INSPECT_THROTTLE)
        end
    end
end

-- Re-queue anyone still missing an item level. Inspect only reaches ~100
-- yards, so raiders who were across the zone when we first tried would
-- otherwise sit at 0 for the whole night. Cheap: it only queues units that
-- are both unknown and currently in range.
function PlayerData:SweepMissingItemLevels()
    if InCombatLockdown() or self.pendingInspect then return end

    for _, unit in ipairs(self.playerOrder) do
        if not UnitIsUnit(unit, "player")
            and UnitExists(unit)
            and UnitIsConnected(unit)
            and UnitIsVisible(unit)
            and CanInspect(unit)
            and not self:GetCachedItemLevel(UnitGUID(unit))
        then
            self:QueueInspect(unit, false)
        end
    end
end

-- Map a GUID back to a current unit token
function PlayerData:ResolveUnitForGuid(guid)
    for _, unit in ipairs(self.playerOrder) do
        if UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

-- Handle INSPECT_READY event
function PlayerData:OnInspectReady(event, guid)
    if event ~= "INSPECT_READY" then return end

    -- If this is the reply we were waiting on, clear the pending slot. The
    -- running tick chain picks the next entry up on its own; scheduling another
    -- tick here would fork a second chain and double the request rate.
    local pending = nil
    if self.pendingInspect and self.pendingInspect.guid == guid then
        pending = self.pendingInspect
        self.pendingInspect = nil
    end

    -- Skip processing during combat
    if InCombatLockdown() then
        return
    end

    local unit = self:ResolveUnitForGuid(guid)

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

        -- Release Blizzard's inspect slot as soon as we have read the data.
        -- Leaving it held is what makes later inspects silently no-op.
        ClearInspectPlayer()

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
        elseif pending then
            -- Reply arrived but the gear data was not populated yet; try again,
            -- preserving the attempt count so this can't loop forever
            self:RetryInspect(pending)
            self:EnsureInspectEngine()
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
            self.unitGuids[unit] = nil
        end
    end

    -- guidCache is deliberately NOT cleared here: keeping item levels for
    -- players who have left is what makes them render instantly if they come
    -- back. Trim it only when it grows past a few raids' worth of players.
    local count = 0
    for _ in pairs(self.guidCache) do
        count = count + 1
    end

    if count > 500 then
        local cutoff = GetTime() - CACHE_STALE_AFTER
        for guid, entry in pairs(self.guidCache) do
            if entry.scannedAt < cutoff then
                self.guidCache[guid] = nil
            end
        end
    end
end

return PlayerData
