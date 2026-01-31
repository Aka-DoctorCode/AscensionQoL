-------------------------------------------------------------------------------
-- Project: AscensionSound
-- Author: Aka-DoctorCode 
-- File: AscensionSound.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------

--  INIT & CONSTANTS
local addonName, addon = ...
local frame = CreateFrame("Frame", "AscensionSoundMainFrame", UIParent)

-- Default settings
local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 1.0,
    isExpanded = false
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


--  UTILITY FUNCTIONS
local function UpdateCVar(cvar, value)
    if not cvar then return end
    -- C_CVar.SetCVar requires a string value
    C_CVar.SetCVar(cvar, tostring(value))
end

local function GetCVarNumber(cvar)
    if not cvar then return 0 end
    local val = C_CVar.GetCVar(cvar)
    return tonumber(val) or 0
end

local function GetCVarBool(cvar)
    if not cvar then return false end
    local val = C_CVar.GetCVar(cvar)
    return val == "1"
end


--  UI CREATION
function addon:CreateUI()
    -- Main Container (The small rectangle)
    frame:SetSize(150, 30)
    frame:ClearAllPoints()
    local point = AscensionSoundDB.point or "CENTER"
    local relativePoint = AscensionSoundDB.relativePoint or "CENTER"
    local x = AscensionSoundDB.x or 0
    local y = AscensionSoundDB.y or 0
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetClampedToScreen(true) -- Prevents the frame from going off-screen

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        AscensionSoundDB.point = point
        AscensionSoundDB.relativePoint = relativePoint
        AscensionSoundDB.x = x
        AscensionSoundDB.y = y
    end)

    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0, 0, 0, 0.8)

    -- Master Mute Button (Toggle)
    local masterMuteBtn = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    masterMuteBtn:SetSize(26, 26)
    masterMuteBtn:SetHitRectInsets(0, 0, 0, 0)
    masterMuteBtn:SetPoint("LEFT", frame, "LEFT", 5, 0)
    masterMuteBtn.tooltip = "Master Mute"
    masterMuteBtn:SetScript("OnClick", function(self)
        local isEnabled = self:GetChecked()
        UpdateCVar(cvars.Master.toggle, isEnabled and "1" or "0")
    end)
    -- Sync initial state
    masterMuteBtn:SetChecked(GetCVarBool(cvars.Master.toggle))
    frame.masterMuteBtn = masterMuteBtn

    -- Decrease Volume Button (-)
    local decBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    decBtn:SetSize(25, 25)
    decBtn:SetPoint("LEFT", masterMuteBtn, "RIGHT", 5, 0)
    decBtn:SetText("-")
    decBtn:SetScript("OnClick", function()
        local current = GetCVarNumber(cvars.Master.volume)
        local newVol = math.max(0, current - 0.1)
        UpdateCVar(cvars.Master.volume, newVol)
    end)

    -- Increase Volume Button (+)
    local incBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    incBtn:SetSize(25, 25)
    incBtn:SetPoint("LEFT", decBtn, "RIGHT", 5, 0)
    incBtn:SetText("+")
    incBtn:SetScript("OnClick", function()
        local current = GetCVarNumber(cvars.Master.volume)
        local newVol = math.min(1, current + 0.1)
        UpdateCVar(cvars.Master.volume, newVol)
    end)

    -- Expand/Dropdown Button
    local expandBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    expandBtn:SetSize(40, 25)
    expandBtn:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
    expandBtn:SetText("Vol")
    expandBtn:SetScript("OnClick", function()
        addon:ToggleDropdown()
    end)

    -- Dropdown Container (Initially Hidden)
    local dropdown = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    dropdown:SetSize(120, 280)
    dropdown:SetPoint("TOP", frame, "BOTTOM", 0, -5)
    dropdown:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    dropdown:Hide()
    frame.dropdown = dropdown

    -- Create Sliders for each channel
    local startY = -15
    for _, type in ipairs(sliderOrder) do
        local data = cvars[type]
        if data then
            addon:CreateSliderControl(dropdown, type, data, startY)
            startY = startY - 50
        end
    end
end

function addon:CreateSliderControl(parent, labelText, cvarData, yOffset)
    if not parent or not cvarData then return end

    -- 1. Label (Centered at the top of the row)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", parent, "TOP", 0, yOffset)
    label:SetText(labelText)

    -- 2. Checkbox (Placed to the LEFT of the Label)
    local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    cb:SetSize(20, 20) -- Small compact size
    cb:SetHitRectInsets(0, 0, 0, 0) -- Fix click area
    cb:SetPoint("RIGHT", label, "LEFT", -2, 0) -- Attached to the left of the text
    
    cb:SetScript("OnClick", function(self)
        local isEnabled = self:GetChecked()
        UpdateCVar(cvarData.toggle, isEnabled and "1" or "0")
    end)
    cb:SetScript("OnShow", function(self)
        self:SetChecked(GetCVarBool(cvarData.toggle))
    end)

    -- 3. Slider (Centered below label, 90% width)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOP", label, "BOTTOM", 0, -8) -- 8px below the label
    slider:SetWidth(100)
    slider:SetHeight(17)
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    
    slider:SetScript("OnValueChanged", function(self, value)
        UpdateCVar(cvarData.volume, value)
    end)

    slider:SetScript("OnShow", function(self)
        self:SetValue(GetCVarNumber(cvarData.volume))
    end)
end

function addon:ToggleDropdown()
    if not frame.dropdown then return end
    
    if frame.dropdown:IsShown() then
        frame.dropdown:Hide()
        AscensionSoundDB.isExpanded = false
    else
        frame.dropdown:Show()
        AscensionSoundDB.isExpanded = true
    end
end


--  EVENT HANDLING
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not AscensionSoundDB then AscensionSoundDB = defaults end
        addon:CreateUI()
        
        -- Restore dropdown state if desired, or keep closed by default
        if AscensionSoundDB.isExpanded then
            addon:ToggleDropdown()
        end
    end
end)