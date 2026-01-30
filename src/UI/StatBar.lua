local addonName, PIL = ...

-- Initialize StatBar namespace
PIL.StatBar = {}
local StatBar = PIL.StatBar


-- Creates a new stat bar instance
function StatBar:New(parent, name, statType)
	local obj = {}
	setmetatable(obj, { __index = StatBar })

	obj.name = name
	obj.statType = statType
	obj.value = 0
	obj.maxValue = 100
	obj.targetValue = 0
	obj.smoothing = true
	obj.yOffset = 0
	obj.frame = obj:CreateFrame(parent)

	-- Set the initial color after frame is created
	obj:UpdateColor()

	obj:InitAnimationSystem()
	obj:InitTooltip()

	-- Call UpdateNameText to handle initial truncation
	obj:UpdateNameText()

	return obj
end

-- Sets up the animation system for smooth value transitions
function StatBar:InitAnimationSystem()
	self.smoothing = true
	self.animationGroup = self.frame.bar:CreateAnimationGroup()
	self.valueAnimation = self.animationGroup:CreateAnimation("Progress")
	self.valueAnimation:SetDuration(0.3)
	self.valueAnimation:SetSmoothing("OUT")

	self.valueAnimation:SetScript("OnUpdate", function(anim)
		local progress = anim:GetProgress()
		local startValue = anim.startValue or 0
		local changeValue = anim.changeValue or 0
		local currentValue = startValue + (changeValue * progress)

		self.frame.bar:SetValue(currentValue)
	end)
end


-- Creates the visual elements of the stat bar
function StatBar:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetSize(PIL.Config.barWidth, PIL.Config.barHeight)

	local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	bg:SetBackdrop({
		bgFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeFile = "Interface\\BUTTONS\\WHITE8X8",
		tile = true, edgeSize = 1,
	})
	bg:SetBackdropColor(0, 0, 0, PIL.Config.barBgAlpha)
	bg:SetBackdropBorderColor(0, 0, 0, PIL.Config.barBgAlpha)
	frame.bg = bg

	-- Create the status bar
	local bar = CreateFrame("StatusBar", "PIL_StatBar_" .. self.statType, bg)
	bar:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)

	-- Set the status bar texture using the configured texture if available
	if PIL.Config.barTexture then
		bar:SetStatusBarTexture(PIL.Config.barTexture)
	else
		-- Fallback to a plain white texture if no texture path is configured
		local texture = bar:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()
		texture:SetColorTexture(1, 1, 1, 1) -- White texture that will take color
		bar:SetStatusBarTexture(texture)
	end

	-- Set initial color
	bar:SetStatusBarColor(0.8, 0.8, 0.8, PIL.Config.barAlpha)

	frame.bar = bar


	-- Create a text layer frame that will be above the bar
	local textLayer = CreateFrame("Frame", nil, bar)
	textLayer:SetAllPoints()
	textLayer:SetFrameLevel(bar:GetFrameLevel() + 1) -- Set higher than bar

	local valueText = textLayer:CreateFontString(nil, "OVERLAY")
	valueText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	valueText:SetFont(PIL.Config.fontFace, PIL.Config.fontSize, PIL.Config.fontOutline)
	valueText:SetJustifyH("RIGHT")
	valueText:SetText("0")
	valueText:SetTextColor(1, 1, 1, PIL.Config.barAlpha)
	if PIL.Config.fontShadow then
		valueText:SetShadowOffset(1, -1)
	else
		valueText:SetShadowOffset(0, 0)
	end
	frame.valueText = valueText

	local nameText = textLayer:CreateFontString(nil, "OVERLAY")
	nameText:SetPoint("LEFT", bar, "LEFT", 4, 0) -- Position name at the left of the bar
	nameText:SetFont(PIL.Config.fontFace, PIL.Config.fontSize, PIL.Config.fontOutline)
	nameText:SetJustifyH("LEFT")
	nameText:SetText(self.name)
	nameText:SetTextColor(1, 1, 1, PIL.Config.barAlpha)
	if PIL.Config.fontShadow then
		nameText:SetShadowOffset(1, -1)
	else
		nameText:SetShadowOffset(0, 0)
	end
	frame.nameText = nameText

	-- Store the text layer for future reference
	frame.textLayer = textLayer

	return frame
