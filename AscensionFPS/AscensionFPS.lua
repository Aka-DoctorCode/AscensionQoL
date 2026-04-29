-------------------------------------------------------------------------------
-- Project: AscensionFPS
-- Author: Aka-DoctorCode
-- File: AscensionFPS.lua
-- Version: @project-version@
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------

local addonName, private = ...
local MAJOR, MINOR = "AscensionFPS", 1
local AceAddon = LibStub("AceAddon-3.0")
local AscensionFPS = AceAddon:NewAddon(MAJOR, "AceEvent-3.0", "AceConsole-3.0")

-- Factory UI library
local UIFactory = LibStub("AscensionSuit-UI")
if not UIFactory then
    error("AscensionFPS requires AscensionSuit-UI library (Factory.lua)")
end

local styles = UIFactory.DefaultStyles
local colors = styles.colors
local _, playerClass = UnitClass("player")

-- Default profile settings (solo offset x,y desde el centro)
local defaults = {
    profile = {
        general = {
            enabled = true,
            updateInterval = 0.5,
            customText = "FPS: ",
            customTextBefore = true,
            useCustomText = false,
        },
        display = {
            locked = false,
            x = 0,
            y = -200,
            scale = 1.0,
            width = 80,
            height = 40,
            bgVisible = true,
            bgColor = { r = 0.02, g = 0.02, b = 0.031, a = 0.85 },
        },
        text = {
            customColor = { r = 1, g = 1, b = 1, a = 1 },
            font = "Friz Quadrata TT",
            size = 16,
            style = "OUTLINE",
            align = "CENTER",
        },
    },
}

-- Helper: get font path from LibSharedMedia
local LSM = LibStub("LibSharedMedia-3.0")
local function getFontPath(fontName)
    if not fontName then return nil end
    return LSM:Fetch("font", fontName)
end

-- Helper: format FPS with custom text
local function formatFPS()
    local fps = GetFramerate() or 0
    local fpsInt = math.floor(fps + 0.5)
    if not AscensionFPS.profile then return tostring(fpsInt) end
    local profile = AscensionFPS.profile
    local custom = profile.general.customText or ""
    if profile.general.useCustomText then
        if profile.general.customTextBefore then
            return custom .. fpsInt
        else
            return fpsInt .. custom
        end
    else
        return tostring(fpsInt)
    end
end

-- Apply current text color (class or custom)
local function applyTextColor()
    if not AscensionFPS.profile or not AscensionFPS.text then return end
    local profile = AscensionFPS.profile
    local c = profile.text.customColor
    if c then
        AscensionFPS.text:SetTextColor(c.r, c.g, c.b, c.a)
    end
end

function AscensionFPS:OnInitialize()
    if private and private.isModuleEnabled and not private:isModuleEnabled("AscensionFPS") then
        self:Disable()
        return
    end

    self.db = private.db
    self.profile = self.db.profile.modulesData.AscensionFPS
    self.ctx = UIFactory:CreateContext()

    self:RegisterEvent("PLAYER_LOGIN")
end

function AscensionFPS:createUI()
    -- self.pos read here, after PLAYER_LOGIN (private.positions guaranteed loaded)
    self.pos = private.positions.AscensionFPS

    self.frame = CreateFrame("Frame", "AscensionFPSFrame", UIParent, "BackdropTemplate")
    self.frame:SetSize(80, 40)
    self.frame:SetPoint(self.pos.point, UIParent, self.pos.relativePoint, self.pos.x, self.pos.y)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetClampedToScreen(true)
    self.frame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    self.frame:SetBackdropColor(unpack(colors.backgroundDark))
    self.frame:SetBackdropBorderColor(unpack(colors.surfaceHighlight))

    self.bgTexture = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bgTexture:SetAllPoints()
    self.bgTexture:SetColorTexture(0, 0, 0, 0)

    self.text = self.frame:CreateFontString(nil, "OVERLAY", styles.fonts.label)
    self.text:SetPoint("CENTER")
    self.text:SetJustifyH("CENTER")

    self.frame:SetScript("OnDragStart", function(f)
        if self.profile and not self.profile.display.locked then
            f.isDragging = true
            f:StartMoving()
        end
    end)
    self.frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        f.isDragging = false
        C_Timer.After(0, function()
            local point, _, relativePoint, x, y = f:GetPoint()
            if self.pos and point then
                self.pos.point = point
                self.pos.relativePoint = relativePoint
                self.pos.x = x
                self.pos.y = y
            end
        end)
    end)

    self.frame:SetScript("OnMouseDown", function(_, btn)
        if btn == "RightButton" then AscensionFPS:showContextMenu() end
    end)
    self.frame:SetScript("OnMouseUp", function(f, btn)
        if btn == "LeftButton" and not f.isDragging then
            AscensionFPS:showRenderScaleMenu()
        end
    end)

    local lastUpdate = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        if not self.profile or not self.profile.general.enabled then return end
        lastUpdate = lastUpdate + elapsed
        if lastUpdate >= (self.profile.general.updateInterval or 0.5) then
            lastUpdate = 0
            if self.text then
                self.text:SetText(formatFPS())
                local newWidth = (self.text:GetStringWidth() or 0) + 16
                if (self.profile.display.width or 0) < newWidth then
                    self.profile.display.width = newWidth
                    self.frame:SetWidth(newWidth)
                end
            end
        end
    end)
