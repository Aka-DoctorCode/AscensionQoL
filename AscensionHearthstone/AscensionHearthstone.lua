-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: AscensionHearthstone.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- Core Addon Init
-------------------------------------------------------------------------------
local addonName, private = ...
local MAJOR = "AscensionHearthstone"
local AceAddon = LibStub("AceAddon-3.0")
local AscensionHearthstone = AceAddon:NewAddon(MAJOR, "AceEvent-3.0")

AscensionHearthstone.isCasting = false
AscensionHearthstone.castStartTime = 0
AscensionHearthstone.castDuration = 0
AscensionHearthstone.startZoom = 0
AscensionHearthstone.targetZoom = 0.5
AscensionHearthstone.castSuccess = nil

-------------------------------------------------------------------------------
-- Spell Recognition Helpers
-------------------------------------------------------------------------------
AscensionHearthstone.SpellTable = {}

local KNOWN_SPELLS = {
    -- Death Knight
    [50977] = { isPortal = true }, -- Death Gate
    -- Druid
    [18960] = { isPortal = false }, -- Teleport: Moonglade
    [193753] = { isPortal = false }, -- Dreamwalk
    -- Monk
    [126892] = { isPortal = false }, -- Zen Pilgrimage
    [126895] = { isPortal = false }, -- Zen Pilgrimage: Return
    -- Shaman
    [556] = { isPortal = false }, -- Astral Recall
    -- Mage (Alliance)
    [3561] = { isPortal = true }, -- Teleport: Stormwind
    [10059] = { isPortal = true }, -- Portal: Stormwind
    [3562] = { isPortal = true }, -- Teleport: Ironforge
    [11416] = { isPortal = true }, -- Portal: Ironforge
    [3565] = { isPortal = true }, -- Teleport: Darnassus
    [11419] = { isPortal = true }, -- Portal: Darnassus
    [32271] = { isPortal = true }, -- Teleport: Exodar
    [32266] = { isPortal = true }, -- Portal: Exodar
    [49359] = { isPortal = true }, -- Teleport: Theramore
    [49360] = { isPortal = true }, -- Portal: Theramore
    [8362] = { isPortal = true }, -- Teleport: Tol Barad (Alliance)
    [8364] = { isPortal = true }, -- Portal: Tol Barad (Alliance)
    [132621] = { isPortal = true }, -- Teleport: Vale of Eternal Blossoms (Alliance)
    [132620] = { isPortal = true }, -- Portal: Vale of Eternal Blossoms (Alliance)
    [176248] = { isPortal = true }, -- Teleport: Stormshield
    [176246] = { isPortal = true }, -- Portal: Stormshield
    [120145] = { isPortal = true }, -- Teleport: Ancient Dalaran
    [120146] = { isPortal = true }, -- Portal: Ancient Dalaran
    [224869] = { isPortal = true }, -- Teleport: Dalaran - Broken Isles
    [224871] = { isPortal = true }, -- Portal: Dalaran - Broken Isles
    [281403] = { isPortal = true }, -- Teleport: Boralus
    [281400] = { isPortal = true }, -- Portal: Boralus
    [344587] = { isPortal = true }, -- Teleport: Oribos
    [344597] = { isPortal = true }, -- Portal: Oribos
    [395277] = { isPortal = true }, -- Teleport: Valdrakken
    [395289] = { isPortal = true }, -- Portal: Valdrakken
    [432254] = { isPortal = true }, -- Teleport: Dornogal
    [432258] = { isPortal = true }, -- Portal: Dornogal
    -- Mage (Horde)
    [3563] = { isPortal = true }, -- Teleport: Undercity
    [11417] = { isPortal = true }, -- Portal: Undercity
    [3566] = { isPortal = true }, -- Teleport: Thunder Bluff
    [11420] = { isPortal = true }, -- Portal: Thunder Bluff
    [3567] = { isPortal = true }, -- Teleport: Orgrimmar
    [11418] = { isPortal = true }, -- Portal: Orgrimmar
    [32272] = { isPortal = true }, -- Teleport: Silvermoon
    [32267] = { isPortal = true }, -- Portal: Silvermoon
    [35715] = { isPortal = true }, -- Teleport: Shattrath
    [35717] = { isPortal = true }, -- Portal: Shattrath
    [8363] = { isPortal = true }, -- Teleport: Tol Barad (Horde)
    [8365] = { isPortal = true }, -- Portal: Tol Barad (Horde)
    [132627] = { isPortal = true }, -- Teleport: Vale of Eternal Blossoms (Horde)
    [132626] = { isPortal = true }, -- Portal: Vale of Eternal Blossoms (Horde)
    [176242] = { isPortal = true }, -- Teleport: Warspear
    [176244] = { isPortal = true }, -- Portal: Warspear
    [281404] = { isPortal = true }, -- Teleport: Dazar'alor
    [281402] = { isPortal = true }, -- Portal: Dazar'alor
}

