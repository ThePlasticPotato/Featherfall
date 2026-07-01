local PlatformActorState = libRequire("featherfall", "scripts.world.states.PlatformActorState")
local PlatformActions = libRequire("featherfall", "scripts.world.states.PlatformActions")

---@class FollowerPlatformState : PlatformActorState
---@field follower Follower
local FollowerPlatformState, super = Class(PlatformActorState)

function FollowerPlatformState:init(follower)
    self.follower = follower
    self.entity = nil
    self.hspeed = 0
    self.vspeed = 0
    self.on_ground = false
    self.facing = "right"
    self.current_animation = nil
    self.current_sprite_facing = nil
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    self.turn_facing = nil
    self.important_blend = 1
    self.menu_pause_active = false
    self.targetmode_sprite_pause = nil
    self.timer = 0
    self.history_step_timer = 0
    self.dash_transition_active = false
    self.dash_lerp_start_x = 0
    self.dash_lerp_start_y = 0
    self.offscreen_despawn_cooldown = 0
    self.recover_alpha_timer = 0
    self.respawn_leap_enabled = true
    self.fallen_in_pit = false
    self.respawn_leap = false
    self.respawn_leap_wait = 15
    self.respawn_leap_time = 15
    self.pit_lerp_start_x = 0
    self.checkpoint_x = 0
    self.position_history_length = 36
    self.caterpillar_history_x = {}
    self.caterpillar_history_y = {}
    self.caterpillar_history_speed = {}
    self.caterpillar_history_direction = {}
    self.caterpillar_history_ground = {}
    self.ralsei_platform_mode = 0
    self.action_platform_mode = 0
    self.ralsei_platform_timer = 0
    self.action_platform_timer = 0
    self.ralsei_platform_target = nil
    self.action_platform_target = nil
    self.action_platform_target_override = nil
    self.ralsei_platform_offset_x = 0
    self.ralsei_platform_offset_y = 0
    self.action_platform_offset_x = 0
    self.action_platform_offset_y = 0
    self.ralsei_platform_object = nil
    self.ralsei_scarf_object = nil
    self.ralsei_platform_stand_count = 0
    self.player_stood_on_ralsei_recently = false
    self.player_stood_on_action_platform_recently = false
    self.ralsei_platform_long = false
    self.action_platform_long = false
    self.ralsei_fall_timer = 0
    self.ralsei_fall_splat_duration = 0
    self.ralsei_fall_phase = 0
    self.ralsei_splat_timer = 0
    self.ralsei_splat_timer_max = 0
    self.ralsei_splat_timer_max = 0
    self.actions = PlatformActions(self)
end

function FollowerPlatformState:registerEvents()
    self:registerEvent("enter", self.onEnter)
    self:registerEvent("update", self.onUpdate)
    self:registerEvent("leave", self.onExit)
    self:registerEvent("drawDebug", self.drawDebug)
    self:registerEvent("getDebugInfo", self.getDebugInfo)
end

function FollowerPlatformState:getDebugInfo(info)
    table.insert(info, string.format("Featherfall follower speed: %.2f, %.2f", self.hspeed, self.vspeed))
    table.insert(info, "Featherfall follower grounded: " .. (self.on_ground and "True" or "False"))
    if self.actions and self.actions.active then
        table.insert(info, "Featherfall follower action: " .. tostring(self.actions.phase))
    end
end

function FollowerPlatformState:requestAction(target, data)
    data = data or self.actions:getData()
    if not (target and data) then
        return false
    end
    if self.actions and self.actions.prepareTargetData then
        data = self.actions:prepareTargetData(data, target)
    end
    if data.onAutoSelect then
        local handled = data.onAutoSelect(self, self.actions, target, data)
        if handled ~= nil then
            return handled
        end
    end
    if target.platform_action_target and not target.platform_action_override and self.turnIntoActionPlatform then
        return self:turnIntoActionPlatform(target, target.hang_xoffset or 0, target.hang_yoffset or 0, data)
    end
    if self:isActionPlatformActive() then
        self:dropOffActionPlatform(true)
    end
    self.actions:begin(target, data)
    return true
end

function FollowerPlatformState:setFollowerAnimation(name)
    return self:setPlatformAnimation(name)
end

function FollowerPlatformState:getFollowerKind()
    return self:getActionKind()
end

function FollowerPlatformState:getInitialOffset()
    if Featherfall and Featherfall.getPlatformFollowerOffset then
        return Featherfall:getPlatformFollowerOffset(self.follower)
    end
    local index = self.follower.index or 1
    return index % 2 == 1 and -40 or 40
end

function FollowerPlatformState:getCaterpillarDistance()
    if Featherfall and Featherfall.getPlatformFollowerHistoryDistance then
        return Featherfall:getPlatformFollowerHistoryDistance(self.follower)
    end
    return ((self.follower and self.follower.index) or 1) * 6
end

function FollowerPlatformState:updateActionOutline()
    local should_outline = self.targetmode_highlighted
    local fx = self.follower:getFX("platform_action_outline")

    if not should_outline then
        if fx then
            self.follower:removeFX(fx)
        end
        return
    end

    if not fx then
        fx = self.follower:addFX(OutlineFX({1, 1, 1, 1}, {thickness = 1}), "platform_action_outline")
    end

    local color = self.targetmode_outline_kind and Featherfall and Featherfall.getActionColorTable and Featherfall:getActionColorTable(self.targetmode_outline_kind)
    local r, g, b = self:getOutlineBaseColor()
    if color then
        r, g, b = color[1], color[2], color[3]
    end
    local amount = 0.8 + (math.sin(Kristal.getTime() * 10) * 0.2)
    fx:setColor(MathUtils.lerp(r, 1, amount), MathUtils.lerp(g, 1, amount), MathUtils.lerp(b, 1, amount), 1)
end

function FollowerPlatformState:updateImportantBlend(targetmode)
    local forced_anim = (self.action_platform_mode or self.ralsei_platform_mode) == 3
    local target = (targetmode or forced_anim or (self.actions and self.actions.active)) and 1 or 0
    self.important_blend = MathUtils.approach(self.important_blend or 1, target, 0.15 * DTMULT)

    local gray = 143 / 255
    local value = MathUtils.lerp(gray, 1, self.important_blend)
    if self.follower and self.follower.sprite then
        self.follower.sprite:setColor(value, value, value)
    end
end

function FollowerPlatformState:isRalseiPlatformActive()
    return self:isActionPlatformActive()
end

function FollowerPlatformState:isActionPlatformActive()
    return (self.action_platform_mode or self.ralsei_platform_mode or 0) > 0
end

function FollowerPlatformState:getActionPlatformTargetOverride(target)
    local override = self.action_platform_target_override
    if type(override) == "function" then
        return override(self, target)
    end
    return override
