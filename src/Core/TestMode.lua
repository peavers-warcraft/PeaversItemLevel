local addonName, PIL = ...

--[[
    PIL TestMode - fills the display with a fake group so appearance settings
    can be previewed while solo.

    Isolation note: test units use synthetic tokens ("pilTest1", ...) which no
    Unit* API recognises. UnitGUID returns nil for them, and PlayerData only
    writes its persistent identity cache when a GUID exists, so test data can
    never leak into the real item level cache. The reverse is handled by
    ScanGroup and the inspect engine bailing out while test mode is active.

    Test mode is intentionally NOT persisted to config: a /reload always returns
    to the real group, so a user can never get stuck looking at fake bars and
    conclude the addon is broken.
]]

PIL.TestMode = {
    active = false,
    units = {},
}

local TestMode = PIL.TestMode

local UNIT_PREFIX = "pilTest"

-- Roster shape: a plausible small-raid role mix so "Group players by role" has
-- something realistic to show.
local ROLE_SLOTS = {
    { role = "TANK",    count = 2 },
    { role = "HEALER",  count = 3 },
    { role = "DAMAGER", count = 7 },
}

-- Classes are drawn per role rather than at random across all of them: a
-- warrior healer would read as obviously fake to anyone who plays the game.
local CLASSES_BY_ROLE = {
    TANK    = { "WARRIOR", "PALADIN", "DRUID", "DEATHKNIGHT", "MONK", "DEMONHUNTER" },
    HEALER  = { "PRIEST", "PALADIN", "DRUID", "SHAMAN", "MONK", "EVOKER" },
    DAMAGER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
                "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" },
}

local NAME_POOL = {
    "Bulwark", "Stonehide", "Lightwell", "Riverbloom", "Sunmender", "Emberfang",
    "Nightreave", "Grimhowl", "Thundergale", "Voidstep", "Frostbourne", "Dawnscale",
    "Ashvale", "Brightspear", "Cinderwake", "Duskmantle", "Everfrost", "Gloomtide",
    "Hallowmere", "Ironvow", "Kestrelwing", "Moonquill", "Palegrove", "Ravenshold",
    "Silverbrand", "Stormcaller", "Thornwild", "Umbershade", "Wyrmrest", "Zephyrbane",
}

local ITEM_LEVEL_MIN = 640
local ITEM_LEVEL_MAX = 685

-- Pick a random entry from `pool` that is not already in `used`. Falls back to
-- any entry once the pool is exhausted, so the roster can always be filled.
local function PickUnused(pool, used)
    local available = {}
    for _, value in ipairs(pool) do
        if not used[value] then
            available[#available + 1] = value
        end
    end

    local chosen
    if #available > 0 then
        chosen = available[math.random(#available)]
    else
        chosen = pool[math.random(#pool)]
    end

    used[chosen] = true
    return chosen
end

-- Build a fresh roster. Regenerated on every enable so repeated toggling shows
-- different names, classes and item levels rather than the same canned list.
local function BuildRoster()
    local roster = {}
    local usedNames, usedClasses = {}, {}

    for _, slot in ipairs(ROLE_SLOTS) do
        for _ = 1, slot.count do
            roster[#roster + 1] = {
                name = PickUnused(NAME_POOL, usedNames),
                -- Prefer unused classes so bar colours stay visually distinct
                class = PickUnused(CLASSES_BY_ROLE[slot.role], usedClasses),
                role = slot.role,
                itemLevel = math.random(ITEM_LEVEL_MIN, ITEM_LEVEL_MAX),
            }
        end
    end

    return roster
end

function TestMode:IsActive()
    return self.active == true
end

-- True for a synthetic unit token
function TestMode:IsTestUnit(unit)
    return type(unit) == "string" and unit:sub(1, #UNIT_PREFIX) == UNIT_PREFIX
end

function TestMode:Toggle()
    if self.active then
        self:Disable()
    else
        self:Enable()
    end
    return self.active
end

function TestMode:Enable()
    if self.active then return end

    local PlayerData = PIL.PlayerData
    self.active = true
    self.units = {}

    local roster = BuildRoster()

    -- Seed the cache directly. PlayerData's getters are all cache-first, so
    -- populating name/class/role/itemLevel is enough for the whole UI to treat
    -- these as ordinary players.
    for i, player in ipairs(roster) do
        local unit = UNIT_PREFIX .. i
        self.units[#self.units + 1] = unit

        PlayerData.cache[unit] = {
            name = player.name,
            class = player.class,
            role = player.role,
            itemLevel = player.itemLevel,
        }
        PlayerData.combatSnapshot[unit] = player.itemLevel
    end

    -- Replace the roster wholesale
    PlayerData.playerOrder = {}
    for _, unit in ipairs(self.units) do
        table.insert(PlayerData.playerOrder, unit)
    end

    PlayerData:SortPlayerOrder()
    PlayerData:RecalculateHighest()

    if PIL.BarManager then
        PIL.BarManager:RebuildBars()
    end

    -- Force the frame visible: the whole point is previewing while solo, and
    -- display modes like "party only" or "hide out of combat" would hide it.
    if PIL.Core then
        PIL.Core:UpdateFrameVisibility()
    end

    self:Print("Test mode |cff44ff44ON|r - showing " .. #roster ..
        " example players. Run again to return to your real group.")
end

function TestMode:Disable()
    if not self.active then return end

    local PlayerData = PIL.PlayerData

    -- Drop every synthetic entry before handing control back
    for _, unit in ipairs(self.units) do
        PlayerData.cache[unit] = nil
        PlayerData.combatSnapshot[unit] = nil
        PlayerData.unitGuids[unit] = nil
    end

    self.units = {}
    self.active = false

    -- Rebuild from the real group
    PlayerData.playerOrder = {}
    PlayerData:ScanGroup()

    if PIL.BarManager then
        PIL.BarManager:RebuildBars()
    end

    if PIL.Core then
        PIL.Core:UpdateFrameVisibility()
    end

    self:Print("Test mode |cffff4444OFF|r.")
end

function TestMode:Print(msg)
    if PIL.Utils and PIL.Utils.Print then
        PIL.Utils.Print(msg)
    else
        print("|cff3abdf7PeaversItemLevel|r: " .. msg)
    end
end

return TestMode
