-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: AscensionAFK.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, private = ...
local MAJOR = "AscensionAFK"
local AceAddon = LibStub("AceAddon-3.0")
local AscensionAFK = AceAddon:NewAddon(MAJOR, "AceEvent-3.0")

local UIFactory = LibStub("AscensionSuit-UI")
if not UIFactory then
    error("AscensionAFK requires AscensionSuit-UI library")
end

local styles = UIFactory.DefaultStyles
local colors = styles.colors

-- Constants
local cameraRotateSec = 40

-------------------------------------------------------------------------------
-- Helpers: CVar wrappers
-------------------------------------------------------------------------------
local function getCurrentFpsCap()
    if C_CVar.GetCVarBool("useMaxFPS") then
        return tonumber(C_CVar.GetCVar("maxFPS")) or 60
    end
    return 999
end

local function applyFpsCap(value)
    value = tonumber(value)
    if not value then return end
    if value >= 999 then
        C_CVar.SetCVar("useMaxFPS", "0")
        C_CVar.SetCVar("maxFPS", C_CVar.GetCVarDefault("maxFPS"))
    else
        C_CVar.SetCVar("useMaxFPS", "1")
        C_CVar.SetCVar("maxFPS", tostring(value))
    end
end

-------------------------------------------------------------------------------
-- Overlay: vignette border that fades to 0 alpha toward center
-------------------------------------------------------------------------------
local function createOverlayVignette()
    local overlay = CreateFrame("Frame", nil, WorldFrame)
    overlay:SetAllPoints(WorldFrame)
    overlay:SetFrameStrata("BACKGROUND")
    overlay:SetFrameLevel(1)

    local br, bg, bb = colors.blackDetail[1], colors.blackDetail[2], colors.blackDetail[3]

    -- Base fade for the somnolence feel
    local baseFade = overlay:CreateTexture(nil, "BACKGROUND")
    baseFade:SetAllPoints(WorldFrame)
    baseFade:SetColorTexture(br, bg, bb, 0.25)

    local function addStrip(horiz, edgePoint)
        local tex = overlay:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        if horiz then
            tex:SetPoint(edgePoint, WorldFrame, edgePoint)
            if edgePoint == "LEFT" then
                tex:SetPoint("RIGHT", WorldFrame, "CENTER")
            else
                tex:SetPoint("LEFT", WorldFrame, "CENTER")
            end
            tex:SetPoint("TOP",    WorldFrame, "TOP")
            tex:SetPoint("BOTTOM", WorldFrame, "BOTTOM")
            
            if edgePoint == "LEFT" then
                tex:SetGradient("HORIZONTAL",
                    CreateColor(br, bg, bb, 0.9),
                    CreateColor(br, bg, bb, 0))
            else
                tex:SetGradient("HORIZONTAL",
                    CreateColor(br, bg, bb, 0),
                    CreateColor(br, bg, bb, 0.9))
            end
        else
            tex:SetPoint(edgePoint, WorldFrame, edgePoint)
            if edgePoint == "TOP" then
                tex:SetPoint("BOTTOM", WorldFrame, "CENTER")
            else
                tex:SetPoint("TOP", WorldFrame, "CENTER")
            end
            tex:SetPoint("LEFT",  WorldFrame, "LEFT")
            tex:SetPoint("RIGHT", WorldFrame, "RIGHT")
            
            if edgePoint == "TOP" then
                tex:SetGradient("VERTICAL",
                    CreateColor(br, bg, bb, 0),
                    CreateColor(br, bg, bb, 0.9))
            else
                tex:SetGradient("VERTICAL",
                    CreateColor(br, bg, bb, 0.9),
                    CreateColor(br, bg, bb, 0))
            end
        end
    end

    addStrip(true,  "LEFT")
    addStrip(true,  "RIGHT")
    addStrip(false, "TOP")
    addStrip(false, "BOTTOM")

    overlay:Hide()
    return overlay
end


