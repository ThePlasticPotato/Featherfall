---@class PlatformSlashpusher : PlatformAttackable
local PlatformAttackable = libRequire("featherfall", "scripts.world.events.platform.attackable")
local PlatformSlashpusher, super = Class(PlatformAttackable)

local SPRITES = {
    base = "world/platform/slashpusher/base",
    circle = "world/platform/slashpusher/circle",
    petals = "world/platform/slashpusher/petals",
    petals_yellow = "world/platform/slashpusher/petals_yellow",
    closed = "world/platform/slashpusher/closed",
    semiclosed = "world/platform/slashpusher/semiclosed",
}

local METADATA = {
    [SPRITES.base] = {origin_x = 10, origin_y = 10},
    [SPRITES.circle] = {origin_x = 10, origin_y = 10},
    [SPRITES.petals] = {origin_x = 26, origin_y = 22},
    [SPRITES.petals_yellow] = {origin_x = 26, origin_y = 22},
    [SPRITES.closed] = {origin_x = 12, origin_y = 10},
    [SPRITES.semiclosed] = {origin_x = 14, origin_y = 14},
    ["effects/platform/hit_vfx"] = {origin_x = 80, origin_y = 72},
    ["effects/platform/directional_hit"] = {origin_x = 100, origin_y = 45},
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

local function gmPointDirection(x1, y1, x2, y2)
    return math.deg(math.atan2(y1 - y2, x2 - x1))
end

local function gmFrameIndex(angle, frames)
    frames = frames or 16
    return (math.floor((angle + 12.25 + 360) / 22.5) % frames) + 1
end

function PlatformSlashpusher:init(data)
    super.init(self, data)

    self.properties = self.properties or (data and data.properties) or {}
    self.platform_slashpusher = true
    self.solid = false
    self.platform_collision = true
    self.strength = tonumber(self.properties["strength"]) or 5
    self.index = tonumber(self.properties["index"]) or 0
    self.angle = tonumber(
        self.properties["platform_angle"]
        or self.properties["angle"]
        or self.properties["direction"]
        or self.rotation
    ) or 0
    self.directional = propertyBool(self.properties["directional"], false)
        or propertyBool(self.properties["target"], false)
        or propertyBool(self.properties["circle"], false)
    self.disabled = propertyBool(self.properties["disabled"], false)
    self.player_slashable = propertyBool(self.properties["player_slashable"], true)
    self.autocloses = propertyBool(self.properties["autocloses"], false)
    self.closed = propertyBool(self.properties["closed"], false)
    self.closed_state = self.closed and 1 or 0
    self.hitcooldown = 0
    self.lerptimer = 0
    self.lerpdirection = 0
    self.anchorx = self.x
    self.anchory = self.y
    self.bulb_hitstop = 0
    self.flash = 0
    self.disabled_lerp = 0
    self.image_xscale = tonumber(self.properties["image_xscale"] or self.properties["xscale"]) or 2
    self.image_yscale = tonumber(self.properties["image_yscale"] or self.properties["yscale"]) or 2
    self.move_mode = propertyBool(self.properties["move_mode"], false)
    self.draw_shadow = propertyBool(self.properties["draw_shadow"], false)
    self.yellow_bouncer = propertyBool(self.properties["yellow_bouncer"], false)
    self.sprite_path = self.directional and SPRITES.circle or SPRITES.base
    self.petal_sprite = self.directional and SPRITES.petals_yellow or SPRITES.petals
    self.closed_sprite = SPRITES.closed
    self.semiclosed_sprite = SPRITES.semiclosed
    if self.closed then
        self.sprite_path = self.semiclosed_sprite
    end
    self.orb_x = self.x + ((self.width or 0) / 2)
    self.orb_y = self.y + ((self.height or 0) / 2)
end

function PlatformSlashpusher:getBulbLocalPosition()
    return (self.width or 0) / 2, (self.height or 0) / 2
end

function PlatformSlashpusher:getBulbPosition()
    local x, y = self:getBulbLocalPosition()
    return self.x + x, self.y + y
end

function PlatformSlashpusher:getPetalIndex()
    if self.strength > 8 then
        return 3
    elseif self.strength > 5 then
        return 2
    end
    return 1
end

function PlatformSlashpusher:update()
    super.update(self)

    if self.disabled then
        self.disabled_lerp = MathUtils.approach(self.disabled_lerp, 1, 0.1 * DTMULT)
    else
        self.disabled_lerp = MathUtils.approach(self.disabled_lerp, 0, 0.1 * DTMULT)
    end
    self.hitcooldown = self.hitcooldown - DTMULT
    self.bulb_hitstop = self.bulb_hitstop - DTMULT
    self.flash = MathUtils.approach(self.flash, 0, DTMULT)

    local lerpvar = 0
    local lerpstrength = 0
    local lerpmax = self.move_mode and 40 or 80
    if self.lerptimer > 0 then
        self.lerptimer = self.lerptimer + DTMULT
        local len = 32
        lerpstrength = Utils.lerp(lerpmax, 0, self.lerptimer / len)
        if self.lerptimer < len then
            lerpvar = math.sin(((self.lerptimer / (len / 6)) * math.pi) / 2)
        else
            self.lerptimer = 0
        end
    else
        self.anchorx = self.x
        self.anchory = self.y
    end

    if self.lerptimer > 0 then
        self.x = self.anchorx + gmLengthdirX(lerpvar * lerpstrength, self.lerpdirection)
        self.y = self.anchory + gmLengthdirY(lerpvar * lerpstrength, self.lerpdirection)
        Object.uncache(self)
    end
end

function PlatformSlashpusher:canPlatformAttackHit(hitbox)
    if not super.canPlatformAttackHit(self, hitbox) then
        return false
    end
    if self.disabled or not self.player_slashable or self.hitcooldown > 0 then
        return false
    end
    if self.closed_state == 1 or not self.visible then
        return false
    end
    return true
end

function PlatformSlashpusher:getLaunchDirection(player)
    if self.directional and player then
        local x, y = self:getBulbPosition()
        return gmPointDirection(x, y, player.x, player.y)
    end
    return self.angle
end

function PlatformSlashpusher:getRecoilDirection(player)
    if self.directional and player then
        return 180 + self:getLaunchDirection(player)
    end
    return 180 + self.angle
end

function PlatformSlashpusher:getCameraAttenuation()
    local camera = Game.world and Game.world.camera
    if not camera then
        return 1
    end
    local x, y = self:getBulbPosition()
    local cx, cy = camera.x or x, camera.y or y
    return 1 - ((Utils.dist(x, y, cx, cy) - 300) / 200)
end

function PlatformSlashpusher:getBouncePitch()
    local pitch = 1
    for _ = 1, (self.index % 7) do
        pitch = pitch * 1.059
    end
    return pitch
end

function PlatformSlashpusher:playLaunchSounds()
    local attenuation = self:getCameraAttenuation()
    if attenuation <= 0 then
        return
    end

    Assets.stopSound(Featherfall.sounds.slashpusher_launch)
    Assets.playSound(Featherfall.sounds.slashpusher_launch, attenuation * 0.87, 1)
    if Game.world and Game.world.timer then
        Game.world.timer:after(4 / 30, function()
            Assets.playSound(Featherfall.sounds.slashpusher_bounce, 0.8 * attenuation, self:getBouncePitch())
        end)
    else
        Assets.playSound(Featherfall.sounds.slashpusher_bounce, 0.8 * attenuation, self:getBouncePitch())
    end
end

function PlatformSlashpusher:applyLaunchToPlayer(player)
    local state = player and player.platform_state
    local entity = state and state.entity
    if not entity then
        return
    end

    local str = self.strength * 4
    local launch_direction = self:getLaunchDirection(player)
    if not self.directional then
        local x, y = self:getBulbPosition()
        local x_perp = gmLengthdirX(1, self.lerpdirection)
        local y_perp = gmLengthdirY(1, self.lerpdirection)
        local dp = (x_perp * (player.x - x)) + (y_perp * (player.y - y))
        str = str + (0.025 * dp)
    end

    entity.grounded = false
    entity.ground = nil
    entity.jumping = 1
    entity.jump_boost = true
    entity.hspeed = gmLengthdirX(str, launch_direction)
    entity.vspeed = math.min(entity.vspeed or 0, gmLengthdirY(str, launch_direction))
    state.hspeed = entity.hspeed
    state.vspeed = entity.vspeed
    state.on_ground = false
end

function PlatformSlashpusher:spawnHitEffects()
    local x, y = self:getBulbPosition()
    local layer = (self.layer or WORLD_LAYERS["above_events"]) + 0.01
    if PlatformDust then
        local hit = PlatformDust(x, y, 1, "effects/platform/hit_vfx", {
            hspeed = 0,
            image_xscale = 2,
            image_yscale = 2,
            image_angle = math.rad(love.math.random(0, 359)),
            image_speed = 1,
        })
        Game.world:spawnObject(hit, layer)
        local directional = PlatformDust(x, y, 1, "effects/platform/directional_hit", {
            hspeed = 0,
            image_xscale = 2,
            image_yscale = 2,
            image_angle = math.rad(-self.lerpdirection),
            image_speed = 0.5,
        })
        directional.image_index = 1
        Game.world:spawnObject(directional, layer)
    end
end

function PlatformSlashpusher:onPlatformAttack(hitbox)
    if self.hitcooldown > 0 or self.closed_state == 1 or not self.visible then
        return false
    end

    self.hitcooldown = self.move_mode and 5 or 15
    local player = Game.world and Game.world.player
    self.lerpdirection = self:getRecoilDirection(player)

    if not self.yellow_bouncer and hitbox and hitbox.doHit then
        Assets.stopSound(Featherfall.sounds.attack_1)
        Assets.stopSound(Featherfall.sounds.attack_2)
        Assets.stopSound(Featherfall.sounds.attack_3)
        hitbox:doHit()
        self.bulb_hitstop = 6
    end

    self:playLaunchSounds()
    self.flash = 8
    if self.autocloses or self.closed then
        self.closed_state = 1
        self.sprite_path = self.closed_sprite
    end
    self.lerptimer = 1
    self:applyLaunchToPlayer(player)
    self:spawnHitEffects()
    return true
end

function PlatformSlashpusher:getSpriteTexture(path, frame)
    local frames = Assets.getFrames(path)
    if frames then
        return frames[math.max(1, math.min(#frames, frame or 1))]
    end
    return Assets.getTexture(path)
end

function PlatformSlashpusher:drawSprite(path, frame, x, y, sx, sy, r, g, b, a)
    local texture = self:getSpriteTexture(path, frame)
    if not texture then
        return
    end
    local metadata = METADATA[path] or {}
    Draw.setColor(r or 1, g or 1, b or 1, a or 1)
    Draw.draw(texture, x, y, 0, sx or 1, sy or sx or 1, metadata.origin_x or 0, metadata.origin_y or 0)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformSlashpusher:draw()
    local x, y = self:getBulbLocalPosition()
    local blend = Utils.lerp(1, 0.5, self.disabled_lerp)
    local alpha = self.alpha or 1
    local frame = 1
    if not self.directional then
        frame = gmFrameIndex(self.angle, 16)
    end
    if self.closed_state == 1 then
        self:drawSprite(self.sprite_path, 1, x, y, self.image_xscale, self.image_yscale, blend, blend, blend, alpha)
        super.draw(self)
        return
    end
    if self.draw_shadow then
        self:drawSprite(self.petal_sprite, self:getPetalIndex(), x + 4, y + 4, self.image_xscale, self.image_yscale, 0, 0, 0, 0.5 * alpha)
    end
    self:drawSprite(self.petal_sprite, self:getPetalIndex(), x, y, self.image_xscale, self.image_yscale, blend, blend, blend, alpha)
    self:drawSprite(self.sprite_path, frame, x, y, self.image_xscale, self.image_yscale, blend, blend, blend, alpha)
    super.draw(self)
end

return PlatformSlashpusher