end

function FollowerPlatformState:turnIntoActionPlatform(target, offset_x, offset_y, action_data)
    if not target then
        return false
    end

    if self:isActionPlatformActive() then
        self:dropOffActionPlatform(false)
    end
    self.ralsei_platform_mode = 1
    self.action_platform_mode = 1
    self.ralsei_platform_timer = 0
    self.action_platform_timer = 0
    self.ralsei_platform_target = target
    self.action_platform_target = target
    self.action_platform_target_override = action_data and action_data.action_platform_target_override
    self.ralsei_platform_offset_x = offset_x or 0
    self.ralsei_platform_offset_y = offset_y or 0
    self.action_platform_offset_x = self.ralsei_platform_offset_x
    self.action_platform_offset_y = self.ralsei_platform_offset_y
    self.ralsei_platform_stand_count = 0
    self.player_stood_on_ralsei_recently = false
    self.player_stood_on_action_platform_recently = false
    self.ralsei_platform_long = target.platform_long or false
    self.action_platform_long = self.ralsei_platform_long
    self.ralsei_fall_timer = 0
    self.ralsei_fall_splat_duration = 0
    self.ralsei_fall_phase = 0
    self.ralsei_splat_timer = 0
    self.ralsei_splat_timer_max = 0
    self.offscreen_despawn_cooldown = 100
    self.follower.alpha = 1
    if self.follower.sprite then
        self.follower.sprite.visible = true
    end
    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = 1
        self.entity.wallcollision = false
        self.entity.grounded = false
        self.entity.ground = nil
    end
    self:setFollowerAnimation("jump_down")

    if Game.world and RalseiPlatform then
        if self.ralsei_platform_object and self.ralsei_platform_object.parent then
            self.ralsei_platform_object:remove()
        end
        if self.ralsei_scarf_object and self.ralsei_scarf_object.parent then
            self.ralsei_scarf_object:remove()
        end
        self.ralsei_scarf_object = RalseiPlatformScarf and Game.world:spawnObject(RalseiPlatformScarf(self), self.follower.layer - 0.01) or nil
        self.ralsei_platform_object = Game.world:spawnObject(RalseiPlatform(self), self.follower.layer + 0.01)
    end
    return true
end

FollowerPlatformState.turnIntoRalseiPlatform = FollowerPlatformState.turnIntoActionPlatform

function FollowerPlatformState:dropOffActionPlatform(reset_history)
    local old_target = self.action_platform_target or self.ralsei_platform_target
    self.ralsei_platform_mode = 0
    self.action_platform_mode = 0
    self.ralsei_platform_timer = 0
    self.action_platform_timer = 0
    self.ralsei_platform_target = nil
    self.action_platform_target = nil
    self.action_platform_target_override = nil
    self.ralsei_platform_offset_x = 0
    self.ralsei_platform_offset_y = 0
    self.action_platform_offset_x = 0
    self.action_platform_offset_y = 0
    self.ralsei_platform_stand_count = 0
    self.player_stood_on_ralsei_recently = false
    self.player_stood_on_action_platform_recently = false
    self.ralsei_platform_long = false
    self.action_platform_long = false
    self.ralsei_fall_timer = 0
    self.ralsei_fall_splat_duration = 0
    self.ralsei_fall_phase = 0
    self.ralsei_splat_timer = 0
    self.ralsei_splat_timer_max = 0
    if self.ralsei_platform_object and self.ralsei_platform_object.parent then
        self.ralsei_platform_object:remove()
    end
    if self.ralsei_scarf_object and self.ralsei_scarf_object.parent then
        self.ralsei_scarf_object:remove()
    end
    self.ralsei_platform_object = nil
    self.ralsei_scarf_object = nil
    self.follower.alpha = 1
    if self.follower.sprite then
        self.follower.sprite.visible = true
    end
    if self.entity then
        self.entity.wallcollision = true
        self.entity.grounded = false
        self.entity.ground = nil
    end
    self:setFollowerAnimation("jump_down")
    if reset_history ~= false then
        self:seedCaterpillarHistory(Game.world and Game.world.player)
    end
    if old_target and old_target.updateActionPlatformState then
        old_target:updateActionPlatformState()
    end
end

FollowerPlatformState.dropOffRalseiPlatform = FollowerPlatformState.dropOffActionPlatform

function FollowerPlatformState:actionPlatformFallDown(splat_duration)
    if (self.ralsei_platform_mode or 0) < 3 then
        self:dropOffActionPlatform(true)
        return true
    end

    if self.ralsei_platform_object and self.ralsei_platform_object.parent then
        self.ralsei_platform_object.platform_collision = false
        self.ralsei_platform_object:remove()
        self.ralsei_platform_object = nil
    end
    if self.ralsei_scarf_object and self.ralsei_scarf_object.parent then
        self.ralsei_scarf_object:remove()
    end
    self.ralsei_scarf_object = nil
    self.ralsei_platform_mode = 4
    self.action_platform_mode = 4
    self.ralsei_platform_timer = 0
    self.action_platform_timer = 0
    self.ralsei_fall_timer = 0
    self.ralsei_fall_phase = 1
    self.ralsei_fall_splat_duration = splat_duration or 0
    self.ralsei_platform_stand_count = 0
    self.player_stood_on_ralsei_recently = true
    self.player_stood_on_action_platform_recently = true
    self.follower.alpha = 1
    if self.follower.sprite then
        self.follower.sprite.visible = true
    end
    if self.entity then
        self.entity.wallcollision = true
        self.entity.hspeed = 0
        self.entity.vspeed = 0
        self.entity.grounded = false
        self.entity.ground = nil
    end
    self:setFollowerAnimation("jump_down")
    return true
end

FollowerPlatformState.ralseiFallDown = FollowerPlatformState.actionPlatformFallDown

function FollowerPlatformState:syncRalseiPlatformObject()
    if self.ralsei_scarf_object and self.ralsei_scarf_object.syncFromState then
        self.ralsei_scarf_object:syncFromState()
    end
    if self.ralsei_platform_object and self.ralsei_platform_object.syncFromState then
        self.ralsei_platform_object:syncFromState()
    end
end

function FollowerPlatformState:getRalseiPlatformTargetPosition()
    local target = self.action_platform_target or self.ralsei_platform_target
    if not (target and target.parent) then
        return
    end
    return target.x + (self.action_platform_offset_x or self.ralsei_platform_offset_x or 0),
        target.y + (self.action_platform_offset_y or self.ralsei_platform_offset_y or 0)
end

