local _, PIL = ...
local Config = PIL.Config
local UI = PIL.UI

local ConfigUI = {}
PIL.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

local SettingsObjects = PeaversCommons.SettingsObjects
local W = PeaversCommons.Widgets
local C = W.Colors
local ConfigUIUtils = PeaversCommons.ConfigUIUtils

local function RefreshBars()
    if PIL.BarManager and PIL.Core and PIL.Core.contentFrame then
        PIL.BarManager:CreateBars(PIL.Core.contentFrame)
        PIL.Core:AdjustFrameHeight()
    end
end

local function OnSettingChanged(key, value)
    if key == "frameWidth" then
        Config.barWidth = value - 20
        if PIL.Core and PIL.Core.frame then
            PIL.Core.frame:SetWidth(value)
            if PIL.BarManager then PIL.BarManager:ResizeBars() end
        end
    elseif key == "bgAlpha" or key == "bgColor" then
        if PIL.Core and PIL.Core.frame then
            local color = Config.bgColor or { r = 0, g = 0, b = 0 }
            PIL.Core.frame:SetBackdropColor(color.r, color.g, color.b, Config.bgAlpha or 0.8)
            PIL.Core.frame:SetBackdropBorderColor(0, 0, 0, Config.bgAlpha or 0.8)
            if PIL.Core.titleBar then
                PIL.Core.titleBar:SetBackdropColor(color.r, color.g, color.b, Config.bgAlpha or 0.8)
                PIL.Core.titleBar:SetBackdropBorderColor(0, 0, 0, Config.bgAlpha or 0.8)
            end
        end
    elseif key == "lockPosition" then
        if PIL.Core then PIL.Core:UpdateFrameLock() end
    elseif key == "showTitleBar" then
        if PIL.Core then PIL.Core:UpdateTitleBarVisibility() end
    elseif key == "barAlpha" or key == "barBgAlpha" or key == "barTexture" then
        if PIL.BarManager then PIL.BarManager:ResizeBars() end
    elseif key == "barHeight" or key == "barSpacing" then
        RefreshBars()
    elseif key == "fontFace" or key == "fontSize" or key == "fontOutline" or key == "fontShadow" then
        RefreshBars()
    elseif key == "displayMode" or key == "hideOutOfCombat" or key == "showOnLogin" then
        if PIL.Core and PIL.Core.UpdateFrameVisibility then
            PIL.Core:UpdateFrameVisibility()
        end
    end
end

local pageOpts = {
    indent = 25,
    width = 360,
    onChanged = OnSettingChanged,
}

local function GetPageOpts(parentFrame)
    local opts = {}
    for k, v in pairs(pageOpts) do opts[k] = v end
    local frameWidth = parentFrame:GetWidth()
    if frameWidth and frameWidth > 100 then
        opts.width = frameWidth - (opts.indent * 2) - 10
    end
    return opts
end

function ConfigUI:BuildGeneralPage(parentFrame)
    local y = -10
    local opts = GetPageOpts(parentFrame)

    y = SettingsObjects.FrameSettings(parentFrame, Config, y, opts)
    y = SettingsObjects.Visibility(parentFrame, Config, y, opts)

    parentFrame:SetHeight(math.abs(y) + 30)
end

function ConfigUI:BuildBarsPage(parentFrame)
    local y = -10
    local opts = GetPageOpts(parentFrame)

    y = SettingsObjects.BarAppearance(parentFrame, Config, y, opts)

    -- Item Level Progress section
    local indent = opts.indent
    local width = opts.width

    local _, newY = W:CreateSectionHeader(parentFrame, "Item Level Progress", indent, y)
    y = newY - 8

    local slider = W:CreateSlider(parentFrame, "Item Level Step (% per level)", {
        min = 0.5, max = 5, step = 0.1,
        value = Config.ilvlStepPercentage or 2.0,
        width = width,
        onChange = function(value)
            Config.ilvlStepPercentage = value
            Config:Save()
            if PIL.BarManager then
                PIL.BarManager:UpdateBarsWithSorting(true)
            end
        end,
    })
    slider:SetPoint("TOPLEFT", indent, y)
    y = y - 52

    parentFrame:SetHeight(math.abs(y) + 30)
