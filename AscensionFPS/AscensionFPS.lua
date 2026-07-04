-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: AscensionFPS.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

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
local function getDefaultFPSProfile()
    return {
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
            alpha = 1.0,
            width = 80,
            height = 40,
            bgVisible = true,
            bgColor = { r = 0.02, g = 0.02, b = 0.031, a = 0.85 },
        },
        text = {
            customColor = { r = 1, g = 1, b = 1, a = 1 },
            useClassColor = false,
            font = "Friz Quadrata TT",
            size = 16,
            style = "OUTLINE",
            align = "CENTER",
        },
    }
end

local function validateProfile(profile, defaults)
    if not profile or type(profile) ~= "table" then return defaults end
    for key, defaultVal in pairs(defaults) do
        if profile[key] == nil then
            profile[key] = defaultVal
        elseif type(defaultVal) == "table" and type(profile[key]) == "table" then
            validateProfile(profile[key], defaultVal)
        end
    end
    return profile
end

-- Helper: get font path from LibSharedMedia
local LSM = LibStub("LibSharedMedia-3.0")
local function getFontPath(fontName)
    local path = fontName and LSM:Fetch("font", fontName)
    return path or "Fonts\\FRIZQT__.TTF"
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
    if profile.text.useClassColor then
        local _, class = UnitClass("player")
        local classColor = class and RAID_CLASS_COLORS[class]
        if classColor then
            AscensionFPS.text:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        end
    else
        local c = profile.text.customColor or { r = 1, g = 1, b = 1, a = 1 }
        AscensionFPS.text:SetTextColor(c.r, c.g, c.b, c.a)
    end
end

function AscensionFPS:OnInitialize()
    if private and private.isModuleEnabled and not private:isModuleEnabled("AscensionFPS") then
        self:Disable()
        return
    end
    self:RegisterEvent("PLAYER_LOGIN")
end

function AscensionFPS:createUI()
    -- self.pos read here, after PLAYER_LOGIN (private.positions guaranteed loaded)
    self.pos = private.positions.AscensionFPS

    self.frame = CreateFrame("Frame", "AscensionFPSFrame", UIParent, "BackdropTemplate")
    if not self.frame then return end
    self.frame:SetSize(80, 40)
    self.frame:SetPoint(self.pos.point, UIParent, self.pos.relativePoint, self.pos.x, self.pos.y)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetClampedToScreen(true)
    self.frame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 2,
        insets = { left = 1, right = -1, top = 1, bottom = 1 }
    })
    self.frame:SetBackdropColor(unpack(colors.mainBackground))
    self.frame:SetBackdropBorderColor(unpack(colors.blackDetail
))

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
            local left = f:GetLeft()
            local bottom = f:GetBottom()
            if self.pos and left and bottom then
                local w = f:GetWidth() or 0
                local h = f:GetHeight() or 0
                local screenW = GetScreenWidth() or 1920
                local screenH = GetScreenHeight() or 1080
                
                self.pos.point = "CENTER"
                self.pos.relativePoint = "CENTER"
                self.pos.x = math.floor(left + w/2 - screenW/2 + 0.5)
                self.pos.y = math.floor(bottom + h/2 - screenH/2 + 0.5)
                
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "CENTER", self.pos.x, self.pos.y)
                
                self:updateSliders()
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
    self.frame:SetScript("OnUpdate", function(f, elapsed)
        if f.isDragging then
            local left = f:GetLeft()
            local bottom = f:GetBottom()
            if self.pos and left and bottom then
                local w = f:GetWidth() or 0
                local h = f:GetHeight() or 0
                local screenW = GetScreenWidth() or 1920
                local screenH = GetScreenHeight() or 1080
                
                self.pos.point = "CENTER"
                self.pos.relativePoint = "CENTER"
                self.pos.x = math.floor(left + w/2 - screenW/2 + 0.5)
                self.pos.y = math.floor(bottom + h/2 - screenH/2 + 0.5)
                self:updateSliders()
            end
        end

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
    local bgAlpha = profile.display.alpha or 1.0
    frame:SetBackdropColor(colors.mainBackground[1], colors.mainBackground[2], colors.mainBackground[3], bgAlpha)
    frame:SetBackdropBorderColor(colors.blackDetail[1], colors.blackDetail[2], colors.blackDetail[3], bgAlpha)
    if profile.display.bgVisible then
        bg:Show()
        local c = profile.display.bgColor
        if c then
            bg:SetVertexColor(c.r, c.g, c.b, bgAlpha)
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

            self.alphaSlider = layout:slider(nil, "Alpha", 0.0, 1.0, 0.05,
                function() return self.profile.display.alpha or 1.0 end,
                function(v)
                    self.profile.display.alpha = v
                    refreshDisplay()
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

            self.textSizeSlider = layout:slider(nil, "Text Size", 8, 48, 1,
                function() return self.profile.text.size or 16 end,
                function(v)
                    self.profile.text.size = v
                    refreshDisplay()
                end)

            layout:checkbox(nil, "Use Class Color", nil,
                function() return self.profile.text.useClassColor end,
                function(v)
                    self.profile.text.useClassColor = v
                    refreshDisplay()
                end)

            layout.y = layout.y - 10

            layout:colorPicker(nil, "Text Color", nil,
                function()
                    local c = self.profile.text.customColor or { r = 1, g = 1, b = 1, a = 1 }
                    return c.r, c.g, c.b, c.a
                end,
                function(r, g, b, a)
                    self.profile.text.customColor = { r = r, g = g, b = b, a = a }
                    refreshDisplay()
                end, nil, true)
        end
    )
end

function AscensionFPS:updateSliders()
    if not self.optionsMenu or not self.optionsMenu:IsShown() then return end
    if self.scaleSlider then self.scaleSlider:SetValue(self.profile.display.scale) end
    if self.alphaSlider then self.alphaSlider:SetValue(self.profile.display.alpha or 1.0) end
    if self.xSlider then self.xSlider:SetValue(self.pos.x) end
    if self.ySlider then self.ySlider:SetValue(self.pos.y) end
    if self.textSizeSlider then self.textSizeSlider:SetValue(self.profile.text.size or 16) end
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
        function() self:updateSliders() end,
        function()
            private:resetModule("AscensionFPS")
            self.profile = private.db.profile.modulesData.AscensionFPS
            self.pos = private.positions.AscensionFPS
            refreshDisplay()
            self:updateSliders()
        end
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
        "",
        192,
        self.frame,
        "BOTTOM",
        self.profile.display,
        function(layout, menu)
            local minPct = 33
            local maxPct = 100

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
            else
                local rawMax = tonumber(C_CVar.GetCVar("renderscaleMaxQuality"))
                if rawMax then
                    maxPct = math.floor(rawMax * 100 + 0.5)
                end
            end

            if maxPct < 100 then maxPct = 100 end
            if minPct > maxPct then minPct = maxPct end

            local renderSlider = layout:slider(nil, "Render Scale", minPct, maxPct, 5,
                function()
                    return math.floor((tonumber(C_CVar.GetCVar("renderscale")) or 1.0) * 100 + 0.5)
                end,
                function(v)
                    C_CVar.SetCVar("renderscale", string.format("%.2f", v / 100))
                end)
            if renderSlider and renderSlider.label then
                renderSlider.label:SetTextColor(unpack(self.ctx.styles.colors.gold))
            end

            local fgSlider = layout:slider(nil, "Max Foreground FPS", 10, 200, 5,
                function() return tonumber(C_CVar.GetCVar("maxFPS")) or 100 end,
                function(v) C_CVar.SetCVar("maxFPS", tostring(v)) end)
            if fgSlider and fgSlider.label then
                fgSlider.label:SetTextColor(unpack(self.ctx.styles.colors.gold))
            end

            local bgSlider = layout:slider(nil, "Max Background FPS", 8, 200, 5,
                function() return tonumber(C_CVar.GetCVar("maxFPSBk")) or 30 end,
                function(v) C_CVar.SetCVar("maxFPSBk", tostring(v)) end)
            if bgSlider and bgSlider.label then
                bgSlider.label:SetTextColor(unpack(self.ctx.styles.colors.gold))
            end
        end
    )