function FollowerPlatformState:updateRalseiPlatformStandCount()
    self.ralsei_platform_stand_count = 0
    local platform = self.ralsei_platform_object
    if not platform then
        return
    end

    local player = Game.world and Game.world.player
    local player_state = player and player.platform_state
    if player_state and player_state.entity and player_state.entity.ground == platform then
        self.ralsei_platform_stand_count = self.ralsei_platform_stand_count + 1
        self.player_stood_on_ralsei_recently = true
        self.player_stood_on_action_platform_recently = true
    end

    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        local ff_state = follower.platform_state
        if ff_state and ff_state ~= self and ff_state.entity and ff_state.entity.ground == platform then
            self.ralsei_platform_stand_count = self.ralsei_platform_stand_count + 1
        end
    end
    self.ralsei_platform_stand_count = MathUtils.clamp(self.ralsei_platform_stand_count, 0, 2)
end

function FollowerPlatformState:updateRalseiPlatformMode(player)
    if not self:isRalseiPlatformActive() then
        return false
    end

    local target_x, target_y = self:getRalseiPlatformTargetPosition()
    if not target_x then
        self:dropOffActionPlatform()
        return false
    end

    self.ralsei_platform_timer = self.ralsei_platform_timer + DTMULT

    if self.ralsei_platform_mode > 1
        and self.offscreen_despawn_cooldown <= 0
        and not self:isOnscreen(120, false)
    then
        self:dropOffActionPlatform(true)
        return true
    end

    if self.ralsei_platform_mode == 1 then
        self.follower.alpha = math.max((self.follower.alpha or 1) - (0.15 * DTMULT), 0)
        if self.ralsei_platform_timer >= 8 then
            self.follower.alpha = 0
            self.ralsei_platform_mode = 2
            self.action_platform_mode = 2
            self.ralsei_platform_timer = 0
            self.action_platform_timer = 0
            self.follower.x = target_x
            self.follower.y = target_y - 20
            Object.uncache(self.follower)
            self:syncRalseiPlatformObject()
            if self.entity then
                self.entity.vspeed = 2
            end
        end
    elseif self.ralsei_platform_mode == 2 then
        self.follower.x = target_x
        local vspeed = (self.entity and self.entity.vspeed or self.vspeed or 0) + (0.2 * DTMULT)
        local next_y = self.follower.y + (vspeed * DTMULT)
        self.follower.alpha = math.min((self.follower.alpha or 0) + (0.1 * DTMULT), 1)
        if next_y >= target_y + 60 then
            self.follower.y = target_y + 60
            self.follower.alpha = 1
            self.ralsei_platform_mode = 3
            self.action_platform_mode = 3
            self.ralsei_platform_timer = 0
            self.action_platform_timer = 0
            vspeed = 0
            Assets.playSound(Featherfall.sounds.action_platform_grab)
        else
            self.follower.y = next_y
        end
        Object.uncache(self.follower)
        self:syncRalseiPlatformObject()
        if self.entity then
            self.entity.hspeed = 0
            self.entity.vspeed = vspeed
            self.entity.grounded = false
            self.entity.ground = nil
        end
    elseif self.ralsei_platform_mode == 3 then
        self.follower.x = target_x
        self.follower.y = target_y + 60
        self.follower.alpha = 1
        Object.uncache(self.follower)
        self:syncRalseiPlatformObject()
        if self.follower.sprite then
            self.follower.sprite.visible = false
        end
        if self.entity then
            self.entity.hspeed = 0
            self.entity.vspeed = 0
            self.entity.grounded = false
            self.entity.ground = nil
        end
        self:updateRalseiPlatformStandCount()
        if self.actions then
            self.actions:update(player)
        end
    elseif self.ralsei_platform_mode == 4 then
        self:updateRalseiFallDown(player)
    end

    self:syncFromEntity()
    return true
end

function FollowerPlatformState:updateRalseiFallDown(player)
    self.ralsei_fall_timer = (self.ralsei_fall_timer or 0) + DTMULT
    if self.ralsei_platform_object and self.ralsei_platform_object.parent then
        self.ralsei_platform_object.platform_collision = false
        self.ralsei_platform_object:remove()
        self.ralsei_platform_object = nil
        if self.ralsei_scarf_object and self.ralsei_scarf_object.parent then
            self.ralsei_scarf_object:remove()
        end
        self.ralsei_scarf_object = nil
        if self.follower.sprite then
            self.follower.sprite.visible = true
        end
    end

    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = math.min((self.entity.vspeed or 0) + (0.5 * DTMULT), 15)
        self.entity:updatePhysics({skip_moving_ground = true})
    else
        self.follower.y = self.follower.y + (8 * DTMULT)
        Object.uncache(self.follower)
    end
    self:syncFromEntity()

    if not self.on_ground then
        self:setFollowerAnimation("jump_down")
        return
    end

    local splat_duration = self.ralsei_fall_splat_duration or 0
    local old_target = self.action_platform_target or self.ralsei_platform_target
    self.ralsei_platform_mode = 0
    self.action_platform_mode = 0
    self.ralsei_platform_target = nil
    self.action_platform_target = nil
    self.action_platform_target_override = nil
    self.ralsei_platform_offset_x = 0
    self.ralsei_platform_offset_y = 0
    self.action_platform_offset_x = 0
    self.action_platform_offset_y = 0
    self.ralsei_platform_long = false
    self.action_platform_long = false
    self.ralsei_fall_phase = 0
    self.ralsei_fall_timer = 0
    self.ralsei_fall_splat_duration = 0
    if self.entity then
        self.entity.wallcollision = true
        self.entity.hspeed = 0
        self.entity.vspeed = 0
    end
    if self.follower.sprite then
        self.follower.sprite.visible = true
    end
    if splat_duration > 0 then
        Assets.playSound("splat")
        self.ralsei_splat_timer = splat_duration
        self.ralsei_splat_timer_max = splat_duration
    end
    self:setFollowerAnimation(splat_duration > 0 and "splat" or "idle")
    self:seedCaterpillarHistory(player)
    if old_target and old_target.updateActionPlatformState then
        old_target:updateActionPlatformState()
    end
end

function FollowerPlatformState:updateRalseiSplat(player)
    if (self.ralsei_splat_timer or 0) <= 0 then
        return false
    end

    self.ralsei_splat_timer = MathUtils.approach(self.ralsei_splat_timer, 0, DTMULT)
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = 0
        local ground = self.entity.ground or self.entity:findGroundAt(self.follower.x, self.follower.y, 8)
        if ground then
            self.entity:landOn(ground)
            self.entity:applyGroundEffects()
        else
            self.entity.grounded = true
        end
        self:syncFromEntity()
    end
    self.hspeed = 0
    self.vspeed = 0
    self.on_ground = true
    if self.actions then
        self.actions:updateCooldown()
    end
    self:setFollowerAnimation("splat")

    if self.ralsei_splat_timer <= 0 then
        self.ralsei_splat_timer_max = 0
        self:setFollowerAnimation("idle")
        self:seedCaterpillarHistory(player)
    end
    return true
