-------------------------------------------------------------------------------
-- Project: AscensionSound
-- Author: Aka-DoctorCode
-- File: AscensionSound.lua
-- Version: 03
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------

--  INIT & CONSTANTS
local addonName, addon = ...
local frame = CreateFrame("Frame", "AscensionSoundMainFrame", UIParent, "BackdropTemplate")

---@diagnostic disable-next-line: undefined-global
local AscensionSoundDB = AscensionSoundDB

--------------------------------------------------------------------------------
-- COLOR SCHEME
-------------------------------------------------------------------------------
local COLORS = {
    bg = { 0.08, 0.08, 0.08, 0.85 },
    window_border = { 0.4, 0.4, 0.4, 1.0 },
    text_title = { 1.0, 0.8, 0.0, 1.0 },
    text_normal = { 1.0, 1.0, 1.0, 1.0 },
    text_dim = { 0.6, 0.6, 0.6, 1.0 },
    text_highlight = { 1.0, 1.0, 0.0, 1.0 },
    input_bg = { 0.15, 0.15, 0.15, 0.85 },
    input_border = { 0.4, 0.4, 0.4, 1.0 },
    input_focus = { 1.0, 0.8, 0.0, 1.0 },
    menu_bg = { 0.12, 0.12, 0.12, 0.85 },
    sidebar_accent = { 0.8, 0.6, 0.2, 1.0 },
    card_bg = { 0.15, 0.15, 0.15, 0.85 },
    card_border = { 0.3, 0.3, 0.3, 1.0 },
    card_hover = { 0.8, 0.6, 0.2, 1.0 },
}

-- Default settings
local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 1.0,
    isExpanded = false,
    locked = false,
}

-- CVars map
local cvars = {
    Master = { volume = "Sound_MasterVolume", toggle = "Sound_EnableAllSound" },
    Music = { volume = "Sound_MusicVolume", toggle = "Sound_EnableMusic" },
    SFX = { volume = "Sound_SFXVolume", toggle = "Sound_EnableSFX" },
    Ambience = { volume = "Sound_AmbienceVolume", toggle = "Sound_EnableAmbience" },
    Dialog = { volume = "Sound_DialogVolume", toggle = "Sound_EnableDialog" }
}

-- Order of sliders in the dropdown
local sliderOrder = { "Master", "Music", "SFX", "Ambience", "Dialog" }


--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function UpdateCVar(cvar, value)
    if not cvar then return end
    pcall(C_CVar.SetCVar, cvar, tostring(value))
end

local function GetCVarNumber(cvar)
    if not cvar then return 0 end
    local success, val = pcall(C_CVar.GetCVar, cvar)
    if success and val then
        return tonumber(val) or 0
    end
    return 0
end

local function GetCVarBool(cvar)
    if not cvar then return false end
    local success, val = pcall(C_CVar.GetCVar, cvar)
    if success and val then
        return val == "1"
    end
    return false
end

local function GetCVarDefault(cvar)
    if not cvar then return 0 end
    local success, val = pcall(C_CVar.GetCVarDefault, cvar)
    if success and val then
        return tonumber(val) or 0
    end
    return 0
end

--------------------------------------------------------------------------------
-- STYLED BUTTON (como en AscensionNotes)
--------------------------------------------------------------------------------
function addon:CreateStyledButton(parent, text, style)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    if style == "primary" then
        btn:SetBackdropColor(0.2, 0.5, 0.2, 1)
        btn:SetBackdropBorderColor(0.4, 0.8, 0.4, 1)
    elseif style == "danger" then
        btn:SetBackdropColor(0.5, 0.2, 0.2, 1)
        btn:SetBackdropBorderColor(0.8, 0.4, 0.4, 1)
    else
        btn:SetBackdropColor(unpack(COLORS.card_bg))
        btn:SetBackdropBorderColor(unpack(COLORS.card_border))
    end

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(unpack(COLORS.text_normal))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.card_hover))
        self.text:SetTextColor(unpack(COLORS.text_highlight))
    end)
    btn:SetScript("OnLeave", function(self)
        if style == "primary" then
            self:SetBackdropBorderColor(0.4, 0.8, 0.4, 1)
        elseif style == "danger" then
            self:SetBackdropBorderColor(0.8, 0.4, 0.4, 1)
        else
            self:SetBackdropBorderColor(unpack(COLORS.card_border))
        end
        self.text:SetTextColor(unpack(COLORS.text_normal))
    end)

    return btn
