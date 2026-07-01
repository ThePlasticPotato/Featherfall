---@class PlatformTalk : PlatformAttackable
local PlatformAttackable = libRequire("featherfall", "scripts.world.events.platform.attackable")
local PlatformTalk, super = Class(PlatformAttackable)

function PlatformTalk:init(data)
    super.init(self, data)

    self.platform_talk = true
    self.text = self.properties["text"] or self.properties["dialogue"] or "* ..."
    self.once = self.properties["once"] == true
    self.triggered = false
    self.visible = self.properties["visible"] ~= false
end

function PlatformTalk:onPlatformAttack(hitbox)
    if self.once and self.triggered then
        return false
    end
    self.triggered = true
    if hitbox and hitbox.doHit then
        hitbox:doHit()
    end
    Featherfall:showPlatformText(self.text, {
        side = self.properties["side"],
        dynamic_side = self.properties["dynamic_side"] == true,
        actor = self.properties["actor"] or self.properties["speaker"],
        face = self.properties["face"] or self.properties["portrait"],
        small = self.properties["small"] == true,
        skippable = self.properties["skippable"] ~= false,
        draw_bg = self.properties["draw_bg"] ~= false,
        xoff = tonumber(self.properties["xoff"] or self.properties["x"]) or 0,
        yoff = tonumber(self.properties["yoff"] or self.properties["y"]) or 0,
    })
    return true
end

return PlatformTalk