end

function FollowerPlatformState:isPlatformActionBlocked()
    return (self.ralsei_splat_timer or 0) > 0
end

function FollowerPlatformState:getPlatformMeters()
    if (self.ralsei_splat_timer or 0) <= 0 then
        return {}
    end
    local color = {0.5, 1, 0.5}
    if Featherfall and Featherfall.getActionColorTable then
        color = Featherfall:getActionColorTable(self:getFollowerKind(), nil, self) or color
    end
    return {{
        text = "SPLAT",
        value = self.ralsei_splat_timer,
        max_value = math.max(self.ralsei_splat_timer_max or self.ralsei_splat_timer, 1),
        color = color,
    }}
end

function FollowerPlatformState:getFollowDistance(target)
    local distance = 90
    local actor = self:getPlatformActor()
    local data = actor and actor.getPlatformData and actor:getPlatformData()
    local custom_distance = data and (data.follow_distance or data.follower_follow_distance)
    local distance_bonus = data and (data.follow_distance_bonus or data.follower_follow_distance_bonus)
    if type(custom_distance) == "function" then
        distance = custom_distance(actor, self, target, distance) or distance
    elseif custom_distance ~= nil then
        distance = tonumber(custom_distance) or distance
    elseif type(distance_bonus) == "function" then
        distance = distance + (distance_bonus(actor, self, target, distance) or 0)
    elseif distance_bonus ~= nil then
        distance = distance + (tonumber(distance_bonus) or 0)
    end
    if target and self.follower.y > target.y then
        distance = 60
    end
    if not self.on_ground then
        distance = 20
    end
    return distance
end

function FollowerPlatformState:getAirAnimationName()
    local jumping = self.entity and self.entity.jumping or 0
    local air_animation = self.air_animation or self.current_animation

    if jumping == 1 then
        air_animation = "jump_up"
    elseif jumping >= 2 then
        air_animation = "jump_down"
    elseif air_animation == "jump_down" then
        if self.vspeed <= -1 then
            air_animation = "jump_up"
        end
    elseif self.vspeed >= 1 then
        air_animation = "jump_down"
    else
        air_animation = "jump_up"
    end

    self.air_animation = air_animation
    return air_animation
end

function FollowerPlatformState:beginLandAnimation()
    self.land_anim = true
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = self:getAnimationDuration("land", 0.25)
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
end

function FollowerPlatformState:beginTurnAnimation(facing)
    self.turn_anim = true
    self.turn_facing = facing or self.facing
    self.turn_anim_timer = self:getAnimationDuration("turn")
end

function FollowerPlatformState:beginRunstopAnimation()
    self.runstop_anim = true
    self.turn_anim = false
    self.turn_facing = nil
    self.runstop_anim_timer = self:getAnimationDuration("halt", 0.3)
    self.turn_anim_timer = 0
end

function FollowerPlatformState:updateMovementAnimationFlags(key_left, key_right, move)
    if not self.on_ground then
        self.land_anim = false
        self.turn_anim = false
        self.runstop_anim = false
        self.land_anim_timer = 0
        self.turn_anim_timer = 0
        self.runstop_anim_timer = 0
        self.turn_facing = nil
        return
    end

    self.air_animation = nil

    if self.land_anim and (key_left or key_right) then
        self.land_anim = false
        self.land_anim_timer = 0
    end

    if self.land_anim then
        self.land_anim_timer = self.land_anim_timer - DTMULT
        if self.land_anim_timer <= 0 then
            self.land_anim = false
        end
    end
    if self.turn_anim then
        self.turn_anim_timer = self.turn_anim_timer - DTMULT
        if self.turn_anim_timer <= 0 then
            self.turn_anim = false
            self.turn_facing = nil
        end
    end
    if self.runstop_anim then
        self.runstop_anim_timer = self.runstop_anim_timer - DTMULT
        if self.runstop_anim_timer <= 0 or key_left or key_right or move ~= 0 then
            self.runstop_anim = false
        end
    end

    local landed = self.entity and self.entity.grounded and not self.entity.grounded_prev
    if landed and not self.land_anim then
        self:beginLandAnimation()
    end

    if not self.land_anim then
        if key_left and not self.turn_anim and self.hspeed > 0.1 then
            self:beginTurnAnimation("left")
        elseif key_right and not self.turn_anim and self.hspeed < -0.1 then
            self:beginTurnAnimation("right")
        elseif move == 0 and not self.runstop_anim and not self.turn_anim and self.current_animation == "run" and math.abs(self.hspeed) <= 0.5 then
            self:beginRunstopAnimation()
        end
    end
end

function FollowerPlatformState:applyMovementAnimation(move)
    if not self.on_ground then
        self:setFollowerAnimation(self:getAirAnimationName())
    elseif self.land_anim then
        self:setFollowerAnimation("land")
    elseif self.turn_anim then
        if self.turn_facing then
            self.facing = self.turn_facing
            self.follower:setFacing(self.facing)
            self.follower.sprite.flip_x = self:getPlatformFlipX()
        end
        self:setFollowerAnimation("turn")
    elseif self.runstop_anim then
        self:setFollowerAnimation("halt")
    elseif move ~= 0 or math.abs(self.hspeed) > 0.5 then
        self:setFollowerAnimation("run")
    else
        self:setFollowerAnimation("idle")
    end
end

function FollowerPlatformState:isOnscreen(tolerance, vertical)
    local camera = Game.world and Game.world.camera
    if not camera then
        return true
    end

    tolerance = tolerance or 0
    if vertical == nil then
        vertical = true
    end

    local x, y, width, height = camera:getRect(false)
    if (self.follower.x + tolerance) <= x then
        return false
    end
    if (self.follower.x - tolerance) >= (x + width) then
        return false
    end
    if vertical then
        if (self.follower.y + tolerance) <= y then
            return false
        end
        if (self.follower.y - tolerance) >= (y + height) then
            return false
        end
    end
    return true
end

function FollowerPlatformState:resetCaterpillarHistory(anchor_x, anchor_y)
    self.history_step_timer = 0
    self.caterpillar_history_x = {}
    self.caterpillar_history_y = {}
    self.caterpillar_history_speed = {}
    self.caterpillar_history_direction = {}
    self.caterpillar_history_ground = {}

    for index = 0, self.position_history_length do
        self.caterpillar_history_x[index] = anchor_x
        self.caterpillar_history_y[index] = anchor_y
        self.caterpillar_history_speed[index] = 0
        self.caterpillar_history_direction[index] = 0
        self.caterpillar_history_ground[index] = nil
    end
end

