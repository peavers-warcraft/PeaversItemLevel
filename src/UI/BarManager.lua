local addonName, PIL = ...

-- Initialize BarManager namespace
PIL.BarManager = {}
local BarManager = PIL.BarManager

-- Collection to store all created bars
BarManager.bars = {}

-- Collection to store role headers
BarManager.roleHeaders = {}

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

-- Creates or recreates all player bars
function BarManager:CreateBars(parent)
    -- Clear existing bars
    for _, bar in ipairs(self.bars) do
        bar.frame:Hide()
    end
    self.bars = {}

    -- Clear existing role headers
    for role, header in pairs(self.roleHeaders) do
        header.frame:Hide()
    end
    self.roleHeaders = {}

    local yOffset = 0

    if PIL.Config.groupByRole then
        -- Group players by role
        local playersByRole = {
            ["TANK"] = {},
            ["HEALER"] = {},
            ["DAMAGER"] = {}
        }

        -- Sort players into role groups
        for _, unit in ipairs(PIL.Players.PLAYER_ORDER) do
            local role = PIL.Players:GetRole(unit)
            table.insert(playersByRole[role], unit)
        end

        -- Create bars for each role group
        local roleOrder = {"TANK", "HEALER", "DAMAGER"}

        for _, role in ipairs(roleOrder) do
            local players = playersByRole[role]

            -- Only create a header if there are players with this role
            if #players > 0 then
                -- Calculate average item level for this role group
                local avgItemLevel = PIL.Players:CalculateAverageItemLevel(players)

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
                    local playerName = PIL.Players:GetName(unit)
                    local bar = PIL.StatBar:New(parent, playerName, unit)
                    bar:SetPosition(0, yOffset)

                    local itemLevel = PIL.Players:GetItemLevel(unit)
                    -- Pass true for noAnimation to prevent flashing during initial creation
                    bar:Update(itemLevel, nil, nil, true)

                    -- Ensure the color is properly applied
                    bar:UpdateColor()

                    table.insert(self.bars, bar)

                    -- When barSpacing is 0, position bars exactly barHeight pixels apart
                    if PIL.Config.barSpacing == 0 then
                        yOffset = yOffset - PIL.Config.barHeight
                    else
                        yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
                    end
                end
            end
        end
    else
        -- Original behavior without role grouping
        for _, unit in ipairs(PIL.Players.PLAYER_ORDER) do
            local playerName = PIL.Players:GetName(unit)
            local bar = PIL.StatBar:New(parent, playerName, unit)
            bar:SetPosition(0, yOffset)

            local itemLevel = PIL.Players:GetItemLevel(unit)
            -- Pass true for noAnimation to prevent flashing during initial creation
            bar:Update(itemLevel, nil, nil, true)

            -- Ensure the color is properly applied
            bar:UpdateColor()

            table.insert(self.bars, bar)

            -- When barSpacing is 0, position bars exactly barHeight pixels apart
            if PIL.Config.barSpacing == 0 then
                yOffset = yOffset - PIL.Config.barHeight
            else
                yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
            end
        end
    end

    return math.abs(yOffset)
end

