-------------------------------------------------------------------------------
-- Module: AscensionMountManager
-- Author: Aka-DoctorCode
-- File: AscensionMountManager/AscensionMountManager.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local _, private = ...

local FLYING_MOUNT_TYPES = {
    [247] = true,
    [248] = true,
    [402] = true,
    [424] = true,
    [436] = true,
}

local AQUATIC_MOUNT_TYPES = {
    [231] = true,
    [232] = true,
    [254] = true,
    [407] = true,
    [408] = true,
    [412] = true,
}

local KNOWN_SERVICE_MOUNTS = {
    "traveler's tundra mammoth",
    "traveller's tundra mammoth",
    "grand expedition yak",
    "mighty caravan brutosaur",
    "trader's gilded brutosaur",
    "chauffeured mekgineer's chopper",
    "chauffeured mechano-hog"
}

private.mountManager = {
    favoriteMountsCache = {},
    recentSummonHistory = {},
    maxHistorySize = 3
}

local eventFrame = CreateFrame("Frame")

local function isPlayerUnderwater()
    if IsSubmerged and IsSubmerged() then
        return true
    end
    if IsSwimming and IsSwimming() then
        if IsFlyableArea and IsFlyableArea() then
            return false
        end
        return true
    end
    return false
end

function private.mountManager:buildFavoritesCache()
    wipe(self.favoriteMountsCache)

    local mountIds = C_MountJournal.GetMountIDs()
    for _, mountId in ipairs(mountIds) do
        local _, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)

        if isCollected and isFavorite and isUsable then
            local creatureDisplayInfoID, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountId)

            local mountCategory
            if FLYING_MOUNT_TYPES[mountTypeID] then
                mountCategory = "flying"
            elseif AQUATIC_MOUNT_TYPES[mountTypeID] then
                mountCategory = "aquatic"
            else
                mountCategory = "ground"
            end

            table.insert(self.favoriteMountsCache, {
                id = mountId,
                modelId = creatureDisplayInfoID,
                category = mountCategory
            })
        end
    end
end

function private.mountManager:buildPriorityPool()
    local flyingPool  = {}
    local aquaticPool = {}
    local groundPool  = {}

    for _, mount in ipairs(self.favoriteMountsCache) do
        if mount.category == "flying" then
            table.insert(flyingPool, mount)
        elseif mount.category == "aquatic" then
            table.insert(aquaticPool, mount)
        else
            table.insert(groundPool, mount)
        end
    end

    local canFly     = IsFlyableArea and IsFlyableArea()
    local underwater = isPlayerUnderwater()

    if underwater and #aquaticPool > 0 then
        return aquaticPool
    elseif canFly and #flyingPool > 0 then
        return flyingPool
    elseif #groundPool > 0 then
        return groundPool
    end

    return self.favoriteMountsCache
end

function private.mountManager:summonMount()
    local pool = self:buildPriorityPool()
    if #pool == 0 then return end

    local candidateIndex
    local candidate
    local maxAttempts = #pool
    local attempt     = 0

    while attempt < maxAttempts do
        attempt = attempt + 1
        local randomIndex = math.random(1, #pool)
        candidate = pool[randomIndex]

        local isRecent = false
        for _, recentModelId in ipairs(self.recentSummonHistory) do
            if recentModelId == candidate.modelId then
                isRecent = true
                break
            end
        end

        if not isRecent then
            candidateIndex = randomIndex
            break
        end
    end

    if not candidateIndex then
        candidateIndex = math.random(1, #pool)
        candidate      = pool[candidateIndex]
    end

    if GetShapeshiftForm and GetShapeshiftForm() > 0 then
        CancelShapeshiftForm()
    end

    C_MountJournal.SummonByID(candidate.id)

    table.insert(self.recentSummonHistory, 1, candidate.modelId)
    if #self.recentSummonHistory > self.maxHistorySize then
        table.remove(self.recentSummonHistory)
    end
end

function private.mountManager:createAscensionMacro()
    local icon       = "ability_mount_ridinghorse"
    local macroIndex = CreateMacro("AscensionMount", icon, "/ascensionmount", true)
    if not macroIndex or macroIndex == 0 then
        macroIndex = CreateMacro("AscensionMount", icon, "/ascensionmount", false)
    end
    return macroIndex
end

function private.mountManager:ensureMacroExists()
    local macroIndex = GetMacroIndexByName("AscensionMount")
    if macroIndex == 0 then
        macroIndex = self:createAscensionMacro()
    else
        EditMacro(macroIndex, "AscensionMount", "ability_mount_ridinghorse", "/ascensionmount")
    end
    return macroIndex
end

function private.mountManager:showServiceMenu(anchor)
    if not MenuUtil then return end

    MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
        rootDescription:CreateTitle("Service Mounts")
        local hasMounts = false

        local mountIds = C_MountJournal.GetMountIDs()
        for _, mountId in ipairs(mountIds) do
            local name, _, icon, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)
            if isCollected and isUsable then
                local lowerName = name:lower()
                local isService = false
                for _, pattern in ipairs(KNOWN_SERVICE_MOUNTS) do
                    if lowerName:find(pattern, 1, true) then
                        isService = true
                        break
                    end
                end

                if isService then
                    hasMounts = true
                    rootDescription:CreateButton(name, function()
                        C_MountJournal.SummonByID(mountId)
                    end)
                end
            end
        end

        if not hasMounts then
            rootDescription:CreateTitle("None available")
        end
    end)