function FollowerPlatformState:getOwnerBottomY(owner, entity)
    if entity then
        local _, _, _, _, _, bottom = entity:getWorldBoundsAt(owner.x, owner.y)
        return bottom
    end
    return owner.y
end

function FollowerPlatformState:getCaterpillarAnchorY(player)
    local player_state = player and player.platform_state
    local player_bottom = player and self:getOwnerBottomY(player, player_state and player_state.entity) or self.follower.y
    local follower_bottom = self.entity and self:getOwnerBottomY(self.follower, self.entity) or self.follower.y
    return player_bottom - (follower_bottom - self.follower.y)
end

function FollowerPlatformState:seedCaterpillarHistory(player)
    if not player then
        return
    end

    local anchor_y = self:getCaterpillarAnchorY(player)
    self:resetCaterpillarHistory(player.x, anchor_y)
    local distance = self:getCaterpillarDistance()
    if distance <= 0 then
        return
    end

    for index = 0, distance do
        local progress = index / distance
        self.caterpillar_history_x[index] = MathUtils.lerp(player.x, self.follower.x, progress)
        self.caterpillar_history_y[index] = MathUtils.lerp(anchor_y, self.follower.y, progress)
        self.caterpillar_history_speed[index] = 0
        self.caterpillar_history_direction[index] = 0
        self.caterpillar_history_ground[index] = nil
    end
end

function FollowerPlatformState:recoverToParent(player)
    if not player then
        return
    end

    self:resetCaterpillarHistory(player.x, self:getCaterpillarAnchorY(player))
    self.recover_alpha_timer = 30
    self.offscreen_despawn_cooldown = 100
    self.follower.alpha = 0
end

function FollowerPlatformState:beginPitRespawn(player)
    if self.fallen_in_pit or not (self.respawn_leap_enabled and player) then
        return
    end

    local camera_x, _, camera_width = self:getCameraRect()
    local player_state = player.platform_state
    local facing = player_state and player_state.facing or player:getFacing()
    local sign = facing == "left" and -1 or 1
    self.checkpoint_x = MathUtils.clamp(player.x - (80 * sign), camera_x + 80, camera_x + camera_width - 80)
    self.fallen_in_pit = true
    self.respawn_leap = false
    self.respawn_leap_wait = 15
    self.respawn_leap_time = 15
    self.pit_lerp_start_x = self.follower.x
    self.offscreen_despawn_cooldown = 100
    Assets.playSound(Featherfall.sounds.pit_start, nil, 1.2)
    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = 0
        self.entity.grounded = false
        self.entity.ground = nil
    end
    self:syncFromEntity()
end

function FollowerPlatformState:updatePitRespawn(player)
    local camera_x, camera_y, camera_width, camera_height = self:getCameraRect()
    if not self.fallen_in_pit then
        if self.respawn_leap_enabled and player and self.follower.y > camera_y + camera_height + (self.follower.height * 0.5) then
            self:beginPitRespawn(player)
        else
            return false
        end
    end

    if not self.respawn_leap then
        self.respawn_leap_wait = self.respawn_leap_wait - DTMULT
        local progress = MathUtils.clamp((self.respawn_leap_time - self.respawn_leap_wait) / self.respawn_leap_time, 0, 1)
        self.follower.x = Utils.ease(self.pit_lerp_start_x, self.checkpoint_x, progress, "outCubic")
        self.follower.y = camera_y + camera_height + (self.follower.height * 2)
        Object.uncache(self.follower)
        if self.entity then
            self.entity.hspeed = 0
            self.entity.vspeed = 0
        end
        if self.respawn_leap_wait <= 0 then
            self.follower.x = self.checkpoint_x
            self.follower.y = camera_y + camera_height
            Object.uncache(self.follower)
            self.respawn_leap = true
            Assets.playSound(Featherfall.sounds.pit_jump)
            if self.entity then
                self.entity.hspeed = 0
                self.entity.vspeed = -33
                self.entity.grounded = false
                self.entity.ground = nil
                self.entity.jumping = 1
            end
        end
        self:syncFromEntity()
        return true
    end

    local clamped_x = MathUtils.clamp(self.follower.x, camera_x + 80, camera_x + camera_width - 80)
    if self.follower.x ~= clamped_x then
        self.follower.x = clamped_x
        Object.uncache(self.follower)
        if self.entity then
            self.entity.hspeed = 0
        end
    end
    if self.entity then
        self.entity:updatePhysics({skip_moving_ground = true})
    end
    self:syncFromEntity()
    if self.vspeed > 0 and self:isOnscreen(0) and not (self.entity and self.entity:findBlockAt(self.follower.x, self.follower.y)) and self.follower.y < camera_y + camera_height - 40 then
        self.fallen_in_pit = false
        self.respawn_leap = false
        self:seedCaterpillarHistory(player)
    end
    return true
end

function FollowerPlatformState:getParentHistoryState(player)
    local player_state = player and player.platform_state
    if not player_state then
        return 0, 0, nil
    end

    local hspeed = player_state.hspeed or 0
    local vspeed = player_state.vspeed or 0
    return MathUtils.dist(0, 0, hspeed, vspeed),
        Utils.angle(0, 0, hspeed, vspeed),
        player_state.entity and player_state.entity.ground
end

function FollowerPlatformState:refreshCaterpillarGround()
    if not self.entity then
        return false
    end

    local distance = self:getCaterpillarDistance()
    local remembered_ground = self.caterpillar_history_ground[distance]
    if remembered_ground then
        self.entity.ground = remembered_ground
        self.entity.grounded = true
    end

    local force_follow = false
    local ground = self.entity:findGroundAt(self.follower.x, self.follower.y, 2)
    if ground then
        self.entity.ground = ground
        self.entity.grounded = true
    else
        force_follow = true
    end

    if self.entity:findBlockAt(self.follower.x, self.follower.y) then
        force_follow = true
    end

    self.caterpillar_history_ground[distance] = self.entity.ground
    self:syncFromEntity()
    return force_follow
end

function FollowerPlatformState:findFollowerCue()
    if not self:isOnscreen(0) then
        return
    end
    if not (Game.world and Game.world.map) then
        return
    end

    for _, event in ipairs(Game.world.map.events or {}) do
        if event.platform_followercue and event.collider and self.follower:collidesWith(event.collider) then
            return event
        end
    end
end

