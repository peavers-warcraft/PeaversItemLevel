local addonName, PIL = ...

-- Initialize BarManager namespace
PIL.BarManager = {}
local BarManager = PIL.BarManager

-- Collection to store role headers
BarManager.roleHeaders = {}

-- Previous values cache for change detection
BarManager.previousValues = {}

-- Creates a role header with the same style as the titlebar
function BarManager:CreateRoleHeader(parent, role, yOffset, avgItemLevel)
    -- Hide existing header if it exists
    if self.roleHeaders[role] then
        self.roleHeaders[role].frame:Hide()
    end

    local header = {}

    -- Create the frame
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(20)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    frame:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
    })

    frame:SetBackdropColor(PIL.Config.bgColor.r, PIL.Config.bgColor.g, PIL.Config.bgColor.b, PIL.Config.bgAlpha)
    frame:SetBackdropBorderColor(0, 0, 0, PIL.Config.bgAlpha)

    -- Create the title text
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(PIL.Config.fontFace, PIL.Config.fontSize, PIL.Config.fontOutline)
    title:SetPoint("LEFT", frame, "LEFT", 6, 0)

    -- Set the title text based on the role
    local roleText = "Unknown"
    if role == "TANK" then
        roleText = "Tanks"
    elseif role == "HEALER" then
        roleText = "Healers"
    elseif role == "DAMAGER" then
        roleText = "DPS"
    end

    title:SetText(roleText)
    title:SetTextColor(1, 1, 1)
    if PIL.Config.fontShadow then
        title:SetShadowOffset(1, -1)
    else
        title:SetShadowOffset(0, 0)
    end

    -- Add vertical line separator
    local verticalLine = frame:CreateTexture(nil, "ARTWORK")
    verticalLine:SetSize(1, 16)
    verticalLine:SetPoint("LEFT", title, "RIGHT", 5, 0)
    verticalLine:SetColorTexture(0.3, 0.3, 0.3, 0.5)

    -- Add average item level text
    local avgIlvlText = frame:CreateFontString(nil, "OVERLAY")
    avgIlvlText:SetFont(PIL.Config.fontFace, PIL.Config.fontSize, PIL.Config.fontOutline)
    avgIlvlText:SetPoint("LEFT", verticalLine, "RIGHT", 5, 0)

    -- Format the average item level to show only one decimal place
    local formattedAvgIlvl = string.format("%.1f", avgItemLevel or 0)
    avgIlvlText:SetText("avg " .. formattedAvgIlvl)
    avgIlvlText:SetTextColor(0.8, 0.8, 0.8)
    if PIL.Config.fontShadow then
        avgIlvlText:SetShadowOffset(1, -1)
    else
        avgIlvlText:SetShadowOffset(0, 0)
    end

    header.frame = frame
    header.title = title
    header.avgIlvlText = avgIlvlText
    header.role = role
    header.yOffset = yOffset

    self.roleHeaders[role] = header

    return header
end

