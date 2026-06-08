-------------------------------------------------------------------------------
-- Module: AscensionProfessionHelper
-- Author: Aka-DoctorCode
-- File: AscensionProfessionHelper/AscensionProfessionHelper.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, private = ...

private.crafting = {
    queue = {},
    currentTargetItem = nil,
    sessionConfirmed = false,
    allowedDangerousItems = {}
}

private.isProfDebugEnabled = false

local function profLog(message)
    if private.isProfDebugEnabled then
        print("|cff00ff00[ProfessionHelper]|r " .. tostring(message))
    end
end

-------------------------------------------------------------------------------
-- UI AND LOGIC
-------------------------------------------------------------------------------
local massDestroyButton = CreateFrame("Button", "AscensionMassDestroyBtn", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
massDestroyButton:RegisterForClicks("AnyUp", "AnyDown")
massDestroyButton:SetSize(150, 40)
massDestroyButton:SetAttribute("*type1", "macro")
massDestroyButton:Hide()

local destroyOverlayBtn = CreateFrame("Button", "AscensionMassDestroyOverlayBtn", UIParent, "BackdropTemplate")
destroyOverlayBtn:SetSize(150, 40)
destroyOverlayBtn:Hide()
destroyOverlayBtn:SetScript("OnClick", function()
    if not private.crafting.currentTargetItem then return end
    StaticPopupDialogs["ASCENSION_CONFIRM_DESTROY"] = {
        text = "Are you sure you want to start destroying items?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            private.crafting.sessionConfirmed = true
            if AscensionQoLDB and AscensionQoLDB.profHelper and AscensionQoLDB.profHelper.lastBind and _G.AscensionProfHelperUI then
                SetOverrideBindingClick(_G.AscensionProfHelperUI, true, AscensionQoLDB.profHelper.lastBind, "AscensionMassDestroyBtn", "LeftButton")
            end
            destroyOverlayBtn:Hide()
            private.crafting.updateDestroyQueue()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("ASCENSION_CONFIRM_DESTROY")
end)

local categoryPanels = {}
local itemFrames = {}
local blFrames = {}
local searchFilter = ""

function private.crafting.updateBlacklistUI()
    local activePanel = categoryPanels[4]
    if not activePanel then return end

    for _, f in ipairs(blFrames) do f:Hide() end
    local y = -45
    local i = 1
    local blacklist = AscensionQoLDB and AscensionQoLDB.profHelper and AscensionQoLDB.profHelper.blacklist or {}
    for id, _ in pairs(blacklist) do
        local name, link = C_Item.GetItemInfo(id)
        local itemName = name or ("Item " .. id)

        if searchFilter == "" or string.find(string.lower(itemName), string.lower(searchFilter)) then
            local f = blFrames[i]
            if not f then
                f = CreateFrame("Button", nil, activePanel, "BackdropTemplate")
                f:SetHeight(40)
                f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                f:SetBackdropColor(0, 0, 0, 0.3)
                f:SetScript("OnEnter", function() f:SetBackdropColor(0.2, 0.2, 0.2, 0.8) end)
                f:SetScript("OnLeave", function() f:SetBackdropColor(0, 0, 0, 0.3) end)

                local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("LEFT", 10, 0)
                text:SetJustifyH("LEFT")
                text:SetWordWrap(false)
                f.text = text

                local ilvlText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                ilvlText:SetPoint("RIGHT", -10, 0)
                ilvlText:SetJustifyH("RIGHT")
                ilvlText:SetTextColor(0.7, 0.7, 0.7)
                f.ilvlText = ilvlText

                text:SetPoint("RIGHT", ilvlText, "LEFT", -10, 0)

                f:RegisterForClicks("RightButtonUp")
                f:SetScript("OnClick", function(self, button)
                    if button == "RightButton" then
                        local lib = LibStub("AscensionSuit-UI", true)
                        if lib and lib.UX and lib.UX.showContextMenu then
                            lib.UX:showContextMenu(self, {
                                {
                                    text = "Remove from Blacklist",
                                    func = function()
                                        AscensionQoLDB.profHelper.blacklist[f.itemId] = nil
                                        profLog("Removed from blacklist.")
                                        private.crafting.updateBlacklistUI()
                                        private.crafting.updateDestroyQueue()
                                    end
                                }
                            })
                        end
                    end
                end)
                table.insert(blFrames, f)
            end

            f.itemId = id
            local name, link, quality, ilvl = C_Item.GetItemInfo(id)
            local icon = C_Item.GetItemIconByID(id)
            local iconStr = icon and ("|T" .. icon .. ":30:30|t ") or ""
            f.text:SetText(iconStr .. (link or itemName))
            f.ilvlText:SetText(ilvl and ("iLvl " .. ilvl) or "")
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 10, y)
            f:SetPoint("RIGHT", activePanel, "RIGHT", -10, y)
            f:Show()
            y = y - 45
            i = i + 1
        end
    end
    activePanel:SetHeight(math.abs(y) + 20)
end

function private.crafting.isItemDestroyable(bagIndex, slotIndex, itemId)
    local blacklist = AscensionQoLDB and AscensionQoLDB.profHelper and AscensionQoLDB.profHelper.blacklist or {}
    if blacklist[itemId] then
        return false, nil
    end

    local tooltipData
    if bagIndex and slotIndex then
        tooltipData = C_TooltipInfo.GetBagItem(bagIndex, slotIndex)
    else
        tooltipData = C_TooltipInfo.GetItemByID(itemId)
    end

    local isNotDisenchantable = false

    if tooltipData then
        for _, line in ipairs(tooltipData.lines) do
            local fullText = (line.leftText or "") .. " " .. (line.rightText or "")
            if line.args then
                for _, arg in ipairs(line.args) do
                    if arg.stringVal then
                        fullText = fullText .. arg.stringVal .. " "
                    end
                end
            end

            local plainText = string.gsub(fullText, "|c%x%x%x%x%x%x%x%x", "")
            plainText = string.gsub(plainText, "|r", "")
            plainText = string.gsub(plainText, "|T.-|t", "")
            plainText = string.gsub(plainText, "\n", "")

            local lowerText = string.lower(plainText)

            if string.find(lowerText, "prospectable") or string.find(lowerText, "se puede prospectar") or (ITEM_PROSPECTABLE and string.find(plainText, ITEM_PROSPECTABLE, 1, true)) then
                return true, "Prospecting"
            end

            if string.find(lowerText, "millable") or string.find(lowerText, "molible") or string.find(lowerText, "se puede moler") or (ITEM_MILLABLE and string.find(plainText, ITEM_MILLABLE, 1, true)) then
                return true, "Milling"
            end

            if string.find(lowerText, "cannot be disenchanted") or string.find(lowerText, "not disenchantable") or string.find(lowerText, "no se puede desencantar") or string.find(lowerText, "no desencantable") then
                isNotDisenchantable = true
            end

            if ITEM_DISENCHANT_NOT_DISENCHANTABLE and string.find(plainText, ITEM_DISENCHANT_NOT_DISENCHANTABLE, 1, true) then
                isNotDisenchantable = true
            end
        end
    end

    if isNotDisenchantable then return false, nil end

    local _, _, itemQuality, itemLevel, _, _, _, _, equipLoc, _, _, classId, subClassId = C_Item.GetItemInfo(itemId)

    if not classId or not itemQuality then return false, nil end

    local invalidEquipLocs = {
        ["INVTYPE_TABARD"]          = true,
        ["INVTYPE_BODY"]            = true,
        ["INVTYPE_BAG"]             = true,
        ["INVTYPE_QUIVER"]          = true,
        ["INVTYPE_PROFESSION_TOOL"] = true,
        ["INVTYPE_PROFESSION_GEAR"] = true,
        [""]                        = true
    }

    if invalidEquipLocs[equipLoc] then
        return false, nil
    end

    if classId == 4 and subClassId == 5 then return false, nil end
    if classId == 2 and subClassId == 20 then return false, nil end

    if (classId == 2 or classId == 4) and itemQuality >= 2 and itemQuality <= 4 then
        if itemLevel and itemLevel > 4 then
            return true, "Disenchant"
        end
    end

    return false, nil
end

function private.crafting.isItemDangerous(link, itemId)
    local itemEquipLoc = select(9, C_Item.GetItemInfo(link))
    if not itemEquipLoc or itemEquipLoc == "" then return false end

    local inventorySlotId = nil
    if itemEquipLoc == "INVTYPE_HEAD" then inventorySlotId = 1
    elseif itemEquipLoc == "INVTYPE_NECK" then inventorySlotId = 2
    elseif itemEquipLoc == "INVTYPE_SHOULDER" then inventorySlotId = 3
    elseif itemEquipLoc == "INVTYPE_CHEST" or itemEquipLoc == "INVTYPE_ROBE" then inventorySlotId = 5
    elseif itemEquipLoc == "INVTYPE_WAIST" then inventorySlotId = 6
    elseif itemEquipLoc == "INVTYPE_LEGS" then inventorySlotId = 7
    elseif itemEquipLoc == "INVTYPE_FEET" then inventorySlotId = 8
    elseif itemEquipLoc == "INVTYPE_WRIST" then inventorySlotId = 9
    elseif itemEquipLoc == "INVTYPE_HAND" then inventorySlotId = 10
    elseif itemEquipLoc == "INVTYPE_FINGER" then inventorySlotId = 11
    elseif itemEquipLoc == "INVTYPE_TRINKET" then inventorySlotId = 13
    elseif itemEquipLoc == "INVTYPE_CLOAK" then inventorySlotId = 15
    elseif itemEquipLoc == "INVTYPE_WEAPON" or itemEquipLoc == "INVTYPE_2HWEAPON" or itemEquipLoc == "INVTYPE_WEAPONMAINHAND" then inventorySlotId = 16
    elseif itemEquipLoc == "INVTYPE_SHIELD" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND" or itemEquipLoc == "INVTYPE_HOLDABLE" then inventorySlotId = 17
    end

    if not inventorySlotId then return false end

    local detailedILvl = C_Item.GetDetailedItemLevelInfo(link)
    if not detailedILvl then return false end

    local function getSlotILvl(slot)
        local l = GetInventoryItemLink("player", slot)
        if not l then return 0 end
        return C_Item.GetDetailedItemLevelInfo(l) or 0
    end

    local equippedILvl = getSlotILvl(inventorySlotId)
    if inventorySlotId == 11 then equippedILvl = math.min(equippedILvl, getSlotILvl(12)) end
    if inventorySlotId == 13 then equippedILvl = math.min(equippedILvl, getSlotILvl(14)) end

    if detailedILvl >= equippedILvl then
        return true
    end
    return false
end

function private.crafting.updateDestroyQueue()
    if InCombatLockdown() then return end

    if not _G.AscensionProfHelperUI or not _G.AscensionProfHelperUI:IsVisible() then
        private.crafting.currentTargetItem = nil
        if _G.AscensionMassDestroyBtn then
            _G.AscensionMassDestroyBtn:SetAttribute("macrotext", "")
            _G.AscensionMassDestroyBtn:Hide()
        end
        if _G.AscensionMassDestroyOverlayBtn then
            _G.AscensionMassDestroyOverlayBtn:Hide()
        end
        return
    end

    local activeTab = 1
    if _G.AscensionProfHelperUI and _G.AscensionProfHelperUI.tabbedUI then
        activeTab = _G.AscensionProfHelperUI.tabbedUI:getActiveTab()
    end

    local tabCategoryMap = {
        [1] = "Disenchant",
        [2] = "Milling",
        [3] = "Prospecting"
    }

    local targetCategory = tabCategoryMap[activeTab]
    if not targetCategory then
        private.crafting.currentTargetItem = nil
        massDestroyButton:SetAttribute("macrotext", "")
        massDestroyButton:SetAttribute("macrotext1", "")
        massDestroyButton:SetAttribute("*macrotext1", "")
        massDestroyButton:SetAttribute("macrotext-down", "")
        massDestroyButton:SetAttribute("macrotext1-down", "")
        massDestroyButton:SetAttribute("*macrotext1-down", "")
        massDestroyButton:Hide()
        if _G.AscensionMassDestroyOverlayBtn then _G.AscensionMassDestroyOverlayBtn:Hide() end
        return
    end

    local foundItems = {}
    local orderedLinks = {}
    local targetBag, targetSlot, targetSpell, targetItem = nil, nil, nil, nil

    for bagIndex = 0, 4 do
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            local itemInfo = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
            if itemInfo and itemInfo.itemID and not itemInfo.isLocked then
                local isDestroyable, spellName = private.crafting.isItemDestroyable(bagIndex, slotIndex, itemInfo.itemID)
                if isDestroyable and spellName == targetCategory then
                    local link = itemInfo.hyperlink
                    if link then
                        if not foundItems[link] then
                            foundItems[link] = { count = 0, itemId = itemInfo.itemID }
                            table.insert(orderedLinks, link)
                        end
                        foundItems[link].count = foundItems[link].count + 1

                        local isDangerous = private.crafting.isItemDangerous(link, itemInfo.itemID)
                        foundItems[link].isDangerous = isDangerous

                        if not targetBag and (not isDangerous or private.crafting.allowedDangerousItems[itemInfo.itemID]) then
                            targetBag = bagIndex
                            targetSlot = slotIndex
                            targetSpell = spellName
                            targetItem = itemInfo.itemID
                        end
                    end
                end
            end
        end
    end

    local activePanel = categoryPanels[activeTab]
    if activePanel then
        for _, f in ipairs(itemFrames) do f:Hide() end
        local y = -5
        local i = 1
        for _, link in ipairs(orderedLinks) do
            local data = foundItems[link]
            local count = data.count
            local id = data.itemId
            local f = itemFrames[i]
            if not f then
                f = CreateFrame("Button", nil, activePanel, "BackdropTemplate")
                f:SetHeight(40)
                f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                f:SetBackdropColor(0, 0, 0, 0.3)
                f:SetScript("OnEnter", function() f:SetBackdropColor(0.2, 0.2, 0.2, 0.8) end)
                f:SetScript("OnLeave", function() f:SetBackdropColor(0, 0, 0, 0.3) end)

                local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("LEFT", 10, 0)
                text:SetJustifyH("LEFT")
                text:SetWordWrap(false)
                f.text = text

                local ilvlText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                ilvlText:SetPoint("RIGHT", -10, 0)
                ilvlText:SetJustifyH("RIGHT")
                ilvlText:SetTextColor(0.7, 0.7, 0.7)
                f.ilvlText = ilvlText

                text:SetPoint("RIGHT", ilvlText, "LEFT", -10, 0)

                f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                f:SetScript("OnClick", function(self, button)
                    if self.isDangerous and not private.crafting.allowedDangerousItems[self.itemId] then
                        StaticPopupDialogs["ASCENSION_HANDLE_DANGEROUS"] = {
                            text = "This item might be an upgrade. Do you want to delete it or blacklist it?",
                            button1 = "Delete",
                            button2 = "Blacklist",
                            button3 = "Cancel",
                            OnAccept = function()
                                private.crafting.allowedDangerousItems[self.itemId] = true
                                private.crafting.updateDestroyQueue()
                            end,
                            OnCancel = function(popup, data, reason)
                                if reason == "clicked" then
                                    AscensionQoLDB.profHelper.blacklist[self.itemId] = true
                                    private.crafting.updateDestroyQueue()
                                end
                            end,
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true,
                        }
                        StaticPopup_Show("ASCENSION_HANDLE_DANGEROUS")
                    elseif button == "RightButton" then
                        local lib = LibStub("AscensionSuit-UI", true)
                        if lib and lib.UX and lib.UX.showContextMenu then
                            lib.UX:showContextMenu(self, {
                                {
                                    text = "Blacklist Item",
                                    func = function()
                                        AscensionQoLDB.profHelper.blacklist[f.itemId] = true
                                        profLog("Blacklisted item " .. f.itemId)
                                        private.crafting.updateDestroyQueue()
                                    end
                                }
                            })
                        end
                    end
                end)
                table.insert(itemFrames, f)
            end

            f:SetParent(activePanel)
            f.itemId = id
            f.isDangerous = data.isDangerous
            if f.isDangerous and not private.crafting.allowedDangerousItems[id] then
                f:SetBackdropBorderColor(1, 0, 0, 1)
            else
                f:SetBackdropBorderColor(0, 0, 0, 0)
            end
            local detailedILvl = C_Item.GetDetailedItemLevelInfo(link)
            local icon = C_Item.GetItemIconByID(id)
            local iconStr = icon and ("|T" .. icon .. ":30:30|t ") or ""
            f.text:SetText(count .. "x " .. iconStr .. link)
            f.ilvlText:SetText(detailedILvl and ("iLvl " .. detailedILvl) or "")
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 10, y)
            f:SetPoint("RIGHT", activePanel, "RIGHT", -10, y)
            f:Show()
            y = y - 45
            i = i + 1
        end
        activePanel:SetHeight(math.abs(y) + 60)
    end

    if targetBag and targetSlot and targetSpell and targetCategory then
        private.crafting.currentTargetItem = targetItem

        local castSpellName = targetSpell
        if targetSpell == "Disenchant" then
            local spellInfo = C_Spell.GetSpellInfo(13262)
            castSpellName = spellInfo and spellInfo.name or "Disenchant"
        elseif targetSpell == "Milling" then
            local spellInfo = C_Spell.GetSpellInfo(51005)
            castSpellName = spellInfo and spellInfo.name or "Milling"
        elseif targetSpell == "Prospecting" then
            local spellInfo = C_Spell.GetSpellInfo(31252)
            castSpellName = spellInfo and spellInfo.name or "Prospecting"
        end

        massDestroyButton:SetAttribute("type", "macro")
        massDestroyButton:SetAttribute("type1", "macro")
        massDestroyButton:SetAttribute("*type1", "macro")
        massDestroyButton:SetAttribute("type-down", "macro")
        massDestroyButton:SetAttribute("type1-down", "macro")
        massDestroyButton:SetAttribute("*type1-down", "macro")

        local text = "/cast " .. castSpellName .. "\n/use " .. targetBag .. " " .. targetSlot
        massDestroyButton:SetAttribute("macrotext", text)
        massDestroyButton:SetAttribute("macrotext1", text)
        massDestroyButton:SetAttribute("*macrotext1", text)
        massDestroyButton:SetAttribute("macrotext-down", text)
        massDestroyButton:SetAttribute("macrotext1-down", text)
        massDestroyButton:SetAttribute("*macrotext1-down", text)

        if not private.crafting.sessionConfirmed then
            massDestroyButton:Hide()
            if _G.AscensionMassDestroyOverlayBtn then _G.AscensionMassDestroyOverlayBtn:Show() end
        else
            if _G.AscensionMassDestroyOverlayBtn then _G.AscensionMassDestroyOverlayBtn:Hide() end
            massDestroyButton:Show()
        end
    else
        private.crafting.currentTargetItem = nil
        massDestroyButton:SetAttribute("macrotext", "")
        massDestroyButton:SetAttribute("macrotext1", "")
        massDestroyButton:SetAttribute("*macrotext1", "")
        massDestroyButton:SetAttribute("macrotext-down", "")
        massDestroyButton:SetAttribute("macrotext1-down", "")
        massDestroyButton:SetAttribute("*macrotext1-down", "")
        massDestroyButton:Hide()
        if _G.AscensionMassDestroyOverlayBtn then _G.AscensionMassDestroyOverlayBtn:Hide() end
    end