function FollowerPlatformState:pushCaterpillarHistory(player, force_follow)
    if not player then
        return
    end

    local player_state = player.platform_state
    local parent_grounded = not player_state or player_state.on_ground
    local parent_speed = player_state and MathUtils.dist(0, 0, player_state.hspeed or 0, player_state.vspeed or 0) or 0
    local parent_dist = MathUtils.dist(self.follower.x, self.follower.y, player.x, player.y)
    local should_shift = force_follow
        or (not self.on_ground)
        or (not parent_grounded)
        or (math.floor(parent_speed + 0.5) > 2)
        or (parent_dist >= 200)

    if not should_shift then
        self.history_step_timer = 0
        return
    end

    self.history_step_timer = self.history_step_timer + DTMULT
    while self.history_step_timer >= 1 do
        local parent_speed, parent_direction, parent_ground = self:getParentHistoryState(player)
        for index = self.position_history_length, 1, -1 do
            self.caterpillar_history_x[index] = self.caterpillar_history_x[index - 1]
            self.caterpillar_history_y[index] = self.caterpillar_history_y[index - 1]
            self.caterpillar_history_speed[index] = self.caterpillar_history_speed[index - 1]
            self.caterpillar_history_direction[index] = self.caterpillar_history_direction[index - 1]
            self.caterpillar_history_ground[index] = self.caterpillar_history_ground[index - 1]
        end
        self.caterpillar_history_x[0] = player.x
        self.caterpillar_history_y[0] = self:getCaterpillarAnchorY(player)
        self.caterpillar_history_speed[0] = parent_speed
        self.caterpillar_history_direction[0] = parent_direction
        self.caterpillar_history_ground[0] = parent_ground
        self.history_step_timer = self.history_step_timer - 1
    end
end

function FollowerPlatformState:getCaterpillarTarget(player)
    if not player then
        return
    end
    local distance = self:getCaterpillarDistance()
    return self.caterpillar_history_x[distance] or player.x,
        self.caterpillar_history_y[distance] or player.y,
        self.caterpillar_history_ground[distance]
end

function FollowerPlatformState:applyGroundDifference()
    if not self.entity then
        return
    end

    self.entity.last_platform_dx = 0
    self.entity.last_platform_dy = 0
    local ground = self.entity.ground
    if not (ground and (ground.moving_platform or ground.rideable)) then
        self.ground_difference_consumed_ground = nil
        self.ground_difference_consumed_id = nil
        return
    end

    local difference_id = ground.platform_difference_update_id
    if difference_id and self.ground_difference_consumed_ground == ground and self.ground_difference_consumed_id == difference_id then
        return
    end

    local dx = ground.dif_x or 0
    local dy = ground.dif_y or 0
    if dx == 0 and dy == 0 then
        self.ground_difference_consumed_ground = ground
        self.ground_difference_consumed_id = difference_id
        return
    end
    if self.entity:findBlockAt(self.follower.x + dx, self.follower.y + dy, ground) then
        self.ground_difference_consumed_ground = ground
        self.ground_difference_consumed_id = difference_id
        return
    end

    self.follower.x = self.follower.x + dx
    self.follower.y = self.follower.y + dy
    Object.uncache(self.follower)
    self.entity.last_platform_dx = dx
    self.entity.last_platform_dy = dy
    self.ground_difference_consumed_ground = ground
    self.ground_difference_consumed_id = difference_id

    for index = 0, self.position_history_length do
        self.caterpillar_history_x[index] = (self.caterpillar_history_x[index] or self.follower.x) + dx
        self.caterpillar_history_y[index] = (self.caterpillar_history_y[index] or self.follower.y) + dy
    end
end

function FollowerPlatformState:applyGroundEffectDifference()
    if not self.entity then
        return
    end

    local dx = self.entity.last_ground_effect_dx or 0
    local dy = self.entity.last_ground_effect_dy or 0
    if dx == 0 and dy == 0 then
        return
    end

    for index = 0, self.position_history_length do
        self.caterpillar_history_x[index] = (self.caterpillar_history_x[index] or self.follower.x) + dx
        self.caterpillar_history_y[index] = (self.caterpillar_history_y[index] or self.follower.y) + dy
    end
    self.entity.last_ground_effect_dx = 0
    self.entity.last_ground_effect_dy = 0
    self.entity.last_ground_effect_ground = nil
end

function FollowerPlatformState:applyCaterpillarTarget(target_x, target_y, target_ground)
    if not (target_x and target_y) then
        return
    end

    local old_x, old_y = self.follower.x, self.follower.y
    local amount = 1 - (0.5 ^ DTMULT)
    self.follower.x = MathUtils.lerp(self.follower.x, target_x, amount)
    self.follower.y = MathUtils.lerp(self.follower.y, target_y, amount)
    Object.uncache(self.follower)

    local mult = math.max(DTMULT, 0.001)
    local visual_hspeed = (self.follower.x - old_x) / mult
    local visual_vspeed = (self.follower.y - old_y) / mult
    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = 0
    end
    if target_ground and self.entity then
        self.entity.ground = target_ground
        self.entity.grounded = true
    end
    self:syncFromEntity()
    self.hspeed = visual_hspeed
    self.vspeed = visual_vspeed
end

function FollowerPlatformState:unstickAfterEnter(player)
    if not self.entity then
        return
    end

    if self.entity:findBlockAt(self.follower.x, self.follower.y) then
        for _ = 1, 30 do
            self.follower.y = self.follower.y - 4
            Object.uncache(self.follower)
            if not self.entity:findBlockAt(self.follower.x, self.follower.y) then
                break
            end
        end
    end

    if player and self.entity:findBlockAt(self.follower.x, self.follower.y) then
        for index = 0, 30 do
            local progress = index / 30
            local test_x = MathUtils.lerp(self.follower.x, player.x, progress)
            local test_y = MathUtils.lerp(self.follower.y, player.y, progress)
            if not self.entity:findBlockAt(test_x, test_y) then
                self.follower.x = test_x
                self.follower.y = test_y
                Object.uncache(self.follower)
                break
            end
        end
    end
end

function FollowerPlatformState:shouldJump(move, target)
    if not target then
        return false
    end

    local target_state = target.platform_state
    local target_grounded = not target_state or target_state.on_ground
    if self.on_ground and self.follower.y > target.y + 40 and math.abs(target.x - self.follower.x) <= 80 and target_grounded then
        return true
    end

    if move < 0 and self.entity and self.entity:findBlockAt(self.follower.x - 4, self.follower.y - 2) then
        return true
    elseif move > 0 and self.entity and self.entity:findBlockAt(self.follower.x + 4, self.follower.y - 2) then
        return true
    end

    if self.on_ground and self.entity and math.abs(self.hspeed) > 0.1 then
        local ahead = self.hspeed > 0 and 10 or -10
        if not self.entity:findGroundAt(self.follower.x + ahead, self.follower.y, 10) then
            return true
        end
    end

    local cue = self:findFollowerCue()
    if cue then
        if cue.dothing == 0 then
            return true
        elseif cue.dothing == 1 and self.on_ground then
            if self.hspeed > 0 and not self.entity:findGroundAt(self.follower.x + 20, self.follower.y + 2, 10) then
                return true
            elseif self.hspeed < 0 and not self.entity:findGroundAt(self.follower.x - 20, self.follower.y + 2, 10) then
                return true
            end
        end
    end

    return false