-------------------------------------------------------------------------------
-- AFK Frame UI
-------------------------------------------------------------------------------
local function buildAfkFrame(self)
    self.ctx = UIFactory:CreateContext()

    if self.profile.scale == nil then self.profile.scale = 1.0 end
    if self.profile.locked == nil then self.profile.locked = false end

    local frameW, frameH = 320, 110

    local afkFrame = CreateFrame("Frame", "AscensionAFKFrame", WorldFrame, "BackdropTemplate")
    afkFrame:SetSize(frameW, frameH)
    afkFrame:SetPoint("TOP", WorldFrame, "TOP", 0, -200)
    afkFrame:SetFrameStrata("DIALOG")
    afkFrame:SetFrameLevel(10)
    afkFrame:SetClampedToScreen(true)
    afkFrame:SetBackdrop({
        bgFile   = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 2,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    afkFrame:SetBackdropColor(unpack(colors.mainBackground))
    afkFrame:SetBackdropBorderColor(unpack(colors.surfaceLight))

    -- Header bar: 6px inset from left, right and top of main frame
    local headerBar = CreateFrame("Frame", nil, afkFrame, "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT",  afkFrame, "TOPLEFT",   6, -6)
    headerBar:SetPoint("TOPRIGHT", afkFrame, "TOPRIGHT", -6, -6)
    headerBar:SetBackdrop({
        bgFile   = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
    })
    headerBar:SetBackdropColor(unpack(colors.surfaceDark))
    headerBar:SetBackdropBorderColor(0, 0, 0, 0)

    local headerLabel = headerBar:CreateFontString(nil, "OVERLAY")
    headerLabel:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    headerLabel:SetPoint("CENTER", headerBar, "CENTER")
    headerLabel:SetText("Ascension AFK")
    headerLabel:SetTextColor(unpack(colors.gold))

    -- 5px padding top and bottom of the text
    headerBar:SetHeight(headerLabel:GetStringHeight() + 10)

    -- FPS counter: gold, size 32, anchored just below the header bar
    local fpsText = afkFrame:CreateFontString(nil, "OVERLAY")
    fpsText:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
    fpsText:SetPoint("TOP", headerBar, "BOTTOM", 0, -10)
    fpsText:SetTextColor(unpack(colors.gold))
    fpsText:SetText("0 FPS")

    -- AFK logout countdown label
    local timerLabel = afkFrame:CreateFontString(nil, "OVERLAY", styles.fonts.desc)
    timerLabel:SetPoint("TOP", fpsText, "BOTTOM", 0, -4)
    timerLabel:SetJustifyH("CENTER")
    timerLabel:SetText("Your AFK time before log out is: |cFFEDBA1F00:00|r")
    timerLabel:SetTextColor(unpack(colors.textLight))

    -- 3D Player Model
    local playerModel = CreateFrame("PlayerModel", nil, afkFrame)
    playerModel:SetSize(700, 700)
    playerModel:SetPoint("RIGHT", WorldFrame, "RIGHT", -50, -50)
    playerModel:SetFrameStrata("DIALOG")
    playerModel:SetFrameLevel(20)
    
    -- Animation IDs: 60(Talk), 64(Bow), 65(Wave), 66(Cheer), 68(Laugh), 73(Point), 113(Salute), 67(Dance)
    local emotes = { 60, 64, 65, 66, 67, 68, 73, 113 }
    playerModel:SetScript("OnShow", function(self)
        -- Small delay ensures the model loads properly when UIParent is hiding
        C_Timer.After(0.1, function()
            self:ClearModel()
            self:SetUnit("player")
            self:SetCamDistanceScale(1.15)
            self:SetFacing(math.rad(15)) -- Rotated slightly towards the center
            self:SetAnimation(0)
        end)
        
        self.timer = C_Timer.NewTicker(10, function()
            if self:IsVisible() then
                self:SetAnimation(emotes[math.random(#emotes)])
            end
        end)
    end)
    playerModel:SetScript("OnHide", function(self)
        if self.timer then
            self.timer:Cancel()
            self.timer = nil
        end
    end)

    -- Draggable & Closable from UX
    UIFactory.UX:makeMovable(afkFrame, self.pos)
    if self.profile.locked then
        afkFrame:SetMovable(false)
    end
    UIFactory.UX:makeClosableWithEscape(afkFrame)

    -- Since makeMovable defaults to UIParent, re-anchor to WorldFrame
    local point, relativeTo, relativePoint, xOfs, yOfs = afkFrame:GetPoint()
    if point then
        afkFrame:ClearAllPoints()
        afkFrame:SetPoint(point, WorldFrame, relativePoint or point, xOfs, yOfs)
    end

    afkFrame:HookScript("OnDragStart", function(frame)
        frame.isDragging = true
    end)

    afkFrame:HookScript("OnDragStop", function(frame)
        frame.isDragging = false
        C_Timer.After(0, function()
            local left = frame:GetLeft()
            local bottom = frame:GetBottom()
            if left and bottom and self.pos then
                local w = frame:GetWidth() or 0
                local h = frame:GetHeight() or 0
                local screenW = GetScreenWidth() or 1920
                local screenH = GetScreenHeight() or 1080
                
                self.pos.point = "CENTER"
                self.pos.relativePoint = "CENTER"
                self.pos.x = math.floor(left + w/2 - screenW/2 + 0.5)
                self.pos.y = math.floor(bottom + h/2 - screenH/2 + 0.5)
                
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", WorldFrame, "CENTER", self.pos.x, self.pos.y)
                
                self:updateSliders()
            end
        end)
    end)

    afkFrame:HookScript("OnUpdate", function(frame)
        if frame.isDragging then
            local left = frame:GetLeft()
            local bottom = frame:GetBottom()
            if left and bottom and self.pos then
                local w = frame:GetWidth() or 0
                local h = frame:GetHeight() or 0
                local screenW = GetScreenWidth() or 1920
                local screenH = GetScreenHeight() or 1080
                
                self.pos.point = "CENTER"
                self.pos.relativePoint = "CENTER"
                self.pos.x = math.floor(left + w/2 - screenW/2 + 0.5)
                self.pos.y = math.floor(bottom + h/2 - screenH/2 + 0.5)
                self:updateSliders()
            end
        end
    end)

    -- Standard Close Button from Suite
    local closeBtn = self.ctx:createCloseButton(headerBar, function()
        self:deactivateAfkMode()
    end)
    closeBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 0)

    afkFrame:SetScale(self.profile.scale)

    afkFrame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            self:showContextMenu()
        end
    end)

    afkFrame:SetScript("OnHide", function()
        self:deactivateAfkMode()
    end)

    afkFrame:Hide()

    self.afkFrame    = afkFrame
    self.fpsText     = fpsText
    self.timerLabel  = timerLabel
    self.headerBar   = headerBar
    self.playerModel = playerModel
end

-------------------------------------------------------------------------------
-- Camera rotation helpers
-------------------------------------------------------------------------------
local function startCameraRotation(self)
    local cameraYawMoveSpeed = tonumber(C_CVar.GetCVar("cameraYawMoveSpeed")) or 180
    if cameraYawMoveSpeed <= 0 then cameraYawMoveSpeed = 180 end
    local desiredSpeed = 360 / cameraRotateSec
    local speedMultiplier = desiredSpeed / cameraYawMoveSpeed
    MoveViewLeftStop()
    MoveViewRightStart(speedMultiplier)
end

local function stopCameraRotation(self)
    MoveViewRightStop()
end

-------------------------------------------------------------------------------
-- AFK state machine
-------------------------------------------------------------------------------
local function formatCountdown(secs)
    local s = math.max(0, math.floor(secs))
    return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

function AscensionAFK:activateAfkMode()
    if self.isAfk then return end
    self.isAfk = true

    self.savedFpsCap = getCurrentFpsCap()

    local profile = self.profile
    applyFpsCap(profile.afkFPS)

    self.afkFrame:Show()
    self.overlay:Show()
    C_Timer.After(0, function() UIParent:Hide() end)

    self.afkStartTime   = GetTime()
    self.afkLogoutSecs  = self.manualAfk and 2100 or 1800
    startCameraRotation(self)

    self.onUpdateTimer = C_Timer.NewTicker(0.25, function()
        if not self.isAfk then return end
        local fps = math.floor((GetFramerate() or 0) + 0.5)
        if self.fpsText then
            self.fpsText:SetText(tostring(fps) .. " FPS")
        end
        if self.timerLabel then
            local elapsed = GetTime() - (self.afkStartTime or GetTime())
            local remaining = math.max(0, self.afkLogoutSecs - elapsed)
            local countdown = string.format("|cFFEDBA1F%s|r", formatCountdown(remaining))
            self.timerLabel:SetText("You AFK time before log out is: " .. countdown)

            if remaining <= 0 then
                if not self.timerReachedZeroCalled then
                    self.timerReachedZeroCalled = true
                    if self.OnTimerReachedZero then
                        self:OnTimerReachedZero()
                    end
                end
            end
        end
    end)
end

function AscensionAFK:deactivateAfkMode()
    if self.reactivateTimer then
        self.reactivateTimer:Cancel()
        self.reactivateTimer = nil
    end

    if not self.isAfk then return end
    self.isAfk = false

    if self.onUpdateTimer then
        self.onUpdateTimer:Cancel()
        self.onUpdateTimer = nil
    end

    stopCameraRotation(self)

    if self.afkFrame and self.afkFrame.contextMenu then
        self.afkFrame.contextMenu:Hide()
    end
    if self.optionsMenu then
        self.optionsMenu:Hide()
    end

    self.afkFrame:Hide()
    self.overlay:Hide()
    C_Timer.After(0, function() UIParent:Show() end)

    applyFpsCap(self.savedFpsCap or getCurrentFpsCap())
    self.savedFpsCap = nil
    self.manualAfk = nil
    self.timerReachedZeroCalled = nil

    if UnitIsAFK("player") then
        self.reactivateTimer = C_Timer.NewTimer(30, function()
            if UnitIsAFK("player") and not self.isAfk then
                self:activateAfkMode()
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- Options & Context Menu
-------------------------------------------------------------------------------
function AscensionAFK:showContextMenu()
    if not self.profile or not self.ctx then return end

    private:createContextMenu(
        self.ctx,
        self.afkFrame,
        self.profile,
        self.pos,
        { point = "TOP", relativePoint = "TOP", x = 0, y = -200 },
        function() self:showOptionsMenu() end,
        function() self:updateSliders() end,
        function()
            private:resetModule("AscensionAFK")
            self.profile = private.db.profile.modulesData.AscensionAFK
            self.pos = private.positions.AscensionAFK
            self.afkFrame:SetScale(self.profile.scale or 1.0)
            self.afkFrame:ClearAllPoints()
            self.afkFrame:SetPoint(self.pos.point, WorldFrame, self.pos.relativePoint, self.pos.x, self.pos.y)
            self:updateSliders()
        end
    )
end

function AscensionAFK:showOptionsMenu()
    if self.optionsMenu and self.optionsMenu:IsShown() then
        self.optionsMenu:Hide()
        return
    end

    self.optionsMenu = private:createSmartMenu(
        self.ctx,
        "AFK Module Options",
        280,
        self.afkFrame,
        "LEFT",
        self.profile,
        function(layout, menu)
            self.scaleSlider = layout:slider(nil, "Scale", 0.5, 2.0, 0.1,
                function() return self.profile.scale or 1.0 end,
                function(v)
                    self.profile.scale = v
                    if self.afkFrame then self.afkFrame:SetScale(v) end
                end)

            local screenWidth = math.floor(GetScreenWidth())
            self.xSlider = layout:slider(nil, "X Position", -screenWidth, screenWidth, 1,
                function() return self.pos.x end,
                function(v)
                    self.pos.x = v
                    if self.afkFrame then
                        self.afkFrame:ClearAllPoints()
                        self.afkFrame:SetPoint(self.pos.point, WorldFrame, self.pos.relativePoint, self.pos.x, self.pos.y)
                    end
                end)

            local screenHeight = math.floor(GetScreenHeight())
            self.ySlider = layout:slider(nil, "Y Position", -screenHeight, screenHeight, 1,
                function() return self.pos.y end,
                function(v)
                    self.pos.y = v
                    if self.afkFrame then
                        self.afkFrame:ClearAllPoints()
                        self.afkFrame:SetPoint(self.pos.point, WorldFrame, self.pos.relativePoint, self.pos.x, self.pos.y)
                    end
                end)
        end
    )
end

function AscensionAFK:updateSliders()
    if not self.optionsMenu or not self.optionsMenu:IsShown() then return end
    if self.scaleSlider then self.scaleSlider:SetValue(self.profile.scale or 1.0) end
    if self.xSlider then self.xSlider:SetValue(self.pos.x) end
    if self.ySlider then self.ySlider:SetValue(self.pos.y) end
end



-------------------------------------------------------------------------------
-- ACE Events
-------------------------------------------------------------------------------
function AscensionAFK:OnInitialize()
    if private and private.isModuleEnabled and not private:isModuleEnabled(MAJOR) then
        self:Disable()
        return
    end
    self.isAfk = false
    self:RegisterEvent("PLAYER_LOGIN")
end

function AscensionAFK:PLAYER_LOGIN()
    self.db = private.db
    if private.db and private.db.profile and private.db.profile.modulesData and private.db.profile.modulesData.AscensionAFK then
        self.profile = private.db.profile.modulesData.AscensionAFK
    else
        self.profile = {}
    end
    self.pos = private.positions.AscensionAFK
    buildAfkFrame(self)
    self.overlay = createOverlayVignette()

    self:RegisterEvent("PLAYER_FLAGS_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")

    -- Restore FPS cap after logout hook
    hooksecurefunc("Logout", function()
        if AscensionAFK.isAfk then
            AscensionAFK:deactivateAfkMode()
        end
    end)

    if SlashCmdList["AFK"] then
        hooksecurefunc(SlashCmdList, "AFK", function()
            if UnitIsAFK("player") then
                self.manualAfk = true
            else
                self.manualAfk = nil
            end
        end)
    end
end

function AscensionAFK:PLAYER_FLAGS_CHANGED(_, unit)
    if unit ~= "player" then return end
    if UnitIsAFK("player") then
        if not IsEncounterInProgress() then
            C_Timer.After(0, function()
                if UnitIsAFK("player") and not self.isAfk then
                    self:activateAfkMode()
                end
            end)
        end
    else
        self:deactivateAfkMode()
    end
end

function AscensionAFK:PLAYER_ENTERING_WORLD()
    if UnitIsAFK("player") then
        self:activateAfkMode()
    else
        self:deactivateAfkMode()
    end
end

function AscensionAFK:PLAYER_LEAVING_WORLD()
    if self.isAfk then
        self:deactivateAfkMode()
    else
        self.profile.savedFpsCap = getCurrentFpsCap()
    end
end

function AscensionAFK:OnDisable()
    self:deactivateAfkMode()
end
