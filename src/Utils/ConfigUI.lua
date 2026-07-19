local _, PIL = ...
local Config = PIL.Config

local ConfigUI = {}
PIL.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

local SettingsObjects = PeaversCommons.SettingsObjects
local W = PeaversCommons.Widgets
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

local PARAGRAPH_GAP = 16
local BEFORE_HEADER_GAP = 12

-- There is no multi-line paragraph widget in PeaversCommons.
--
-- Note the explicit SetWidth rather than the TOPLEFT+TOPRIGHT anchor pair used
-- elsewhere in the ecosystem: with dual anchors the wrap width comes from the
-- parent's layout, which is not resolved while the tab is being built, so
-- GetStringHeight() reports fewer lines than eventually render and the next
-- paragraph is placed on top of this one. An explicit width makes both the
-- wrapping and the measurement deterministic at build time.
local function AddParagraph(parentFrame, text, indent, y, width, color)
    local C = W.Colors
    local fs = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", indent, y)
    fs:SetWidth(width)
    fs:SetWordWrap(true)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(2)
    fs:SetText(text)

    color = color or C.textSec
    fs:SetTextColor(color[1], color[2], color[3])

    -- Measure only after width and text are both set
    local height = fs:GetStringHeight() or 0

    -- Floor at one line in case measurement is unavailable this frame, so a bad
    -- read can never collapse the gap to zero and overlap the next block
    if height < 14 then height = 14 end

    fs:SetHeight(height)

    return y - (height + PARAGRAPH_GAP)
end

-- Explains the one thing users consistently misread as the addon being slow:
-- other players' item levels arrive one at a time because the game only allows
-- one inspect request at a time. Deliberately does NOT claim a combat
-- limitation - inspecting during combat is allowed, and this addon does it.
function ConfigUI:BuildWelcomePage(parentFrame)
    local y = -10
    local opts = GetPageOpts(parentFrame)
    local indent = opts.indent
    local width = opts.width
    local C = W.Colors

    local function Paragraph(text, color)
        y = AddParagraph(parentFrame, text, indent, y, width, color)
    end

    local function Section(text)
        y = y - BEFORE_HEADER_GAP
        local _, newY = W:CreateSectionHeader(parentFrame, text, indent, y)
        y = newY - 10
    end

    local title = W:CreateLabel(parentFrame, "Item Level", {
        font = "GameFontNormalLarge",
        color = C.gold,
    })
    title:SetPoint("TOPLEFT", indent, y)
    y = y - 30

    Paragraph("Shows the equipped item level of everyone in your party or raid, as a " ..
        "sorted list of bars.")

    Section("Why other players fill in gradually")

    Paragraph("Your own item level is available instantly. Everyone else's has to be " ..
        "requested from the server using an inspect, and the game permits only " ..
        "one inspect at a time with a short pause between each.")

    Paragraph("This is a limit of the game itself, not of this addon - every item level " ..
        "addon works the same way. In a party the list is effectively instant; in " ..
        "a full raid it fills in over several seconds.")

    Section("If someone shows no item level")

    Paragraph("They are either still in the queue, or too far away. The game only allows " ..
        "inspecting players who are close enough to be visible, so distant raiders " ..
        "fill in as they get nearer.")

    Section("It gets faster as you play")

    Paragraph("Once a player has been seen they are remembered. If your group re-forms, " ..
        "someone reloads, or a raider rejoins, they appear immediately instead of " ..
        "being scanned again.")

    Paragraph("Item levels also keep updating during combat, including for players who " ..
        "join mid-pull.", C.accentLight)

    parentFrame:SetHeight(math.abs(y) + 30)
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
    local indent = opts.indent
    local width = opts.width

    -- Preview section first, so style changes below can be seen while solo
    local _, previewY = W:CreateSectionHeader(parentFrame, "Preview", indent, y)
    y = previewY - 8

    local TestMode = PIL.TestMode
    local testButton

    local function TestButtonLabel()
        return (TestMode and TestMode:IsActive()) and "Hide Example Group" or "Show Example Group"
    end

    testButton = W:CreateButton(parentFrame, TestButtonLabel(), {
        width = 190,
        onClick = function()
            if not TestMode then return end
            TestMode:Toggle()
            testButton:SetLabel(TestButtonLabel())
        end,
    })
    testButton:SetPoint("TOPLEFT", indent, y)
    y = y - 32

    y = AddParagraph(parentFrame,
        "Fills the display with example players so you can adjust the settings " ..
        "below without being in a group. Turns off automatically on reload.",
        indent, y, width, W.Colors.textMuted)

    y = SettingsObjects.BarAppearance(parentFrame, Config, y, opts)

    -- Item Level Progress section
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

    local toggle = W:CreateCheckbox(parentFrame, "Group Players by Role", {
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
        -- First entry renders leftmost and is the default-selected tab
        { key = "welcome", label = "Welcome", builder = function(f) ConfigUI:BuildWelcomePage(f) end },
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
