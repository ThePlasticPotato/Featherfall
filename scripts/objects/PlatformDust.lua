---@class PlatformDust : Object
local PlatformDust, super = Class(Object)

local DUST_METADATA = {
    ["effects/platform/landingdust"] = {origin_x = 40, origin_y = 40},
    ["effects/platform/landingdust_new"] = {origin_x = 40, origin_y = 40},
    ["effects/platform/hit_vfx"] = {origin_x = 80, origin_y = 72},
    ["effects/platform/directional_hit"] = {origin_x = 100, origin_y = 45},
    ["effects/platform/smack_vfx"] = {origin_x = 40, origin_y = 40},
    ["effects/platform/leaf_fall"] = {origin_x = 0, origin_y = 0},
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
    self.gravity_direction = options.gravity_direction
    self.gravity = options.gravity or 0
    self.vspeed = options.vspeed or 0
    self.rspeed = options.rspeed or 0
    self.alpha = options.alpha or 1
    self.fade_speed = options.fade_speed or 0
    self.grow_x = options.grow_x or 0
    self.grow_y = options.grow_y or 0
    self.grow_from_x = self.image_xscale
    self.grow_from_y = self.image_yscale
    self.grow_to_x = options.grow_to_x
    self.grow_to_y = options.grow_to_y
    self.grow_time = options.grow_time or 1
    self.loop = options.loop or false
    self.hold_frame = options.hold_frame or false
    self.max_life = options.max_life
    self.timer = 0
    self.hspeed = options.hspeed
    if self.hspeed == nil then
        self.hspeed = 2 * (direction or 1)
    end
    self:setOrigin(0.5, 0.5)
end

function PlatformDust:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.timer = self.timer + DTMULT
    if self.gravity_direction and self.gravity ~= 0 then
        self.hspeed = self.hspeed + (math.cos(math.rad(self.gravity_direction)) * self.gravity * DTMULT)
        self.vspeed = self.vspeed - (math.sin(math.rad(self.gravity_direction)) * self.gravity * DTMULT)
    end
    self.x = self.x + (self.hspeed * DTMULT)
    self.y = self.y + ((self.vspeed or 0) * DTMULT)
    self.image_index = self.image_index + (self.image_speed * DTMULT)
    self.image_angle = self.image_angle + ((self.rspeed or 0) * DTMULT)
    if self.grow_to_x or self.grow_to_y then
        local progress = MathUtils.clamp(self.timer / math.max(self.grow_time or 1, 0.001), 0, 1)
        self.image_xscale = MathUtils.lerp(self.grow_from_x, self.grow_to_x or self.grow_from_x, progress)
        self.image_yscale = MathUtils.lerp(self.grow_from_y, self.grow_to_y or self.grow_from_y, progress)
    else
        self.image_xscale = self.image_xscale + ((self.grow_x or 0) * DTMULT)
        self.image_yscale = self.image_yscale + ((self.grow_y or 0) * DTMULT)
    end
    self.alpha = self.alpha - ((self.fade_speed or 0) * DTMULT)

    local frames = Assets.getFrames(self.sprite_path)
    if frames and self.image_index >= #frames and self.loop then
        self.image_index = self.image_index % #frames
    end
    if self.alpha <= 0
        or (self.max_life and self.timer >= self.max_life)
        or (frames and self.image_index >= #frames and not self.loop and not self.hold_frame)
    then
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
    Draw.setColor(1, 1, 1, self.alpha or 1)
    Draw.draw(texture, 0, 0, self.image_angle, self.image_xscale, self.image_yscale, origin_x, origin_y)
    Draw.setColor(1, 1, 1, 1)
end

return PlatformDust