local KNOWN_ITEMS = {
    -- 1. Hearthstones
    6948,   -- Hearthstone
    110560, -- Garrison Hearthstone
    140192, -- Dalaran Hearthstone

    -- 2. Toys
    54452,  -- Ethereal Portal
    64488,  -- The Innkeeper's Daughter
    93672,  -- Dark Portal
    142542, -- Tome of Town Portal
    162973, -- Greatfather Winter's Hearthstone
    163045, -- Headless Horseman's Hearthstone
    165669, -- Lunar Elder's Hearthstone
    165670, -- Peddlefeet's Lovely Hearthstone
    165802, -- Noble Gardener's Hearthstone
    166746, -- Fire Eater's Hearthstone
    166747, -- Brewfest Reveler's Hearthstone
    168907, -- Holographic Digitalization Hearthstone
    172179, -- Eternal Traveler's Hearthstone
    180290, -- Kyrian Hearthstone
    182773, -- Necrolord Hearthstone
    183716, -- Night Fae Hearthstone
    184353, -- Venthyr Sinstone
    188952, -- Dominated Hearthstone
    190196, -- Enlightened Hearthstone
    193588, -- Timewalker's Hearthstone
    194048, -- Broker Translocation Matrix
    200630, -- Ohn'ir Windsage's Hearthstone
    208704, -- Deepdweller's Earthen Hearthstone
    209035, -- Path of the Naaru
    210455, -- Draenic Hologem
    212337, -- Stone of the Hearth
    228582, -- Notorious Thread's Hearthstone

    -- Engineering Wormholes & Transporters
    18984,  -- Dimensional Ripper - Everlook
    18986,  -- Ultrasafe Transporter: Gadgetzan
    30542,  -- Ultrasafe Transporter: Toshley's Station
    30544,  -- Dimensional Ripper - Area 52
    48933,  -- Wormhole Generator: Northrend
    87215,  -- Wormhole Generator: Pandaria
    112059, -- Wormhole Centrifuge (Draenor)
    151652, -- Wormhole Generator: Argus
    166559, -- Wormhole Generator: Kul Tiras
    166560, -- Wormhole Generator: Zandalar
    172924, -- Wormhole Generator: Shadowlands
    198156, -- Wyrmhole Generator: Dragon Isles
    221966, -- Wormhole Generator: Khaz Algar

    -- Other Toys
    32566,  -- Fractured Necrolyte Skull
    37254,  -- Direbrew's Remote
    118663, -- Relic of Karabor
    136849, -- Nature's Beacon

    -- Rings
    44934,  -- Ring of the Kirin Tor
    44935,  -- Ring of the Kirin Tor
    45688,  -- Signet of the Kirin Tor
    45689,  -- Signet of the Kirin Tor
    45690,  -- Band of the Kirin Tor
    45691,  -- Band of the Kirin Tor
    51557,  -- Runed Ring of the Kirin Tor
    51558,  -- Runed Ring of the Kirin Tor
    51559,  -- Runed Signet of the Kirin Tor
    51560,  -- Runed Signet of the Kirin Tor
    144369, -- Karazhan Ring / Violet Seal

    -- Misc
    28585,  -- Ruby Slippers
    32757,  -- Blessed Medallion of Karabor
    63378,  -- Hellscream's Reach Tabard
    63379,  -- Baradin's Warden Tabard
    104198, -- Admiral Taylor's Loyalty Ring
    128502, -- Admiral's Compass
    142469, -- Violet Seal of the Grand Magus
    43463,  -- Scroll of Recall
    142543, -- Scroll of Town Portal (Diablo Event Consumable)
    50287,  -- Boots of the Bay
    58487,  -- Potion of Deepholm
    103678, -- Time-Lost Artifact
    22589,  -- Atiesh, Greatstaff of the Guardian (Mage)
    22630,  -- Atiesh, Greatstaff of the Guardian (Warlock)
    22631,  -- Atiesh, Greatstaff of the Guardian (Priest)
    22632,  -- Atiesh, Greatstaff of the Guardian (Druid)
}