end


-- Updates the bar with a new value, using animation for smooth transitions
function StatBar:Update(value, maxValue, change, noAnimation)
	-- Only update if the value has actually changed
	if self.value ~= value then
		self.value = value or 0

		-- Calculate the percentage value based on the highest item level in the group
		local percentValue = PIL.Players:CalculateBarValues(self.value)

		-- Format the display value as a simple number for item level
		local displayValue = tostring(math.floor(self.value + 0.5))

		-- Only update text if it actually changed
		local currentText = self.frame.valueText:GetText()
		if currentText ~= displayValue then
			self.frame.valueText:SetText(displayValue)
		end

		-- Use animation if enabled and not explicitly disabled, otherwise set value directly
		if self.smoothing and not noAnimation then
			-- Only animate if the change is significant
			if math.abs(percentValue - self.frame.bar:GetValue()) >= 0.5 then
				self:AnimateToValue(percentValue)
			else
				self.frame.bar:SetValue(percentValue)
			end
		else
			self.frame.bar:SetValue(percentValue)
		end
	end
end

-- Animates the bar to a new value
function StatBar:AnimateToValue(newValue)
	self.animationGroup:Stop()

	-- Handle the main bar animation
	local currentValue = self.frame.bar:GetValue()

	if math.abs(newValue - currentValue) >= 0.5 then
		self.valueAnimation.startValue = currentValue
		self.valueAnimation.changeValue = newValue - currentValue
		self.animationGroup:Play()
	else
		self.frame.bar:SetValue(newValue)
	end
end

-- Returns the color for a specific stat type
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

	-- Ultimate fallback to ensure visibility
	return 0.8, 0.8, 0.8
end



-- Updates the color of the bar
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

	-- Ensure we have valid color values
	r = r or 0.8
	g = g or 0.8
	b = b or 0.8

	-- Apply the color to the status bar - set color directly without recreating texture
	if self.frame and self.frame.bar then
		self.frame.bar:SetStatusBarColor(r, g, b, PIL.Config.barAlpha)
	end
end

-- Sets the position of the bar relative to its parent
function StatBar:SetPosition(x, y)
	self.yOffset = y
	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", x, y)
	self.frame:SetPoint("TOPRIGHT", self.frame:GetParent(), "TOPRIGHT", 0, y)
end

-- Sets the highlight/select state of the bar
function StatBar:SetSelected(selected)
	if selected then
		if not self.frame.highlight then
			local highlight = self.frame.bar:CreateTexture(nil, "OVERLAY")
			highlight:SetAllPoints()
			highlight:SetColorTexture(1, 1, 1, 0.1)
			self.frame.highlight = highlight
		end
		self.frame.highlight:Show()
	elseif self.frame.highlight then
		self.frame.highlight:Hide()
	end
end

-- Updates the font used for text elements
function StatBar:UpdateFont()
	self.frame.valueText:SetFont(PIL.Config.fontFace, PIL.Config.fontSize, PIL.Config.fontOutline)
	self.frame.nameText:SetFont(PIL.Config.fontFace, PIL.Config.fontSize, PIL.Config.fontOutline)

	-- Apply the same opacity as the bar to the text
	self.frame.valueText:SetTextColor(1, 1, 1, PIL.Config.barAlpha)
	self.frame.nameText:SetTextColor(1, 1, 1, PIL.Config.barAlpha)

	-- Apply shadow if enabled
	if PIL.Config.fontShadow then
		self.frame.valueText:SetShadowOffset(1, -1)
		self.frame.nameText:SetShadowOffset(1, -1)
	else
		self.frame.valueText:SetShadowOffset(0, 0)
		self.frame.nameText:SetShadowOffset(0, 0)
	end

	-- Update name text to handle truncation after font changes
	self:UpdateNameText()
end

-- Updates the texture used for the status bar
function StatBar:UpdateTexture()
	-- Use the configured texture path if available
	if PIL.Config.barTexture then
		self.frame.bar:SetStatusBarTexture(PIL.Config.barTexture)
	else
		-- Fallback to a plain white texture if no texture path is configured
		local texture = self.frame.bar:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()
		texture:SetColorTexture(1, 1, 1, 1)
		self.frame.bar:SetStatusBarTexture(texture)
	end

	-- Reapply color after updating texture
	self:UpdateColor()

	-- Force tooltip reinitialization
	self.tooltipInitialized = false
	self:InitTooltip()
