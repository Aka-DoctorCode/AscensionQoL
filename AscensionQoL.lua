-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: AscensionQoL.lua
-- Version: @project-version@
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, private = ...

-- Get Factory UI library
local UIFactory = LibStub("AscensionSuit-UI")
if not UIFactory then
    error("AscensionQoL requires AscensionSuit-UI library (Factory.lua)")
end

-- Global variables for UI components
local configFrame = nil
local optionsMenu = nil

-- Default DB Structure
local defaults = {
    profile = {
        general = {
            scale = 1.0,
        },
        modules = {
            ["AscensionSound"] = true,
            ["AscensionFPS"] = true,
        },
        modulesData = {
            AscensionSound = {
                scale = 1.0,
                locked = false,
                isExpanded = false,
            },
            AscensionFPS = {
                general = {
                    enabled = true,
                    updateInterval = 0.5,
                    customText = "FPS: ",
                    customTextBefore = true,
                    useCustomText = false,
                },
                display = {
                    scale = 1.0,
                    locked = false,
                    width = 80,
                    height = 40,
                    bgVisible = true,
                    bgColor = { r = 0.02, g = 0.02, b = 0.031, a = 0.85 },
                },
                text = {
                    useClassColor = true,
                    color = { r = 1, g = 0.8, b = 0.2, a = 1},
                    size = 16,
                    font = "Friz Quadrata TT",
                    style = "OUTLINE",
                }
            }
        }
    }
}

-------------------------------------------------------------------------------
-- DB Management
-------------------------------------------------------------------------------
local function initializeDB()
    private.db = LibStub("AceDB-3.0"):New("AscensionQoLDB", defaults, "Default")
end

local function showConfigFrame()
    if configFrame then
        configFrame:Show()
        return
    end

    local ctx = UIFactory:CreateContext()
    local styles = ctx.styles
    local colors = styles.colors
    local profile = private.db.profile
    local pos = private.positions.configFrame

    configFrame = CreateFrame("Frame", "AscensionQoLConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(450, 400)
    configFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    configFrame:SetScale(profile.general.scale)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetFrameStrata("HIGH")

    configFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    configFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        C_Timer.After(0, function()
            local point, _, relativePoint, x, y = self:GetPoint()
            local pos = private.positions.configFrame
            if pos and point then
                pos.point = point
                pos.relativePoint = relativePoint
                pos.x = x
                pos.y = y
            end
        end)
    end)

    configFrame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    configFrame:SetBackdropColor(unpack(colors.backgroundDark))
    configFrame:SetBackdropBorderColor(unpack(colors.surfaceHighlight))

    -- Header Title
    local title = configFrame:CreateFontString(nil, "OVERLAY", styles.fonts.header)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension QoL")
    title:SetTextColor(unpack(colors.gold))

    -- Close Button (Factory style)
    local closeBtn = ctx:createCloseButton(configFrame, function() configFrame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)

    -- Content Frame (No Scroll)
    local content = CreateFrame("Frame", nil, configFrame)
    content:SetPoint("TOPLEFT", 10, -50)
    content:SetPoint("BOTTOMRIGHT", -10, 60)

    -- Layout Model for automatic positioning
    local layout = ctx.layoutModel:reset(content, -10)

    layout:header(nil, "Modules")

    layout:checkbox(nil, "Enable Ascension Sound",
        "Control master volume and channels with a compact UI.",
        function() return profile.modules["AscensionSound"] end,
        function(v)
            profile.modules["AscensionSound"] = v
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionSound|r " ..
                (v and "enabled" or "disabled") .. " (Reload UI required).")
        end)

    layout:checkbox(nil, "Enable Ascension FPS",
        "Monitor your framerate with a customizable display.",
        function() return profile.modules["AscensionFPS"] end,
        function(v)
            profile.modules["AscensionFPS"] = v
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionFPS|r " ..
                (v and "enabled" or "disabled") .. " (Reload UI required).")
        end)

    -- Reload UI Button
    layout:button(nil, "Reload UI", "Apply changes by reloading the interface.", 140, 28, 140, function()
        ReloadUI()
    end)

    -- Help text at bottom
    local help = configFrame:CreateFontString(nil, "OVERLAY", styles.fonts.desc)
    help:SetPoint("BOTTOM", 0, 15)
    help:SetText("Changes to modules require /reload to take effect.")
    help:SetTextColor(unpack(colors.gold))

    configFrame:Show()
end

-- Export global showConfig for modules
private.showConfigFrame = showConfigFrame

-------------------------------------------------------------------------------
-- Module Interface (for AscensionSound and others)
-------------------------------------------------------------------------------
function private:isModuleEnabled(moduleName)
    if not private.db or not private.db.profile.modules then return true end
    return private.db.profile.modules[moduleName] ~= false
end

