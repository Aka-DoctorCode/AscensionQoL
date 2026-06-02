-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: AscensionQoL.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

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
            ["AscensionFPS"]   = true,
            ["AscensionAFK"]   = true,
            ["AscensionHearthstone"] = true,
        },
        positions = {
            configFrame    = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0    },
            AscensionSound = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0    },
            AscensionFPS   = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -200 },
            AscensionAFK   = { point = "TOP",    relativePoint = "TOP",    x = 0, y = -200 },
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
                    alpha = 1.0,
                    locked = false,
                    width = 80,
                    height = 40,
                    bgVisible = true,
                    bgColor = { r = 0.02, g = 0.02, b = 0.031, a = 0.85 },
                },
                text = {
                    useClassColor = false,
                    customColor = { r = 1, g = 1, b = 1, a = 1 },
                    color = { r = 1, g = 0.8, b = 0.2, a = 1},
                    size = 16,
                    font = "Friz Quadrata TT",
                    style = "OUTLINE",
                }
            },
            AscensionAFK = {
                afkFPS      = 8,
                savedFpsCap = 60,
            },
            AscensionHearthstone = {
                enabled = true,
                savedZoom = 15,
                shouldRestore = false,
            },
        }
    }
}

-------------------------------------------------------------------------------
-- DB Management
-------------------------------------------------------------------------------
local function initializeDB()
    private.db = LibStub("AceDB-3.0"):New("AscensionQoLDB", defaults, "Default")
end

local function deepCopyInto(dest, src)
    for k in pairs(dest) do dest[k] = nil end
    for k, v in pairs(src) do
        dest[k] = type(v) == "table" and deepCopyInto({}, v) or v
    end
    return dest
end

