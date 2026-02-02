--------------------------------------------------------------------------------
-- PeaversItemLevel Utils
-- Thin wrapper around PeaversCommons.Utils for addon-specific functionality
--------------------------------------------------------------------------------

local addonName, PIL = ...

-- Access PeaversCommons utilities
local PeaversCommons = _G.PeaversCommons
local CommonUtils = PeaversCommons.Utils

-- Initialize Utils namespace
PIL.Utils = {}
local Utils = PIL.Utils

-- Print a message to the chat frame with addon prefix
function Utils.Print(message)
    if not message then return end
    CommonUtils.Print(PIL, message)
end

-- Debug print only when debug mode is enabled
function Utils.Debug(message)
    if not message then return end
    CommonUtils.Debug(PIL, message)
end

-- Delegate common utility functions to PeaversCommons.Utils
Utils.FormatPercent = CommonUtils.FormatPercent
Utils.FormatChange = CommonUtils.FormatChange
Utils.FormatTime = CommonUtils.FormatTime
Utils.Round = CommonUtils.Round
Utils.TableContains = CommonUtils.TableContains
Utils.GetPlayerInfo = CommonUtils.GetPlayerInfo
Utils.GetCharacterKey = CommonUtils.GetCharacterKey

return Utils
