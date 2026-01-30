local _, PIL = ...
local Players = PIL.Players

-- Players module now delegates to PlayerData for all data operations
-- This file is kept for backward compatibility with existing code references

-- Delegate class colors to PlayerData
Players.CLASS_COLORS = PIL.PlayerData.CLASS_COLORS

-- Player order is now managed by PlayerData
-- This property accessor provides backward compatibility
function Players:GetPlayerOrder()
    return PIL.PlayerData.playerOrder
end

-- Backward compatibility: PLAYER_ORDER is accessed directly in some places
-- We'll set it up to reference PlayerData's playerOrder
Players.PLAYER_ORDER = PIL.PlayerData.playerOrder

-- Combat cache delegation
Players.combatCache = PIL.PlayerData.combatSnapshot

-- Initialize player tracking (delegates to PlayerData)
function Players:Initialize()
    -- PlayerData is initialized before this, so just ensure PLAYER_ORDER reference is current
    Players.PLAYER_ORDER = PIL.PlayerData.playerOrder
    self:ScanGroup()
end

-- Scan for players in group/raid (delegates to PlayerData)
function Players:ScanGroup()
    PIL.PlayerData:ScanGroup()
    -- Update reference for backward compatibility
    Players.PLAYER_ORDER = PIL.PlayerData.playerOrder
end

-- Get player name (delegates to PlayerData)
function Players:GetName(unit)
    return PIL.PlayerData:GetName(unit)
end

-- Get player class (delegates to PlayerData)
function Players:GetClass(unit)
    return PIL.PlayerData:GetClass(unit)
end

-- Get player item level (delegates to PlayerData)
function Players:GetItemLevel(unit)
    return PIL.PlayerData:GetItemLevel(unit)
end

-- Returns the color for a specific player class (delegates to PlayerData)
function Players:GetColor(unit)
    return PIL.PlayerData:GetColor(unit)
end

-- Gets the formatted display value for an item level (delegates to PlayerData)
function Players:GetDisplayValue(unit)
    return PIL.PlayerData:GetDisplayValue(unit)
end

-- Get player role (delegates to PlayerData)
function Players:GetRole(unit)
    return PIL.PlayerData:GetRole(unit)
end

-- Calculate average item level for a group of players (delegates to PlayerData)
function Players:CalculateAverageItemLevel(units)
    return PIL.PlayerData:CalculateAverageItemLevel(units)
end

-- Gets the highest item level in the group (delegates to PlayerData)
function Players:GetHighestItemLevel()
    return PIL.PlayerData:GetHighestItemLevel()
end

-- Calculates the bar values for display (delegates to PlayerData)
function Players:CalculateBarValues(value)
    return PIL.PlayerData:CalculateBarValues(value)
end

-- Updates the combat cache with fresh values (delegates to PlayerData)
function Players:UpdateCombatCache()
    PIL.PlayerData:RefreshCombatCache()
end

-- Queue a unit for inspection (delegates to PlayerData)
function Players:QueueInspect(unit)
    PIL.PlayerData:QueueInspect(unit)
end

return Players