function private:createContextMenu(ctx, moduleFrame, profile, pos, defaultPos, optionsCallback, updateSlidersCallback)
    if moduleFrame.contextMenu and moduleFrame.contextMenu:IsShown() then
        moduleFrame.contextMenu:Hide()
        return
    end

    local styles = ctx.styles
    local colors = styles.colors

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    local btnHeight = 28
    local spacing = 10
    local numButtons = 3
    local totalHeight = (numButtons * btnHeight) + ((numButtons + 1) * spacing)
    
    menu:SetSize(190, totalHeight)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetScale(profile.scale or 1.0)
    menu:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
    })
    menu:SetBackdropColor(unpack(colors.surfaceDark))
    menu:SetBackdropBorderColor(unpack(colors.surfaceHighlight))
    menu:SetPoint("TOP", moduleFrame, "BOTTOM", 0, -5)
    menu:Show()

    local lockBtn = ctx:createButton({
        parent = menu,
        text = profile.locked and "Unlock" or "Lock",
        width = 170, height = btnHeight,
        xOffset = 10, yOffset = -spacing,
        onClick = function()
            profile.locked = not profile.locked
            if moduleFrame.SetMovable then
                moduleFrame:SetMovable(not profile.locked)
            end
            menu:Hide()
        end,
    })

    local optBtn = ctx:createButton({
        parent = menu,
        text = "Options",
        width = 170, height = btnHeight,
        xOffset = 10, yOffset = -(spacing * 2 + btnHeight),
        onClick = function()
            menu:Hide()
            if optionsCallback then optionsCallback() end
        end,
    })

    local resetBtn = ctx:createButton({
        parent = menu,
        text = "Reset position",
        width = 170, height = btnHeight,
        xOffset = 10, yOffset = -(spacing * 3 + btnHeight * 2),
        onClick = function()
            pos.point = defaultPos.point or "CENTER"
            pos.relativePoint = defaultPos.relativePoint or "CENTER"
            pos.x = defaultPos.x or 0
            pos.y = defaultPos.y or 0
            moduleFrame:ClearAllPoints()
            moduleFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
            if updateSlidersCallback then updateSlidersCallback() end
            menu:Hide()
        end,
    })

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints()
    closer:SetFrameStrata("BACKGROUND")
    closer:SetFrameLevel(1)
    closer:SetScript("OnClick", function() menu:Hide() end)
    closer:Show()

    menu:SetScript("OnHide", function()
        closer:Hide()
        moduleFrame.contextMenu = nil
    end)
    moduleFrame.contextMenu = menu
end

function private:createSmartMenu(ctx, title, width, anchorFrame, anchorPoint, profile, buildFunc)
    local styles = ctx.styles
    local colors = styles.colors

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetWidth(width)
    menu:SetFrameStrata("DIALOG")
    if profile and profile.scale then
        menu:SetScale(profile.scale)
    end
    menu:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    menu:SetBackdropColor(unpack(colors.backgroundDark))
    menu:SetBackdropBorderColor(unpack(colors.surfaceHighlight))

    local content = CreateFrame("Frame", nil, menu)
    content:SetSize(width, 10)

    local layout = ctx.layoutModel:reset(content, -20)
    layout:header(nil, title)

    buildFunc(layout, menu)

    local contentHeight = math.abs(layout.y) + 20
    local maxHeight = 400

    if contentHeight > maxHeight then
        menu:SetHeight(maxHeight)
        local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
        
        content:SetParent(scrollFrame)
        content:ClearAllPoints()
        content:SetSize(width - 40, contentHeight)
        scrollFrame:SetScrollChild(content)
    else
        menu:SetHeight(contentHeight)
        content:SetPoint("TOPLEFT", 0, 0)
        content:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    local closeBtn = ctx:createCloseButton(menu, function() menu:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)

    if anchorPoint == "RIGHT" and anchorFrame then
        menu:SetPoint("LEFT", anchorFrame, "RIGHT", 10, 0)
    elseif anchorPoint == "BOTTOM" and anchorFrame then
        menu:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -5)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    end

    menu:Show()
    return menu
end

-------------------------------------------------------------------------------
-- Initialization & Events
-------------------------------------------------------------------------------
local function initPositions()
    if not AscensionQoLPositions then
        AscensionQoLPositions = {}
    end
    local p = AscensionQoLPositions
    if not p.configFrame then p.configFrame = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 } end
    if not p.AscensionSound then p.AscensionSound = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 } end
    if not p.AscensionFPS then p.AscensionFPS = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -200 } end
    private.positions = AscensionQoLPositions
end

initializeDB()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        -- SavedVariables are guaranteed loaded by PLAYER_LOGIN
        initPositions()
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        if not private.db then initializeDB() end

        -- Slash commands
        SLASH_AQOL1 = "/aqol"
        SLASH_AQOL2 = "/ascensionqol"
        SlashCmdList["AQOL"] = function(cmd)
            if cmd == "debug" then
                if not private.db then print("AscensionQoL: DB is nil!"); return end
                local pos = private.positions
                print("|cff7f13ecAscensionQoL DB Debug:|r")
                print("  Config frame: x="..tostring(pos.configFrame.x).." y="..tostring(pos.configFrame.y))
                print("  AscensionSound: x="..tostring(pos.AscensionSound.x).." y="..tostring(pos.AscensionSound.y))
                print("  AscensionFPS: x="..tostring(pos.AscensionFPS.x).." y="..tostring(pos.AscensionFPS.y))
            else
                showConfigFrame()
            end
        end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

