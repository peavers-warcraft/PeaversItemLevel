local addonName, PIL = ...

--------------------------------------------------------------------------------
-- PIL StatBar - Extends PeaversCommons.StatBar with class color support
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local BaseStatBar = PeaversCommons.StatBar

-- Initialize StatBar namespace
PIL.StatBar = {}
local StatBar = PIL.StatBar

-- Inherit from base StatBar
setmetatable(StatBar, { __index = BaseStatBar })

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function StatBar:New(parent, name, statType)
    -- Create base instance with PIL config
    local obj = BaseStatBar.New(self, parent, name, statType, PIL.Config)

    -- Override metatable to use PIL.StatBar methods
    setmetatable(obj, { __index = StatBar })

    -- Initialize tooltip (minimal for PIL)
    obj:InitTooltip()

    -- Update name text with truncation
    obj:UpdateNameText()

    return obj
end

--------------------------------------------------------------------------------
-- Color Management (PIL-specific - uses class colors)
--------------------------------------------------------------------------------

function StatBar:GetColorForStat(statType)
    -- Check if there's a custom color for this stat
    if PIL.Config.customColors and PIL.Config.customColors[statType] then
        local color = PIL.Config.customColors[statType]
        if color and color.r and color.g and color.b then
            return color.r, color.g, color.b
        end
    end

    -- For item level, use a default blue color
    if statType == "ITEM_LEVEL" then
        return 0.0, 0.44, 0.87
    end

    return 0.8, 0.8, 0.8
end

-- Override UpdateColor to support unit-based class colors
function StatBar:UpdateColor()
    local r, g, b

    -- Check if this is a unit ID (player, party1, raid1, etc.)
    if self.statType and (UnitExists(self.statType) or self.statType == "player") then
        -- Get the class color from the Players module
        r, g, b = PIL.Players:GetColor(self.statType)
    else
        -- Fallback to stat-based coloring for non-unit stats
        r, g, b = self:GetColorForStat(self.statType)
    end

    r = r or 0.8
    g = g or 0.8
    b = b or 0.8

    self.statusBar:SetColor(r, g, b, PIL.Config.barAlpha or 1.0)
end

--------------------------------------------------------------------------------
-- Value Calculations (PIL-specific)
--------------------------------------------------------------------------------

-- Calculate bar percentage based on highest item level in group
function StatBar:CalculateBarValues(value, maxValue)
    if PIL.Players and PIL.Players.CalculateBarValues then
        return PIL.Players:CalculateBarValues(value)
    end
    return BaseStatBar.CalculateBarValues(self, value, maxValue)
end

-- Simple display value for item level
function StatBar:GetDisplayValue(value)
    return tostring(math.floor(value + 0.5))
end

--------------------------------------------------------------------------------
-- Update Override (PIL-specific)
--------------------------------------------------------------------------------

function StatBar:Update(value, maxValue, change, noAnimation)
    if self.value == value then return end

    self.value = value or 0

    -- Calculate percentage based on highest item level in group
    local percentValue = self:CalculateBarValues(self.value, maxValue)

    -- Update status bar
    self.statusBar:SetMinMaxValues(0, 100)
    self.statusBar:SetValue(percentValue, noAnimation)

    -- Update value text
    local displayValue = self:GetDisplayValue(self.value)
    self.textManager:SetValue(displayValue)
end

--------------------------------------------------------------------------------
-- Position Override (PIL uses simple TOPLEFT anchoring)
--------------------------------------------------------------------------------

function StatBar:SetPosition(x, y, anchorPoint)
    self.yOffset = y
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", x, y)
    self.frame:SetPoint("TOPRIGHT", self.frame:GetParent(), "TOPRIGHT", 0, y)
end

--------------------------------------------------------------------------------
-- Appearance Updates
--------------------------------------------------------------------------------

function StatBar:UpdateFont()
    self.textManager:UpdateFont(
        PIL.Config.fontFace,
        PIL.Config.fontSize,
        PIL.Config.fontOutline,
        PIL.Config.fontShadow
    )
    self.textManager:SetTextAlpha(PIL.Config.barAlpha or 1.0)
    self:UpdateNameText()
end

function StatBar:UpdateTexture()
    self.statusBar:SetTexture(PIL.Config.barTexture)
    self:UpdateColor()

    self.tooltipInitialized = false
    self:InitTooltip()
end

function StatBar:UpdateHeight()
    self.frame:SetHeight(PIL.Config.barHeight)
    self.statusBar:SetHeight(PIL.Config.barHeight)
    self:UpdateNameText()
end

function StatBar:UpdateWidth()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", 0, self.yOffset)
    self.frame:SetPoint("TOPRIGHT", self.frame:GetParent(), "TOPRIGHT", 0, self.yOffset)
    self:UpdateNameText()
end

return StatBar
