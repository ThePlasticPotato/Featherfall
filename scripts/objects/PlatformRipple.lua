---@class PlatformRipple : Object
local PlatformRipple, super = Class(Object)

local function gmColorToRGB(color)
    color = tonumber(color) or 16777215
    local r = math.floor(color / 65536) % 256
    local g = math.floor(color / 256) % 256
    local b = color % 256
    return r / 255, g / 255, b / 255
end

function PlatformRipple:init(x, y, options)
    super.init(self, x, y)
    options = options or {}

    self.life = options.life or 60
    self.lifemax = self.life
    self.rad = options.radstart or 1
    self.radstart = self.rad
    self.radmax = options.radmax or 160
    self.thickness = options.thickness or 15
    self.curve = options.curve or 0
    self.yratio = options.yratio or 1
    self.blend = options.blend or 0
    self.banding = options.banding or 0
    self.fading = options.fading ~= false
    self.hsp = options.hsp or 0
    self.vsp = options.vsp or 0
    self.fric = options.fric or 0.1
    self:setColorFromGM(options.color)
    self.layer = options.layer or WORLD_LAYERS["above_events"]
    self:setOrigin(0.5, 0.5)
end

function PlatformRipple:setColorFromGM(color)
    self.r, self.g, self.b = gmColorToRGB(color)
end

function PlatformRipple:evaluateCurve(progress)
    progress = MathUtils.clamp(progress, 0, 1)
    if self.curve == 7 then
        return 1 - progress
    elseif self.curve == 8 then
        return progress * progress
    end
    return progress
end

function PlatformRipple:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    self.life = MathUtils.approach(self.life, 0, DTMULT)
    self.x = self.x + (self.hsp * DTMULT)
    self.y = self.y + (self.vsp * DTMULT)
    self.hsp = MathUtils.approach(self.hsp, 0, self.fric * DTMULT)
    self.vsp = MathUtils.approach(self.vsp, 0, self.fric * DTMULT)

    if self.life <= 0 then
        self:remove()
    end
end

function PlatformRipple:getProgress()
    return self:evaluateCurve(1 - (self.life / math.max(self.lifemax, 1)))
end

function PlatformRipple:draw()
    local progress = self:getProgress()
    local radius = MathUtils.lerp(self.radstart, self.radmax, progress)
    local thickness = MathUtils.lerp(self.thickness, 0, progress)
    if radius <= 0 or thickness <= 0 then
        return
    end

    local alpha = 1
    if self.fading then
        local fade_start = self.radmax / 3
        alpha = MathUtils.clamp(1 - ((radius - fade_start) / math.max(self.radmax - fade_start, 1)), 0, 1)
    end
    local old_width = love.graphics.getLineWidth()
    local old_blend, old_alpha = love.graphics.getBlendMode()

    if self.blend == 1 then
        love.graphics.setBlendMode("add", "alphamultiply")
    end

    love.graphics.setLineWidth(math.max(thickness * 0.5, 1))
    Draw.setColor(self.r, self.g, self.b, alpha)
    love.graphics.ellipse("line", 0, 0, radius, radius * self.yratio)

    love.graphics.setLineWidth(old_width)
    love.graphics.setBlendMode(old_blend, old_alpha)
    Draw.setColor(1, 1, 1, 1)
end

return PlatformRipple