end

function private.mountManager:integrateUi()
    if not MountJournal then return end

    local uiButton = CreateFrame("Button", "AscensionMountUiButton", MountJournal, "BackdropTemplate")

    local oldBtn = MountJournal.SummonRandomFavoriteButton
    if oldBtn then
        uiButton:SetParent(oldBtn:GetParent())
        uiButton:SetSize(oldBtn:GetSize())
        uiButton:SetPoint("CENTER", oldBtn, "CENTER", 0, 0)

        oldBtn:SetAlpha(0)
        oldBtn:EnableMouse(false)
        oldBtn:UnregisterAllEvents()
        hooksecurefunc(oldBtn, "SetAlpha", function(self, alpha) if alpha > 0 then self:SetAlpha(0) end end)
    else
        uiButton:SetSize(48, 48)
        uiButton:SetPoint("BOTTOMRIGHT", MountJournal, "TOPLEFT", -8, -50)
    end

    uiButton:SetFrameStrata("HIGH")
    uiButton:SetFrameLevel(99)
    uiButton:EnableMouse(true)

    uiButton:SetBackdropColor(0.10, 0.10, 0.10, 1)
    uiButton:SetBackdropBorderColor(0.83, 0.68, 0.22, 1)

    uiButton:SetNormalTexture("Interface\\Icons\\ability_mount_ridinghorse")
    local normalTex = uiButton:GetNormalTexture()
    if normalTex then
        normalTex:SetTexCoord(0.10, 0.90, 0.10, 0.90)
    end

    uiButton:RegisterForDrag("LeftButton")
    uiButton:SetScript("OnDragStart", function(self)
        if GetMacroIndexByName("AscensionMount") == 0 then
            private.mountManager:ensureMacroExists()
        end
        PickupMacro("AscensionMount")
    end)

    uiButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    uiButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            private.mountManager:showServiceMenu(self)
        else
            private.mountManager:summonMount()
        end
    end)

    uiButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Ascension Mount Summoner", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Summon a random smart favorite.", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Service mounts (Repair / Auction House).", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Drag to any action bar to bind.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    uiButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

local function onEvent(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == "Blizzard_Collections" then
        private.mountManager:integrateUi()
    elseif event == "PLAYER_LOGIN" then
        if not private:isModuleEnabled("AscensionMountManager") then return end
        if C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            private.mountManager:integrateUi()
        end
        private.mountManager:buildFavoritesCache()
        C_Timer.After(2, function() private.mountManager:ensureMacroExists() end)
    elseif event == "NEW_MOUNT_ADDED" then
        private.mountManager:buildFavoritesCache()
    elseif event == "COMPANION_UPDATE" then
        local companionType = ...
        if companionType == "MOUNT" then
            private.mountManager:buildFavoritesCache()
        end
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
eventFrame:RegisterEvent("COMPANION_UPDATE")
eventFrame:SetScript("OnEvent", onEvent)

SLASH_ASCENSIONMOUNTSUMMONER1 = "/ascensionmount"
SlashCmdList["ASCENSIONMOUNTSUMMONER"] = function()
    private.mountManager:summonMount()
end
