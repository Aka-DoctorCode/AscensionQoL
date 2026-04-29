-------------------------------------------------------------------------------
-- Project: AscensionSound
-- Author: Aka-DoctorCode
-- File: AscensionSound.lua
-- Version: @project-version@
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------

local addonName, private = ...
local MAJOR, MINOR = "AscensionSound", 1
local AceAddon = LibStub("AceAddon-3.0")
local AscensionSound = AceAddon:NewAddon(MAJOR, "AceEvent-3.0", "AceConsole-3.0")

-- Get Factory UI library
local UIFactory = LibStub("AscensionSuit-UI")
if not UIFactory then
    error("AscensionSound requires AscensionSuit-UI library (Factory.lua)")
end

-------------------------------------------------------------------------------
-- CVar MAPPING
-------------------------------------------------------------------------------
local cvars = {
    Master   = { volume = "Sound_MasterVolume", toggle = "Sound_EnableAllSound" },
    Music    = { volume = "Sound_MusicVolume",   toggle = "Sound_EnableMusic" },
    SFX      = { volume = "Sound_SFXVolume",     toggle = "Sound_EnableSFX" },
    Ambience = { volume = "Sound_AmbienceVolume", toggle = "Sound_EnableAmbience" },
    Dialog   = { volume = "Sound_DialogVolume",  toggle = "Sound_EnableDialog" }
}
local channelOrder = { "Music", "SFX", "Ambience", "Dialog" }

-- Helper CVar functions (safe)
local function getCVarNumber(cvar)
    if not cvar then return 0 end
    local success, val = pcall(C_CVar.GetCVar, cvar)
    if success and val then
        return tonumber(val) or 0
    end
    return 0
end

local function getCVarBool(cvar)
    if not cvar then return false end
    local success, val = pcall(C_CVar.GetCVar, cvar)
    if success and val then
        return val == "1"
    end
    return false
end

local function updateCVar(cvar, value)
    if not cvar then return end
    pcall(C_CVar.SetCVar, cvar, tostring(value))
end

-------------------------------------------------------------------------------
-- TEXTURE BUTTON HELPER (+ / -)
-------------------------------------------------------------------------------
local function createTextureButton(parent, symbol, size, onClick, styles)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop({
        bgFile   = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(unpack(styles.colors.surfaceHighlight))
    btn:SetBackdropBorderColor(unpack(styles.colors.blackDetail))

    local iconTextures = {}
    local hLine = btn:CreateTexture(nil, "OVERLAY")
    hLine:SetTexture(styles.textures.bar)
    hLine:SetSize(12, 2)
    hLine:SetPoint("CENTER", 0, 0)
    hLine:SetVertexColor(unpack(styles.colors.textLight))
    table.insert(iconTextures, hLine)

    if symbol == "+" then
        local vLine = btn:CreateTexture(nil, "OVERLAY")
        vLine:SetTexture(styles.textures.bar)
        vLine:SetSize(2, 12)
        vLine:SetPoint("CENTER", 0, 0)
        vLine:SetVertexColor(unpack(styles.colors.textLight))
        table.insert(iconTextures, vLine)
    end

    btn.iconTextures = iconTextures

    local function setIconColor(r, g, b)
        for _, tex in ipairs(iconTextures) do
            tex:SetVertexColor(r, g, b, 1)
        end
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(styles.colors.primary))
        self:SetBackdropBorderColor(unpack(styles.colors.textLight))
        setIconColor(1, 1, 1)
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(styles.colors.surfaceHighlight))
        self:SetBackdropBorderColor(unpack(styles.colors.blackDetail))
        self._holding = false
        setIconColor(unpack(styles.colors.textLight))
    end)

    btn:SetScript("OnMouseDown", function(self)
        for _, tex in ipairs(self.iconTextures) do
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", 1, -1)
        end
        onClick()
        self._holdId = (self._holdId or 0) + 1
        local currentHold = self._holdId
        self._holding = true
        C_Timer.After(0.4, function()
            local function doRepeat()
                if not self:IsVisible() then self._holding = false end
                if self._holding and self._holdId == currentHold then
                    onClick()
                    C_Timer.After(0.08, doRepeat)
                end
            end
            if not self:IsVisible() then self._holding = false end
            if self._holding and self._holdId == currentHold then
                doRepeat()
            end
        end)
    end)

    btn:SetScript("OnMouseUp", function(self)
        for _, tex in ipairs(self.iconTextures) do
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", 0, 0)
        end
        self._holding = false
    end)

    return btn