function AscensionHearthstone:InitializeSpellTable()
    -- Copy known spells
    for spellID, info in pairs(KNOWN_SPELLS) do
        self.SpellTable[spellID] = info
    end
    
    -- Request and cache item spells
    for _, itemID in ipairs(KNOWN_ITEMS) do
        local item = Item:CreateFromItemID(itemID)
        if item then
            item:ContinueOnItemLoad(function()
                local spellName, spellID = C_Item.GetItemSpell(itemID)
                if spellID then
                    -- Items are usually not portals (except toy portals, but those act like normal teleport)
                    self.SpellTable[spellID] = { isPortal = false }
                end
            end)
        end
    end
end

local function isTeleportSpell(spellID)
    if not spellID then return false end
    return AscensionHearthstone.SpellTable[spellID] ~= nil
end

local function isPortalSpell(spellID)
    if not spellID then return false end
    local info = AscensionHearthstone.SpellTable[spellID]
    return info and info.isPortal
end

-------------------------------------------------------------------------------
-- Camera Control Helpers
-------------------------------------------------------------------------------
local function startCameraRotation(duration, isPortal, spellID)
    local cameraYawMoveSpeed = tonumber(C_CVar.GetCVar("cameraYawMoveSpeed")) or 180
    if cameraYawMoveSpeed <= 0 then cameraYawMoveSpeed = 180 end
    
    local degrees = 540
    if isPortal then
        if duration >= 5 then
            degrees = 720
        else
            degrees = 360
        end
    else
        if duration >= 10 then
            degrees = 900
        elseif duration >= 5 then
            degrees = 540
        else
            degrees = 180
        end
    end
    
    local desiredSpeed = degrees / duration
    local speedMultiplier = desiredSpeed / cameraYawMoveSpeed
    MoveViewLeftStop()
    MoveViewRightStart(speedMultiplier)
end

local function stopCameraRotation()
    MoveViewRightStop()
end

-------------------------------------------------------------------------------
-- UI Manipulation Helpers
-------------------------------------------------------------------------------
local originalParents = {}

local function reparentFrame(frame, newParent)
    if frame and frame.GetParent then
        local parent = frame:GetParent()
        if parent and parent ~= newParent then
            originalParents[frame] = parent
            frame:SetParent(newParent)
        end
    end
end

local function restoreParents()
    for frame, parent in pairs(originalParents) do
        if frame and frame.SetParent then
            frame:SetParent(parent)
        end
    end
    originalParents = {}
end

local function hideUIButCastBar()
    if PlayerCastingBarFrame then
        reparentFrame(PlayerCastingBarFrame, WorldFrame)
    end
    if AscensionCastBarFrame then
        local anchor = AscensionCastBarFrame:GetParent()
        if anchor then
            reparentFrame(anchor, WorldFrame)
        end
    end
    if AscensionCastBarTextFrame then
        reparentFrame(AscensionCastBarTextFrame, WorldFrame)
    end
    
    C_Timer.After(0, function() UIParent:Hide() end)
end

local function restoreUI()
    UIParent:Show()
    restoreParents()
end

-------------------------------------------------------------------------------
-- Module Lifecycles
-------------------------------------------------------------------------------
function AscensionHearthstone:OnInitialize()
    if private and private.isModuleEnabled and not private:isModuleEnabled(MAJOR) then
        self:Disable()
        return
    end
    self:RegisterEvent("PLAYER_LOGIN")
end

function AscensionHearthstone:PLAYER_LOGIN()
    self:InitializeSpellTable()
    self.db = private.db
    if self.db and self.db.profile and self.db.profile.modulesData then
        if not self.db.profile.modulesData.AscensionHearthstone then
            self.db.profile.modulesData.AscensionHearthstone = { enabled = true, savedZoom = 15, shouldRestore = false }
        end
        self.profile = self.db.profile.modulesData.AscensionHearthstone
    else
        self.profile = { enabled = true, savedZoom = 15, shouldRestore = false }
    end
    
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self.updateFrame = CreateFrame("Frame")
    self.updateFrame:SetScript("OnUpdate", function(_, elapsed)
        self:onUpdate(elapsed)
    end)
    
    -- Debug Command to manually test casting effect
    SLASH_HEARTHTEST1 = "/hearthtest"
    SlashCmdList["HEARTHTEST"] = function()
        self:startCastingEffect(10, 8690)
        C_Timer.After(10, function()
            self:stopCastingEffect(true)
        end)
    end
