---@class PetalWing : Object
local PetalWing, super = Class(Object)

local PETAL_SPRITE = "effects/platform/petal/barrier"
local PETAL_METADATA = {
    [PETAL_SPRITE] = {origin_x = 10, origin_y = 10},
}

local function getFrame(path, frame)
    local frames = Assets.getFrames(path)
    if frames and #frames > 0 then
        return frames[math.floor(MathUtils.clamp(frame or 1, 1, #frames))]
    end
    return Assets.getTexture(path)
end

local function easeOutPower(progress, power)
    progress = MathUtils.clamp(progress, 0, 1)
    power = power or 2
    return 1 - ((1 - progress) ^ power)
end

function PetalWing:init(x, y, options)
    options = options or {}
    super.init(self, x, y)

    self.fixate = options.fixate
    self.transition_time = math.max(options.transition_time or (Featherfall and Featherfall.transition_timemax) or 20, 1)
    self.timer = 0
    self.timerstart = options.timerstart == true or options.timerstart == 1
    self.timermax = options.timermax or 300
    self.flash_white = options.flash_white or 15
    self.flash_whitemax = options.flash_whitemax or 15
    self.petals = {}
    self.renderers = {}
    self.layer = options.layer or WORLD_LAYERS["above_events"]
    self.disperse_when_platform = options.disperse_when_platform ~= false

    local count = options.petals or 10
    for index = 0, count - 1 do
        local timex = 50 + love.math.random(0, 20)
        local timey = 50 + love.math.random(0, 20)
        table.insert(self.petals, {
            fx = (2 * math.pi) / timex,
            fy = (2 * math.pi) / timey,
            ff = (2 * math.pi) / (20 + love.math.random(0, 10)),
            rspd = 1 + love.math.random(0, 3),
            bg_side = love.math.random(0, 1) == 0 and -1 or 1,
            t = MathUtils.lerp(0, timex, index / count),
            angle = love.math.random(0, 360),
            ax = 0,
            ay = 0,
            alpha = 1,
            scale = 2,
            image_index = 1,
            dispersed = false,
            speed = 0,
            direction = 0,
            x = x,
            y = y,
            previous_x = x,
            draw_side = love.math.random(0, 1) == 0 and -1 or 1,
        })
    end
end

function PetalWing:getFollowTarget()
    if self.fixate and self.fixate.parent then
        return self.fixate
    end
    return Featherfall and Featherfall.transition_prop or nil
end

function PetalWing:getRenderLayer(side)
    local target = self:getFollowTarget()
    local layer = (target and target.layer) or self.layer
    return layer + ((side or 1) * 0.01)
end

function PetalWing:onAdd(parent)
    super.onAdd(self, parent)
    if not (Game.world and PetalWingRenderer) then
        return
    end

    self.renderers[0] = Game.world:spawnObject(PetalWingRenderer(self, 0), self:getRenderLayer(0))
    self.renderers[-1] = Game.world:spawnObject(PetalWingRenderer(self, -1), self:getRenderLayer(-1))
    self.renderers[1] = Game.world:spawnObject(PetalWingRenderer(self, 1), self:getRenderLayer(1))
end

function PetalWing:disperse()
    for _, petal in ipairs(self.petals) do
        petal.dispersed = true
        petal.direction = MathUtils.angle(self.x, self.y, petal.x or self.x, petal.y or self.y)
        petal.speed = 12
        petal.fade_timer = 15
    end
end

function PetalWing:beginPlatformDisperse()
    if self.timerstart then
        return
    end
    Assets.playSound(Featherfall.sounds.petal_drain, 1, 1.2)
    self.timerstart = true
    self:disperse()
    self.dispersing = true
end

function PetalWing:updatePetal(petal)
    petal.t = petal.t + DTMULT
    petal.previous_x = petal.x or self.x

    if not petal.dispersed then
        local progress = easeOutPower(self.timer / self.transition_time, 2)
        petal.ax = MathUtils.lerp(0, 60, progress)
        petal.ay = MathUtils.lerp(0, 60, progress)
        petal.x = self.x + (math.sin(petal.t * petal.fx) * petal.ax)
        petal.y = self.y + (math.cos(petal.t * petal.fy) * petal.ay)
    else
        petal.x = (petal.x or self.x) + (math.cos(petal.direction) * petal.speed * DTMULT)
        petal.y = (petal.y or self.y) + (math.sin(petal.direction) * petal.speed * DTMULT)
        petal.speed = petal.speed * (0.95 ^ DTMULT)
        petal.speed = MathUtils.approach(petal.speed, 0, 0.2 * DTMULT)
        petal.fade_timer = MathUtils.approach(petal.fade_timer or 0, 0, DTMULT)
        petal.alpha = MathUtils.clamp((petal.fade_timer or 0) / 15, 0, 1)
    end

    local horizontal_sign = MathUtils.sign((petal.x or self.x) - petal.previous_x)
    if horizontal_sign == 0 then
        horizontal_sign = petal.bg_side
    end
    petal.draw_side = horizontal_sign > 0 and -1 or 1

    petal.xscale = math.cos(petal.t * petal.ff) * petal.scale
    petal.yscale = math.sin(petal.t * petal.ff) * petal.scale
    petal.angle = petal.angle + (petal.rspd * DTMULT)
end

function PetalWing:update()
    super.update(self)

    local target = self:getFollowTarget()
	if target and not self.dispersing then
        self.x = target.x
        self.y = target.y
        self.layer = target.layer or self.layer
	end
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    if self.disperse_when_platform and not self.timerstart
        and Featherfall and Game.world and Game.world.player
        and Game.world.player.state == Featherfall.state
        and Featherfall.transition_timer <= 0
    then
        self:beginPlatformDisperse()
    end

    self.timer = self.timer + DTMULT
    self.flash_white = MathUtils.approach(self.flash_white, 0, DTMULT)
    for index = #self.petals, 1, -1 do
        local petal = self.petals[index]
        self:updatePetal(petal)
        if petal.dispersed and petal.alpha <= 0 then
            table.remove(self.petals, index)
        end
    end

    if self.dispersing and #self.petals == 0 then
        self:remove()
    end
end

function PetalWing:onRemove(parent)
    for _, renderer in pairs(self.renderers or {}) do
        if renderer and renderer.parent then
            renderer:remove()
        end
    end
    self.renderers = {}
    if Featherfall and Featherfall.unregisterPetalWing then
        Featherfall:unregisterPetalWing(self)
    end
    super.onRemove(self, parent)
end

function PetalWing:drawPetal(petal)
    local texture = getFrame(PETAL_SPRITE, petal.image_index or 1)
    if not texture then
        return
    end
    local metadata = PETAL_METADATA[PETAL_SPRITE]
    local origin_x = metadata and metadata.origin_x or (texture:getWidth() / 2)
    local origin_y = metadata and metadata.origin_y or (texture:getHeight() / 2)
    local alpha = petal.alpha or 1
    Draw.setColor(1, 1, 1, alpha)
    Draw.draw(
        texture,
        (petal.x or self.x) - self.x,
        (petal.y or self.y) - self.y,
        math.rad(petal.angle or 0),
        petal.xscale or 2,
        petal.yscale or 2,
        origin_x,
        origin_y
    )
    Draw.setColor(1, 1, 1, 1)
end

function PetalWing:drawPetals(side)
    for _, petal in ipairs(self.petals) do
        if side == nil or petal.draw_side == side then
            self:drawPetal(petal)
        end
    end
end

function PetalWing:draw()
end

return PetalWing