end

-- Updates the height of the bar
function StatBar:UpdateHeight()
    self.frame:SetHeight(PIL.Config.barHeight)

    -- Recalculate name truncation with the actual current dimensions
    self:UpdateNameText()
end

-- Updates the width of the bar
function StatBar:UpdateWidth()
	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", 0, self.yOffset)
	self.frame:SetPoint("TOPRIGHT", self.frame:GetParent(), "TOPRIGHT", 0, self.yOffset)

	-- Update name text to handle truncation
	self:UpdateNameText()
end

-- Updates the name text, truncating if necessary
function StatBar:UpdateNameText()
    if not self.frame or not self.frame.nameText then return end

    -- Get the actual width of the bar instead of using config value
    local barWidth = self.frame.bar:GetWidth()
    if barWidth == 0 then
        -- Fallback to config width if actual width isn't available yet
        barWidth = PIL.Config.barWidth
    end

    local valueTextWidth = self.frame.valueText:GetStringWidth() + 8 -- Add padding
    local availableWidth = barWidth - valueTextWidth - 8 -- Subtract padding

    -- Set the full name first to measure its width
    local fullName = self.name
    self.frame.nameText:SetText(fullName)
    local nameWidth = self.frame.nameText:GetStringWidth()

    -- Only truncate if necessary and we have space to show something
    if nameWidth > availableWidth and availableWidth > 10 then
        local ellipsis = "..."

        -- Performance optimization: use estimation instead of character-by-character loop
        -- This reduces GetStringWidth calls from O(n) to O(1)
        self.frame.nameText:SetText(ellipsis)
        local ellipsisWidth = self.frame.nameText:GetStringWidth()
        local targetWidth = availableWidth - ellipsisWidth

        if targetWidth <= 0 then
            self.frame.nameText:SetText(ellipsis)
            return
        end

        -- Estimate characters that fit using average width ratio
        local avgCharWidth = nameWidth / #fullName
        local estimatedChars = math.floor(targetWidth / avgCharWidth)
        estimatedChars = math.max(1, math.min(estimatedChars, #fullName - 1))

        -- Single adjustment pass (at most 1 extra GetStringWidth call)
        local truncatedName = string.sub(fullName, 1, estimatedChars)
        self.frame.nameText:SetText(truncatedName)
        if self.frame.nameText:GetStringWidth() > targetWidth and estimatedChars > 1 then
            truncatedName = string.sub(fullName, 1, estimatedChars - 1)
        end

        self.frame.nameText:SetText(truncatedName .. ellipsis)
    else
        -- Name fits, use the full name
        self.frame.nameText:SetText(fullName)
    end
end

-- Updates the background opacity of the bar
function StatBar:UpdateBackgroundOpacity()
	self.frame.bg:SetBackdropColor(0, 0, 0, PIL.Config.barBgAlpha)
	self.frame.bg:SetBackdropBorderColor(0, 0, 0, PIL.Config.barBgAlpha)
end

-- Sets up the tooltip for the stat bar (placeholder for future implementation)
function StatBar:InitTooltip()
	-- Clear any existing scripts
	self.frame:SetScript("OnEnter", nil)
	self.frame:SetScript("OnLeave", nil)

	-- Mark as initialized to prevent further calls
	self.tooltipInitialized = true
end

function StatBar:Destroy()
	-- Hide and clear the frame
	if self.frame then
		self.frame:Hide()
		self.frame:SetScript("OnEnter", nil)
		self.frame:SetScript("OnLeave", nil)
	end
end

-- Reset the bar for pool reuse
function StatBar:Reset(parent, name, unit)
	self.name = name
	self.statType = unit
	self.value = 0

	-- Reparent and show the frame
	self.frame:SetParent(parent)
	self.frame:Show()

	-- Update visuals
	self:UpdateNameText()
	self:UpdateColor()

	-- Stop any running animations
	if self.animationGroup then
		self.animationGroup:Stop()
	end

	-- Reset bar value
	self.frame.bar:SetValue(0)
end

-- Hide the bar (for pool release)
function StatBar:Hide()
	if self.frame then
		self.frame:Hide()
	end
end