end

local bagEventFrame = CreateFrame("Frame")
bagEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagEventFrame:RegisterEvent("BAG_UPDATE")
bagEventFrame:SetScript("OnEvent", function()
    private.crafting.updateDestroyQueue()
end)

local errorEventFrame = CreateFrame("Frame")
errorEventFrame:RegisterEvent("UI_ERROR_MESSAGE")
errorEventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    local msg = ""
    if type(arg2) == "string" then
        msg = arg2
    elseif type(arg1) == "string" then
        msg = arg1
    end

    local lowerMsg = string.lower(msg)
    local isDestroyError = false

    if msg == ERR_NOT_DISENCHANTABLE then isDestroyError = true end
    if msg == (ERR_SPELL_FAILED_SKILL_LINE_NOT_KNOWN or "") then isDestroyError = true end

    if string.find(lowerMsg, "disenchant") or string.find(lowerMsg, "desencantar") then isDestroyError = true end
    if string.find(lowerMsg, "mill") or string.find(lowerMsg, "moler") then isDestroyError = true end
    if string.find(lowerMsg, "prospect") or string.find(lowerMsg, "prospectar") then isDestroyError = true end
    if string.find(lowerMsg, "skill") or string.find(lowerMsg, "habilidad") then isDestroyError = true end
    if string.find(lowerMsg, "invalid target") or string.find(lowerMsg, "objetivo no válido") then isDestroyError = true end

    if isDestroyError and private.crafting.currentTargetItem then
        AscensionQoLDB.profHelper.blacklist[private.crafting.currentTargetItem] = true
        profLog("Auto-blacklisted on server rejection: " .. msg)
        private.crafting.updateDestroyQueue()
        if UIErrorsFrame then UIErrorsFrame:Clear() end
    end
