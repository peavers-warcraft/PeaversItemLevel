local addonName, PIL = ...

--------------------------------------------------------------------------------
-- PIL TitleBar - Uses PeaversCommons.TitleBar
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

-- Initialize TitleBar namespace
PIL.TitleBar = {}
local TitleBar = PIL.TitleBar

-- Creates the title bar using PeaversCommons.TitleBar
function TitleBar:Create(parentFrame)
    return PeaversCommons.TitleBar:Create(parentFrame, PIL.Config, {
        title = "PIL",
        version = PIL.version or "1.0.0",
        leftPadding = 6
    })
end

return TitleBar