end

-------------------------------------------------------------------------------
-- ADDON DEFINITION
-------------------------------------------------------------------------------
function AscensionSound:OnInitialize()
    -- Check if module is enabled by AscensionQoL core
    if private and private.isModuleEnabled and not private:isModuleEnabled("AscensionSound") then
        self:Disable()
        return
    end

    self.db = private.db
    self.profile = self.db.profile.modulesData.AscensionSound

    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("CVAR_UPDATE")
end

function AscensionSound:PLAYER_LOGIN()
    self:createUI()
    self:UnregisterEvent("PLAYER_LOGIN")
end

function AscensionSound:CVAR_UPDATE(event, cvarName, value)
    if not cvarName or not value then return end
    self:syncUIWithCVar(cvarName, value)
end

-------------------------------------------------------------------------------
-- UI CREATION (using Factory styles, center anchor)
-------------------------------------------------------------------------------
function AscensionSound:createUI()
    self.pos = private.positions.AscensionSound
    self.ctx = UIFactory:CreateContext()
    local styles = self.ctx.styles

    -- Main frame
    local frame = CreateFrame("Frame", "AscensionSoundMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(190, 40)
    -- Anchor to saved point
    frame:SetPoint(self.pos.point, UIParent, self.pos.relativePoint, self.pos.x, self.pos.y)
    frame:SetMovable(not self.profile.locked)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScale(self.profile.scale)

    -- Backdrop
    frame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(unpack(styles.colors.backgroundDark))
    frame:SetBackdropBorderColor(unpack(styles.colors.surfaceHighlight))
    self.frame = frame

    -- Drag handling
    frame:SetScript("OnDragStart", function(self)
        if not AscensionSound.profile.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        C_Timer.After(0, function()
            local point, _, relativePoint, x, y = self:GetPoint()
            if AscensionSound.pos and point then
                AscensionSound.pos.point = point
                AscensionSound.pos.relativePoint = relativePoint
                AscensionSound.pos.x = x
                AscensionSound.pos.y = y
                AscensionSound:updateSliders()
            end
        end)
    end)

    -- Right-click context menu
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            AscensionSound:showContextMenu()
        end
    end)

    -- Positioning constants
    local topY = -7
    local masterMuteX = 5
    local masterMuteWidth = 32
    local btnWidth = 26
    local btnSpacing = 5
    local expandBtnWidth = 45

    -- Master Mute (checkbox)
    local masterMute = self.ctx:createCheckbox({
        parent = frame,
        text = "",
        getter = function() return getCVarBool(cvars.Master.toggle) end,
        setter = function(val) updateCVar(cvars.Master.toggle, val and "1" or "0") end,
        yOffset = -4,
        xOffset = 5,
    })
    masterMute:SetSize(masterMuteWidth, masterMuteWidth)
    masterMute.tooltip = "Master Mute"
    masterMute:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Master Mute", 1, 1, 1)
        GameTooltip:Show()
    end)
    masterMute:SetScript("OnLeave", GameTooltip_Hide)
    self.masterMute = masterMute

    -- Decrease volume button (texture)
    local decX = masterMuteX + masterMuteWidth + btnSpacing
    local decBtn = createTextureButton(frame, "-", btnWidth, function()
        local current = getCVarNumber(cvars.Master.volume)
        updateCVar(cvars.Master.volume, math.max(0, current - 0.1))
    end, styles)
    decBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", decX, topY)

    -- Increase volume button (texture)
    local incX = decX + btnWidth + btnSpacing
    local incBtn = createTextureButton(frame, "+", btnWidth, function()
        local current = getCVarNumber(cvars.Master.volume)
        updateCVar(cvars.Master.volume, math.min(1, current + 0.1))
    end, styles)
    incBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", incX, topY)

    -- Expand / Dropdown button (text button, could be changed later)
    local expandX = frame:GetWidth() - expandBtnWidth - 5
    local expandBtn = self.ctx:createButton({
    parent = frame,
    text = "Vol",
    width = expandBtnWidth,
    height = btnWidth,
    xOffset = expandX,
    yOffset = topY,
    onClick = function() AscensionSound:toggleDropdown() end,
    })
    
    expandBtn.text:SetFontObject("GameFontNormalLarge")

    self:createDropdownPanel()
    self:updateMasterMuteState()

    -- Restore expanded state if needed (with slight delay to ensure positioning)
    if self.profile.isExpanded then
        C_Timer.After(0.05, function()
            if not self.dropdown then return end
            self:toggleDropdown()
        end)
    end