end

-- Refresh display: position, scale, size, font (siempre desde CENTER)
local function refreshDisplay()
    local profile = AscensionFPS.profile
    local frame = AscensionFPS.frame
    local text = AscensionFPS.text
    local bg = AscensionFPS.bgTexture

    if not profile or not frame or not text or not bg then return end

    -- Position and scale
    frame:ClearAllPoints()
    frame:SetPoint(AscensionFPS.pos.point, UIParent, AscensionFPS.pos.relativePoint, AscensionFPS.pos.x, AscensionFPS.pos.y)
    frame:SetScale(profile.display.scale or 1.0)
    frame:SetMovable(not profile.display.locked)
    frame:EnableMouse(not profile.display.locked)

    -- Tamaño del frame
    frame:SetSize(profile.display.width or 80, profile.display.height or 40)
    bg:SetAllPoints(frame)

    -- Fondo
    if profile.display.bgVisible then
        bg:Show()
        local c = profile.display.bgColor
        if c then
            bg:SetVertexColor(c.r, c.g, c.b, c.a)
        end
    else
        bg:Hide()
    end

    -- Fuente
    local fontPath = getFontPath(profile.text.font)
    if fontPath then
        text:SetFont(fontPath, profile.text.size or 16, profile.text.style or "OUTLINE")
    end
    text:SetJustifyH(profile.text.align or "CENTER")
    text:ClearAllPoints()
    if profile.text.align == "LEFT" then
        text:SetPoint("LEFT", frame, "LEFT", 8, 0)
    elseif profile.text.align == "RIGHT" then
        text:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    else
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    -- Auto‑ajuste de ancho mínimo
    local minWidth = (text:GetStringWidth() or 0) + 16
    if (profile.display.width or 0) < minWidth then
        profile.display.width = minWidth
        frame:SetWidth(minWidth)
    end

    applyTextColor()
    text:SetText(formatFPS())

    if profile.general.enabled then
        frame:Show()
    else
        frame:Hide()
    end
end

