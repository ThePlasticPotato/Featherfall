---@class PlatformAttackable : Event
local PlatformAttackable, super = Class(Event)

function PlatformAttackable:init(data)
    super.init(self, data)

    self.properties = data and data.properties or {}
    self.solid = self.properties["solid"] == true
    self.platform_attackable = true
    self.platform_collision = self.properties["platform_collision"] ~= false
    self.can_hit_default = self.properties["can_hit"] ~= false
    self.can_hit = self.can_hit_default
    self.hit = 0
    self.hit_cooldown = self.properties["hit_cooldown"] or 0
    self.attack_cooldown = self.properties["attack_cooldown"] or 0
end

function PlatformAttackable:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    local was_cooling_down = self.hit_cooldown > 0
    self.hit_cooldown = MathUtils.approach(self.hit_cooldown, 0, DTMULT)
    if was_cooling_down and self.hit_cooldown <= 0 then
        self:onPlatformAttackCooldownEnd()
    end
end

function PlatformAttackable:canPlatformAttackHit(hitbox)
    if not self.visible or not self.can_hit or self.hit_cooldown > 0 then
        return false
    end
    if not self.can_hit_default then
        return false
    end
    if not (Game.world and Game.world.player and Game.world.player.state == Featherfall.state) then
        return false
    end
    return true
end

function PlatformAttackable:onPlatformAttackHit(hitbox)
    if not self:canPlatformAttackHit(hitbox) then
        return false
    end
    return self:onPlatformAttack(hitbox)
end

function PlatformAttackable:onPlatformAttack(hitbox)
    self.hit = 1
    if self.attack_cooldown > 0 then
        self.can_hit = false
        self.hit_cooldown = self.attack_cooldown
    end
    if hitbox and hitbox.doHit then
        hitbox:doHit()
    end
    return true
end

function PlatformAttackable:onPlatformAttackCooldownEnd()
    if self.can_hit_default then
        self.can_hit = true
        self.hit = 0
    end
end

return PlatformAttackable