-- Updates all player bars with latest item levels
function BarManager:UpdateAllBars(forceUpdate, noAnimation)
	if not self.previousValues then
		self.previousValues = {}
	end

	local inCombat = InCombatLockdown()

	-- Track if any player's item level has changed
	local anyValueChanged = false
	local highestItemLevelChanged = false

	-- Skip highest item level change detection during combat to avoid secret value errors
	if not inCombat then
		local previousHighestItemLevel = PIL.Players.previousHighestItemLevel or 0
		local currentHighestItemLevel = PIL.Players:GetHighestItemLevel()

		-- Check if the highest item level has changed
		if currentHighestItemLevel ~= previousHighestItemLevel then
			highestItemLevelChanged = true
			PIL.Players.previousHighestItemLevel = currentHighestItemLevel
		end
	end

	-- First pass: Check if any values have changed
	for _, bar in ipairs(self.bars) do
		local unit = bar.statType -- In our case, statType is the unit ID
		local value = PIL.Players:GetItemLevel(unit)

		if not self.previousValues[unit] then
			self.previousValues[unit] = 0
		end

		-- Skip value comparisons during combat to avoid secret value errors
		if not inCombat then
			if value ~= self.previousValues[unit] then
				anyValueChanged = true
				-- Store the new value for next comparison
				self.previousValues[unit] = value
			end
		end

		-- Always update the name text to ensure it's visible
		local playerName = PIL.Players:GetName(unit)
		if bar.name ~= playerName then
			bar.name = playerName
			bar.frame.nameText:SetText(playerName)
			-- Call UpdateNameText to handle truncation after updating the name
			bar:UpdateNameText()
		end
	end

	-- Second pass: Update bars as needed
	-- During combat, always display cached values without animation
	if inCombat then
		for _, bar in ipairs(self.bars) do
			local unit = bar.statType
			local value = PIL.Players:GetItemLevel(unit)
			bar:Update(value, nil, 0, true) -- noAnimation = true during combat
			bar:UpdateColor()
		end
	elseif anyValueChanged or highestItemLevelChanged or forceUpdate then
		-- If the highest item level changes, update all bars at once with noAnimation
		-- to prevent staggered flashing
		local useNoAnimation = noAnimation or highestItemLevelChanged

		for _, bar in ipairs(self.bars) do
			local unit = bar.statType
			local value = PIL.Players:GetItemLevel(unit)
			local valueChanged = (self.previousValues[unit] and value ~= self.previousValues[unit])

			-- Only update the bar if:
			-- 1. This specific bar's value has changed, OR
			-- 2. The highest item level has changed (affects percentage calculations), OR
			-- 3. A force update is requested
			if valueChanged or highestItemLevelChanged or forceUpdate then
				-- Calculate the change in value (for display purposes)
				local change = 0
				if valueChanged then
					change = value - self.previousValues[unit]
				end

				-- Update the bar with the new value and change, passing noAnimation parameter
				bar:Update(value, nil, change, useNoAnimation)

				-- Ensure the color is properly applied when updating
				bar:UpdateColor()
			end
		end
	end
end