-- Rebuild all bars from scratch using the BarPool
function BarManager:RebuildBars()
    -- Release all existing bars back to the pool
    PIL.BarPool:ReleaseAll()

    -- Clear role headers
    for _, header in pairs(self.roleHeaders) do
        header.frame:Hide()
    end
    self.roleHeaders = {}

    local parent = PIL.Core.contentFrame
    if not parent then return 0 end

    local yOffset = 0

    if PIL.Config.groupByRole then
        -- Group players by role
        local playersByRole = {
            ["TANK"] = {},
            ["HEALER"] = {},
            ["DAMAGER"] = {}
        }

        -- Sort players into role groups
        for _, unit in ipairs(PIL.PlayerData.playerOrder) do
            local role = PIL.PlayerData:GetRole(unit)
            table.insert(playersByRole[role], unit)
        end

        -- Create bars for each role group
        local roleOrder = {"TANK", "HEALER", "DAMAGER"}

        for _, role in ipairs(roleOrder) do
            local players = playersByRole[role]

            -- Only create a header if there are players with this role
            if #players > 0 then
                -- Calculate average item level for this role group
                local avgItemLevel = PIL.PlayerData:CalculateAverageItemLevel(players)

                -- Create role header with average item level
                local header = self:CreateRoleHeader(parent, role, yOffset, avgItemLevel)

                -- Update yOffset for the first bar after the header
                if PIL.Config.barSpacing == 0 then
                    yOffset = yOffset - 20 -- Header height
                else
                    yOffset = yOffset - (20 + PIL.Config.barSpacing)
                end

                -- Create bars for players in this role
                for _, unit in ipairs(players) do
                    local playerName = PIL.PlayerData:GetName(unit)
                    local bar = PIL.BarPool:Acquire(parent, playerName, unit)
                    bar:SetPosition(0, yOffset)

                    local itemLevel = PIL.PlayerData:GetItemLevel(unit)
                    bar:Update(itemLevel, nil, nil, true)
                    bar:UpdateColor()

                    -- Update yOffset
                    if PIL.Config.barSpacing == 0 then
                        yOffset = yOffset - PIL.Config.barHeight
                    else
                        yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
                    end
                end
            end
        end
    else
        -- Non-grouped layout
        for _, unit in ipairs(PIL.PlayerData.playerOrder) do
            local playerName = PIL.PlayerData:GetName(unit)
            local bar = PIL.BarPool:Acquire(parent, playerName, unit)
            bar:SetPosition(0, yOffset)

            local itemLevel = PIL.PlayerData:GetItemLevel(unit)
            bar:Update(itemLevel, nil, nil, true)
            bar:UpdateColor()

            -- Update yOffset
            if PIL.Config.barSpacing == 0 then
                yOffset = yOffset - PIL.Config.barHeight
            else
                yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
            end
        end
    end

    -- Adjust frame height
    PIL.Core:AdjustFrameHeight()

    return math.abs(yOffset)
end

-- Reorder existing bars without recreating them
function BarManager:ReorderBars()
    -- If grouping by role, we need a full rebuild
    if PIL.Config.groupByRole then
        self:RebuildBars()
        return
    end

    local yOffset = 0
    for _, unit in ipairs(PIL.PlayerData.playerOrder) do
        local bar = PIL.BarPool:GetBar(unit)
        if bar then
            -- Update name if changed
            local playerName = PIL.PlayerData:GetName(unit)
            if bar.name ~= playerName then
                bar.name = playerName
                bar:UpdateNameText()
            end

            bar:SetPosition(0, yOffset)

            -- Update value without animation during reordering
            local itemLevel = PIL.PlayerData:GetItemLevel(unit)
            bar:Update(itemLevel, nil, nil, true)

            if PIL.Config.barSpacing == 0 then
                yOffset = yOffset - PIL.Config.barHeight
            else
                yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
            end
        end
    end

    PIL.Core:AdjustFrameHeight()
end

-- Updates all player bars with latest item levels
function BarManager:UpdateAllBars(forceUpdate, noAnimation)
    local inCombat = InCombatLockdown()
    local highestItemLevelChanged = false

    -- Skip highest item level change detection during combat
    if not inCombat then
        local previousHighestItemLevel = self.previousHighestItemLevel or 0
        local currentHighestItemLevel = PIL.PlayerData:GetHighestItemLevel()

        if currentHighestItemLevel ~= previousHighestItemLevel then
            highestItemLevelChanged = true
            self.previousHighestItemLevel = currentHighestItemLevel
        end
    end

    -- Use noAnimation if highest changed (prevents staggered flashing)
    local useNoAnimation = noAnimation or highestItemLevelChanged

    -- Update all bars in the pool
    for _, unit in ipairs(PIL.PlayerData.playerOrder) do
        local bar = PIL.BarPool:GetBar(unit)
        if bar then
            local value = PIL.PlayerData:GetItemLevel(unit)
            local previousValue = self.previousValues[unit] or 0

            -- Check for name changes
            local playerName = PIL.PlayerData:GetName(unit)
            if bar.name ~= playerName then
                bar.name = playerName
                bar:UpdateNameText()
            end

            -- Determine if this bar needs updating
            local valueChanged = (value ~= previousValue)
            local needsUpdate = forceUpdate or highestItemLevelChanged or (valueChanged and not inCombat)

            if inCombat then
                -- During combat: always update with cached values, no animation
                bar:Update(value, nil, 0, true)
            elseif needsUpdate then
                local change = valueChanged and (value - previousValue) or 0
                bar:Update(value, nil, change, useNoAnimation)

                if forceUpdate then
                    bar:UpdateColor()
                end
            end

            -- Store value for next comparison (skip during combat)
            if not inCombat and valueChanged then
                self.previousValues[unit] = value
            end
        end
    end

    -- Update role header average item levels if grouped
    if PIL.Config.groupByRole then
        self:UpdateRoleHeaderAverages()
    end