end

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------

function addon:CreateContextMenu()
    if self.contextMenu then return end

    local f = CreateFrame("Frame", "AscensionSoundContextMenu", UIParent, "BackdropTemplate")
    f:SetSize(190, 120)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(unpack(COLORS.menu_bg))
    f:SetBackdropBorderColor(unpack(COLORS.window_border))
    f:Hide()

    local function CreateMenuBtn(text, parent, relativeTo, colorOverride)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(190, 25)
        if relativeTo then
            btn:SetPoint("TOP", relativeTo, "BOTTOM", 0, 0)
        else
            btn:SetPoint("TOP", 0, 0)
        end
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 10, 0)
        btn.text:SetText(text)
        if colorOverride then
            btn.text:SetTextColor(unpack(colorOverride))
        else
            btn.text:SetTextColor(unpack(COLORS.text_normal))
        end
        btn:SetScript("OnEnter", function(s)
            if not colorOverride then
                s.text:SetTextColor(unpack(COLORS.text_highlight))
            end
            s.bg = s.bg or s:CreateTexture(nil, "BACKGROUND")
            s.bg:SetAllPoints()
            s.bg:SetColorTexture(1, 1, 1, 0.1)
        end)
        btn:SetScript("OnLeave", function(s)
            if not colorOverride then
                s.text:SetTextColor(unpack(COLORS.text_normal))
            end
            if s.bg then
                s.bg:Hide()
                s.bg = nil
            end
        end)
        return btn
    end

    -- 1. Lock / Unlock
    local lockBtn = CreateMenuBtn("", f, nil)
    lockBtn:SetScript("OnClick", function()
        AscensionSoundDB.locked = not AscensionSoundDB.locked
        frame:SetMovable(not AscensionSoundDB.locked)
        f:Hide()
    end)

    -- 2. Reset position
    local resetBtn = CreateMenuBtn("Reset position", f, lockBtn)
    resetBtn:SetScript("OnClick", function()
        AscensionSoundDB.point = defaults.point
        AscensionSoundDB.relativePoint = defaults.relativePoint
        AscensionSoundDB.x = defaults.x
        AscensionSoundDB.y = defaults.y
        frame:ClearAllPoints()
        frame:SetPoint(defaults.point, UIParent, defaults.relativePoint, defaults.x, defaults.y)
        f:Hide()
    end)

    -- 3. Separador visual y control de escala
    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOP", resetBtn, "BOTTOM", 0, -5)
    scaleLabel:SetText("Scale")
    scaleLabel:SetTextColor(unpack(COLORS.text_title))

    -- 4. Button‑based scale controls
    local scaleRow = CreateFrame("Frame", nil, f)
    scaleRow:SetSize(160, 30)
    scaleRow:SetPoint("TOP", scaleLabel, "BOTTOM", 0, -5)

    -- Minus button
    local minusBtn = CreateFrame("Button", nil, scaleRow, "BackdropTemplate")
    minusBtn:SetSize(30, 30)
    minusBtn:SetPoint("LEFT", 0, 0)
    minusBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    minusBtn:SetBackdropColor(unpack(COLORS.card_bg))
    minusBtn:SetBackdropBorderColor(unpack(COLORS.card_border))
    minusBtn.text = minusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minusBtn.text:SetPoint("CENTER")
    minusBtn.text:SetText("-")
    minusBtn.text:SetTextColor(unpack(COLORS.text_normal))
    minusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.card_hover))
        self.text:SetTextColor(unpack(COLORS.text_highlight))
    end)
    minusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.card_border))
        self.text:SetTextColor(unpack(COLORS.text_normal))
    end)

    -- Scale value display
    local scaleValue = scaleRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleValue:SetPoint("CENTER")
    scaleValue:SetTextColor(unpack(COLORS.text_normal))
    scaleValue:SetText(string.format("%.1fx", AscensionSoundDB.scale or 1.0))

    -- Plus button
    local plusBtn = CreateFrame("Button", nil, scaleRow, "BackdropTemplate")
    plusBtn:SetSize(30, 30)
    plusBtn:SetPoint("RIGHT", 0, 0)
    plusBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    plusBtn:SetBackdropColor(unpack(COLORS.card_bg))
    plusBtn:SetBackdropBorderColor(unpack(COLORS.card_border))
    plusBtn.text = plusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plusBtn.text:SetPoint("CENTER")
    plusBtn.text:SetText("+")
    plusBtn.text:SetTextColor(unpack(COLORS.text_normal))
    plusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.card_hover))
        self.text:SetTextColor(unpack(COLORS.text_highlight))
    end)
    plusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.card_border))
        self.text:SetTextColor(unpack(COLORS.text_normal))
    end)

    -- Update scale function
    local function SetScale(newScale)
        newScale = math.max(0.5, math.min(2.0, newScale))
        newScale = math.floor(newScale * 10 + 0.5) / 10
        AscensionSoundDB.scale = newScale
        frame:SetScale(newScale)
        scaleValue:SetText(string.format("%.1fx", newScale))
    end

    minusBtn:SetScript("OnClick", function()
        SetScale((AscensionSoundDB.scale or 1.0) - 0.1)
    end)

    plusBtn:SetScript("OnClick", function()
        SetScale((AscensionSoundDB.scale or 1.0) + 0.1)
    end)

    -- 5. Update lock button text
    local function UpdateMenuTexts()
        lockBtn.text:SetText(AscensionSoundDB.locked and "Unlock" or "Lock")
    end

    -- 6. Closer (full‑screen click catcher) – now parented to UIParent
    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetFrameStrata("DIALOG")
    closer:SetFrameLevel(f:GetFrameLevel() - 1) -- below the menu
    closer:SetAllPoints(UIParent)
    closer:SetScript("OnClick", function() f:Hide() end)
    closer:Hide()

    f:SetScript("OnShow", function()
        UpdateMenuTexts()
        scaleValue:SetText(string.format("%.1fx", AscensionSoundDB.scale or 1.0))
        closer:Show()
    end)
    f:SetScript("OnHide", function()
        closer:Hide()
    end)

    self.contextMenu = f
