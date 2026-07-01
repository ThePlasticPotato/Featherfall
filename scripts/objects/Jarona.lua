---@class Jarona : Object
local Jarona, super = Class(Object)

local RAINBOW = {
    {1, 0, 0},
    {0, 177 / 255, 1},
    {0, 1, 1},
    {56 / 255, 230 / 255, 1},
    {1, 245 / 255, 0},
    {238 / 255, 92 / 255, 227 / 255},
    {1, 0, 242 / 255},
}

local FLOWER_SPRITES = {
    {path = "party/flowery/flower_gang/spr_enemy_aqua_idle", width = 38, height = 32, origin_x = 8, origin_y = -4},
    {path = "party/flowery/flower_gang/spr_seth_idle", width = 33, height = 41, origin_x = 0, origin_y = 0},
    {path = "party/flowery/flower_gang/spr_orange_mad", width = 31, height = 16, origin_x = 0, origin_y = 0},
    {path = "party/flowery/flower_gang/spr_yellow_idle", width = 41, height = 62, origin_x = 0, origin_y = -8},
    {path = "party/flowery/flower_gang/spr_enemy_green", width = 33, height = 50, origin_x = 1, origin_y = 1},
    {path = "party/flowery/flower_gang/spr_blue_poses", width = 49, height = 66, origin_x = 0, origin_y = 0},
}

local FLOWER_COLORS = {
    {0, 1, 1},
    {1, 0, 1},
    {1, 0, 0},
    {1, 1, 0},
    {0, 1, 0},
    {0, 0, 1},
}

local function colorToInt(color)
    return (math.floor((color[1] or 1) * 255) * 65536)
        + (math.floor((color[2] or 1) * 255) * 256)
        + math.floor((color[3] or 1) * 255)
end

