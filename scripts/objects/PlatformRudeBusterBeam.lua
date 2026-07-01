---@class PlatformRudeBusterBeam : Sprite
local PlatformRudeBusterBeam, super = Class(Sprite)

function PlatformRudeBusterBeam:init(x, y, target, after, options)
    options = options or {}
    self.red = options.red == true
    super.init(self, self.red and "effects/rudebuster/beam_red" or "effects/rudebuster/beam", x, y)

    self:setOrigin(0.5, 0.5)
    self:setScale(self.red and 2.5 or 2)
    self:play(1 / 30, true)

    self.target = target
    self.after_func = after
    self.alpha = 0
    self.t = 0
    self.bolt_timer = 0
    self.explode = false
    self.afterimage_timer = 0
    self.interim_target_reached = options.interim_target_reached ~= false
    self.interim_target_x = options.interim_target_x or 0
end

function PlatformRudeBusterBeam:getTargetPosition()
    local target = self.target
    if target and target.parent then
        local cx = target.cx or target.target_x or (target.x + ((target.width or 0) / 2))
        local cy = target.cy or target.target_y or (target.y + ((target.height or 0) / 2))
        if not self.interim_target_reached then
            return cx + self.interim_target_x, cy - 60
        end
        return cx, cy
    end
    return self.x + ((self.physics.speed_x or 0) * 2), self.y + ((self.physics.speed_y or 0) * 2)
end

function PlatformRudeBusterBeam:spawnAfterimage()
    local sprite = Sprite(self.red and "effects/rudebuster/beam_red" or "effects/rudebuster/beam", self.x, self.y)
    sprite:fadeOutSpeedAndRemove()
    sprite:setOrigin(0.5, 0.5)
    sprite:setScale(self.red and 2.5 or 2, self.red and 2.5 or 1.8)
    sprite.rotation = self.rotation
    sprite.alpha = self.alpha - 0.2
    sprite.layer = self.layer - 0.01
    sprite.graphics.grow_y = -0.1
    sprite.graphics.remove_shrunk = true
    sprite:play(1 / 15, true)
    self.parent:addChild(sprite)
end

function PlatformRudeBusterBeam:hitTarget()
    local tx, ty = self:getTargetPosition()
    if self.after_func then
        self.after_func()
    end
    Assets.playSound("rudebuster_hit")
    for i = 1, 8 do
        local burst = RudeBusterBurst(self.red, tx, ty, math.rad(45 + ((i - 1) * 90)), i > 4, 25)
        burst.layer = self.layer + (0.01 * i)
        self.parent:addChild(burst)
    end
    self:remove()
end

function PlatformRudeBusterBeam:update()
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.alpha = MathUtils.approach(self.alpha, 1, 0.25 * DTMULT)
    local tx, ty = self:getTargetPosition()

    if self.t == 0 then
        self.rotation = Utils.angle(self.x, self.y, tx, ty) + math.rad(20)
        self.physics.speed = 24
        self.physics.friction = -1.5
        self.physics.match_rotation = true
    else
        self.bolt_timer = self.bolt_timer + DTMULT
        local dir = Utils.angle(self.x, self.y, tx, ty)
        local divisor = math.max(4 - ((self.bolt_timer / 60) * 4), 1)
        local angle_diff = MathUtils.angleDiff(dir, self.rotation) / divisor
        if self.bolt_timer > 30 and math.abs(math.deg(angle_diff)) > 90 then
            self.x = tx
            self.y = ty
        else
            self.rotation = self.rotation + (angle_diff * DTMULT)
        end
        if MathUtils.dist(self.x, self.y, tx, ty) <= 40 then
            if self.interim_target_reached then
                self:hitTarget()
                return
            else
                self.interim_target_reached = true
            end
        end
    end

    self.afterimage_timer = self.afterimage_timer + DTMULT
    while self.afterimage_timer >= 1 do
        self.afterimage_timer = self.afterimage_timer - 1
        self:spawnAfterimage()
    end

    self.t = self.t + DTMULT
    super.update(self)
end

return PlatformRudeBusterBeam
