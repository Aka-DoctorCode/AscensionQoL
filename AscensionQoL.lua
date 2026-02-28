-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: AscensionQoL.lua
-- Version: 02
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------

local addonName, private = ...

-- Global variables for UI components
local configFrame = nil

local COLORS = {
    primary           = { 0.498, 0.075, 0.925, 1.0 },  -- #7f13ec
    gold              = { 1.000, 0.800, 0.200, 1.0 },  -- #ffcc33
    background_dark   = { 0.020, 0.020, 0.031, 0.95 }, -- #050508
    surface_dark      = { 0.047, 0.039, 0.082, 1.0 },  -- #0c0a15
    surface_highlight = { 0.165, 0.141, 0.239, 1.0 },  -- #2a243d
    black_detail      = { 0.0, 0.0, 0.0, 1.0 },        -- #000000
    white_detail      = { 1, 1, 1, 1 },                -- #ffffff
    text_light        = { 0.886, 0.910, 0.941, 1.0 },  -- #e2e8f0
    text_dim          = { 0.580, 0.640, 0.720, 1.0 },  -- #9ca3af
}

local FILES = {
    bgfile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgefile = "Interface\\Tooltips\\UI-Tooltip-Border",
}

-- Default DB Structure
local defaults = {
    modules = {
        ["AscensionSound"] = true,
    },
}

-------------------------------------------------------------------------------
-- DB Management
-------------------------------------------------------------------------------
local function InitializeDB()
    if not AscensionQoLDB then
        AscensionQoLDB = {}
    end
    -- Shallow merge defaults
    for k, v in pairs(defaults) do
        if AscensionQoLDB[k] == nil then
            AscensionQoLDB[k] = v
        elseif type(v) == "table" and type(AscensionQoLDB[k]) == "table" then
            for subK, subV in pairs(v) do
                if AscensionQoLDB[k][subK] == nil then
                    AscensionQoLDB[k][subK] = subV
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- UI Helper Functions
-------------------------------------------------------------------------------
local function CreateHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    header:SetPoint("TOPLEFT", 15, yOffset)
    header:SetText(text)
    header:SetTextColor(unpack(COLORS.gold))

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    divider:SetPoint("RIGHT", parent, "RIGHT", -5, 0)
    divider:SetColorTexture(unpack(COLORS.surface_highlight))

    return header, yOffset - 35
end

local function CreateCheckbox(parent, text, getter, setter, yOffset)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 15, yOffset)
    cb:SetSize(28, 28)

    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText(text)
    cb.text:SetTextColor(unpack(COLORS.text_light))

    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)

    return cb, yOffset - 40
end

-------------------------------------------------------------------------------
-- Main Frame Creation
-------------------------------------------------------------------------------
local function ShowConfigFrame()
    if configFrame then
        configFrame:Show()
        return
    end

    configFrame = CreateFrame("Frame", "AscensionQoLConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(400, 300)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetFrameStrata("HIGH")

    configFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    configFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    configFrame:SetBackdrop({
        bgFile = FILES.bgfile,
        edgeFile = FILES.edgefile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    configFrame:SetBackdropColor(unpack(COLORS.background_dark))
    configFrame:SetBackdropBorderColor(unpack(COLORS.surface_highlight))

    -- Header Title
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Ascension QoL")
    title:SetTextColor(unpack(COLORS.gold))

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

    -- Content 영역
    local curY = -50
    local _, curY = CreateHeader(configFrame, "Modules", curY)

    _, curY = CreateCheckbox(configFrame, "Enable Ascension Sound",
        function() return AscensionQoLDB.modules["AscensionSound"] end,
        function(v)
            AscensionQoLDB.modules["AscensionSound"] = v
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionSound|r " ..
                (v and "enabled" or "disabled") .. " (Reload UI required).")
        end,
        curY)

    -- Help text at bottom
    local help = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("BOTTOM", 0, 15)
    help:SetText("Changes to modules require /reload to take effect.")
    help:SetTextColor(unpack(COLORS.text_dim))

    configFrame:Show()
end

-------------------------------------------------------------------------------
-- Module Interface (for AscensionSound and others)
-------------------------------------------------------------------------------
function private:IsModuleEnabled(moduleName)
    if not AscensionQoLDB or not AscensionQoLDB.modules then return true end
    return AscensionQoLDB.modules[moduleName] ~= false
end

-------------------------------------------------------------------------------
-- Initialization & Events
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDB()

        -- Slash commands
        SLASH_AQOL1 = "/aqol"
        SLASH_AQOL2 = "/ascensionqol"
        SlashCmdList["AQOL"] = function()
            ShowConfigFrame()
        end

        print("|cff7f13ecAscension QoL|r initialized. Use /aqol for settings.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