end

function AscensionSound:createDropdownPanel()
    local dropdown = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    dropdown:SetFrameStrata("MEDIUM")
    dropdown:SetFrameLevel(10)
    local numChannels = #channelOrder
    local rowHeight = 85
    
    local padding = 30
    dropdown:SetSize(250, numChannels * rowHeight + padding)
    dropdown:SetPoint("TOP", self.frame, "BOTTOM", 0, -5)
    dropdown:SetBackdrop({
        bgFile = self.ctx.styles.files.bgFile,
        edgeFile = self.ctx.styles.files.edgeFile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    dropdown:SetBackdropColor(unpack(self.ctx.styles.colors.surfaceDark))
    dropdown:SetBackdropBorderColor(unpack(self.ctx.styles.colors.surfaceHighlight))
    dropdown:SetClampedToScreen(true)
    dropdown:EnableMouse(true)
    dropdown:Hide()
    self.dropdown = dropdown

    -- Layout model for easy vertical positioning
    local layout = self.ctx.layoutModel:reset(dropdown, -15)
    self.dropdownSliders = {}
    self.dropdownCheckboxes = {}

    for _, channel in ipairs(channelOrder) do
        local data = cvars[channel]
        if data then
            -- Channel label
            layout:label(nil, channel, nil, self.ctx.styles.colors.gold)

            -- Checkbox (mute)
            local cb = self.ctx:createCheckbox({
                parent = dropdown,
                text = "",
                getter = function() return getCVarBool(data.toggle) end,
                setter = function(val) updateCVar(data.toggle, val and "1" or "0") end,
                yOffset = layout.y,
                xOffset = 16,
            })
            cb:SetSize(28, 28)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 16, layout.y)

            -- Slider (volume)
            local slider = self.ctx:createSlider({
                parent = dropdown,
                text = "",
                minVal = 0,
                maxVal = 100,
                step = 5,
                getter = function() return getCVarNumber(data.volume) * 100 end,
                setter = function(val) updateCVar(data.volume, val / 100) end,
                width = 150,
                xOffset = 50,
                yOffset = layout.y - 10,
            })
            slider:ClearAllPoints()
            slider:SetPoint("LEFT", cb, "RIGHT", 5, 0)

            table.insert(self.dropdownSliders, { slider = slider, cvar = data.volume })
            table.insert(self.dropdownCheckboxes, { checkbox = cb, cvar = data.toggle })

            layout.y = layout.y - 70
        end
    end

    self:createDropdownCatcher()
end

function AscensionSound:createDropdownCatcher()
    if self.dropdownCatcher then return end
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetFrameStrata("BACKGROUND")
    catcher:SetFrameLevel(1)
    catcher:SetAllPoints()
    catcher:SetScript("OnClick", function()
        if self.dropdown and self.dropdown:IsShown() then
            if not self.dropdown:IsMouseOver() then
                self:toggleDropdown()
            end
        end
    end)
    catcher:Hide()
    self.dropdownCatcher = catcher
end

function AscensionSound:toggleDropdown()
    if not self.dropdown then return end
    if self.dropdown:IsShown() then
        self.dropdown:Hide()
        self.profile.isExpanded = false
        if self.dropdownCatcher then self.dropdownCatcher:Hide() end
    else
        self:positionDropdown()
        self.dropdown:Show()
        self.profile.isExpanded = true
        if self.dropdownCatcher then self.dropdownCatcher:Show() end
    end
end

function AscensionSound:positionDropdown()
    if not self.dropdown or not self.frame then return end
    -- Get absolute rectangle of the main frame
    local left, bottom, width, height = self.frame:GetRect()
    if not bottom then
        -- Frame not yet laid out, skip positioning
        return
    end
    local dropdownHeight = self.dropdown:GetHeight()
    local spaceBelow = bottom - 10   -- 10 pixel margin

    if spaceBelow >= dropdownHeight then
        self.dropdown:ClearAllPoints()
        self.dropdown:SetPoint("TOP", self.frame, "BOTTOM", 0, -5)
    else
        self.dropdown:ClearAllPoints()
        self.dropdown:SetPoint("BOTTOM", self.frame, "TOP", 0, 5)
    end
end

-------------------------------------------------------------------------------
-- OPTIONS MENU (Second level)
-------------------------------------------------------------------------------
function AscensionSound:showOptionsMenu(parentFrame)
    if self.optionsMenu and self.optionsMenu:IsShown() then
        self.optionsMenu:Hide()
        return
    end

    -- Open main config frame first
    if private.showConfigFrame then private.showConfigFrame() end
    local aqolFrame = _G["AscensionQoLConfigFrame"]

    self.optionsMenu = private:createSmartMenu(
        self.ctx,
        "Sound Module Options",
        280,
        aqolFrame,
        "RIGHT",
        self.profile,
        function(layout, menu)
            self.scaleSlider = layout:slider(nil, "Scale", 0.5, 2.0, 0.1,
                function() return self.profile.scale end,
                function(v)
                    self.profile.scale = v
                    if self.frame then self.frame:SetScale(v) end
                end)

            local screenWidth = math.floor(GetScreenWidth())
            self.xSlider = layout:slider(nil, "X Position", -screenWidth, screenWidth, 1,
                function() return self.pos.x end,
                function(v)
                    self.pos.x = v
                    if self.frame then
                        self.frame:ClearAllPoints()
                        self.frame:SetPoint(self.pos.point, UIParent, self.pos.relativePoint, self.pos.x, self.pos.y)
                    end
                end)

            local screenHeight = math.floor(GetScreenHeight())
            self.ySlider = layout:slider(nil, "Y Position", -screenHeight, screenHeight, 1,
                function() return self.pos.y end,
                function(v)
                    self.pos.y = v
                    if self.frame then
                        self.frame:ClearAllPoints()
                        self.frame:SetPoint(self.pos.point, UIParent, self.pos.relativePoint, self.pos.x, self.pos.y)
                    end
                end)
        end
    )
end

function AscensionSound:updateSliders()
    if not self.optionsMenu or not self.optionsMenu:IsShown() then return end
    if self.scaleSlider then self.scaleSlider:SetValue(self.profile.scale) end
    if self.xSlider then self.xSlider:SetValue(self.pos.x) end
    if self.ySlider then self.ySlider:SetValue(self.pos.y) end
end

-------------------------------------------------------------------------------
-- CONTEXT MENU (Right-click)
-------------------------------------------------------------------------------
function AscensionSound:showContextMenu()
    private:createContextMenu(
        self.ctx,
        self.frame,
        self.profile,
        self.pos,
        { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
        function() self:showOptionsMenu() end,
        function() self:updateSliders() end
    )
end

-------------------------------------------------------------------------------
-- SYNC METHODS
-------------------------------------------------------------------------------
function AscensionSound:updateMasterMuteState()
    if self.masterMute then
        self.masterMute:SetChecked(getCVarBool(cvars.Master.toggle))
    end
end

function AscensionSound:syncUIWithCVar(cvarName, value)
    -- Master mute button
    if cvarName == cvars.Master.toggle then
        if self.masterMute then
            self.masterMute:SetChecked(value == "1")
        end
    end

    -- Dropdown controls if visible
    if self.dropdown and self.dropdown:IsShown() then
        for _, item in ipairs(self.dropdownSliders or {}) do
            if item.cvar == cvarName then
                local numVal = (tonumber(value) or 0) * 100
                item.slider:SetValue(numVal)
            end
        end
        for _, item in ipairs(self.dropdownCheckboxes or {}) do
            if item.cvar == cvarName then
                item.checkbox:SetChecked(value == "1")
            end
        end
    end
end

function AscensionSound:OnDisable()
    if self.dropdown then self.dropdown:Hide() end
    if self.frame then self.frame:Hide() end
end