end

function ConfigUI:BuildTextPage(parentFrame)
    local y = -10
    local opts = GetPageOpts(parentFrame)

    y = SettingsObjects.FontSettings(parentFrame, Config, y, opts)

    parentFrame:SetHeight(math.abs(y) + 30)
end

function ConfigUI:BuildBehaviorPage(parentFrame)
    local y = -10
    local opts = GetPageOpts(parentFrame)
    local indent = opts.indent
    local width = opts.width

    local _, newY = W:CreateSectionHeader(parentFrame, "Sorting & Grouping", indent, y)
    y = newY - 8

    local toggle = W:CreateToggle(parentFrame, "Group Players by Role", {
        checked = Config.groupByRole or false,
        width = width,
        onChange = function(checked)
            Config.groupByRole = checked
            Config:Save()
            RefreshBars()
        end,
    })
    toggle:SetPoint("TOPLEFT", indent, y)
    y = y - 30

    local sortOptions = {
        { value = "ILVL_DESC", label = "Item Level (Highest to Lowest)" },
        { value = "ILVL_ASC", label = "Item Level (Lowest to Highest)" },
        { value = "NAME_ASC", label = "Name (A to Z)" },
        { value = "NAME_DESC", label = "Name (Z to A)" },
    }

    local dropdown = W:CreateDropdown(parentFrame, "Sort Players By", {
        options = sortOptions,
        selected = Config.sortOption or "NAME_ASC",
        width = width,
        onChange = function(value)
            Config.sortOption = value
            Config:Save()
            if PIL.Players then
                PIL.Players:ScanGroup()
                if PIL.BarManager then
                    PIL.BarManager:UpdateBarsWithSorting(true)
                end
            end
        end,
    })
    dropdown:SetPoint("TOPLEFT", indent, y)
    y = y - 58

    parentFrame:SetHeight(math.abs(y) + 30)
end

function ConfigUI:GetPages()
    return {
        { key = "general", label = "General", builder = function(f) ConfigUI:BuildGeneralPage(f) end },
        { key = "bars", label = "Bars", builder = function(f) ConfigUI:BuildBarsPage(f) end },
        { key = "text", label = "Text", builder = function(f) ConfigUI:BuildTextPage(f) end },
        { key = "behavior", label = "Behavior", builder = function(f) ConfigUI:BuildBehaviorPage(f) end },
    }
end

function ConfigUI:BuildIntoFrame(parentFrame)
    local y = -10
    y = SettingsObjects.FrameSettings(parentFrame, Config, y, pageOpts)
    y = SettingsObjects.BarAppearance(parentFrame, Config, y, pageOpts)
    y = SettingsObjects.FontSettings(parentFrame, Config, y, pageOpts)
    y = SettingsObjects.Visibility(parentFrame, Config, y, pageOpts)
    parentFrame:SetHeight(math.abs(y) + 30)
    return parentFrame
end

function ConfigUI:InitializeOptions()
    local panel = ConfigUIUtils.CreateSettingsPanel(
        "Settings",
        "Configuration options for the item level display"
    )
    local content = panel.content
    self:BuildIntoFrame(content)
    panel:UpdateContentHeight(content:GetHeight())
    return panel
end

function ConfigUI:OpenOptions()
    PIL.Config:Save()

    if _G.PeaversConfig and _G.PeaversConfig.MainFrame then
        _G.PeaversConfig.MainFrame:Show()
        _G.PeaversConfig.MainFrame:SelectAddon("PeaversItemLevel")
        return
    end

    if Settings and Settings.OpenToCategory then
        if PIL.directSettingsCategoryID then
            local success = pcall(Settings.OpenToCategory, PIL.directSettingsCategoryID)
            if success then return end
        end
        if PIL.directCategoryID then
            local success = pcall(Settings.OpenToCategory, PIL.directCategoryID)
            if success then return end
        end
    end

    if SettingsPanel then
        ShowUIPanel(SettingsPanel)
    end
end

PIL.Config.OpenOptionsCommand = function()
    ConfigUI:OpenOptions()
end

function ConfigUI:Initialize()
    self.panel = self:InitializeOptions()
end

return ConfigUI
