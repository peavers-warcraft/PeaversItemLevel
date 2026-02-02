local addonName, PIL = ...
local Core = {}
PIL.Core = Core

-- Init combat state
Core.inCombat = false

-- Sets up the addon's main frame and components
function Core:Initialize()
	-- Initialize player tracking
	PIL.Players:Initialize()

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
	local PeaversCommons = _G.PeaversCommons
	PeaversCommons.FrameLock:ApplyFromConfig(
		self.frame,
		self.contentFrame,
		PIL.Config,
		function() PIL.Config:Save() end
	)
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
	local PeaversCommons = _G.PeaversCommons
	PeaversCommons.VisibilityManager:UpdateVisibility(self.frame, PIL.Config, self.inCombat)
end

return Core
