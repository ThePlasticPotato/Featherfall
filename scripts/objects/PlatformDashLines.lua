---@class PlatformDashLines : Object
local PlatformDashLines, super = Class(Object)

function PlatformDashLines:init(owner, xspeed)
    super.init(self, 0, 0)
    self.owner = owner
    self.sprite_path = "world/platform/torii/dashlines"
    self.timer = 0
    self.xspeed = xspeed or -15
    self.fadespeed = 0.2
    self.alpha = 0
    self.draw_alpha = 0.35
end

function PlatformDashLines:applyTransformTo(transform)
    if self.parent then
        transform:reset()
    end
    super.applyTransformTo(self, transform)
end

function PlatformDashLines:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    self.timer = self.timer + (self.xspeed * DTMULT)

    self.alpha = self.alpha + (self.fadespeed * DTMULT)
    if self.alpha > 1 then
        self.fadespeed = 0
        self.alpha = 1
    elseif self.alpha <= 0 then
        self:remove()
        return
    end

    local owner = self.owner
    local owner_state = owner and owner.platform_state
    if not (owner and owner.parent and owner_state and owner_state.dashing) then
        self.fadespeed = -0.1
    end
end

function PlatformDashLines:draw()
    local texture = Assets.getTexture(self.sprite_path) or (Assets.getFrames(self.sprite_path) or {})[1]
    if not texture then
        return
    end

    local shader = Assets.getShader("platform_dashblend")
    local last_shader = love.graphics.getShader()
    love.graphics.setBlendMode("add")
    Draw.setColor(1, 1, 1, (self.alpha or 0) * self.draw_alpha)

    if shader then
        love.graphics.setShader(shader)
        shader:send("iTime", self.timer * 0.0015)
    end
    Draw.draw(texture, 0, 0, 0, 1, 1)

    if shader then
        shader:send("iTime", 14.123553 + (self.timer * 0.0015))
    end
    Draw.draw(texture, 0, 360, 0, 1, 1)

    if shader then
        love.graphics.setShader(last_shader)
    end
    Draw.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
end

return PlatformDashLines
