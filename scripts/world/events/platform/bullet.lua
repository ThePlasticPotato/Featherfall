---@class PlatformBullet : Event
local PlatformBullet, super = Class(Event)

local SPRITES = {
    blue = "world/platform/bullets/blue",
}

local METADATA = {
    [SPRITES.blue] = {origin_x = 16, origin_y = 16, margin_left = 10, margin_right = 21, margin_top = 10, margin_bottom = 21},
}

local function propertyBool(value, default)
    if value == nil then
        return default
    elseif value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
    value = string.lower(tostring(value))
    return value == "true" or value == "1" or value == "yes"
end

local function gmLengthdirX(length, angle)
    return math.cos(math.rad(angle)) * length
end

local function gmLengthdirY(length, angle)
    return -math.sin(math.rad(angle)) * length
end

function PlatformBullet:init(data)
    super.init(self, data)

    self.properties = data and data.properties or {}
    self.platform_bullet = true
    self.collidable = true
    self.solid = false
    self.sprite_path = self.properties["sprite"] or self.properties["sprite_path"] or SPRITES.blue
    self.image_index = tonumber(self.properties["image_index"]) or 0
    self.image_speed = tonumber(self.properties["image_speed"]) or 0.25
    self.image_xscale = tonumber(self.properties["image_xscale"] or self.properties["xscale"]) or 1
    self.image_yscale = tonumber(self.properties["image_yscale"] or self.properties["yscale"]) or self.image_xscale
    self.image_angle = tonumber(self.properties["image_angle"]) or 0
    self.image_alpha = tonumber(self.properties["image_alpha"]) or 1
    self.damage = tonumber(self.properties["damage"]) or 1
    self.knockback = propertyBool(self.properties["knockback"], false)
    self.neutralized = tonumber(self.properties["neutralized"]) or 0
    self.neutralizable = propertyBool(self.properties["neutralizable"], false)
    self.contact_kill = propertyBool(self.properties["contact_kill"], true)
    self.lifetime = tonumber(self.properties["lifetime"]) or -1
    self.speed = tonumber(self.properties["speed"]) or 0
    self.direction = tonumber(self.properties["direction"] or self.properties["angle"]) or 0
    self.hspeed = tonumber(self.properties["hspeed"]) or gmLengthdirX(self.speed, self.direction)
    self.vspeed = tonumber(self.properties["vspeed"]) or gmLengthdirY(self.speed, self.direction)
    self.platform_bullet_hit = false

    self:updateCollider()
end

function PlatformBullet:getSpriteMetadata()
    return METADATA[self.sprite_path] or {}
end

function PlatformBullet:updateCollider()
    local metadata = self:getSpriteMetadata()
    local left = metadata.margin_left or 0
    local top = metadata.margin_top or 0
    local right = metadata.margin_right or 31
    local bottom = metadata.margin_bottom or 31
    local origin_x = metadata.origin_x or 0
    local origin_y = metadata.origin_y or 0
    self.collider = Hitbox(self, left - origin_x, top - origin_y, (right - left) + 1, (bottom - top) + 1)
end

function PlatformBullet:update()
    super.update(self)

    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    self.neutralized = MathUtils.approach(self.neutralized or 0, 0, DTMULT)
    self.x = self.x + ((self.hspeed or 0) * DTMULT)
    self.y = self.y + ((self.vspeed or 0) * DTMULT)
    self.image_index = (self.image_index or 0) + ((self.image_speed or 0) * DTMULT)
    Object.uncache(self)

    self:checkPlayerHeartCollision()

    if self.lifetime > -1 then
        self.lifetime = self.lifetime - DTMULT
        if self.lifetime <= 0 then
            self:remove()
        end
    end
end

function PlatformBullet:checkPlayerHeartCollision()
    if self.platform_bullet_hit then
        return
    end
    local player = Game.world and Game.world.player
    local state = player and player.platform_state
    local platforming = player and player.isPlatforming and player:isPlatforming()
    if not (state and platforming and state.getHeartCollider and state.onPlatformBulletHit) then
        return
    end
    local heart = state:getHeartCollider()
    if heart and self:collidesWith(heart) then
        state:onPlatformBulletHit(self)
    end
end

function PlatformBullet:neutralize(frames)
    self.neutralized = math.max(self.neutralized or 0, frames or 1)
end

function PlatformBullet:doContactKill()
    if self.contact_kill then
        self:remove()
    end
end

function PlatformBullet:getFrame()
    local frames = Assets.getFrames(self.sprite_path)
    if not frames or #frames == 0 then
        return Assets.getTexture(self.sprite_path), 1
    end
    local frame = (math.floor(self.image_index or 0) % #frames) + 1
    return frames[frame], frame
end

function PlatformBullet:draw()
    local texture = self:getFrame()
    if not texture then
        return
    end
    local metadata = self:getSpriteMetadata()
    Draw.setColor(1, 1, 1, self.image_alpha or 1)
    Draw.draw(texture, 0, 0, math.rad(-(self.image_angle or 0)), self.image_xscale or 1, self.image_yscale or self.image_xscale or 1, metadata.origin_x or 0, metadata.origin_y or 0)
    Draw.setColor(1, 1, 1, 1)
    if DEBUG_RENDER and self.collider then
        self.collider:draw(0.2, 0.5, 1, 0.85)
    end
end

return PlatformBullet