end

-- Update role header average item levels
function BarManager:UpdateRoleHeaderAverages()
    local playersByRole = {
        ["TANK"] = {},
        ["HEALER"] = {},
        ["DAMAGER"] = {}
    }

    for _, unit in ipairs(PIL.PlayerData.playerOrder) do
        local role = PIL.PlayerData:GetRole(unit)
        table.insert(playersByRole[role], unit)
    end

    for role, players in pairs(playersByRole) do
        local header = self.roleHeaders[role]
        if header and header.avgIlvlText and #players > 0 then
            local avgItemLevel = PIL.PlayerData:CalculateAverageItemLevel(players)
            local formattedAvgIlvl = string.format("%.1f", avgItemLevel or 0)
            header.avgIlvlText:SetText("avg " .. formattedAvgIlvl)
        end
    end
end

-- Resizes all bars based on current configuration
function BarManager:ResizeBars()
    for _, unit in ipairs(PIL.PlayerData.playerOrder) do
        local bar = PIL.BarPool:GetBar(unit)
        if bar then
            bar:UpdateHeight()
            bar:UpdateWidth()
            bar:UpdateTexture()
            bar:UpdateFont()
            bar:UpdateBackgroundOpacity()
            bar:InitTooltip()
        end
    end

    -- Rebuild to recalculate positions
    self:RebuildBars()
end

-- Adjusts the frame height based on number of bars and title bar visibility
function BarManager:AdjustFrameHeight(frame, contentFrame, titleBarVisible)
    local barCount = PIL.BarPool:GetInUseCount()
    local contentHeight

    -- When barSpacing is 0, calculate height without spacing
    if PIL.Config.barSpacing == 0 then
        contentHeight = barCount * PIL.Config.barHeight
    else
        contentHeight = barCount * (PIL.Config.barHeight + PIL.Config.barSpacing) - PIL.Config.barSpacing
    end

    -- Add height for role headers if grouping by role is enabled
    if PIL.Config.groupByRole then
        local headerCount = 0
        for _, _ in pairs(self.roleHeaders) do
            headerCount = headerCount + 1
        end

        contentHeight = contentHeight + (headerCount * 20)

        if PIL.Config.barSpacing > 0 then
            contentHeight = contentHeight + (headerCount * PIL.Config.barSpacing)
        end
    end

    if contentHeight <= 0 then
        contentHeight = 0
    end

    if contentHeight == 0 then
        if titleBarVisible then
            frame:SetHeight(20) -- Just title bar
        else
            frame:SetHeight(10) -- Minimal height
        end
    else
        if titleBarVisible then
            frame:SetHeight(contentHeight + 20) -- Add title bar height
        else
            frame:SetHeight(contentHeight) -- Just content
        end
    end
end

-- Gets a bar by its unit ID (delegates to BarPool)
function BarManager:GetBar(unit)
    return PIL.BarPool:GetBar(unit)
end

-- Gets the number of visible bars
function BarManager:GetBarCount()
    return PIL.BarPool:GetInUseCount()
end

-- Backward compatibility: CreateBars delegates to RebuildBars
function BarManager:CreateBars(parent)
    return self:RebuildBars()
end

-- Backward compatibility: UpdateBarsWithSorting delegates to appropriate methods
function BarManager:UpdateBarsWithSorting(forceUpdate)
    -- During combat, skip full sorting
    if InCombatLockdown() then
        self:UpdateAllBars(forceUpdate, true)
        return
    end

    -- Use UpdateCoordinator if available
    if PIL.UpdateCoordinator then
        if forceUpdate then
            PIL.UpdateCoordinator:ScheduleUpdate("fullRebuild")
        else
            PIL.UpdateCoordinator:ScheduleUpdate("sortRequired")
        end
    else
        -- Fallback direct handling
        PIL.PlayerData:ScanGroup()
        self:RebuildBars()
    end
end

return BarManager