end)

local function createProfHelperUI()
    if not private:isModuleEnabled("AscensionProfessionHelper") then return end

    local lib = LibStub and LibStub:GetLibrary("AscensionSuit-UI", true)
    if not lib then return end

    local ctx = lib:CreateContext()

    local buildFuncs = {
        function(panel) categoryPanels[1] = panel.content end,
        function(panel) categoryPanels[2] = panel.content end,
        function(panel) categoryPanels[3] = panel.content end,
        function(panel)
            categoryPanels[4] = panel.content

            local searchBox = CreateFrame("EditBox", nil, panel.content, "InputBoxTemplate")
            searchBox:SetSize(200, 30)
            searchBox:SetPoint("TOPLEFT", 10, -10)
            searchBox:SetAutoFocus(false)
            searchBox:SetScript("OnTextChanged", function(self)
                searchFilter = self:GetText()
                private.crafting.updateBlacklistUI()
            end)

            local label = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 0, 2)
            label:SetText("Search Blacklist:")

            private.crafting.updateBlacklistUI()
        end,
        function(panel)
            categoryPanels[5] = panel.content

            local title = panel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            title:SetPoint("TOPLEFT", 10, -10)
            title:SetText("Options & Macro")

            local desc1 = panel.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            desc1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
            desc1:SetPoint("RIGHT", panel.content, "RIGHT", -20, 0)
            desc1:SetJustifyH("LEFT")
            desc1:SetWordWrap(true)
            desc1:SetText("Blizzard's interface does not permit automatic casting. You must click manually.")

            local desc2 = panel.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            desc2:SetPoint("TOPLEFT", desc1, "BOTTOMLEFT", 0, -10)
            desc2:SetPoint("RIGHT", panel.content, "RIGHT", -20, 0)
            desc2:SetJustifyH("LEFT")
            desc2:SetWordWrap(true)
            desc2:SetText("However, you can bind the button to your mouse wheel to speed it up!")

            local desc3 = panel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            desc3:SetPoint("TOPLEFT", desc2, "BOTTOMLEFT", 0, -15)
            desc3:SetPoint("RIGHT", panel.content, "RIGHT", -20, 0)
            desc3:SetJustifyH("LEFT")
            desc3:SetWordWrap(true)
            desc3:SetText("Select your preferred modifier and direction below, then click Apply Bind.")

            local profHelperDB = AscensionQoLDB.profHelper

            local modDrop = ctx:createDropdown({
                parent = panel.content,
                text = "Modifier",
                options = {
                    { label = "SHIFT", value = "SHIFT" },
                    { label = "CTRL",  value = "CTRL"  },
                    { label = "ALT",   value = "ALT"   },
                    { label = "CMD",   value = "META"  },
                },
                getter = function() return profHelperDB.macroMod or "SHIFT" end,
                setter = function(val) profHelperDB.macroMod = val end,
                width = 220
            })
            modDrop:ClearAllPoints()
            modDrop:SetPoint("TOPLEFT", desc3, "BOTTOMLEFT", 10, -20)

            local dirDrop = ctx:createDropdown({
                parent = panel.content,
                text = "Direction",
                options = {
                    { label = "UP",   value = "MOUSEWHEELUP"   },
                    { label = "DOWN", value = "MOUSEWHEELDOWN" },
                },
                getter = function() return profHelperDB.macroDir or "MOUSEWHEELUP" end,
                setter = function(val) profHelperDB.macroDir = val end,
                width = 220
            })
            dirDrop:ClearAllPoints()
            dirDrop:SetPoint("TOPLEFT", modDrop, "BOTTOMLEFT", 0, -10)

            local bindBtn = ctx:createButton({
                parent = panel.content,
                text = "Apply Bind",
                width = 220,
                height = 40,
                onClick = function()
                    if not InCombatLockdown() then
                        if profHelperDB.lastBind then
                            SetBinding(profHelperDB.lastBind, nil)
                        end
                        local bindStr = (profHelperDB.macroMod or "SHIFT") .. "-" .. (profHelperDB.macroDir or "MOUSEWHEELUP")
                        profHelperDB.lastBind = bindStr
                        if _G.AscensionProfHelperUI then
                            SetOverrideBindingClick(_G.AscensionProfHelperUI, true, bindStr, "AscensionMassDestroyBtn", "LeftButton")
                        end
                        profLog("Bound " .. bindStr .. " to Destroy Button!")
                    end
                end
            })
            bindBtn:ClearAllPoints()
            bindBtn:SetPoint("TOPLEFT", dirDrop, "BOTTOMLEFT", 0, -20)

            local unbindBtn = ctx:createButton({
                parent = panel.content,
                text = "Remove Bind",
                width = 220,
                height = 40,
                onClick = function()
                    if not InCombatLockdown() then
                        if profHelperDB.lastBind then
                            if _G.AscensionProfHelperUI then
                                ClearOverrideBindings(_G.AscensionProfHelperUI)
                            end
                            profLog("Removed bind: " .. profHelperDB.lastBind)
                            profHelperDB.lastBind = nil
                        end
                    end
                end
            })
            unbindBtn:ClearAllPoints()
            unbindBtn:SetPoint("TOPLEFT", bindBtn, "BOTTOMLEFT", 0, -10)
        end
    }

    local mainFrame = ctx:createMainFrame({
        name     = "AscensionProfessionHelperFrame",
        title    = "Ascension Profession Helper",
        tabNames = { "Disenchant", "Milling", "Prospecting", "Blacklist", "Options" },
        tabFuncs = buildFuncs,
        width    = 450,
        height   = 400
    })

    if mainFrame.frame and mainFrame.frame.SetResizeBounds then
        mainFrame.frame:SetResizeBounds(400, 300, 2000, 2000)
    end

    _G.AscensionProfHelperUI = mainFrame

    if mainFrame.tabbedUI then
        for i, panel in ipairs(mainFrame.tabbedUI.panels) do
            panel:SetPoint("BOTTOMRIGHT", -10, 70)
            panel:HookScript("OnShow", function()
                if i == 4 then
                    private.crafting.updateBlacklistUI()
                    if _G.AscensionMassDestroyBtn then _G.AscensionMassDestroyBtn:Hide() end
                    if _G.AscensionMassDestroyOverlayBtn then _G.AscensionMassDestroyOverlayBtn:Hide() end
                elseif i == 5 then
                    if _G.AscensionMassDestroyBtn then _G.AscensionMassDestroyBtn:Hide() end
                    if _G.AscensionMassDestroyOverlayBtn then _G.AscensionMassDestroyOverlayBtn:Hide() end
                else
                    private.crafting.updateDestroyQueue()
                end
            end)
        end
    end

    local styles = ctx.styles
    massDestroyButton:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    massDestroyButton:SetBackdropColor(unpack(styles.colors.surfaceLight or {0.2, 0.2, 0.2, 1}))
    massDestroyButton:SetBackdropBorderColor(unpack(styles.colors.blackDetail or {0, 0, 0, 1}))

    local btnText = massDestroyButton:CreateFontString(nil, "OVERLAY", styles.fonts.label or "GameFontNormal")
    btnText:SetPoint("CENTER", 0, 0)
    btnText:SetText("Destroy Next")
    btnText:SetTextColor(unpack(styles.colors.textLight or {1, 1, 1, 1}))
    massDestroyButton:SetFontString(btnText)

    massDestroyButton:SetScript("OnEnter", function(self)
        if styles.colors.primary then self:SetBackdropColor(unpack(styles.colors.primary)) end
        if styles.colors.textLight then self:SetBackdropBorderColor(unpack(styles.colors.textLight)) end
    end)
    massDestroyButton:SetScript("OnLeave", function(self)
        if styles.colors.surfaceLight then self:SetBackdropColor(unpack(styles.colors.surfaceLight)) end
        if styles.colors.blackDetail then self:SetBackdropBorderColor(unpack(styles.colors.blackDetail)) end
    end)
    massDestroyButton:SetScript("OnMouseDown", function(self) btnText:SetPoint("CENTER", 1, -1) end)
    massDestroyButton:SetScript("OnMouseUp", function(self) btnText:SetPoint("CENTER", 0, 0) end)

    if _G.AscensionMassDestroyOverlayBtn then
        _G.AscensionMassDestroyOverlayBtn:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        _G.AscensionMassDestroyOverlayBtn:SetBackdropColor(unpack(styles.colors.surfaceLight or {0.2, 0.2, 0.2, 1}))
        _G.AscensionMassDestroyOverlayBtn:SetBackdropBorderColor(unpack(styles.colors.blackDetail or {0, 0, 0, 1}))
        local overlayText = _G.AscensionMassDestroyOverlayBtn:CreateFontString(nil, "OVERLAY", styles.fonts.label or "GameFontNormal")
        overlayText:SetPoint("CENTER", 0, 0)
        overlayText:SetText("Start Destroy")
        overlayText:SetTextColor(unpack(styles.colors.textLight or {1, 1, 1, 1}))
        _G.AscensionMassDestroyOverlayBtn:SetFontString(overlayText)
        _G.AscensionMassDestroyOverlayBtn:SetScript("OnEnter", massDestroyButton:GetScript("OnEnter"))
        _G.AscensionMassDestroyOverlayBtn:SetScript("OnLeave", massDestroyButton:GetScript("OnLeave"))
        _G.AscensionMassDestroyOverlayBtn:SetScript("OnMouseDown", function(self) overlayText:SetPoint("CENTER", 1, -1) end)
        _G.AscensionMassDestroyOverlayBtn:SetScript("OnMouseUp", function(self) overlayText:SetPoint("CENTER", 0, 0) end)
    end

    massDestroyButton:SetParent(mainFrame)
    massDestroyButton:SetPoint("BOTTOM", mainFrame, "BOTTOMLEFT", 300, 20)

    if _G.AscensionMassDestroyOverlayBtn then
        _G.AscensionMassDestroyOverlayBtn:SetParent(mainFrame)
        _G.AscensionMassDestroyOverlayBtn:SetPoint("BOTTOM", mainFrame, "BOTTOMLEFT", 300, 20)
    end

    mainFrame:HookScript("OnShow", function()
        private.crafting.sessionConfirmed = false
        local profHelperDB = AscensionQoLDB.profHelper
        if profHelperDB.lastBind then
            SetOverrideBindingClick(mainFrame, true, profHelperDB.lastBind, "AscensionMassDestroyOverlayBtn", "LeftButton")
        end
        private.crafting.updateDestroyQueue()
    end)
    mainFrame:HookScript("OnHide", function()
        ClearOverrideBindings(mainFrame)
    end)

    _G.SLASH_ASCENSIONPROF1 = "/aph"
    _G.SlashCmdList["ASCENSIONPROF"] = function() mainFrame:Show() end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        AscensionQoLDB.profHelper = AscensionQoLDB.profHelper or {}
        AscensionQoLDB.profHelper.blacklist = AscensionQoLDB.profHelper.blacklist or {}
        createProfHelperUI()
    end
end)