-------------------------------------------------------------------------------
-- OPTIONS MENU (Second level)
-------------------------------------------------------------------------------
function AscensionFPS:showOptionsMenu(parentFrame)
    if self.optionsMenu and self.optionsMenu:IsShown() then
        self.optionsMenu:Hide()
        return
    end

    -- Open main config frame first
    if private.showConfigFrame then private.showConfigFrame() end
    local aqolFrame = _G["AscensionQoLConfigFrame"]

    self.optionsMenu = private:createSmartMenu(
        self.ctx,
        "FPS Module Options",
        280,
        aqolFrame,
        "RIGHT",
        self.profile.display,
        function(layout, menu)
            self.scaleSlider = layout:slider(nil, "Scale", 0.5, 2.0, 0.1,
                function() return self.profile.display.scale end,
                function(v)
                    self.profile.display.scale = v
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

function AscensionFPS:updateSliders()
    if not self.optionsMenu or not self.optionsMenu:IsShown() then return end
    if self.scaleSlider then self.scaleSlider:SetValue(self.profile.display.scale) end
    if self.xSlider then self.xSlider:SetValue(self.pos.x) end
    if self.ySlider then self.ySlider:SetValue(self.pos.y) end
end

-- Menú contextual (clic derecho)
function AscensionFPS:showContextMenu()
    if not self.profile or not self.ctx then return end

    private:createContextMenu(
        self.ctx,
        self.frame,
        self.profile.display,
        self.pos,
        { point = "CENTER", relativePoint = "CENTER", x = 0, y = -200 },
        function() self:showOptionsMenu() end,
        function() self:updateSliders() end
    )
end

-- Render Scale Menu (Clic Izquierdo)
function AscensionFPS:showRenderScaleMenu()
    if self.renderMenu and self.renderMenu:IsShown() then
        self.renderMenu:Hide()
        return
    end

    if not self.profile or not self.ctx then return end

    self.renderMenu = private:createSmartMenu(
        self.ctx,
        "Render Scale",
        250,
        self.frame,
        "BOTTOM",
        self.profile.display,
        function(layout, menu)
            local minPct = 33
            local maxPct = 200

            if Settings and Settings.GetSetting then
                local setting = Settings.GetSetting("PROXY_RENDERSCALE") or Settings.GetSetting("Graphics_RenderScale")
                if setting and setting.GetMinValue and setting.GetMaxValue then
                    local sMin = setting:GetMinValue()
                    local sMax = setting:GetMaxValue()
                    if sMin and sMax then
                        minPct = math.floor(sMin * 100 + 0.5)
                        maxPct = math.floor(sMax * 100 + 0.5)
                    end
                end
            end

            if maxPct == 200 then
                local rawMax = tonumber(C_CVar.GetCVar("renderscaleMaxQuality"))
                if rawMax then
                    maxPct = math.floor(rawMax * 100 + 0.5)
                end
            end

            if minPct > maxPct then minPct = maxPct end

            layout:slider(nil, "Render Scale  (" .. minPct .. "% = Min  |  100% = Native  |  " .. maxPct .. "% = Max)", minPct, maxPct, 5,
                function()
                    return math.floor((tonumber(C_CVar.GetCVar("renderscale")) or 1.0) * 100 + 0.5)
                end,
                function(v)
                    C_CVar.SetCVar("renderscale", string.format("%.2f", v / 100))
                end)
        end
    )
end

-- Ventana de configuración (pestañas usando Factory UI)
function AscensionFPS:buildConfigWindow()
    if self.configFrame then return end
    
    local styles = self.ctx.styles
    local colors = styles.colors

    self.configFrame = CreateFrame("Frame", "AscensionFPSConfig", UIParent, "BackdropTemplate")
    self.configFrame:SetSize(700, 500)
    self.configFrame:SetPoint("CENTER")
    self.configFrame:SetMovable(true)
    self.configFrame:EnableMouse(true)
    self.configFrame:RegisterForDrag("LeftButton")
    self.configFrame:SetScript("OnDragStart", self.configFrame.StartMoving)
    self.configFrame:SetScript("OnDragStop", self.configFrame.StopMovingOrSizing)
    self.configFrame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    self.configFrame:SetBackdropColor(unpack(colors.backgroundDark))
    self.configFrame:SetBackdropBorderColor(unpack(colors.surfaceHighlight))

    -- Título
    local title = self.configFrame:CreateFontString(nil, "OVERLAY", styles.fonts.header)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension FPS Monitor")
    title:SetTextColor(unpack(colors.gold))

    -- Botón cerrar
    local closeBtn = CreateFrame("Button", nil, self.configFrame, "BackdropTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -16, -16)
    closeBtn:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(unpack(colors.surfaceHighlight))
    closeBtn:SetBackdropBorderColor(unpack(colors.blackDetail))
    local xLine1 = closeBtn:CreateTexture(nil, "OVERLAY")
    xLine1:SetTexture(styles.textures.bar)
    xLine1:SetSize(13, 2)
    xLine1:SetPoint("CENTER", 0, 0)
    xLine1:SetRotation(math.rad(45))
    xLine1:SetVertexColor(unpack(colors.textLight))
    local xLine2 = closeBtn:CreateTexture(nil, "OVERLAY")
    xLine2:SetTexture(styles.textures.bar)
    xLine2:SetSize(13, 2)
    xLine2:SetPoint("CENTER", 0, 0)
    xLine2:SetRotation(math.rad(-45))
    xLine2:SetVertexColor(unpack(colors.textLight))
    closeBtn:SetScript("OnClick", function() self.configFrame:Hide() end)
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.6, 0.1, 0.1, 1)
        xLine1:SetVertexColor(1, 0.4, 0.4)
        xLine2:SetVertexColor(1, 0.4, 0.4)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(colors.surfaceHighlight))
        xLine1:SetVertexColor(unpack(colors.textLight))
        xLine2:SetVertexColor(unpack(colors.textLight))
    end)

    -- Pestañas
    local tabNames = { "General", "Display", "Text" }
    local buildFuncs = {
        function(panel) self:buildGeneralTab(panel) end,
        function(panel) self:buildDisplayTab(panel) end,
        function(panel) self:buildTextTab(panel) end,
    }
    self.configTabs = self.ctx:createTabbedInterface(self.configFrame, tabNames, buildFuncs, 1)
    self.configFrame:Hide()
end

