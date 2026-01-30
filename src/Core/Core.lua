local addonName, PIL = ...
local Core = {}
PIL.Core = Core

-- Init combat state
Core.inCombat = false

-- Sets up the addon's main frame and components
function Core:Initialize()
	-- PlayerData is already initialized by Main.lua before this is called
	-- Initialize Players module for backward compatibility
	if PIL.Players and PIL.Players.Initialize then
		PIL.Players:Initialize()
	end

	self.frame = CreateFrame("Frame", "PeaversItemLevelFrame", UIParent, "BackdropTemplate")
	self.frame:SetSize(PIL.Config.frameWidth, PIL.Config.frameHeight)
	self.frame:SetBackdrop({
		bgFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeFile = "Interface\\BUTTONS\\WHITE8X8",
		tile = true, tileSize = 16, edgeSize = 1,
	})
	self.frame:SetBackdropColor(PIL.Config.bgColor.r, PIL.Config.bgColor.g, PIL.Config.bgColor.b, PIL.Config.bgAlpha)
	self.frame:SetBackdropBorderColor(0, 0, 0, PIL.Config.bgAlpha)

	local titleBar = PIL.TitleBar:Create(self.frame)
	self.titleBar = titleBar

	self.contentFrame = CreateFrame("Frame", nil, self.frame)
	self.contentFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -20)
	self.contentFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)

	self:UpdateTitleBarVisibility()

	-- Create bars using the BarManager
	PIL.BarManager:CreateBars(self.contentFrame)

	-- Adjust frame height based on visible bars
	self:AdjustFrameHeight()

	-- Now set the position after bars are created and frame height is adjusted
	self.frame:SetPoint(PIL.Config.framePoint, PIL.Config.frameX, PIL.Config.frameY)

	self:UpdateFrameLock()

 	-- Determine initial visibility based on settings
	self:UpdateFrameVisibility()
end

-- Recalculates frame height based on number of bars and title bar visibility
function Core:AdjustFrameHeight()
	-- Use the BarManager to adjust frame height
	PIL.BarManager:AdjustFrameHeight(self.frame, self.contentFrame, PIL.Config.showTitleBar)
end

-- Enables or disables frame dragging based on lock setting
function Core:UpdateFrameLock()
	if PIL.Config.lockPosition then
		self.frame:SetMovable(false)
		self.frame:EnableMouse(true) -- Keep mouse enabled for tooltips
		self.frame:RegisterForDrag("")
		self.frame:SetScript("OnDragStart", nil)
		self.frame:SetScript("OnDragStop", nil)
	else
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
		self.frame:RegisterForDrag("LeftButton")
		self.frame:SetScript("OnDragStart", self.frame.StartMoving)
		self.frame:SetScript("OnDragStop", function(frame)
			frame:StopMovingOrSizing()

			local point, _, _, x, y = frame:GetPoint()
			PIL.Config.framePoint = point
			PIL.Config.frameX = x
			PIL.Config.frameY = y
			PIL.Config:Save()
		end)
	end
end

-- Shows or hides the title bar and adjusts content frame accordingly
function Core:UpdateTitleBarVisibility()
	if self.titleBar then
		if PIL.Config.showTitleBar then
			self.titleBar:Show()
			self.contentFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -20)
		else
			self.titleBar:Hide()
			self.contentFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
		end

		self:AdjustFrameHeight()
	end
end

-- Updates frame visibility based on display mode and combat state
function Core:UpdateFrameVisibility()
	if not self.frame then return end

	local inCombat = self.inCombat or InCombatLockdown()
	local isInParty = IsInGroup() and not IsInRaid()
	local isInRaid = IsInRaid()
	local shouldShow = false

	-- First check if we should show based on display mode
	if PIL.Config.displayMode == "ALWAYS" then
		shouldShow = true
	elseif PIL.Config.displayMode == "PARTY_ONLY" and isInParty then
		shouldShow = true
	elseif PIL.Config.displayMode == "RAID_ONLY" and isInRaid then
		shouldShow = true
	end

	-- Then check if we should hide based on combat state
	if shouldShow and PIL.Config.hideOutOfCombat and not inCombat then
		shouldShow = false
	end

	-- Apply visibility
	if shouldShow and PIL.Config.showOnLogin then
		self.frame:Show()
	else
		self.frame:Hide()
	end
end

return Core
