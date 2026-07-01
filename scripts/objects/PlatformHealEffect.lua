---@class PlatformHealEffect : Object
local PlatformHealEffect, super = Class(Object)

local PARTICLE_SPRITE = "effects/spare/star"
local PARTICLE_COLOR = {0, 1, 0}

function PlatformHealEffect:init(target, options)
    if type(target) == "number" then
        options = {x = target, y = options}
        target = nil
    elseif type(options) ~= "table" then
        options = {}
    end

    local x = options.x or (target and target.x) or 0
    local y = options.y or (target and target.y) or 0
    super.init(self, x, y)

    self.target = target
    self.effect_x = x
    self.effect_y = y
    self.effect_width = options.width or (target and target.width) or 24
    self.effect_height = options.height or (target and target.height) or 24
    self.timer = 0
    self.stars = {}
    self.layer = options.layer or WORLD_LAYERS["above_events"] + 1
end

function PlatformHealEffect:random(width)
    return love.math.random() * (width or 1)
end

function PlatformHealEffect:spawnStar()
    local frames = Assets.getFrames(PARTICLE_SPRITE)
    local texture = frames and frames[1] or Assets.getTexture(PARTICLE_SPRITE)
    table.insert(self.stars, {
        x = self.effect_x + self:random(self.effect_width),
        y = self.effect_y + self:random(self.effect_height),
        hspeed = 2 - self:random(2),
        vspeed = -3 - self:random(2),
        friction = 0.2,
        angle = self:random(360),
        alpha = 2,
        frame = 1,
        frame_timer = 0,
        texture = texture,
    })
end

function PlatformHealEffect:updateStar(star)
    star.x = star.x + (star.hspeed * DTMULT)
    star.y = star.y + (star.vspeed * DTMULT)

    local friction = star.friction * DTMULT
    if math.abs(star.hspeed) <= friction then
        star.hspeed = 0
    else
        star.hspeed = star.hspeed - (MathUtils.sign(star.hspeed) * friction)
    end
    if math.abs(star.vspeed) <= friction then
        star.vspeed = 0
    else
        star.vspeed = star.vspeed - (MathUtils.sign(star.vspeed) * friction)
    end

    star.frame_timer = star.frame_timer + (0.25 * DTMULT)
    local frames = Assets.getFrames(PARTICLE_SPRITE)
    if frames and #frames > 0 then
        star.frame = ((math.floor(star.frame_timer) % #frames) + 1)
        star.texture = frames[star.frame]
    end
end

function PlatformHealEffect:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.timer = self.timer + DTMULT

    if self.target and self.target.parent then
        self.effect_x = self.target.x
        self.effect_y = self.target.y
        self.effect_width = self.target.width or self.effect_width
        self.effect_height = self.target.height or self.effect_height
    end

    local previous = self.timer - DTMULT
    for frame = math.floor(previous) + 1, math.floor(self.timer) do
        if frame >= 1 and frame <= 5 then
            self:spawnStar()
            self:spawnStar()
        end
    end

    for index = #self.stars, 1, -1 do
        local star = self.stars[index]
        self:updateStar(star)
        if self.timer >= 5 then
            star.angle = star.angle - (10 * DTMULT)
            star.alpha = star.alpha - (0.1 * DTMULT)
            if star.alpha <= 0 then
                table.remove(self.stars, index)
            end
        end
    end

    if self.timer >= 30 then
        self:remove()
    end
end

function PlatformHealEffect:draw()
    for _, star in ipairs(self.stars) do
        if star.texture then
            Draw.setColor(PARTICLE_COLOR[1], PARTICLE_COLOR[2], PARTICLE_COLOR[3], star.alpha)
            Draw.draw(star.texture, star.x - self.x, star.y - self.y, math.rad(star.angle), 2, 2, star.texture:getWidth() / 2, star.texture:getHeight() / 2)
        end
    end
    Draw.setColor(1, 1, 1, 1)
end

-- _G.PlatformHealEffect = PlatformHealEffect

return PlatformHealEffect
