---@class DarkConfigMenu : DarkConfigMenu
local DarkConfigMenu, super = HookSystem.hookScript(DarkConfigMenu)
function DarkConfigMenu:registerDefaults()
    self:addOption(DarkConfigVolumeOption(self))

    self:addOption(DarkConfigOption(self, "Controls", function()
        self:setState("REBIND")
    end))

    self:addOption(DarkConfigFeatherOption(self, "Feather", function(option)
        Game:setFlag("featherInvertedControls", not Game:getFlag("featherInvertedControls", false))
        option:setInverted(Game:getFlag("featherInvertedControls", false))
    end, Game:getFlag("featherInvertedControls", false)))

    if not Kristal.isForcedFullscreen() then
        self:addOption(DarkConfigBooleanOption(self, "Fullscreen", function(option)
            Kristal.Config["fullscreen"] = not Kristal.Config["fullscreen"]
            love.window.setFullscreen(Kristal.Config["fullscreen"])
            option:setEnabled(Kristal.Config["fullscreen"])
        end, Kristal.Config["fullscreen"]))
    end

    self:addOption(DarkConfigBooleanOption(self, "Auto-Run", function(option)
        Kristal.Config["autoRun"] = not Kristal.Config["autoRun"]
        option:setEnabled(Kristal.Config["autoRun"])
    end, Kristal.Config["autoRun"]))

    if Kristal.isForcedFullscreen() then
        self:addOption(DarkConfigBorderOption(self))
    end
end

return DarkConfigMenu
