local addonName, PIL = ...

--[[
    PIL BarPool - Now uses PeaversCommons.BarPool as base with PIL-specific factory

    This file creates a PIL-specific pool that wraps PeaversCommons.BarPool
    with a factory that creates PIL.StatBar instances.
]]

local PeaversCommons = _G.PeaversCommons

-- Create PIL's bar pool using Commons
PIL.BarPool = PeaversCommons.BarPool:New({
    maxPoolSize = 50,

    -- Factory creates PIL-specific stat bars
    factory = function(parent, name)
        return PIL.StatBar:New(parent, name, name)  -- name is used as unit ID
    end,

    -- Resetter prepares bars for reuse
    resetter = function(bar)
        if bar.Reset then
            -- PIL.StatBar has a Reset method - but we call it with new values in Acquire
            -- Just stop animations and hide for now
            if bar.animationGroup then
                bar.animationGroup:Stop()
            end
            if bar.frame then
                bar.frame:Hide()
            end
        end
    end,
})

-- Add PIL-specific Acquire that calls Reset with proper params
local baseAcquire = PIL.BarPool.Acquire
function PIL.BarPool:Acquire(parent, name, unit)
    local bar = baseAcquire(self, parent, name, unit)

    -- If bar was reused, reset it with new values
    if bar._poolKey ~= unit and bar.Reset then
        bar:Reset(parent, name, unit)
    end
    bar._poolKey = unit

    return bar
end

-- Alias GetInUseCount for backward compatibility
function PIL.BarPool:GetInUseCount()
    return self:GetActiveCount()
end

return PIL.BarPool