end

-------------------------------------------------------------------------------
-- Camera Frame Update
-------------------------------------------------------------------------------
function AscensionHearthstone:onUpdate(elapsed)
    if not self.isCasting then return end
    
    if GetUnitSpeed("player") > 0 then
        self:stopCastingEffect(false)
        return
    end
    
    local currentTime = GetTime()
    local progress = (currentTime - self.castStartTime) / self.castDuration
    if progress > 1 then progress = 1 end
    
    local targetCurrentZoom = self.startZoom - progress * (self.startZoom - self.targetZoom)
    local currentZoom = GetCameraZoom()
    local diff = currentZoom - targetCurrentZoom
    if diff > 0 then
        CameraZoomIn(diff)
    end
end

-------------------------------------------------------------------------------
-- Casting State Management
-------------------------------------------------------------------------------
function AscensionHearthstone:startCastingEffect(duration, spellID)
    self.isCasting = true
    self.currentSpellID = spellID
    self.castStartTime = GetTime()
    self.castDuration = duration
    self.startZoom = GetCameraZoom()
    self.castSuccess = nil
    
    self.profile.savedZoom = self.startZoom
    self.profile.shouldRestore = true
    
    local isPortal = isPortalSpell(spellID)
    startCameraRotation(duration, isPortal, spellID)
    hideUIButCastBar()
end

function AscensionHearthstone:stopCastingEffect(wasSuccessful)
    if not self.isCasting then return end
    self.isCasting = false
    stopCameraRotation()
    restoreUI()
    
    local isPortal = self.currentSpellID and isPortalSpell(self.currentSpellID)
    self.currentSpellID = nil
    
    if not wasSuccessful or isPortal then
        self.profile.shouldRestore = false
        local currentZoom = GetCameraZoom()
        local diff = self.startZoom - currentZoom
        if diff > 0 then
            CameraZoomOut(diff)
        end
    end
end

-------------------------------------------------------------------------------
-- Casting Events & World Loading
-------------------------------------------------------------------------------
function AscensionHearthstone:UNIT_SPELLCAST_START(_, unitTarget, castGUID, spellID)
    if unitTarget ~= "player" then return end
    
    if isTeleportSpell(spellID) then
        local name, text, texture, startTime, endTime = UnitCastingInfo("player")
        if not startTime and C_Spell and C_Spell.GetSpellCastInfo then
            local castInfo = C_Spell.GetSpellCastInfo("player")
            if castInfo then
                startTime = castInfo.startTime
                endTime = castInfo.endTime
            end
        end
        
        if startTime and endTime then
            local duration = (endTime - startTime) / 1000
            if duration > 0 then
                self:startCastingEffect(duration, spellID)
            end
        end
    end
end

function AscensionHearthstone:UNIT_SPELLCAST_SUCCEEDED(_, unitTarget, castGUID, spellID)
    if unitTarget ~= "player" then return end
    if self.isCasting then
        self.castSuccess = true
        self:stopCastingEffect(true)
    end
end

function AscensionHearthstone:UNIT_SPELLCAST_FAILED(_, unitTarget, castGUID, spellID)
    if unitTarget ~= "player" then return end
    if self.isCasting then
        self:stopCastingEffect(false)
    end
end

function AscensionHearthstone:UNIT_SPELLCAST_INTERRUPTED(_, unitTarget, castGUID, spellID)
    if unitTarget ~= "player" then return end
    if self.isCasting then
        self:stopCastingEffect(false)
    end
end

function AscensionHearthstone:UNIT_SPELLCAST_STOP(_, unitTarget, castGUID, spellID)
    if unitTarget ~= "player" then return end
    if self.isCasting and not self.castSuccess then
        self:stopCastingEffect(false)
    end
    self.castSuccess = nil
end

function AscensionHearthstone:PLAYER_ENTERING_WORLD()
    restoreParents()
    if self.profile and self.profile.shouldRestore then
        self.profile.shouldRestore = false
        local saved = self.profile.savedZoom
        if saved then
            C_Timer.After(0.5, function()
                local current = GetCameraZoom()
                local diff = saved - current
                if diff > 0 then
                    CameraZoomOut(diff)
                end
            end)
        end
    end
end