function private:resetModule(moduleName)
    local moduleDefaults = defaults.profile.modulesData[moduleName]
    local posDefaults    = defaults.profile.positions[moduleName]
    if moduleDefaults and private.db.profile.modulesData[moduleName] then
        deepCopyInto(private.db.profile.modulesData[moduleName], moduleDefaults)
    end
    if posDefaults and private.db.profile.positions[moduleName] then
        deepCopyInto(private.db.profile.positions[moduleName], posDefaults)
    end
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
    local scale = profile and profile.general and profile.general.scale or 1
    configFrame:SetScale(scale)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetFrameStrata("HIGH")
    configFrame:SetClampedToScreen(true)

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
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    configFrame:SetBackdropColor(unpack(colors.mainBackground))
    configFrame:SetBackdropBorderColor(unpack(colors.surfaceLight))

    -- Header Title
    local title = configFrame:CreateFontString(nil, "OVERLAY", styles.fonts.header)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension QoL")
    title:SetTextColor(unpack(colors.gold))

    -- Close Button (Factory style)
    local closeBtn = ctx:createCloseButton(configFrame, function() configFrame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    local UIFactory = LibStub("AscensionSuit-UI")
    if UIFactory and UIFactory.UX then
        UIFactory.UX:makeClosableWithEscape(configFrame)
    end

    -- Content Frame (No Scroll)
    local content = CreateFrame("Frame", nil, configFrame)
    content:SetPoint("TOPLEFT", 10, -50)
    content:SetPoint("BOTTOMRIGHT", -10, 60)

    -- Layout Model for automatic positioning
    local layout = ctx.layoutModel:reset(content, -10)

    layout:header(nil, "Modules")

    layout:checkbox(nil, "Enable Ascension Sound",
        "Control master volume and channels with a compact UI.",
        function() return profile and profile.modules and profile.modules["AscensionSound"] or false end,
        function(v)
            if profile and profile.modules then
                profile.modules["AscensionSound"] = v
            end
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionSound|r " ..
                (v and "enabled" or "disabled") .. " (Reload UI required).")
        end)

    layout:checkbox(nil, "Enable Ascension FPS",
        "Monitor your framerate with a customizable display.",
        function() return profile and profile.modules and profile.modules["AscensionFPS"] or false end,
        function(v)
            if profile and profile.modules then
                profile.modules["AscensionFPS"] = v
            end
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionFPS|r " ..
                (v and "enabled" or "disabled") .. " (Reload UI required).")
        end)

    layout:checkbox(nil, "Enable Ascension AFK",
        "Lower FPS and show overlay when you go AFK. Restores your previous cap on return.",
        function() return profile and profile.modules and profile.modules["AscensionAFK"] or false end,
        function(v)
            if profile and profile.modules then
                profile.modules["AscensionAFK"] = v
            end
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionAFK|r " ..
                (v and "enabled" or "disabled") .. " (Reload UI required).")
        end)

    layout:checkbox(nil, "Enable Ascension Hearthstone",
        "Rotate and zoom camera during teleport/Hearthstone casting.",
        function() return profile and profile.modules and profile.modules["AscensionHearthstone"] or false end,
        function(v)
            if profile and profile.modules then
                profile.modules["AscensionHearthstone"] = v
            end
            print("|cff7f13ecAscension QoL|r: Module |cff00ff00AscensionHearthstone|r " ..
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

function private:closeAllMenus()
    local aceAddon = LibStub("AceAddon-3.0", true)
    if not aceAddon then return end

    local modules = { "AscensionFPS", "AscensionSound", "AscensionAFK" }
    for _, moduleName in ipairs(modules) do
        local addon = aceAddon:GetAddon(moduleName, true)
        if addon then
            if addon.frame and addon.frame.contextMenu then
                addon.frame.contextMenu:Hide()
            end
            if addon.afkFrame and addon.afkFrame.contextMenu then
                addon.afkFrame.contextMenu:Hide()
            end
            if addon.optionsMenu then
                addon.optionsMenu:Hide()
            end
            if addon.renderMenu then
                addon.renderMenu:Hide()
            end
            if addon.dropdown and addon.dropdown:IsShown() and addon.toggleDropdown then
                addon:toggleDropdown()
            end
        end
    end
end

function private:createContextMenu(ctx, moduleFrame, profile, pos, defaultPos, optionsCallback, updateSlidersCallback, resetCallback)
    if moduleFrame.contextMenu and moduleFrame.contextMenu:IsShown() then
        moduleFrame.contextMenu:Hide()
        return
    end

    private:closeAllMenus()

    local styles = ctx.styles
    local colors = styles.colors

    local menuParent = moduleFrame:GetParent() or UIParent
    local menu = CreateFrame("Frame", nil, menuParent, "BackdropTemplate")
    local btnHeight = 28
    local spacing = 10
    local numButtons = resetCallback and 4 or 3
    local totalHeight = (numButtons * btnHeight) + ((numButtons + 1) * spacing)
    
    menu:SetSize(190, totalHeight)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(2)
    menu:SetClampedToScreen(true)
    menu:SetScale(profile.scale or 1.0)
    menu:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
    })
    menu:SetBackdropColor(unpack(colors.surfaceDark))
    menu:SetBackdropBorderColor(unpack(colors.surfaceLight))
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
            moduleFrame:SetPoint(pos.point, menuParent, pos.relativePoint, pos.x, pos.y)
            if updateSlidersCallback then updateSlidersCallback() end
            menu:Hide()
        end,
    })

    if resetCallback then
        ctx:createButton({
            parent = menu,
            text = "Reset to defaults",
            width = 170, height = btnHeight,
            xOffset = 10, yOffset = -(spacing * 4 + btnHeight * 3),
            onClick = function()
                menu:Hide()
                resetCallback()
            end,
        })
    end

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("DIALOG")
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
    private:closeAllMenus()

    local styles = ctx.styles
    local colors = styles.colors

    local menuParent = UIParent
    if not UIParent:IsShown() then
        menuParent = WorldFrame
    end

    local menuName = "AscensionQoLSmartMenu_" .. tostring(math.random(1000000, 9999999))
    local menu = CreateFrame("Frame", menuName, menuParent, "BackdropTemplate")
    menu:SetWidth(width)
    menu:SetFrameStrata("DIALOG")
    if profile and profile.scale then
        menu:SetScale(profile.scale)
    end
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    menu:SetBackdropColor(unpack(colors.surfaceDark))
    menu:SetBackdropBorderColor(unpack(colors.surfaceLight))

    local UIFactory = LibStub("AscensionSuit-UI")
    if UIFactory and UIFactory.UX then
        UIFactory.UX:makeClosableWithEscape(menu)
    end

    local content = CreateFrame("Frame", nil, menu)
    content:SetSize(width, 10)

    local layout = ctx.layoutModel:reset(content, -20)
    if title and title ~= "" then
        layout:header(nil, title)
    else
        layout.y = -20
    end

    buildFunc(layout, menu)

    local contentHeight = math.abs(layout.y) - 5
    local maxHeight = 400

    if contentHeight > maxHeight then
        menu:SetHeight(maxHeight)
        local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -40)
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
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    if anchorPoint == "RIGHT" and anchorFrame and anchorFrame:IsShown() then
        menu:SetPoint("LEFT", anchorFrame, "RIGHT", 10, 0)
    elseif anchorPoint == "LEFT" and anchorFrame and anchorFrame:IsShown() then
        menu:SetPoint("RIGHT", anchorFrame, "LEFT", -10, 0)
    elseif anchorPoint == "BOTTOM" and anchorFrame and anchorFrame:IsShown() then
        menu:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -5)
    else
        menu:SetPoint("CENTER", menuParent, "CENTER", 250, 0)
    end

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("DIALOG")
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetScript("OnClick", function() menu:Hide() end)
    closer:Show()

    menu:HookScript("OnHide", function()
        closer:Hide()
    end)

    menu:Show()
    return menu
end

-------------------------------------------------------------------------------
-- Initialization & Events
-------------------------------------------------------------------------------
local function initPositions()
    private.positions = private.db.profile.positions
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        initializeDB()
        initPositions()

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