end

function addon:CreateDropdownCatcher()
    if self.dropdownCatcher then return end

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetFrameStrata("MEDIUM")
    catcher:SetFrameLevel(1)
    catcher:SetAllPoints(UIParent)
    catcher:SetScript("OnClick", function()
        if frame.dropdown and frame.dropdown:IsShown() then
            if not frame.dropdown:IsMouseOver() then
                addon:ToggleDropdown()
            end
        end
    end)
    catcher:Hide()
    self.dropdownCatcher = catcher
end

function addon:ShowDropdownCatcher()
    if not self.dropdownCatcher then self:CreateDropdownCatcher() end
    self.dropdownCatcher:Show()
end

function addon:ShowContextMenu(anchor)
    if not self.contextMenu then self:CreateContextMenu() end
    local menu = self.contextMenu
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
    menu:Show()
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------
function addon:CreateUI()
    -- Main container
    frame:SetSize(190, 40)
    frame:ClearAllPoints()
    local point = AscensionSoundDB.point or "CENTER"
    local relativePoint = AscensionSoundDB.relativePoint or "CENTER"
    local x = AscensionSoundDB.x or 0
    local y = AscensionSoundDB.y or 0
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:SetMovable(not AscensionSoundDB.locked)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not AscensionSoundDB.locked then self:StartMoving() end
    end)
    frame:SetClampedToScreen(true)
    frame:SetScale(AscensionSoundDB.scale or 1.0)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        AscensionSoundDB.point = point
        AscensionSoundDB.relativePoint = relativePoint
        AscensionSoundDB.x = x
        AscensionSoundDB.y = y
    end)

    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(unpack(COLORS.bg))
    frame:SetBackdropBorderColor(unpack(COLORS.window_border))

    -- Right-click context menu
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            addon:ShowContextMenu(self)
        end
    end)

    -- Master Mute Button (Toggle)
    local masterMuteBtn = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    masterMuteBtn:SetSize(35, 35)
    masterMuteBtn:SetPoint("LEFT", frame, "LEFT", 5, 0)
    masterMuteBtn.tooltip = "Master Mute"
    masterMuteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    masterMuteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    masterMuteBtn:SetScript("OnClick", function(self)
        local isEnabled = self:GetChecked()
        UpdateCVar(cvars.Master.toggle, isEnabled and "1" or "0")
    end)

    -- Sync initial state
    masterMuteBtn:SetChecked(GetCVarBool(cvars.Master.toggle))
    frame.masterMuteBtn = masterMuteBtn

    -- Decrease Volume Button (-)
    local decBtn = self:CreateStyledButton(frame, "-", "normal")
    decBtn:SetSize(26, 26)
    decBtn:SetPoint("LEFT", masterMuteBtn, "RIGHT", 5, 0)
    decBtn:SetScript("OnClick", function()
        local current = GetCVarNumber(cvars.Master.volume)
        local newVol = math.max(0, current - 0.1)
        UpdateCVar(cvars.Master.volume, newVol)
    end)

    -- Increase Volume Button (+)
    local incBtn = self:CreateStyledButton(frame, "+", "normal")
    incBtn:SetSize(26, 26)
    incBtn:SetPoint("LEFT", decBtn, "RIGHT", 5, 0)
    incBtn:SetScript("OnClick", function()
        local current = GetCVarNumber(cvars.Master.volume)
        local newVol = math.min(1, current + 0.1)
        UpdateCVar(cvars.Master.volume, newVol)
    end)

    -- Expand/Dropdown Button
    local expandBtn = self:CreateStyledButton(frame, "Vol", "normal")
    expandBtn:SetSize(45, 26)
    expandBtn:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
    expandBtn:SetScript("OnClick", function()
        addon:ToggleDropdown()
    end)

    --------------------------------------------------------------------------------
    -- DROPDOWN
    --------------------------------------------------------------------------------
    local dropdown = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    dropdown:SetFrameStrata("MEDIUM")
    dropdown:SetFrameLevel(10)
    local numChannels = #sliderOrder
    local rowHeight = 60
    local padding = 20
    local dropdownHeight = numChannels * rowHeight + padding
    dropdown:SetSize(250, dropdownHeight)
    dropdown:SetPoint("TOP", frame, "BOTTOM", 0, -5)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    dropdown:SetBackdropColor(unpack(COLORS.menu_bg))
    dropdown:SetBackdropBorderColor(unpack(COLORS.window_border))
    dropdown:SetClampedToScreen(true)
    dropdown:EnableMouse(true)
    dropdown:Hide()
    frame.dropdown = dropdown

    dropdown.sliders = {}
    dropdown.checkboxes = {}

    -- Create Sliders for each channel
    local startY = -15
    for _, type in ipairs(sliderOrder) do
        local data = cvars[type]
        if data then
            local slider, checkbox = addon:CreateSliderControl(dropdown, type, data, startY)
            if slider and checkbox then
                checkbox:SetChecked(GetCVarBool(data.toggle))
                slider:SetValue(GetCVarNumber(data.volume))
            end
            startY = startY - 60
        end
    end
