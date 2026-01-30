local addonName, PIL = ...

-- Initialize BarPool namespace for frame pooling
PIL.BarPool = {
    available = {},      -- Stack of unused bars
    inUse = {},          -- unit -> bar mapping
    maxPoolSize = 50,
    totalCreated = 0,    -- Track total bars created for debugging
}

local BarPool = PIL.BarPool

-- Acquire a bar from the pool or create a new one
function BarPool:Acquire(parent, name, unit)
    local bar

    if #self.available > 0 then
        -- Reuse an existing bar from the pool
        bar = table.remove(self.available)
        bar:Reset(parent, name, unit)
    else
        -- Create a new bar
        bar = PIL.StatBar:New(parent, name, unit)
        self.totalCreated = self.totalCreated + 1
    end

    self.inUse[unit] = bar
    return bar
end

-- Release a bar back to the pool
function BarPool:Release(unit)
    local bar = self.inUse[unit]
    if bar then
        bar:Hide()
        self.inUse[unit] = nil

        -- Only keep up to maxPoolSize bars in the pool
        if #self.available < self.maxPoolSize then
            table.insert(self.available, bar)
        end
    end
end

-- Release all bars back to the pool
function BarPool:ReleaseAll()
    for unit in pairs(self.inUse) do
        self:Release(unit)
    end
end

-- Get a bar by unit ID
function BarPool:GetBar(unit)
    return self.inUse[unit]
end

-- Get all bars currently in use
function BarPool:GetAllBars()
    local bars = {}
    for unit, bar in pairs(self.inUse) do
        table.insert(bars, bar)
    end
    return bars
end

-- Get count of bars in use
function BarPool:GetInUseCount()
    local count = 0
    for _ in pairs(self.inUse) do
        count = count + 1
    end
    return count
end

-- Get count of available bars in pool
function BarPool:GetAvailableCount()
    return #self.available
end

-- Clear the entire pool (for cleanup/reload)
function BarPool:Clear()
    -- Hide and release all in-use bars
    for unit, bar in pairs(self.inUse) do
        if bar.frame then
            bar.frame:Hide()
        end
    end
    self.inUse = {}

    -- Clear available pool
    for _, bar in ipairs(self.available) do
        if bar.frame then
            bar.frame:Hide()
        end
    end
    self.available = {}
end

-- Debug function to get pool stats
function BarPool:GetStats()
    return {
        totalCreated = self.totalCreated,
        inUse = self:GetInUseCount(),
        available = self:GetAvailableCount(),
        maxPoolSize = self.maxPoolSize,
    }
end

return BarPool
