---@class PlatformSlashpusher : PlatformAttackable
local PlatformAttackable = libRequire("featherfall", "scripts.world.events.platform.attackable")
local PlatformSlashpusher, super = Class(PlatformAttackable)

local SPRITES = {
    base = "world/platform/slashpusher/base",
    circle = "world/platform/slashpusher/circle",
    orb = "world/platform/slashpusher/orb",
    petals = "world/platform/slashpusher/petals",
    petals_yellow = "world/platform/slashpusher/petals_yellow",
    closed = "world/platform/slashpusher/closed",
    semiclosed = "world/platform/slashpusher/semiclosed",
    leaves = "world/platform/slashpusher/leaves",
}

local METADATA = {
    [SPRITES.base] = {origin_x = 10, origin_y = 10},
    [SPRITES.circle] = {origin_x = 10, origin_y = 10},
    [SPRITES.orb] = {origin_x = 8, origin_y = 8},
    [SPRITES.petals] = {origin_x = 26, origin_y = 22},
    [SPRITES.petals_yellow] = {origin_x = 26, origin_y = 22},
    [SPRITES.closed] = {origin_x = 12, origin_y = 10},
    [SPRITES.semiclosed] = {origin_x = 14, origin_y = 14},
    [SPRITES.leaves] = {origin_x = 20, origin_y = 11},
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

local function resolveStemEase(value)
    if type(value) == "function" then
        return value
    end
    local mode = value or "inOutSine"
    if not Ease[mode] then
        mode = "inOutSine"
    end
    return function(t)
        return Utils.ease(0, 1, t, mode)
    end
end

local SlashpusherAfterimage, afterimageSuper = Class(Object)

function SlashpusherAfterimage:init(source, color)
    local x, y = source:getBulbPosition()
    afterimageSuper.init(self, x, y)
    self.sprite_path = source.sprite_path
    self.frame = source.directional and 1 or gmFrameIndex(source.angle, 16)
    self.image_index = self.frame
    self.image_xscale = source.image_xscale
    self.image_yscale = source.image_yscale
    self.color = color or {0, 128 / 255, 128 / 255}
    self.alpha = 1
    self.direction = source.lerpdirection
    self.speed = 2
    self.grow = 0
end

function SlashpusherAfterimage:update()
    afterimageSuper.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.x = self.x + (gmLengthdirX(self.speed, self.direction) * DTMULT)
    self.y = self.y + (gmLengthdirY(self.speed, self.direction) * DTMULT)
    self.grow = self.grow + (0.2 * DTMULT)
    self.alpha = self.alpha - (0.1 * DTMULT)
    if self.alpha < 0 then
        self:remove()
    end
end

function SlashpusherAfterimage:draw()
    local frames = Assets.getFrames(self.sprite_path)
    local texture = frames and frames[math.max(1, math.min(#frames, self.frame or 1))] or Assets.getTexture(self.sprite_path)
    if not texture then
        return
    end
    local metadata = METADATA[self.sprite_path] or {}
    local sx = self.image_xscale + self.grow
    local sy = self.image_yscale + self.grow
    Draw.setColor(self.color[1] or 1, self.color[2] or 1, self.color[3] or 1, self.alpha)
    Draw.draw(texture, 0, 0, 0, sx, sy, metadata.origin_x or 0, metadata.origin_y or 0)
    Draw.setColor(1, 1, 1, 1)
end

local SlashpusherPetalBurst, petalBurstSuper = Class(Object)

function SlashpusherPetalBurst:init(x, y, options)
    petalBurstSuper.init(self, x, y)
    options = options or {}
    self.particles = {}
    local amount = options.amount or 6
    local speed = options.speed or 5
    local spread = options.spread or 360
    local start = -(spread / amount / 2)
    for i = 1, amount do
        local dir = start + ((spread / amount) * i) + love.math.random(-20, 20)
        local spd = speed + love.math.random() * 5
        table.insert(self.particles, {
            x = 0,
            y = 0,
            hspeed = gmLengthdirX(spd, dir),
            vspeed = gmLengthdirY(spd, dir),
            angle = love.math.random(0, 359),
            rspeed = 1 + love.math.random(0, 5),
            f = ({0.4, 0.5, 0.6, 0.7, 0.8})[love.math.random(1, 5)],
            timer = 0,
            fadewait = 10 + love.math.random(0, 10),
            alpha = 1,
        })
    end
end

function SlashpusherPetalBurst:update()
    petalBurstSuper.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.timer = particle.timer + DTMULT
        particle.x = particle.x + (particle.hspeed * DTMULT)
        particle.y = particle.y + (particle.vspeed * DTMULT)
        particle.hspeed = particle.hspeed * (0.92 ^ DTMULT)
        particle.vspeed = particle.vspeed * (0.92 ^ DTMULT)
        particle.vspeed = particle.vspeed + (0.1 * DTMULT)
        particle.angle = particle.angle + (particle.rspeed * DTMULT)
        if particle.timer >= particle.fadewait then
            particle.alpha = particle.alpha - (0.05 * DTMULT)
        end
        if particle.alpha <= 0 then
            table.remove(self.particles, index)
        end
    end
    if #self.particles == 0 then
        self:remove()
    end
end

function SlashpusherPetalBurst:draw()
    local frames = Assets.getFrames("effects/platform/petal/falling")
        or Assets.getFrames("effects/platform/petal/spinning")
        or Assets.getFrames("world/platform/slashpusher/petals")
    local texture = frames and frames[1] or Assets.getTexture("world/platform/slashpusher/petals")
    if not texture then
        return
    end
    for _, particle in ipairs(self.particles) do
        Draw.setColor(0.6, 0.6, 0.6, particle.alpha)
        Draw.draw(texture, particle.x, particle.y, math.rad(-particle.angle), 2, 2, texture:getWidth() / 2, texture:getHeight() / 2)
    end
    Draw.setColor(1, 1, 1, 1)
end

function PlatformSlashpusher:init(data)
    super.init(self, data)

    self.properties = self.properties or (data and data.properties) or {}
    self.platform_slashpusher = true
    self.platform_action_target_event = true
    self.solid = false
    self.platform_collision = true
    self.strength = tonumber(self.properties["strength"]) or 5
    self.index = tonumber(self.properties["index"]) or 0
    self.anchor_index = tonumber(self.properties["anchor_index"] or self.properties["leaves_index"]) or self.index
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
    self.closed_timer = 0
    self.hitcooldown = 0
    self.lerptimer = 0
    self.lerpdirection = 0
    self.anchorx = self.x
    self.anchory = self.y
    self.start_x = self.x
    self.start_y = self.y
    self.bulb_hitstop = 0
    self.flash = 0
    self.disabled_lerp = 0
    self.image_xscale = tonumber(self.properties["image_xscale"] or self.properties["xscale"]) or 2
    self.image_yscale = tonumber(self.properties["image_yscale"] or self.properties["yscale"]) or 2
    self.move_mode = propertyBool(self.properties["move_mode"], false)
        or propertyBool(self.properties["moving_slashpusher"], false)
    local property_hspeed = tonumber(self.properties["hspeed"])
    local property_vspeed = tonumber(self.properties["vspeed"])
    self.move_axis = self.properties["move_axis"] or (property_vspeed and "y" or "x")
    self.move_speed = tonumber(self.properties["move_speed"])
        or (self.move_axis == "y" and property_vspeed or property_hspeed)
        or 0
    self.continuous_mode = propertyBool(self.properties["continuous_mode"], false)
    self.continuous_duration = tonumber(self.properties["continuous_duration"]) or 60
    self.continuous_speed = tonumber(self.properties["continuous_speed"]) or 2
    self.continuous_movetime = 0
    self.pendulum_angle = tonumber(self.properties["pendulum_angle"]) or 0
    self.pendulum_freq = tonumber(self.properties["pendulum_freq"]) or 0
    self.pendulum_offset = tonumber(self.properties["pendulum_offset"]) or 0
    self.pendulum_timer = 0
    self.draw_shadow = propertyBool(self.properties["draw_shadow"], false)
    self.yellow_bouncer = propertyBool(self.properties["yellow_bouncer"], false)
    self.minigame_tag = tonumber(self.properties["minigame_tag"]) or 0
    self.minigame_pos = tonumber(self.properties["minigame_pos"]) or 0
    self.lifetime = tonumber(self.properties["lifetime"]) or -1
    self.orb_density = tonumber(self.properties["orb_density"]) or 24
    self.orb_color = PlatformActionUtils.parseColor(self.properties["orb_color"] or self.properties["orb_col"]) or {1, 1, 1}
    self.stem_ease_x = resolveStemEase(self.properties["stem_ease_x"] or self.properties["stem_x"])
    self.stem_ease_y = resolveStemEase(self.properties["stem_ease_y"] or self.properties["stem_y"])
    self.leaves = nil
    self.arc_increments = {}
    self.init2 = false
    self.sprite_path = self.directional and SPRITES.circle or SPRITES.base
    self.petal_sprite = self.directional and SPRITES.petals_yellow or SPRITES.petals
    self.closed_sprite = SPRITES.closed
    self.semiclosed_sprite = SPRITES.semiclosed
    if self.closed then
        self.sprite_path = self.semiclosed_sprite
    end
    self.orb_x = self.x + ((self.width or 0) / 2)
    self.orb_y = self.y + ((self.height or 0) / 2)
    self.action_kind = "susie"
    self.base_action_kind = "susie"
    self.objectname = self.properties["objectname"] or self.properties["object_name"] or "FLOWER"
    self.description = self.properties["description"] or "I'll make it bloom."
    self.action_label = self.properties["action_label"] or "Flowerbuster"
    self.action_color = PlatformActionUtils.parseColor(self.properties["action_color"] or self.properties["target_color"]) or {1, 0, 1}
    self.active = true
    self.protected = false
    self.blocked = self.closed_state == 0
    self.hovered = false
    self.last_hovered = false
    self.hoverlerp = 0
    self.selected_timer = 0
    self.is_valid_target = false
    self.cx = self.orb_x
    self.cy = self.orb_y
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

function PlatformSlashpusher:findAnchor()
    if not (Game.world and Game.world.map) then
        return nil
    end
    for _, event in ipairs(Game.world.map.events or {}) do
        if event.platform_slashpusher_anchor and (event.index or 0) == (self.anchor_index or self.index or 0) then
            return event
        end
    end
end

function PlatformSlashpusher:resolveAnchor()
    if self.init2 and (not self.leaves or self.leaves.parent) then
        return
    end

    self.init2 = true
    self.leaves = self:findAnchor()
    if self.leaves then
        self.leaves.flower = self
        self.layer = self.leaves.layer or self.layer
        self:rebuildStemArc()
    end
end

function PlatformSlashpusher:rebuildStemArc()
    self.arc_increments = {}
    local leaves = self.leaves
    if not (leaves and leaves.parent) then
        return
    end

    local lx, ly = leaves:getAnchorPosition()
    local x, y = self:getBulbPosition()
    local dist = Utils.dist(lx, ly, x, y)
    if dist <= 1 then
        return
    end

    local previous_x, previous_y = lx, ly
    for i = 0, math.max(0, math.floor(dist - 1)) do
        local t = i / dist
        local new_x = lx + (self.stem_ease_x(t) * (x - lx))
        local new_y = ly + (self.stem_ease_y(t) * (y - ly))
        if Utils.dist(previous_x, previous_y, new_x, new_y) >= self.orb_density then
            previous_x, previous_y = new_x, new_y
            table.insert(self.arc_increments, t)
        end
    end
end

function PlatformSlashpusher:updatePendulum()
    if not (self.pendulum_angle ~= 0 and self.pendulum_freq ~= 0 and self.leaves and self.leaves.parent) then
        return false
    end
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return false
    end
    local lx, ly = self.leaves:getAnchorPosition()
    local sx = self.start_x or self.x
    local sy = self.start_y or self.y
    local lsx = self.leaves.start_x or self.leaves.x
    local lsy = self.leaves.start_y or self.leaves.y
    local amp = Utils.dist(lsx, lsy, sx, sy)
    self.pendulum_timer = self.pendulum_timer + DTMULT
    local myangle = 270 + (self.pendulum_angle * math.sin((self.pendulum_freq * self.pendulum_timer) + math.rad(self.pendulum_offset)))
    local new_x = lx + gmLengthdirX(amp, myangle)
    local new_y = ly + gmLengthdirY(amp, myangle)
    if self.lerptimer > 0 then
        self.anchorx = new_x
        self.anchory = new_y
    else
        self.x = new_x - ((self.width or 0) / 2)
        self.y = new_y - ((self.height or 0) / 2)
        Object.uncache(self)
    end
    return true
end

function PlatformSlashpusher:update()
    super.update(self)
    self:resolveAnchor()
    self.cx, self.cy = self:getBulbPosition()
    self.last_hovered = self.hovered
    self.hoverlerp = MathUtils.approach(self.hoverlerp or 0, self.hovered and 1 or 0, 0.25 * DTMULT)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.selected_timer = MathUtils.approach(self.selected_timer or 0, 0, DTMULT)

    if self.disabled then
        self.disabled_lerp = MathUtils.approach(self.disabled_lerp, 1, 0.1 * DTMULT)
    else
        self.disabled_lerp = MathUtils.approach(self.disabled_lerp, 0, 0.1 * DTMULT)
    end
    self.hitcooldown = self.hitcooldown - DTMULT
    self.bulb_hitstop = self.bulb_hitstop - DTMULT
    self.flash = MathUtils.approach(self.flash, 0, DTMULT)
    if self.lifetime > -1 then
        self.lifetime = self.lifetime - DTMULT
        if self.lifetime <= 0 then
            self:remove()
            return
        end
    end

    if self.closed and self.closed_state == 0 then
        self.closed_timer = self.closed_timer - DTMULT
        if self.closed_timer <= 0 then
            self.closed_state = 1
            self.sprite_path = self.semiclosed_sprite
        end
    end
    self.blocked = self.closed_state == 0

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

    if not self.move_mode then
        if self.lerptimer > 0 then
            self.x = self.anchorx + gmLengthdirX(lerpvar * lerpstrength, self.lerpdirection)
            self.y = self.anchory + gmLengthdirY(lerpvar * lerpstrength, self.lerpdirection)
            Object.uncache(self)
        end
    elseif not self.continuous_mode then
        if self.move_axis == "y" then
            self.y = self.y + (self.move_speed * DTMULT)
        else
            self.x = self.x + (self.move_speed * DTMULT)
            if self.lerptimer > 0 then
                self.y = self.anchory + gmLengthdirY(lerpvar * lerpstrength, self.lerpdirection)
            end
        end
        Object.uncache(self)
    else
        if self.lerptimer > 0 then
            self.y = self.anchory + gmLengthdirY(lerpvar * lerpstrength, self.lerpdirection)
        end
        self.x = self.x + (self.continuous_speed * DTMULT)
        self.continuous_movetime = self.continuous_movetime + DTMULT
        if self.continuous_movetime >= self.continuous_duration then
            self.continuous_speed = -self.continuous_speed
            self.continuous_movetime = 0
        end
        Object.uncache(self)
    end

    self:updatePendulum()
    if self.leaves then
        self:rebuildStemArc()
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

function PlatformSlashpusher:isAvailableFor(kind)
    kind = string.lower(tostring(kind or "any"))
    return self.active and self.closed_state == 1 and (kind == "susie" or kind == "any" or kind == "all")
end

function PlatformSlashpusher:getPlatformActionPresentation(kind, state, data)
    return {
        label = self.action_label,
        color = self.action_color,
        label_color = self.action_color,
    }
end

function PlatformSlashpusher:select(follower_state, action_data)
    self.selected_timer = 8
    return self.closed_state == 1
end

function PlatformSlashpusher:performFollowerAction(kind, follower_state, action_data)
    kind = string.lower(tostring(kind or "susie"))
    if kind == "susie" then
        return self:onPlatformRudeBuster(follower_state, action_data)
    end
    return false
end

function PlatformSlashpusher:onPlatformRudeBuster(follower_state, action_data)
    if self.closed_state == 1 then
        self.closed_timer = 150
        self.closed_state = 0
        self.sprite_path = self.directional and SPRITES.circle or SPRITES.base
        self.blocked = true
        return true
    end
    return false
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
    local volume = attenuation * 0.87
    local source = Assets.playSound(Featherfall.sounds.slashpusher_launch, volume, 1)
    if source and Game.world and Game.world.timer then
        local duration = 25 / 30
        Game.world.timer:during(duration, function(remaining)
            if source.setVolume then
                source:setVolume(volume * MathUtils.clamp(remaining / duration, 0, 1))
            end
        end)
    end
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
    local color = self.directional and {1, 1, 0} or {0, 128 / 255, 128 / 255}
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
    if Game.world then
        local afterimage = SlashpusherAfterimage(self, color)
        afterimage.layer = layer
        Game.world:spawnObject(afterimage, layer)
    end
end

function PlatformSlashpusher:spawnDestroyEffects()
    local x, y = self:getBulbPosition()
    local layer = self.layer or WORLD_LAYERS["above_events"]
    if PlatformDust then
        local hit = PlatformDust(x, y, 1, "effects/platform/hit_vfx", {
            hspeed = 0,
            image_xscale = 1,
            image_yscale = 1,
            image_speed = 1,
        })
        Game.world:spawnObject(hit, layer)
        local smoke = PlatformDust(x, y, 1, Featherfall.assets.effects.landingdust, {
            hspeed = 0,
            image_xscale = 2,
            image_yscale = 2,
            image_speed = 2,
        })
        Game.world:spawnObject(smoke, layer)
    end
    if Game.world then
        local petals = SlashpusherPetalBurst(x, y, {amount = 6, speed = 5})
        petals.layer = layer - 0.01
        Game.world:spawnObject(petals, petals.layer)
    end
end

function PlatformSlashpusher:triggerMinigameDestroy()
    if self.minigame_tag > 0 then
        self:spawnDestroyEffects()
        self.visible = false
        self.active = false
        self.can_hit = false
        self.blocked = true
        return true
    end
    return false
end

function PlatformSlashpusher:onPlatformAttack(hitbox)
    if self.minigame_pos > 1 then
        return false
    end
    if self.minigame_tag ~= 0 and self.minigame_pos <= 0 then
        return false
    end
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
        hitbox:doHit(6)
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

function PlatformSlashpusher:drawStemOrbs()
    local leaves = self.leaves
    if not (leaves and leaves.parent and #self.arc_increments > 0) then
        return
    end

    local lx, ly = leaves:getAnchorPosition()
    local bx, by = self:getBulbPosition()
    local local_lx = lx - self.x
    local local_ly = ly - self.y
    local distx = bx - lx
    local disty = by - ly
    local hitstop = math.max(0, self.bulb_hitstop or 0)
    local alpha = self.alpha or 1
    local r, g, b = self.orb_color[1] or 1, self.orb_color[2] or 1, self.orb_color[3] or 1

    for _, t in ipairs(self.arc_increments) do
        local eased_x = self.stem_ease_x(t)
        local eased_y = self.stem_ease_y(t)
        local xs = self.image_xscale
        if hitstop > 0 then
            xs = xs + (math.max(math.sin((-9.42477796076938 - (t * 4)) + (3 * ((7 - hitstop) / 8))), 0) * (1 - (hitstop / 12)))
        end
        local ys = xs
        self:drawSprite(
            SPRITES.orb,
            1,
            local_lx + (eased_x * distx),
            local_ly + (eased_y * disty),
            xs,
            ys,
            r,
            g,
            b,
            alpha
        )
    end
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
        self:drawStemOrbs()
        self:drawSprite(self.sprite_path, 1, x, y, self.image_xscale, self.image_yscale, blend, blend, blend, alpha)
        super.draw(self)
        return
    end
    self:drawStemOrbs()
    if self.draw_shadow then
        self:drawSprite(self.petal_sprite, self:getPetalIndex(), x + 4, y + 4, self.image_xscale, self.image_yscale, 0, 0, 0, 0.5 * alpha)
    end
    self:drawSprite(self.petal_sprite, self:getPetalIndex(), x, y, self.image_xscale, self.image_yscale, blend, blend, blend, alpha)
    self:drawSprite(self.sprite_path, frame, x, y, self.image_xscale, self.image_yscale, blend, blend, blend, alpha)
    super.draw(self)
end

return PlatformSlashpusher