function AscensionFPS:buildGeneralTab(panel)
    local layout = self.ctx.layoutModel:reset(panel.content, -15)
    local profile = self.profile

    layout:header(nil, "General Settings")
    layout:checkbox(nil, "Enable FPS display", nil,
        function() return profile.general.enabled end,
        function(v) profile.general.enabled = v; refreshDisplay() end)
    layout:checkbox(nil, "Lock position", nil,
        function() return profile.display.locked end,
        function(v) profile.display.locked = v; refreshDisplay() end)
    layout:slider(nil, "Update interval (seconds)", 0.1, 10, 0.1,
        function() return profile.general.updateInterval end,
        function(v) profile.general.updateInterval = v end, 200)

    layout:header(nil, "Custom Text")
    layout:checkbox(nil, "Use custom text", nil,
        function() return profile.general.useCustomText end,
        function(v) profile.general.useCustomText = v; refreshDisplay() end)
    layout:input(nil, "Custom text", 200, nil, function(v) profile.general.customText = v; refreshDisplay() end)
    layout:checkbox(nil, "Place text before FPS", nil,
        function() return profile.general.customTextBefore end,
        function(v) profile.general.customTextBefore = v; refreshDisplay() end)

    panel.content:SetHeight(math.abs(layout.y) + 30)
end

function AscensionFPS:buildDisplayTab(panel)
    local layout = self.ctx.layoutModel:reset(panel.content, -15)
    local profile = self.profile

    layout:header(nil, "Frame Appearance")
    layout:checkbox(nil, "Show background", nil,
        function() return profile.display.bgVisible end,
        function(v) profile.display.bgVisible = v; refreshDisplay() end)
    layout:slider(nil, "Width", 40, 300, 1,
        function() return profile.display.width end,
        function(v) profile.display.width = v; refreshDisplay() end)
    layout:slider(nil, "Height", 20, 100, 1,
        function() return profile.display.height end,
        function(v) profile.display.height = v; refreshDisplay() end)
    layout:colorPicker(nil, "Background color", nil,
        function() return profile.display.bgColor.r, profile.display.bgColor.g, profile.display.bgColor.b, profile.display.bgColor.a end,
        function(r, g, b, a)
            profile.display.bgColor = { r = r, g = g, b = b, a = a }
            refreshDisplay()
        end, nil, true)

    panel.content:SetHeight(math.abs(layout.y) + 30)
end

function AscensionFPS:buildTextTab(panel)
    local layout = self.ctx.layoutModel:reset(panel.content, -15)
    local profile = self.profile

    layout:header(nil, "Font & Color")
    layout:checkbox(nil, "Use class color", nil,
        function() return profile.text.useClassColor end,
        function(v) profile.text.useClassColor = v; refreshDisplay() end)
    layout:colorPicker(nil, "Custom text color", nil,
        function() return profile.text.customColor.r, profile.text.customColor.g, profile.text.customColor.b, profile.text.customColor.a end,
        function(r, g, b, a)
            profile.text.customColor = { r = r, g = g, b = b, a = a }
            refreshDisplay()
        end, nil, true)

    -- Selección de fuente mediante LSM
    local fontOptions = {}
    local fonts = LSM:HashTable("font")
    if fonts then
        for k in pairs(fonts) do
            table.insert(fontOptions, { label = k, value = k })
        end
    end
    layout:dropdown(nil, "Font", fontOptions,
        function() return profile.text.font end,
        function(v) profile.text.font = v; refreshDisplay() end, 200)

    layout:slider(nil, "Font size", 8, 40, 1,
        function() return profile.text.size end,
        function(v) profile.text.size = v; refreshDisplay() end)
    layout:dropdown(nil, "Font style", {
        { label = "None", value = "NONE" },
        { label = "Outline", value = "OUTLINE" },
        { label = "Thick Outline", value = "THICKOUTLINE" },
        { label = "Monochrome", value = "MONOCHROME" },
    }, function() return profile.text.style end,
        function(v) profile.text.style = v; refreshDisplay() end)
    layout:dropdown(nil, "Alignment", {
        { label = "Left", value = "LEFT" },
        { label = "Center", value = "CENTER" },
        { label = "Right", value = "RIGHT" },
    }, function() return profile.text.align end,
        function(v) profile.text.align = v; refreshDisplay() end)

    panel.content:SetHeight(math.abs(layout.y) + 30)
end

function AscensionFPS:toggleConfig()
    if not self.configFrame then self:buildConfigWindow() end
    if not self.configFrame then return end
    if self.configFrame:IsShown() then
        self.configFrame:Hide()
    else
        self.configFrame:Show()
    end
end

function AscensionFPS:PLAYER_LOGIN()
    self:createUI()
    refreshDisplay()
    self:RegisterChatCommand("fps", function(cmd)
        if cmd == "config" then
            self:toggleConfig()
        elseif cmd == "" then
            if self.profile then
                self.profile.general.enabled = not self.profile.general.enabled
                refreshDisplay()
                self:Print(self.profile.general.enabled and "Enabled" or "Disabled")
            end
        else
            self:Print("Usage: /fps - toggle on/off | /fps config - open settings")
        end
    end)
end

function AscensionFPS:OnDisable()
    if self.frame then self.frame:Hide() end
    if self.configFrame then self.configFrame:Hide() end
end