local _, PIL = ...

local ConfigUI = {}
PIL.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

local W = PeaversCommons.Widgets
local ConfigUIUtils = PeaversCommons.ConfigUIUtils

-- Applying a setting lives with the addon's schema now, in EditMode.lua, so the
-- settings page and the Edit Mode panel cannot disagree about what a change
-- should do.

function ConfigUI:BuildInfoPage(parentFrame)
    local C = W.Colors
    ConfigUIUtils.BuildInfoPageWithEditMode(parentFrame, "Item Level", {
        "Shows the equipped item level of everyone in your party or raid, as a " ..
            "sorted list of bars.",
        { command = "/pil", desc = "toggle the display" },
        { command = "/pil config", desc = "open the configuration panel" },

        { header = "Why other players fill in gradually" },
        "Your own item level is available instantly. Everyone else's has to be " ..
            "requested from the server using an inspect, and the game permits only " ..
            "one inspect at a time with a short pause between each.",
        "This is a limit of the game itself, not of this addon - every item level " ..
            "addon works the same way. In a party the list is effectively instant; in " ..
            "a full raid it fills in over several seconds.",

        { header = "If someone shows no item level" },
        "They are either still in the queue, or too far away. The game only allows " ..
            "inspecting players who are close enough to be visible, so distant raiders " ..
            "fill in as they get nearer.",

        { header = "It gets faster as you play" },
        "Once a player has been seen they are remembered. If your group re-forms, " ..
            "someone reloads, or a raider rejoins, they appear immediately instead of " ..
            "being scanned again.",
        { text = "Item levels also keep updating during combat, including for players who " ..
            "join mid-pull.", color = C.accentLight },
    }, {
        title = "the item level list",
        select = "the list",
        reset = function()
            PIL.Config:Reset()
            if PIL.ApplySetting then PIL.ApplySetting() end
            if PeaversCommons.EditModePanel then
                PeaversCommons.EditModePanel:Refresh()
            end
        end,
    })
end

function ConfigUI:GetPages()
    return {
        { key = "info", label = "Information", builder = function(f) ConfigUI:BuildInfoPage(f) end },
    }
end

function ConfigUI:BuildIntoFrame(parentFrame)
    self:BuildInfoPage(parentFrame)
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