end

-- Ventana de configuración (pestañas usando Factory UI)
function AscensionFPS:buildConfigWindow()
    if self.configFrame then return end
    
    local styles = self.ctx.styles
    local colors = styles.colors

    self.configFrame = CreateFrame("Frame", "AscensionFPSConfig", UIParent, "BackdropTemplate")
    if not self.configFrame then return end
    self.configFrame:SetSize(700, 500)
    self.configFrame:SetPoint("CENTER")
    self.configFrame:SetMovable(true)
    self.configFrame:EnableMouse(true)
    self.configFrame:RegisterForDrag("LeftButton")
    self.configFrame:SetScript("OnDragStart", self.configFrame.StartMoving)
    self.configFrame:SetScript("OnDragStop", self.configFrame.StopMovingOrSizing)
    self.configFrame:SetClampedToScreen(true)
    self.configFrame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    self.configFrame:SetBackdropColor(unpack(colors.mainBackground))
    self.configFrame:SetBackdropBorderColor(unpack(colors.surfaceLight))

    -- Título
    local title = self.configFrame:CreateFontString(nil, "OVERLAY", styles.fonts.header)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension FPS Monitor")
    title:SetTextColor(unpack(colors.gold))

    -- Botón cerrar
    local closeBtn = CreateFrame("Button", nil, self.configFrame, "BackdropTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
    })
    closeBtn:SetBackdropColor(unpack(colors.surfaceLight))
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
        self:SetBackdropColor(unpack(colors.surfaceLight))
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
    if self.ctx and self.ctx.createTabbedInterface then
        self.configTabs = self.ctx:createTabbedInterface(self.configFrame, tabNames, buildFuncs, 1)
    end
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
    layout:slider(nil, "Alpha", 0.0, 1.0, 0.05,
        function() return profile.display.alpha or 1.0 end,
        function(v) profile.display.alpha = v; refreshDisplay() end)
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
    self.db = private.db
    self.profile = self.db.profile.modulesData.AscensionFPS
    self.profile = validateProfile(self.profile, getDefaultFPSProfile())
    self.ctx = UIFactory:CreateContext()
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