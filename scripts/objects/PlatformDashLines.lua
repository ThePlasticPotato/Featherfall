---@class PlatformDashLines : Object
local PlatformDashLines, super = Class(Object)

function PlatformDashLines:init(owner, xspeed)
    super.init(self, 0, 0)
    self.owner = owner
    self.sprite_path = "world/platform/torii/dashlines"
    self.timer = 0
    self.xx = 0
    self.xspeed = xspeed or -15
    self.fadespeed = 0.2
    self.alpha = 0
end

function PlatformDashLines:update()
    super.update(self)

    self.xx = self.xx + (self.xspeed * DTMULT)
    local width = 2048
    local texture = Assets.getTexture(self.sprite_path) or (Assets.getFrames(self.sprite_path) or {})[1]
    if texture then
        width = texture:getWidth()
    end
    local max = math.abs(width) * 6
    if math.abs(self.xx) >= max then
        if self.xx > 0 then
            self.xx = self.xx - max
        else
            self.xx = self.xx + max
        end
    end

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

    local camera = Game.world and Game.world.camera
    local x, y = 0, 0
    if camera and camera.getRect then
        x, y = camera:getRect(false)
    elseif camera then
        x = camera.x or 0
        y = camera.y or 0
    end

    love.graphics.setBlendMode("add")
    Draw.setColor(1, 1, 1, (self.alpha or 0) * 0.5)
    Draw.draw(texture, x + self.xx, y, 0, 1, 1)
    Draw.draw(texture, x + self.xx, y + 360, 0, 1, 1)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
end

return PlatformDashLines