end

function FollowerPlatformState:syncFromEntity()
    if not self.entity then
        return
    end

    self.hspeed = self.entity.hspeed
    self.vspeed = self.entity.vspeed
    self.on_ground = self.entity.grounded
end

function FollowerPlatformState:isTargetModePaused(player)
    local player_state = player and player.platform_state
    return player_state and player_state.targetmode
end

function FollowerPlatformState:isWorldMenuPaused()
    return Game.world and Game.world.state == "MENU" and Game.world.menu
end

function FollowerPlatformState:updateTargetModePause(player)
    local targetmode = self:isTargetModePaused(player)
    local menu_paused = self:isWorldMenuPaused()
    local platform_paused = Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused()
    local paused = targetmode or menu_paused or platform_paused
    self.menu_pause_active = menu_paused
    self:setTargetModeSpritePaused(paused)
    self:updateImportantBlend(targetmode or (self.actions and self.actions.active))
    if not paused then
        return false
    end

    self.history_step_timer = 0
    return true
end

function FollowerPlatformState:getFollowerDashIndex()
    if not (Game.world and Game.world.followers) then
        return 1
    end
    for index, follower in ipairs(Game.world.followers) do
        if follower == self.follower then
            return index
        end
    end
    return 1
end

function FollowerPlatformState:updateDashTransition(player)
    local player_state = player and player.platform_state
    if not (player_state and player_state.dash_transition_con and player_state.dash_transition_con > 0) then
        self.dash_transition_active = false
        if self.entity then
            self.entity.wallcollision = true
        end
        return false
    end

    if not self.dash_transition_active then
        self.dash_transition_active = true
        self.dash_lerp_start_x = self.follower.x
        self.dash_lerp_start_y = self.follower.y
        self.current_animation = nil
    end

    local direction = player_state.dashsign or 1
    local index = self:getFollowerDashIndex()
    local gate_x = player_state.dash_position and player_state.dash_position[1] or player.x
    local gate_y = player_state.dash_position and player_state.dash_position[2] or player.y
    local target_x = gate_x + ((20 - (40 * index)) * direction)
    local target_y = gate_y - 62
    local progress = MathUtils.clamp((player_state.dash_transition_timer or 0) / 8, 0, 1)
    local old_x, old_y = self.follower.x, self.follower.y
    self.follower.x = Utils.ease(self.dash_lerp_start_x, target_x, progress, "outCubic")
    self.follower.y = Utils.ease(self.dash_lerp_start_y, target_y, progress, "outCubic")
    Object.uncache(self.follower)

    local mult = math.max(DTMULT, 0.001)
    self.hspeed = (self.follower.x - old_x) / mult
    self.vspeed = (self.follower.y - old_y) / mult
    self.on_ground = false
    self.facing = direction < 0 and "left" or "right"
    self.follower:setFacing(self.facing)
    self.follower.sprite.flip_x = self:getPlatformFlipX()
    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = 0
        self.entity.wallcollision = false
        self.entity.grounded = false
    end
    self:setPlatformAnimationHoldFrame("land", 1)
    return true
end

function FollowerPlatformState:onEnter(old_state, settings)
    settings = settings or {}

    local sprite_ox, sprite_oy = self.follower.sprite:getOrigin()
    local follower_ox, follower_oy = self.follower:getOrigin()
    self.restore_state = {
        width = self.follower.width,
        height = self.follower.height,
        origin_x = follower_ox,
        origin_y = follower_oy,
        origin_exact = self.follower.origin_exact,
        collider = self.follower.collider,
        sprite_origin_x = sprite_ox,
        sprite_origin_y = sprite_oy,
        sprite_origin_exact = self.follower.sprite.origin_exact,
        sprite_flip_x = self.follower.sprite.flip_x,
        following = self.follower.following,
        returning = self.follower.returning,
        visible = self.follower.visible,
        alpha = self.follower.alpha,
        x = self.follower.x,
        y = self.follower.y,
        layer = self.follower.layer,
    }

    self.timer = 0
    self.current_animation = nil
    self.current_sprite_facing = nil
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    self.turn_facing = nil
    self.important_blend = 1
    self.menu_pause_active = false
    self.targetmode_sprite_pause = nil
    self.hspeed = settings.hspeed or 0
    self.vspeed = settings.vspeed or 0
    self.platform_index = settings.index or (Featherfall and Featherfall.getPlatformFollowerIndex and Featherfall:getPlatformFollowerIndex(self.follower)) or self.follower.index or 1
    self.on_ground = false
    self.facing = self.follower:getFacing() == "left" and "left" or "right"
    self.history_step_timer = 0
    self.offscreen_despawn_cooldown = 10
    self.recover_alpha_timer = 0
    self.respawn_leap_enabled = true
    self.fallen_in_pit = false
    self.respawn_leap = false
    self.respawn_leap_wait = 15
    self.respawn_leap_time = 15
    self.pit_lerp_start_x = self.follower.x
    self.checkpoint_x = self.follower.x
    self.ralsei_platform_mode = 0
    self.action_platform_mode = 0
    self.ralsei_platform_timer = 0
    self.action_platform_timer = 0
    self.ralsei_platform_target = nil
    self.action_platform_target = nil
    self.action_platform_target_override = nil
    self.ralsei_platform_offset_x = 0
    self.ralsei_platform_offset_y = 0
    self.action_platform_offset_x = 0
    self.action_platform_offset_y = 0
    self.ralsei_platform_stand_count = 0
    self.player_stood_on_ralsei_recently = false
    self.player_stood_on_action_platform_recently = false
    self.ralsei_platform_long = false
    self.action_platform_long = false
    self.ralsei_fall_timer = 0
    self.ralsei_fall_splat_duration = 0
    self.ralsei_fall_phase = 0
    self.ralsei_splat_timer = 0
    self.ralsei_platform_object = nil
    self.ralsei_scarf_object = nil
    self.actions:reset()
    self.follower.following = false
    self.follower.returning = false

    local actor = self:getPlatformActor()
    local width, height = 20, 38
    if actor and actor.getPlatformSize then
        width, height = actor:getPlatformSize()
    end

    self.follower:setSize(width, height)
    self.follower:setOrigin(0.5, 1)
    self.follower.visible = true
    self.follower.alpha = 1

    local player = Game.world and Game.world.player
    if player then
        self.follower.x = player.x + (settings.x_offset or self:getInitialOffset())
        self.follower.y = player.y
        self.follower.layer = player.layer
        Object.uncache(self.follower)
    end

    local hitbox = {0, 0, width, height}
    if actor and actor.getPlatformHitbox then
        hitbox = {actor:getPlatformHitbox()}
    end
    self.follower.collider = Hitbox(self.follower, unpack(hitbox))

    self.entity = self.entity or PlatformEntity(self.follower, Featherfall.constants)
    self.entity:reset({
        hspeed = self.hspeed,
        vspeed = self.vspeed,
        grounded = self.on_ground,
    })
    self.entity:setHitbox(unpack(hitbox))
    self:unstickAfterEnter(player)
    if self.vspeed == 0 then
        local ground = self.entity:findGroundAt(self.follower.x, self.follower.y, 706)
        if ground then
            self.entity:landOn(ground)
            self.entity.grounded_prev = true
            self.on_ground = true
        end
    end
    self:syncFromEntity()
    self:seedCaterpillarHistory(player)

    if Featherfall.transition_timer > 0 and self.restore_state.x and self.restore_state.y then
        Featherfall:spawnFollowerTransitionProp(
            self.follower,
            "jump_down",
            self.restore_state.x,
            self.restore_state.y,
            self.follower.x,
            self.follower.y,
            nil,
            {kind = "enter", manual_speed = 0.25}
        )
    end

    self:setFollowerAnimation("idle")