local function rainbowColor(offset)
    local index = ((math.floor(((Kristal.getTime() * 30) + (offset or 0)) / 2) % #RAINBOW) + 1)
    return RAINBOW[index]
end

local function mergeColor(color, target, amount)
    return {
        MathUtils.lerp(color[1] or 1, target[1] or 1, amount),
        MathUtils.lerp(color[2] or 1, target[2] or 1, amount),
        MathUtils.lerp(color[3] or 1, target[3] or 1, amount),
    }
end

local function getTargetCenter(target, fallback_x, fallback_y)
    if not target then
        return fallback_x, fallback_y
    end
    return target.cx or target.target_x or target.x or fallback_x,
        target.cy or target.target_y or target.y or fallback_y
end

function Jarona:init(state, target, data)
    local character = state and state.getCharacter and state:getCharacter()
    local x = character and character.x or 0
    local y = character and character.y or 0
    super.init(self, x, y)

    self.state = state
    self.character = character
    self.target = target
    self.data = data or {}
    self.omega = self.data.omega == true or (target and target.action_kind == "flowery_omega")
    self.timer = 0
    self.phase = self.omega and "omega_transform" or "normal_windup"
    self.recover_time = self.omega and (self.data.jarona_recover_time or 20) or (self.data.jarona_post_bounce_time or 1)
    self.omega_transform_time = self.data.omega_transform_time or 150
    self.omega_charge_time = self.data.omega_charge_time or 80
    self.start_x = x
    self.start_y = y
    self.target_x, self.target_y = getTargetCenter(target, x, y)
    self.facing = (self.target_x < x) and "left" or "right"
    self.sign = self.facing == "left" and -1 or 1
    self.normal_speed = self.data.jarona_speed or 20
    self.normal_speed_limit = self.data.jarona_speed_limit or 36
    self.normal_speed_change = self.data.jarona_speed_change or 3
    self.normal_current_speed = self.normal_speed
    self.normal_windup_time = self.data.jarona_windup_time or 14
    self.normal_bounce_time = self.data.jarona_bounce_time or 10
    self.normal_hit_offset = self.data.jarona_hit_offset or 8
    self.normal_crescent_distance = self.data.jarona_crescent_distance or 48
    self.hit_done = false
    self.afterimage_timer = 0
    self.omega_voice_played = false
    self.omega_combined_played = false
    self.omega_music_played = false
    self.played_last_jarona = false
    self.omega_ripple_frame = -1
    self.flower_angle = 0
    self.flower_accel = 0
    self.flower_afterimages = {}
    self.flower_afterimage_frames = {}
    self.effects = {}
    self.layer = (character and character.layer or WORLD_LAYERS["above_events"]) + 0.1

    if self.omega then
        self:setAnimation("omega_poweringup")
    else
        self:setAnimation("jarona_ready")
        local random = MathUtils.randomInt(1, 6)
        if random == 4 then
            Assets.playSound("flowery/forthefans", 0.5)
        end
    end
end

function Jarona:getVoiceList()
    if self.omega then
        return self.data.omega_voices or self.data.jarona_voices
    end
    return self.data.jarona_voices or {
        "flowery/jarona1",
        "flowery/jarona2",
        "flowery/jarona3",
        "flowery/jarona4",
    }
end

function Jarona:playRandomVoice()
    local voices = self:getVoiceList() or {}
    if #voices > 0 then
        Assets.playSound(voices[love.math.random(1, #voices)])
    end
end

function Jarona:setAnimation(name)
    if self.state and self.state.setPlatformAnimation then
        self.state:setPlatformAnimation(name)
    end
end

function Jarona:getPlatformData()
    local actor = self.state and self.state.getPlatformActor and self.state:getPlatformActor()
    if actor and actor.getPlatformData then
        return actor:getPlatformData()
    end
end

function Jarona:getPlatformAnchor(name, fallback_x, fallback_y)
    if not self.character then
        return self.start_x + (fallback_x or 0), self.start_y + (fallback_y or 0)
    end

    local data = self:getPlatformData()
    local actor = self.state and self.state.getPlatformActor and self.state:getPlatformActor()
    if name == "omega_orbit_anchor" or name == "omega_ripple_anchor" then
        if actor and actor.getPlatformActionOmegaAnchor then
            local x, y = actor:getPlatformActionOmegaAnchor(self.character, self.state, name)
            if x and y then
                return x, y
            end
        end
    end

    local anchor = data and data[name]
    if type(anchor) == "function" then
        local x, y = anchor(actor, self.character, self.state)
        if x and y then
            return x, y
        end
    elseif type(anchor) == "table" then
        return self.character.x + (anchor[1] or anchor.x or 0), self.character.y + (anchor[2] or anchor.y or 0)
    end

    return self.character.x + (fallback_x or 0), self.character.y + (fallback_y or 0)
end

function Jarona:getOmegaCenter()
    return self:getPlatformAnchor("omega_orbit_anchor", 10, 5)
end

function Jarona:getOmegaRippleCenter()
    return self:getPlatformAnchor("omega_ripple_anchor", 10, 5)
end

function Jarona:updateCharacterPosition(x, y)
    if not self.character then
        return
    end
    self.character.x = x
    self.character.y = y
    self.character:setFacing(self.facing)
    if self.character.sprite then
        self.character.sprite.flip_x = self.state and self.state.getPlatformFlipX and self.state:getPlatformFlipX() or self.facing == "left"
    end
    Object.uncache(self.character)
    if self.state and self.state.entity then
        self.state.entity.hspeed = 0
        self.state.entity.vspeed = 0
        self.state:syncFromEntity()
    end
end

function Jarona:spawnAfterimage(alpha)
    if not (Game.world and PlatformActionAfterimage and self.character) then
        return
    end

    local afterimage = PlatformActionAfterimage(self.character, rainbowColor(), alpha or 0.75, {solid = true})
    afterimage.fade_speed = 0.04
    afterimage.layer = (self.character.layer or afterimage.layer or 0) - 0.02
    Game.world:addChild(afterimage)
end

function Jarona:updateAfterimages(rate, alpha)
    self.afterimage_timer = self.afterimage_timer + DTMULT
    while self.afterimage_timer >= rate do
        self.afterimage_timer = self.afterimage_timer - rate
        self:spawnAfterimage(alpha)
    end
end

function Jarona:getNormalHitPosition()
    return self.target_x - (self.sign * self.normal_hit_offset), self.target_y
end

function Jarona:getNormalDashAnimation(dist)
    if dist <= self.normal_crescent_distance then
        return "jarona_crescent"
    elseif self.timer < 4 then
        return "jarona_punch"
    end
    return "jarona_fair"
end

function Jarona:addHitEffect(x, y, kind)
    table.insert(self.effects, {
        kind = kind,
        x = x,
        y = y,
        timer = 0,
        life = kind == "shockwave" and 28 or 16,
        color_offset = love.math.random(0, 12),
    })
end

function Jarona:spawnHitEffects()
    local x = self.target_x
    local y = self.target_y
    Featherfall:makeRipple(x, y, {
        life = self.omega and 90 or 48,
        color = colorToInt(rainbowColor()),
        radmax = self.omega and 180 or 72,
        radstart = 4,
        thickness = self.omega and 18 or 10,
        curve = 0,
        yratio = self.omega and 0.75 or 1,
        blend = 1,
        banding = 2,
        fading = true,
        layer = WORLD_LAYERS["above_events"],
    })
    self:addHitEffect(x, y, "shockwave")
    self:addHitEffect(x, y, "spark")
end

function Jarona:performTargetAction()
    local kind = self.omega and "flowery_omega" or "flowery"
    if self.target and self.target.performFollowerAction then
        self.target:performFollowerAction(kind, self.state, self.data)
    end
end

function Jarona:hitTarget()
    if self.hit_done then
        return
    end

    self.hit_done = true
    Assets.playSound("flowery/punchheavythunder", 0.9, 1)
    self:spawnHitEffects()
    self:performTargetAction()
end

function Jarona:updateNormalWindup()
    self:setAnimation("jarona_ready")
    self:updateCharacterPosition(self.character.x, self.start_y)
    if self.timer >= self.normal_windup_time then
        self.phase = "normal_dash"
        self.timer = 0
        self.afterimage_timer = 0
        self.dash_start_x = self.character.x
        self.dash_start_y = self.character.y
        self.dash_target_x, self.dash_target_y = self:getNormalHitPosition()
        self.normal_current_speed = self.normal_speed
        self:setAnimation("jarona_punch")
        self:playRandomVoice()
    end
end

function Jarona:updateNormalDash()
    local x, y = self.character.x, self.character.y
    local dx = self.dash_target_x - x
    local dy = self.dash_target_y - y
    local dist = math.sqrt((dx * dx) + (dy * dy))
    self:setAnimation(self:getNormalDashAnimation(dist))
    self.normal_current_speed = MathUtils.approach(
        self.normal_current_speed,
        self.normal_speed_limit,
        self.normal_speed_change * DTMULT
    )
    local step = self.normal_current_speed * DTMULT

    if dist <= math.max(step, 0.001) then
        self:setAnimation("jarona_crescent")
        self:updateCharacterPosition(self.dash_target_x, self.dash_target_y)
        self:updateAfterimages(1, 0.8)
        self:hitTarget()
        self.phase = "normal_bounce"
        self.timer = 0
        self.bounce_start_x = self.character.x
        self.bounce_start_y = self.character.y
        self.bounce_end_x = self.bounce_start_x - (self.sign * 36)
        self.bounce_end_y = self.start_y
        self:setAnimation("jarona_kick")
        return
    end

    self:updateCharacterPosition(x + ((dx / dist) * step), y + ((dy / dist) * step))
    self:updateAfterimages(1, 0.8)
end

function Jarona:updateNormalBounce()
    self:setAnimation("jarona_kick")
    local progress = MathUtils.clamp(self.timer / math.max(self.normal_bounce_time, 1), 0, 1)
    local eased = Utils.ease(0, 1, progress, "outCubic")
    self:updateCharacterPosition(
        MathUtils.lerp(self.bounce_start_x, self.bounce_end_x, eased),
        MathUtils.lerp(self.bounce_start_y, self.bounce_end_y, eased)
    )
    self:updateAfterimages(1, 0.8)
    if progress >= 1 then
        self.phase = "recover"
        self.timer = 0
        self.afterimage_timer = 0
        self:setAnimation("idle")
    end
end

function Jarona:updateOmegaTransform()
    self:setAnimation("omega_poweringup")
    local sprite = self.character and self.character.sprite
    if sprite and sprite.setFrame then
        local finish_start = math.max(self.omega_transform_time - 20, 1)
        if self.timer < finish_start then
            sprite:setFrame(1)
        else
            local progress = MathUtils.clamp((self.timer - finish_start) / 20, 0, 1)
            sprite:setFrame(1 + math.floor(progress * 4))
        end
    end
    local progress = MathUtils.clamp(self.timer / math.max(self.omega_transform_time, 1), 0, 1)
    local lift = Utils.ease(0, 52, progress, "outCubic")
    self:updateCharacterPosition(self.start_x, self.start_y - lift)

    self.flower_accel = self:getFlowerAccel(self.timer)
    self.flower_angle = self.flower_angle + (self.flower_accel * DTMULT)
    self:updateFlowerAfterimages()

    if not self.omega_music_played then
        self.omega_music_played = true
        Assets.playSound("omegarona")
    end
    if not self.omega_combined_played and progress >= 0.48 then
        self.omega_combined_played = true
        Assets.playSound("flowery/voiceclips/with_your_powers_combined")
    end
    if not self.omega_voice_played and progress >= 0.86 then
        self.omega_voice_played = true
        Assets.playSound("flowery/omega_flowery")
    end
    if self.timer >= self.omega_transform_time then
        self.phase = "omega_charge"
        self.timer = 0
        self.afterimage_timer = 0
        self:setAnimation("omega_powerup")
        Assets.playSound("flowery/chargeshot_charge", 0.8, 0.7)
    end
end

function Jarona:updateOmegaCharge()
    self:updateCharacterPosition(self.start_x, self.start_y - 52)
    self:setAnimation("omega_powerup")

    if (self.timer >= self.omega_charge_time/2) and not self.played_last_jarona then
        self.played_last_jarona = true
        Assets.playSound("flowery/last_jarona")
    end

    local frame = math.floor(self.timer)
    if frame > self.omega_ripple_frame and (frame % 4) == 0 then
        self.omega_ripple_frame = frame
        local ripple_x, ripple_y = self:getOmegaRippleCenter()
        Featherfall:makeRipple(ripple_x, ripple_y, {
            life = 36,
            color = colorToInt(rainbowColor(self.timer)),
            radmax = 110,
            radstart = 8,
            thickness = 12,
            curve = 0,
            yratio = 1,
            blend = 1,
            banding = 2,
            fading = true,
            layer = WORLD_LAYERS["above_events"],
        })
    end
    if self.timer >= self.omega_charge_time then
        self.phase = "omega_strike"
        self.timer = 0
        self.afterimage_timer = 0
        self:setAnimation("omega_jarona")
    end
end

function Jarona:updateOmegaStrike()
    self:setAnimation("omega_jarona")
    local progress = MathUtils.clamp(self.timer / 12, 0, 1)
    local eased = Utils.ease(0, 1, progress, "outCubic")
    self:updateCharacterPosition(
        MathUtils.lerp(self.start_x, self.target_x, eased),
        MathUtils.lerp(self.start_y - 52, self.target_y, eased)
    )
    self:updateAfterimages(2, 0.9)
    if progress >= 0.35 then
        self:hitTarget()
    end
    if self.timer >= 12 then
        self.phase = "recover"
        self.timer = 0
    end
end

function Jarona:updateEffects()
    for index = #self.effects, 1, -1 do
        local effect = self.effects[index]
        effect.timer = effect.timer + DTMULT
        if effect.timer >= effect.life then
            table.remove(self.effects, index)
        end
    end
end

function Jarona:updateFlowerAfterimages()
    for index = #self.flower_afterimages, 1, -1 do
        local afterimage = self.flower_afterimages[index]
        afterimage.timer = afterimage.timer + DTMULT
        afterimage.alpha = afterimage.alpha - (0.04 * DTMULT)
        if afterimage.alpha <= 0 then
            table.remove(self.flower_afterimages, index)
        end
    end

    for i = 1, #FLOWER_SPRITES do
        local info = self:getFlowerDrawInfo(i)
        if info then
            local frame = math.floor(info.age)
            if frame > (self.flower_afterimage_frames[i] or -1) and (frame % 3) == ((i - 1) % 3) then
                self.flower_afterimage_frames[i] = frame
                table.insert(self.flower_afterimages, {
                    texture = info.texture,
                    x = info.x,
                    y = info.y,
                    origin_x = info.origin_x,
                    origin_y = info.origin_y,
                    color = info.color,
                    alpha = 0.2 * info.alpha,
                    timer = 0,
                })
            end
        end
    end
end

function Jarona:update()
    super.update(self)
    if not (self.character and self.character.parent) then
        self:remove()
        return
    end
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    self.timer = self.timer + DTMULT
    self:updateEffects()

    if self.phase == "normal_windup" then
        self:updateNormalWindup()
    elseif self.phase == "normal_dash" then
        self:updateNormalDash()
    elseif self.phase == "normal_bounce" then
        self:updateNormalBounce()
    elseif self.phase == "omega_transform" then
        self:updateOmegaTransform()
    elseif self.phase == "omega_charge" then
        self:updateOmegaCharge()
    elseif self.phase == "omega_strike" then
        self:updateOmegaStrike()
    else
        self:setAnimation(self.omega and "omega_jarona" or "idle")
        if self.timer >= self.recover_time then
            self:remove()
        end
    end
end

function Jarona:getFlowerAccel(timer)
    if timer < 60 then
        return MathUtils.lerp(0, 5, Utils.ease(0, 1, timer / 60, "inOutQuad"))
    elseif timer < 90 then
        return MathUtils.lerp(5, 3, Utils.ease(0, 1, (timer - 60) / 30, "inOutQuad"))
    else
        return MathUtils.lerp(3, 10, Utils.ease(0, 1, (timer - 90) / 60, "inQuad"))
    end
end

function Jarona:getFlowerRadius(timer)
    if timer < 90 then
        return MathUtils.lerp(140, 90, Utils.ease(0, 1, timer / 90, "inOutQuad"))
    end
    return MathUtils.lerp(90, 0, Utils.ease(0, 1, (timer - 90) / 60, "inQuad"))
end

function Jarona:getFlowerDrawInfo(index)
    local sprite = FLOWER_SPRITES[index]
    local spawn_time = index * 10
    local age = self.timer - spawn_time
    if not sprite or age < 0 then
        return
    end

    local frames = Assets.getFrames(sprite.path)
    if not (frames and frames[1]) then
        return
    end

    local radius = self:getFlowerRadius(self.timer)
    local anchor_x, anchor_y = self:getOmegaCenter()
    local angle = math.rad(self.flower_angle + ((index - 1) * 60))
    local xoffset = ((sprite.origin_x or 0) * 2) - (sprite.width or frames[1]:getWidth())
    local yoffset = ((sprite.origin_y or 0) * 2) - (sprite.height or frames[1]:getHeight())
    local color = mergeColor(FLOWER_COLORS[index], {1, 1, 1}, 0.5)
    return {
        texture = frames[1],
        x = anchor_x + (math.cos(angle) * radius) + xoffset,
        y = anchor_y + (math.sin(angle) * radius * 0.7) + yoffset + (math.sin(age * 0.2) * 4),
        origin_x = sprite.origin_x or 0,
        origin_y = sprite.origin_y or 0,
        color = color,
        alpha = MathUtils.clamp((age / 15) * 1.5, 0, 1.5),
        age = age,
    }
end

function Jarona:drawForcedSprite(texture, x, y, origin_x, origin_y, color, alpha)
    local shader = Kristal.Shaders["AddColor"]
    local last_shader = love.graphics.getShader()
    love.graphics.setShader(shader)
    shader:send("inputcolor", {color[1] or 1, color[2] or 1, color[3] or 1})
    shader:send("amount", 1)
    Draw.setColor(1, 1, 1, MathUtils.clamp(alpha or 1, 0, 1))
    Draw.draw(texture, x - self.x, y - self.y, 0, 2, 2, origin_x or 0, origin_y or 0)
    love.graphics.setShader(last_shader)
end

function Jarona:drawFlowerCircle()
    if not self.omega or self.phase ~= "omega_transform" then
        return
    end

    for _, afterimage in ipairs(self.flower_afterimages) do
        self:drawForcedSprite(
            afterimage.texture,
            afterimage.x,
            afterimage.y,
            afterimage.origin_x,
            afterimage.origin_y,
            afterimage.color,
            afterimage.alpha
        )
    end

    for i = 1, #FLOWER_SPRITES do
        local info = self:getFlowerDrawInfo(i)
        if info then
            self:drawForcedSprite(info.texture, info.x, info.y, info.origin_x, info.origin_y, info.color, info.alpha)
            Draw.setColor(1, 1, 1, MathUtils.clamp((info.alpha * info.alpha) * 0.2, 0, 1))
            Draw.draw(info.texture, info.x - self.x, info.y - self.y, 0, 2, 2, info.origin_x, info.origin_y)
        end
    end
    Draw.setColor(1, 1, 1, 1)
end

function Jarona:drawEffects()
    for _, effect in ipairs(self.effects) do
        local progress = MathUtils.clamp(effect.timer / math.max(effect.life, 1), 0, 1)
        local x = effect.x - self.x
        local y = effect.y - self.y
        local color = rainbowColor(effect.color_offset + effect.timer)
        Draw.setColor(color[1], color[2], color[3], 1 - progress)
        if effect.kind == "shockwave" then
            local frames = Assets.getFrames("party/flowery/jarona/spr_flowery_shockwave")
            if frames and #frames > 0 then
                local frame = frames[math.min(#frames, math.floor(progress * #frames) + 1)]
                Draw.draw(frame, x - 12, y + 96, 0, self.facing == "left" and -1 or 1, 0.35 + (progress * 0.9), 0, 200)
            else
                love.graphics.circle("line", x, y, 16 + (progress * 70))
            end
        else
            for i = 1, 8 do
                local angle = ((i / 8) * math.pi * 2) + (progress * 1.5)
                local dist = 8 + (progress * 40)
                love.graphics.rectangle("fill", x + (math.cos(angle) * dist), y + (math.sin(angle) * dist), 3, 3)
            end
        end
    end
    Draw.setColor(1, 1, 1, 1)
end

function Jarona:draw()
    super.draw(self)
    self:drawFlowerCircle()
    self:drawEffects()
end

return Jarona