end

--------------------------------------------------------------------------------
-- CREATION OF CONTROLS BY CHANNEL (Slider + Checkbox + Labels)
--------------------------------------------------------------------------------

function addon:CreateSliderControl(parent, labelText, cvarData, yOffset)
    if not parent or not cvarData then return end

    parent.sliders = parent.sliders or {}
    parent.checkboxes = parent.checkboxes or {}

    -- 1. Label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    label:SetPoint("TOP", parent, "TOP", 0, yOffset)
    label:SetText(labelText)
    label:SetTextColor(unpack(COLORS.text_title))

    -- 2. Checkbox
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(28, 28)

    -- 3. Slider
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOP", label, "BOTTOM", 0, -8)
    slider:SetWidth(150)
    slider:SetHeight(17)
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)
    slider:RegisterForDrag("LeftButton")

    -- Checkbox position
    cb:SetPoint("RIGHT", slider, "LEFT", -5, 0)

    -- 4. Percentage text
    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("LEFT", slider, "RIGHT", 5, 0)
    valueText:SetTextColor(unpack(COLORS.text_normal))
    valueText:SetText("100%")

    -- 5. "Low" and "High" text
    local lowText, highText
    for _, region in ipairs({ slider:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            local text = region["GetText"](region)
            if text == "Low" then
                lowText = region
            elseif text == "High" then
                highText = region
            end
        end
    end

    if lowText then lowText:SetFontObject(GameFontNormalLarge) end
    if highText then highText:SetFontObject(GameFontNormalLarge) end

    -- Right-click to reset to default
    slider:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            local defaultValue = GetCVarDefault(cvarData.volume)
            slider:SetValue(defaultValue)
            UpdateCVar(cvarData.volume, defaultValue)
        end
    end)

    -- Update functions
    local function UpdateValueText()
        local val = slider:GetValue()
        valueText:SetText(string.format("%d%%", val * 100))
    end

    -- Scripts del checkbox
    cb:SetScript("OnClick", function(self)
        local isEnabled = self:GetChecked()
        UpdateCVar(cvarData.toggle, isEnabled and "1" or "0")
    end)
    cb:SetScript("OnShow", function(self)
        self:SetChecked(GetCVarBool(cvarData.toggle))
    end)

    -- Scripts del slider
    slider:SetScript("OnValueChanged", function(self, value)
        local currentCVar = GetCVarNumber(cvarData.volume)
        if math.abs(value - currentCVar) > 0.0001 then
            UpdateCVar(cvarData.volume, value)
        end
        UpdateValueText()
    end)
    slider:SetScript("OnShow", function(self)
        self:SetValue(GetCVarNumber(cvarData.volume))
        UpdateValueText()
    end)

    UpdateValueText()

    -- Save references for update by CVAR_UPDATE
    table.insert(parent.sliders, { slider = slider, cvar = cvarData.volume, valueText = valueText })
    table.insert(parent.checkboxes, { checkbox = cb, cvar = cvarData.toggle })

    return slider, cb
end

function addon:ToggleDropdown()
    if not frame.dropdown then return end

    if frame.dropdown:IsShown() then
        frame.dropdown:Hide()
        AscensionSoundDB.isExpanded = false
        if self.dropdownCatcher then
            self.dropdownCatcher:Hide()
        end
    else
        addon:PositionDropdown()
        frame.dropdown:Show()
        AscensionSoundDB.isExpanded = true
        addon:ShowDropdownCatcher()
    end
end

function addon:PositionDropdown()
    if not frame.dropdown then return end
    local dropdown = frame.dropdown

    local left, bottom, width, height = frame:GetRect()
    local screenHeight = UIParent:GetHeight()
    local dropdownHeight = dropdown:GetHeight()

    local spaceBelow = bottom - 10

    if spaceBelow >= dropdownHeight then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOP", frame, "BOTTOM", 0, -5)
    else
        dropdown:ClearAllPoints()
        dropdown:SetPoint("BOTTOM", frame, "TOP", 0, 5)
    end
end

--------------------------------------------------------------------------------
-- EVENT HANDLING
--------------------------------------------------------------------------------

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CVAR_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Check if module is enabled in the Core hub
        if addon.IsModuleEnabled and not addon:IsModuleEnabled("AscensionSound") then
            return
        end

        if not AscensionSoundDB then
            AscensionSoundDB = defaults
        else
            for k, v in pairs(defaults) do
                if AscensionSoundDB[k] == nil then
                    AscensionSoundDB[k] = v
                end
            end
        end
        addon:CreateUI()
        if AscensionSoundDB.isExpanded then
            addon:ToggleDropdown()
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "CVAR_UPDATE" then
        local cvarName, value = ...
        if not cvarName or not value then return end

        -- Update master button
        if cvarName == cvars.Master.toggle then
            if frame.masterMuteBtn then
                frame.masterMuteBtn:SetChecked(value == "1")
            end
        end

        -- Update dropdown if visible
        if self.dropdown and self.dropdown:IsShown() then
            if frame.dropdown.sliders then
                for _, item in ipairs(frame.dropdown.sliders) do
                    if item.cvar == cvarName then
                        local numVal = tonumber(value) or 0
                        item.slider:SetValue(numVal)
                        if item.valueText then
                            item.valueText:SetText(string.format("%d%%", numVal * 100))
                        end
                    end
                end
            end
            if frame.dropdown.checkboxes then
                for _, item in ipairs(frame.dropdown.checkboxes) do
                    if item.cvar == cvarName then
                        item.checkbox:SetChecked(value == "1")
                    end
                end
            end
        end
    end
end)