end

function FollowerPlatformState:onUpdate()
    local player = Game.world and Game.world.player
    self:updateActionOutline()
    if self:updateTargetModePause(player) then
        return
    end
    if self:updateDashTransition(player) then
        return
    end

    self.timer = self.timer + DTMULT
    self.offscreen_despawn_cooldown = self.offscreen_despawn_cooldown - DTMULT
    if self.recover_alpha_timer > 0 then
        self.recover_alpha_timer = math.max(self.recover_alpha_timer - DTMULT, 0)
        self.follower.alpha = 1 - (self.recover_alpha_timer / 30)
    end
    if Featherfall.transition_timer <= 0 and not Featherfall:isFollowerVisualOwned(self.follower) then
        self.follower.visible = true
    end

    if self:updatePitRespawn(player) then
        self:setFollowerAnimation(self:getAirAnimationName())
        return
    end
    if self:updateRalseiPlatformMode(player) then
        return
    end
    if self:updateRalseiSplat(player) then
        return
    end
    if self.actions:update(player) then
        return
    end
    if Featherfall.transition_timer <= 0 and self.offscreen_despawn_cooldown <= 0 and not self:isOnscreen(120) then
        self:recoverToParent(player)
    end

    if self.entity then
        self.entity:updatePlayer({
            move = 0,
            key_left = false,
            key_right = false,
            press_jump = false,
            key_jump = false,
            skip_moving_ground = true,
        })
    end
    self:applyGroundEffectDifference()

    local force_follow = self:refreshCaterpillarGround()
    self:applyGroundDifference()

    self:pushCaterpillarHistory(player, force_follow)
    local follow_x, follow_y, follow_ground = self:getCaterpillarTarget(player)
    local move = 0
    local follow_distance = 0
    if player then
        follow_x = follow_x or player.x
        follow_y = follow_y or player.y
        follow_distance = MathUtils.dist(self.follower.x, self.follower.y, follow_x, follow_y)
        local follow_dx = follow_x - self.follower.x
        if follow_dx < -0.5 then
            move = -1
        elseif follow_dx > 0.5 then
            move = 1
        end
    end
    local previous_facing = self.facing

    self:applyCaterpillarTarget(follow_x, follow_y, follow_ground)

    local meaningful_follow = follow_distance > 0.5
    if move ~= 0 and self.on_ground and not self.turn_anim and meaningful_follow then
        local facing_sign = previous_facing == "left" and -1 or 1
        local speed_sign = self.hspeed > 0 and 1 or (self.hspeed < 0 and -1 or 0)
        if (math.abs(self.hspeed) > 0.5 and speed_sign ~= facing_sign) or move ~= facing_sign then
            self:beginTurnAnimation(move < 0 and "left" or "right")
        end
    end
    if move ~= 0 then
        self.facing = move < 0 and "left" or "right"
        self.follower:setFacing(self.facing)
        self.follower.sprite.flip_x = self:getPlatformFlipX()
    end

    local anim_move = meaningful_follow and move or 0
    self:updateMovementAnimationFlags(false, false, anim_move)
    self:applyMovementAnimation(anim_move)
end

function FollowerPlatformState:onExit(next_state)
    local platform_x, platform_y = self.follower.x, self.follower.y
    local platform_animation = self.current_animation or "jump_down"
    self.actions:reset()
    self:dropOffRalseiPlatform()
    self.menu_pause_active = false
    self:setTargetModeSpritePaused(false)
    self.follower:removeFX("platform_action_outline")
    self.follower.sprite:setColor(1, 1, 1)
    self.follower:resetSprite()
    self.current_animation = nil
    self.current_sprite_facing = nil
    self.air_animation = nil
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    self.turn_facing = nil
    self.ralsei_splat_timer = 0
    self.ralsei_splat_timer_max = 0
    self.entity = nil

    local restore = self.restore_state or {}
    if restore.width and restore.height then
        self.follower:setSize(restore.width, restore.height)
    end
    if restore.origin_x and restore.origin_y then
        if restore.origin_exact then
            self.follower:setOriginExact(restore.origin_x, restore.origin_y)
        else
            self.follower:setOrigin(restore.origin_x, restore.origin_y)
        end
    end
    if restore.collider then
        self.follower.collider = restore.collider
    end
    if restore.sprite_origin_x and restore.sprite_origin_y then
        if restore.sprite_origin_exact then
            self.follower.sprite:setOriginExact(restore.sprite_origin_x, restore.sprite_origin_y)
        else
            self.follower.sprite:setOrigin(restore.sprite_origin_x, restore.sprite_origin_y)
        end
    end
    self.follower.sprite.flip_x = restore.sprite_flip_x
    self.follower.following = restore.following ~= false
    self.follower.returning = restore.returning or false
    self.follower.visible = restore.visible ~= false
    self.follower.alpha = restore.alpha or 1
    local exit_x, exit_y = Featherfall:getFollowerOverworldExitPosition(self.follower, Featherfall.transition_source)
    if exit_x and exit_y then
        self.follower.x = exit_x
        self.follower.y = exit_y
        Object.uncache(self.follower)
    end
    if restore.layer then
        self.follower.layer = restore.layer
    end
    if Featherfall.transition_timer > 0 then
        Featherfall:spawnFollowerTransitionProp(
            self.follower,
            platform_animation,
            platform_x,
            platform_y,
            self.follower.x,
            self.follower.y,
            nil,
            {kind = "exit", manual_speed = 0.25}
        )
    end
    self.restore_state = nil
end

function FollowerPlatformState:drawDebug()
    self:drawPlatformDebug(0.4, 1, 0.45)
end

return FollowerPlatformState
