-------------------------------------------------------------------------------
-- Project: AscensionQoL
-- Author: Aka-DoctorCode
-- File: afkdebug.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, private = ...
local AceAddon = LibStub("AceAddon-3.0")
local AscensionAFK = AceAddon:GetAddon("AscensionAFK")

-- Hook OnTimerReachedZero
function AscensionAFK:OnTimerReachedZero()
    if self.debugStatsTimer then return end

    self.profile.debugStats = {
        accumulatedSeconds = 0,
        activationType = self.manualAfk and "manual" or "automatic"
    }

    self.debugStatsTimer = C_Timer.NewTicker(1, function()
        if self.profile and self.profile.debugStats then
            self.profile.debugStats.accumulatedSeconds = self.profile.debugStats.accumulatedSeconds + 1
        end
    end)
end

-- Hook deactivateAfkMode
local originalDeactivate = AscensionAFK.deactivateAfkMode
function AscensionAFK:deactivateAfkMode()
    if self.debugStatsTimer then
        self.debugStatsTimer:Cancel()
        self.debugStatsTimer = nil
    end
    originalDeactivate(self)
end

-- Hook PLAYER_LOGIN to print stats
local originalPlayerLogin = AscensionAFK.PLAYER_LOGIN
function AscensionAFK:PLAYER_LOGIN()
    originalPlayerLogin(self)

    if self.profile and self.profile.debugStats then
        local stats = self.profile.debugStats
        local typeStr = stats.activationType == "manual" and "Manual" or "Automatic"
        C_Timer.After(1, function()
            print(string.format("|cff7f13ecAscension AFK Debug:|r Disconnect timer reached 0, but session did not close. Remained in game for |cff00ff00%d|r seconds. Activation type: |cff00ff00%s|r.", stats.accumulatedSeconds, typeStr))
        end)
        self.profile.debugStats = nil
    end
end