-- Resizes all bars based on current configuration
function BarManager:ResizeBars()
    for _, bar in ipairs(self.bars) do
        bar:UpdateHeight()
        bar:UpdateWidth()
        bar:UpdateTexture()
        bar:UpdateFont()
        bar:UpdateBackgroundOpacity()
        bar:InitTooltip() -- Reinitialize tooltips to ensure they're correctly set up
    end

    -- Return the total height of all bars for frame adjustment
    local totalHeight = #self.bars * PIL.Config.barHeight
    if PIL.Config.barSpacing > 0 then
        totalHeight = totalHeight + (#self.bars - 1) * PIL.Config.barSpacing
    end

    -- Add height for role headers if grouping by role is enabled
    if PIL.Config.groupByRole then
        local headerCount = 0
        for _, _ in pairs(self.roleHeaders) do
            headerCount = headerCount + 1
        end

        -- Each header is 20 pixels tall
        totalHeight = totalHeight + (headerCount * 20)

        -- Add spacing between headers and bars if barSpacing is enabled
        if PIL.Config.barSpacing > 0 then
            totalHeight = totalHeight + (headerCount * PIL.Config.barSpacing)
        end
    end

    return totalHeight
end

-- Adjusts the frame height based on number of bars and title bar visibility
function BarManager:AdjustFrameHeight(frame, contentFrame, titleBarVisible)
    local barCount = #self.bars
    local contentHeight

    -- When barSpacing is 0, calculate height without spacing
    if PIL.Config.barSpacing == 0 then
        contentHeight = barCount * PIL.Config.barHeight
    else
        contentHeight = barCount * (PIL.Config.barHeight + PIL.Config.barSpacing) - PIL.Config.barSpacing
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

    -- Content frame position is managed by Core:UpdateTitleBarVisibility
    -- to avoid duplicate repositioning that could cause UI glitches
end

-- Gets a bar by its unit ID
function BarManager:GetBar(unit)
    for _, bar in ipairs(self.bars) do
        if bar.statType == unit then
            return bar
        end
    end
    return nil
end

-- Gets the number of visible bars
function BarManager:GetBarCount()
    return #self.bars
end

-- Updates bars with proper sorting
-- This function will either update the existing bars or recreate them
-- depending on the current configuration
function BarManager:UpdateBarsWithSorting(forceUpdate)
	-- During combat, skip full sorting and just update values
	-- This avoids secret value comparison errors (WoW 12.0.1)
	if InCombatLockdown() then
		self:UpdateAllBars(forceUpdate, true)
		return
	end

	-- Always ensure proper order regardless of sort option
	-- Resort the players
	PIL.Players:ScanGroup()

	-- Check if we have any "Unknown" names that need updating
	local hasUnknownPlayers = false
	for _, unit in ipairs(PIL.Players.PLAYER_ORDER) do
		local playerName = PIL.Players:GetName(unit)
		if playerName == "Unknown" then
			hasUnknownPlayers = true
			break
		end
	end

	-- If we have unknown players or no bars yet, do a full rebuild
	if hasUnknownPlayers or #self.bars == 0 or forceUpdate or PIL.Config.groupByRole then
		if PIL.Core and PIL.Core.contentFrame then
			self:CreateBars(PIL.Core.contentFrame)
			PIL.Core:AdjustFrameHeight()
		end
		return
	end

	-- Create a temporary mapping of unit to bar
	local barsByUnit = {}
	for _, bar in ipairs(self.bars) do
		barsByUnit[bar.statType] = bar
	end

	-- Clear the bar collection but don't destroy the actual bar frames
	local oldBars = self.bars
	self.bars = {}

	-- Reposition bars according to new player order
	local yOffset = 0
	for _, unit in ipairs(PIL.Players.PLAYER_ORDER) do
		local bar = barsByUnit[unit]
		if bar then
			-- Update the name in case it changed
			local playerName = PIL.Players:GetName(unit)
			if bar.name ~= playerName then
				bar.name = playerName
				bar.frame.nameText:SetText(playerName)
				-- Call UpdateNameText to handle truncation after updating the name
				bar:UpdateNameText()
			end

			-- Add this bar back to our collection in the correct order
			table.insert(self.bars, bar)

			-- Position bar at the correct offset
			bar:SetPosition(0, yOffset)

			-- Update value without animation during sorting
			local itemLevel = PIL.Players:GetItemLevel(unit)
			bar:Update(itemLevel, nil, nil, true) -- noAnimation = true

			-- Ensure the color is properly applied
			bar:UpdateColor()

			-- When barSpacing is 0, position bars exactly barHeight pixels apart
			if PIL.Config.barSpacing == 0 then
				yOffset = yOffset - PIL.Config.barHeight
			else
				yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
			end
		else
			-- Create a new bar for this unit
			local playerName = PIL.Players:GetName(unit)
			local newBar = PIL.StatBar:New(PIL.Core.contentFrame, playerName, unit)
			newBar:SetPosition(0, yOffset)

			local itemLevel = PIL.Players:GetItemLevel(unit)
			-- Pass true for noAnimation to prevent flashing
			newBar:Update(itemLevel, nil, nil, true)

			-- Ensure the color is properly applied
			newBar:UpdateColor()

			table.insert(self.bars, newBar)

			-- When barSpacing is 0, position bars exactly barHeight pixels apart
			if PIL.Config.barSpacing == 0 then
				yOffset = yOffset - PIL.Config.barHeight
			else
				yOffset = yOffset - (PIL.Config.barHeight + PIL.Config.barSpacing)
			end
		end
	end

	-- Hide any bars that aren't in the current player list
	for _, bar in ipairs(oldBars) do
		if not tContains(PIL.Players.PLAYER_ORDER, bar.statType) then
			bar.frame:Hide()
		end
	end

	-- Adjust the frame height after reordering
	if PIL.Core then
		PIL.Core:AdjustFrameHeight()
	end
end

return BarManager
