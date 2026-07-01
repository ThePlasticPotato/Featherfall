---@class PlatformDust : Object
local PlatformDust, super = Class(Object)

local DUST_METADATA = {
    ["effects/platform/landingdust"] = {origin_x = 40, origin_y = 40},
    ["effects/platform/landingdust_new"] = {origin_x = 40, origin_y = 40},
    ["effects/platform/hit_vfx"] = {origin_x = 80, origin_y = 72},
    ["effects/platform/directional_hit"] = {origin_x = 100, origin_y = 45},
}

function PlatformDust:init(x, y, direction, sprite, options)
    super.init(self, x, y)
    options = options or {}
    self.sprite_path = sprite or Featherfall.assets.effects.landingdust
    self.image_index = 0
    self.image_speed = options.image_speed or 1
    self.image_xscale = options.image_xscale or (-2 * (direction or 1))
    self.image_yscale = options.image_yscale or 2
    self.image_angle = options.image_angle or 0
    self.hspeed = options.hspeed
    if self.hspeed == nil then
        self.hspeed = 2 * (direction or 1)
    end
    self:setOrigin(0.5, 0.5)
end

function PlatformDust:update()
    super.update(self)
    self.x = self.x + (self.hspeed * DTMULT)
    self.image_index = self.image_index + (self.image_speed * DTMULT)

    local frames = Assets.getFrames(self.sprite_path)
    if frames and self.image_index >= #frames then
        self:remove()
    end
end

function PlatformDust:draw()
    local frames = Assets.getFrames(self.sprite_path)
    local texture = frames and frames[math.max(1, math.min(#frames, math.floor(self.image_index) + 1))]
        or Assets.getTexture(self.sprite_path)
    if not texture then
        return
    end

    local metadata = DUST_METADATA[self.sprite_path]
    local origin_x = metadata and metadata.origin_x or (texture:getWidth() / 2)
    local origin_y = metadata and metadata.origin_y or (texture:getHeight() / 2)
    Draw.draw(texture, 0, 0, self.image_angle, self.image_xscale, self.image_yscale, origin_x, origin_y)
end

return PlatformDust
