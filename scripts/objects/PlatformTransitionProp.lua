---@class PlatformTransitionProp : Object
local PlatformTransitionProp, super = Class(Object)

function PlatformTransitionProp:init(actor, x, y, facing, animation_name, duration, target_x, target_y, start_frame, options)
    options = options or {}
    local width, height = 20, 38
    if actor and actor.getPlatformSize then
        width, height = actor:getPlatformSize()
    end

    super.init(self, x, y, width, height)

    self.actor = actor
    self.facing = facing or "right"
    self.animation_name = animation_name or "idle"
    self.duration = math.max(duration or Featherfall.constants.transition_timemax, 1)
    self.timer = 0
    self.finished = false
    self.suppress_finish = false
    self.start_x = x
    self.start_y = y
    self.target_x = target_x or x
    self.target_y = target_y or y
    self.start_frame = start_frame
    self.transition_kind = options.kind or "linear"
    self.manual_speed = options.manual_speed or 0.25
    self.fallmode = options.fallmode or options.fall_mode or 0
    self.fall_vspeed = options.fall_vspeed or 0
    self.fall_land_timer = options.fall_land_timer or 10
    self.fall_animation = options.fall_animation or "jump_down"
    self.land_animation = options.land_animation or "land"
    self:setOrigin(0.5, 1)
    self:setScale(2)

    self.sprite = nil
    self:setPlatformAnimation(self.animation_name)
    if self.fallmode == 1 then
        self:setPlatformAnimation(self.fall_animation)
    end
end

function PlatformTransitionProp:getPlatformAnimation(name)
    if self.actor and self.actor.getPlatformAnimation then
        return self.actor:getPlatformAnimation(name)
    end
end

function PlatformTransitionProp:getPlatformOffset(name)
    if self.actor and self.actor.getPlatformOffset then
        return self.actor:getPlatformOffset(name, self.facing, self.width, self.height)
    end
    return 0, 0
end

function PlatformTransitionProp:getPlatformFlipX()
    if self.actor and self.actor.getPlatformFlipX then
        return self.actor:getPlatformFlipX(self.facing, self, self)
    end

    local data = self.actor and self.actor.platform
    local animation = self:getPlatformAnimation(self.animation_name)
    local flip_x = self.facing == "left"
    if animation and animation.invert_flip ~= nil then
        return animation.invert_flip and not flip_x or flip_x
    end
    if data and data.invert_flip then
        return not flip_x
    end
    return flip_x
end

function PlatformTransitionProp:setPlatformAnimation(name)
    local animation = self:getPlatformAnimation(name)
    if not animation or not animation.sprite then
        return
    end

    self.animation_name = name
    self.platform_animation = animation
    self.manual_frame = self.start_frame or 1
    local offset_x, offset_y = self:getPlatformOffset(name)
    if self.sprite then
        self.sprite:remove()
    end

    self.sprite = Sprite(animation.sprite, offset_x, offset_y)
    self.sprite.flip_x = self:getPlatformFlipX()
    self:addChild(self.sprite)
    if animation.manual then
        self.sprite:stop()
    elseif animation.speed then
        self.sprite:play(animation.speed, animation.loop ~= false)
    end

    if self.start_frame and self.sprite.frames then
        self.manual_frame = math.max(1, math.min(#self.sprite.frames, self.start_frame))
        self.sprite:setFrame(self.manual_frame)
    end
end

function PlatformTransitionProp:updateManualAnimation()
    if not (self.platform_animation and self.platform_animation.manual and self.sprite and self.sprite.frames) then
        return
    end

    if self.animation_name ~= "slash_ground" and self.animation_name ~= "slash_air" then
        return
    end

    self.manual_frame = math.min(#self.sprite.frames, (self.manual_frame or self.sprite.frame or 1) + (self.manual_speed * DTMULT))
    local image_index = self.manual_frame - 1
    if (image_index >= 4.5 and image_index <= 5) or (image_index >= 7.5 and image_index <= 8) then
        self.start_frame = nil
        self:setPlatformAnimation("idle")
        return
    end

    self.sprite:setFrame(self.manual_frame)
end

function PlatformTransitionProp:setTarget(x, y, duration, kind)
    self.start_x = self.x
    self.start_y = self.y
    self.target_x = x or self.x
    self.target_y = y or self.y
    self.duration = math.max(duration or self.duration, 1)
    self.transition_kind = kind or "linear"
    self.timer = 0
end

function PlatformTransitionProp:getTransitionY(progress)
    if self.transition_kind ~= "enter" then
        return Utils.ease(self.start_y, self.target_y, progress, "inOutCubic")
    end

    local hover_y = self.target_y - 20
    local hover_duration = math.max(self.duration - 2, 1)
    local hover_progress = math.min(self.timer / hover_duration, 1)
    return Utils.ease(self.start_y, hover_y, hover_progress, "inOutCubic")
end

function PlatformTransitionProp:collidesWithPlatformMarker(predicate)
    if not (Game.world and Game.world.map) then
        return false
    end

    for _, event in ipairs(Game.world.map.events or {}) do
        if predicate(event) and event.collider and self:collidesWith(event.collider) then
            return true
        end
    end
    return false
end

function PlatformTransitionProp:isOnFallCue()
    return self:collidesWithPlatformMarker(function(event)
        return event.platform_fall_cue
    end)
end

function PlatformTransitionProp:isInsideSolidBlock()
    return self:collidesWithPlatformMarker(function(event)
        return event.platform_block or (event.solid and event.platform_collision ~= false)
    end)
end

function PlatformTransitionProp:updateFallMode()
    if self.fallmode == 1 then
        self.fall_vspeed = math.min((self.fall_vspeed or 0) + DTMULT, 20)
        self.y = self.y + (self.fall_vspeed * DTMULT)
        if self.animation_name ~= self.fall_animation then
            self:setPlatformAnimation(self.fall_animation)
        end

        if not self:isInsideSolidBlock() and not self:isOnFallCue() and self.y >= 0 then
            self.fallmode = 2
            self.fall_vspeed = 0
            self.fall_land_timer = 10
            Assets.playSound(Featherfall.sounds.landing, nil, 1.2)
            self:setPlatformAnimation(self.land_animation)
            if self.sprite then
                self.sprite:stop()
                self.sprite:setFrame(math.max(1, math.min(2, #(self.sprite.frames or {1}))))
            end
        end
        return true
    elseif self.fallmode == 2 then
        self.fall_land_timer = MathUtils.approach(self.fall_land_timer or 0, 0, DTMULT)
        if self.fall_land_timer <= 0 then
            self:finish()
            self:remove()
        end
        return true
    end
    return false
end

function PlatformTransitionProp:finish()
    if self.finished then
        return
    end

    self.finished = true
    local finish_callback = self.on_finish or self.onFinish
    if finish_callback and not self.suppress_finish then
        finish_callback(self)
    end
end

function PlatformTransitionProp:update()
    super.update(self)

    self:updateManualAnimation()

    if self:updateFallMode() then
        return
    end

    self.timer = self.timer + DTMULT
    local progress = math.min(self.timer / self.duration, 1)
    self.x = Utils.ease(self.start_x, self.target_x, progress, "inOutCubic")
    self.y = self:getTransitionY(progress)

    if progress >= 1 then
        self:finish()
        self:remove()
    end
end

function PlatformTransitionProp:onRemove(parent)
    self:finish()
    super.onRemove(self, parent)
end

return PlatformTransitionProp
