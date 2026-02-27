-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: Core.lua
-- Version: 01
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------

local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Global DB for the entire AddOn
---@diagnostic disable-next-line: undefined-global
local AscensionQoLDB = AscensionQoLDB

local defaults = {
    profile = {
        modules = {
            ["AscensionSound"] = true,
        },
    },
}

function addon:OnInitialize()
    -- Initialize Database
    self.db = LibStub("AceDB-3.0"):New("AscensionQoLDB", defaults, true)

    -- Register Options
    self:SetupOptions()

    -- Print welcome message
    self:Print("Central Hub initialized. Use /aqol to open settings.")
end

function addon:SetupOptions()
    local options = {
        name = "Ascension QoL",
        handler = addon,
        type = "group",
        args = {
            desc = {
                type = "description",
                name = "The central hub for all Ascension add-ons and Quality of Life features.",
                order = 1,
            },
            modules = {
                type = "group",
                name = "Modules",
                guiInline = true,
                order = 10,
                args = {
                    -- We will dynamically/statically register modules here
                    ascensionSound = {
                        type = "toggle",
                        name = "Ascension Sound",
                        desc = "Enable or disable the Sound Control module.",
                        get = function(info) return self.db.profile.modules["AscensionSound"] end,
                        set = function(info, value)
                            self.db.profile.modules["AscensionSound"] = value
                            self:UpdateModuleState("AscensionSound", value)
                        end,
                        order = 1,
                    },
                },
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("AscensionQoL", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AscensionQoL", "Ascension QoL")

    -- Slash command to open options
    self:RegisterChatCommand("aqol", function()
        LibStub("AceConfigDialog-3.0"):Open("AscensionQoL")
    end)
    self:RegisterChatCommand("ascensionqol", function()
        LibStub("AceConfigDialog-3.0"):Open("AscensionQoL")
    end)
end

function addon:UpdateModuleState(moduleName, enabled)
    if enabled then
        self:Print(string.format("Module |cff00ff00%s|r enabled (requires UI Reload to take full effect).", moduleName))
    else
        self:Print(string.format("Module |cffff0000%s|r disabled (requires UI Reload to take full effect).", moduleName))
    end
end

-- Helper for modules to check if they should load
function addon:IsModuleEnabled(moduleName)
    if not self.db then return true end -- Default to true if DB isn't ready
    return self.db.profile.modules[moduleName] ~= false
end
