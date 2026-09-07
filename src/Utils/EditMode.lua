local addonName, PIL = ...

--------------------------------------------------------------------------------
-- Edit Mode
--
-- The list is placed and configured in Blizzard's Edit Mode. All of the
-- machinery lives in PeaversCommons; what is here is the list of settings and
-- how to apply one after it changes.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local EditMode = {}
PIL.EditMode = EditMode

--------------------------------------------------------------------------------
-- Applying a change
--------------------------------------------------------------------------------

local function RefreshBars()
    if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
        PIL.BarManager:CreateBars(PIL.Core.contentFrame)
        PIL.Core:AdjustFrameHeight()
    end
end

function PIL.ApplySetting(key, value)
    local Config = PIL.Config

    if key == "frameX" or key == "frameY" then
        if PIL.Core and PIL.Core.ApplyFramePosition then
            PIL.Core:ApplyFramePosition()
        end
        return
    end

    if key == "frameWidth" then
        -- The bars sit inside the frame, so their width follows it.
        Config.barWidth = value - 20
        if PIL.Core and PIL.Core.frame then
            PIL.Core.frame:SetWidth(value)
            if PIL.BarManager then PIL.BarManager:ResizeBars() end
        end
    elseif key == "bgAlpha" or key == "bgColor" then
        if PIL.Core and PIL.Core.frame then
            local color = Config.bgColor or { r = 0, g = 0, b = 0 }
            local alpha = Config.bgAlpha or 0.8
            PIL.Core.frame:SetBackdropColor(color.r, color.g, color.b, alpha)
            PIL.Core.frame:SetBackdropBorderColor(0, 0, 0, alpha)
            if PIL.Core.titleBar then
                PIL.Core.titleBar:SetBackdropColor(color.r, color.g, color.b, alpha)
                PIL.Core.titleBar:SetBackdropBorderColor(0, 0, 0, alpha)
            end
        end
    elseif key == "lockPosition" then
        if PIL.Core then PIL.Core:UpdateFrameLock() end
    elseif key == "showTitleBar" then
        if PIL.Core then PIL.Core:UpdateTitleBarVisibility() end
    elseif key == "barAlpha" or key == "barBgAlpha" or key == "barTexture" or key == "textAlpha" then
        if PIL.BarManager then PIL.BarManager:ResizeBars() end
    elseif key == "displayMode" or key == "hideOutOfCombat" or key == "showOnLogin" then
        if PIL.Core and PIL.Core.UpdateFrameVisibility then
            PIL.Core:UpdateFrameVisibility()
        end
    else
        -- Everything else changes what a bar shows or how it is drawn.
        RefreshBars()
    end
end

--------------------------------------------------------------------------------
-- Groups
--------------------------------------------------------------------------------

EditMode.SECTIONS = {
    { key = "frame", label = "Frame" },
    { key = "position", label = "Position" },
    { key = "bars", label = "Bars" },
    { key = "text", label = "Text" },
    { key = "list", label = "The List" },
    { key = "behaviour", label = "Behaviour" },
}

EditMode.ENTRIES = {
    ----------------------------------------------------------------- frame ---
    { key = "frameWidth", section = "frame" },
    { key = "showTitleBar", section = "frame" },
    { key = "bgColor", section = "frame" },
    { key = "bgAlpha", section = "frame" },
    { key = "lockPosition", section = "frame" },

    -------------------------------------------------------------- position ---
    { key = "frameX", section = "position", kind = "number" },
    { key = "frameY", section = "position", kind = "number" },

    ------------------------------------------------------------------ bars ---
    { key = "barHeight", section = "bars" },
    { key = "barSpacing", section = "bars" },
    { key = "barAlpha", section = "bars" },
    { key = "barBgAlpha", section = "bars" },
    { key = "barTexture", section = "bars", height = 300 },

    ------------------------------------------------------------------ text ---
    { key = "fontFace", section = "text", height = 300 },
    { key = "fontSize", section = "text" },
    { key = "fontOutline", section = "text" },
    { key = "fontShadow", section = "text" },
    { key = "textAlpha", section = "text" },

    ------------------------------------------------------------------ list ---
    {
        key = "sortOption", label = "Sort By", kind = "dropdown", section = "list",
        fallback = "NAME_ASC",
        values = {
            { value = "ILVL_DESC", label = "Item level, highest first" },
            { value = "ILVL_ASC", label = "Item level, lowest first" },
            { value = "NAME_ASC", label = "Name, A to Z" },
            { value = "NAME_DESC", label = "Name, Z to A" },
        },
    },
    {
        key = "groupByRole", label = "Group By Role", kind = "checkbox",
        section = "list", default = false,
        desc = "Tanks, then healers, then damage, each sorted within its group.",
    },
    {
        key = "ilvlStepPercentage", label = "Bar Scale", kind = "slider",
        section = "list", min = 0.5, max = 5, step = 0.1, default = 2.0,
        desc = "How much of the bar one item level is worth. Lower spreads the "
            .. "group further apart; higher packs it together.",
    },

    ------------------------------------------------------------- behaviour ---
    { key = "showOnLogin", section = "behaviour" },
    { key = "hideOutOfCombat", section = "behaviour" },
    { key = "displayMode", section = "behaviour" },
    {
        key = "combatUpdateInterval", label = "Combat Update Interval", kind = "slider",
        section = "behaviour", min = 0.1, max = 1.0, step = 0.05, default = 0.2,
    },
}

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

-- Edit Mode reports an anchor point and an offset, which is what this addon
-- already stores. Nothing to convert, nothing to migrate.
local function SavePosition(_, point, x, y)
    PIL.Config.framePoint = point
    PIL.Config.frameX = x
    PIL.Config.frameY = y
    PIL.Config:Save()
end

-- The frame drags itself when unlocked, and Edit Mode drags it through its own
-- overlay. Both at once means two systems answering one drag.
local function ReleaseDragging(frame)
    for _, target in ipairs({ frame, PIL.Core.contentFrame }) do
        if target and target.RegisterForDrag then
            target:RegisterForDrag()
            target:SetScript("OnDragStart", nil)
            target:SetScript("OnDragStop", nil)
        end
    end
end

function EditMode:BuildSchema()
    if self.schema then return self.schema end

    self.schema = PeaversCommons.SettingsSchema:New({
        config = PIL.Config,
        sections = self.SECTIONS,
        entries = self.ENTRIES,
        apply = function(entry, _, value) PIL.ApplySetting(entry.key, value) end,
    })

    return self.schema
end

function EditMode:Register()
    if not PeaversCommons.EditMode or not PeaversCommons.EditMode.available then
        return false
    end
    if not PIL.Core or not PIL.Core.frame then return false end

    PeaversCommons.EditMode:Register({
        frame = PIL.Core.frame,
        name = "Peavers Item Level",
        schema = self:BuildSchema(),
        default = {
            point = PIL.Config.defaults and PIL.Config.defaults.framePoint or "RIGHT",
            x = PIL.Config.defaults and PIL.Config.defaults.frameX or -20,
            y = PIL.Config.defaults and PIL.Config.defaults.frameY or 0,
        },
        onPositionChanged = SavePosition,
        onEnter = function(frame)
            ReleaseDragging(frame)
            -- The list can be hidden by the visibility rules, and a hidden frame
            -- takes its own Edit Mode handle down with it.
            frame:Show()
        end,
        onExit = function()
            if PIL.Core.UpdateFrameLock then PIL.Core:UpdateFrameLock() end
            if PIL.Core.UpdateFrameVisibility then PIL.Core:UpdateFrameVisibility() end
        end,
    })

    return true
end

return EditMode
