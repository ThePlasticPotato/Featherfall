local function shallowCopy(data)
    local copy = {}
    for key, value in pairs(data or {}) do
        copy[key] = value
    end
    return copy
end

local function propertyBool(value)
    if value == nil then
        return nil
    elseif value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end

    value = string.lower(tostring(value))
    return value == "true" or value == "1" or value == "yes"
end

---@class PlatformActions : Class
local PlatformActions = Class()

function PlatformActions:init(state)
    self.state = state
    self:reset()
end

function PlatformActions:reset()
    self.active = false
    self.phase = nil
    self.timer = 0
    self.target = nil
    self.data = nil
    self.free_will_target = nil
    self.free_will_target_lerp = 0
    self.free_will_target_x = 0
    self.free_will_target_y = 0
    self.preview_target = nil
    self.highlighted = false
    self.act_busy = false
    self.cooldown_timer = 0
    self.cooldown_max = 0
    self.cooldown_text = nil
end

function PlatformActions:normalizeKind(kind)
    return string.lower(tostring(kind or "any"))
end

function PlatformActions:normalizeKinds(kinds)
    if type(kinds) ~= "table" then
        return self:normalizeKind(kinds)
    end

    local result = {}
    for _, kind in ipairs(kinds) do
        table.insert(result, self:normalizeKind(kind))
    end
    return result
end

function PlatformActions:targetMatchesKind(target, kinds)
    if type(kinds) ~= "table" then
        return target:isAvailableFor(kinds)
    end
    for _, kind in ipairs(kinds) do
        if target:isAvailableFor(kind) then
            return true
        end
    end
    return false
end

function PlatformActions:getCharacter()
    if self.state and self.state.getCharacter then
        return self.state:getCharacter()
    end
    return self.state and self.state.follower
end

function PlatformActions:getData()
    local state = self.state
    if not (state and state.getPlatformActor) then
        return nil
    end

    local actor = state:getPlatformActor()
    local kind = state.getActionKind and state:getActionKind() or (state.getFollowerKind and state:getFollowerKind())
    local data

    if actor and actor.getPlatformFollowerActionData then
        data = actor:getPlatformFollowerActionData(kind, state)
    end
    if data == false then
        return nil
    elseif type(data) == "string" then
        data = {kind = data}
    elseif type(data) ~= "table" then
        return nil
    end

    data.kind = self:normalizeKind(data.kind or kind)
    data.target_kind = self:normalizeKinds(data.target_kind or data.action or data.kind)
    return data
end

function PlatformActions:prepareTargetData(data, target)
    data = shallowCopy(data)
    local properties = target and target.properties or {}
    local quick_attack = propertyBool(
        properties["quick_attack"]
        or properties["attack_fast"]
        or properties["fast_attack"]
        or properties["fast"]
        or properties["quick"]
    )

    if quick_attack ~= nil then
        data.quick_attack = quick_attack
    end
    if data.quick_attack then
        data.skip_approach = true
        data.ready_cue_timer = data.fast_ready_cue_timer or 2
        data.perform_timer = data.fast_perform_timer or 6
        data.recover_timer = data.fast_recover_timer or 10
        data.suppress_ready_sound = data.suppress_ready_sound ~= false
        data.suppress_charge_animation = data.suppress_charge_animation ~= false
    end
    return data
end

function PlatformActions:getTargets()
    if not (Game.world and Game.world.map) then
        return {}
    end

    local targets = {}
    for _, event in ipairs(Game.world.map.events or {}) do
        if event.platform_action_target_event then
            table.insert(targets, event)
        end
    end
    return targets
end

function PlatformActions:targetAvailable(target, data)
    return target
        and target.parent
        and target.isAvailableFor
        and self:targetMatchesKind(target, data.target_kind)
        and target.free_will == true
        and (target.activetimer or 0) > (data.minimum_target_age or 0)
end

function PlatformActions:findLineTarget(data, player)
    if not player then
        return
    end

    local hradius = data.horizontal_radius or 260
    local vradius = data.vertical_radius or 160
    local arrow_margin_h = data.horizontal_margin or 100
    local arrow_margin_v = data.vertical_margin or 40
    local best, in_action_range
    self.free_will_target_lerp = 0

    for _, target in ipairs(self:getTargets()) do
        if self:targetAvailable(target, data) then
            local in_player_scan = target.x >= player.x - hradius - arrow_margin_h
                and target.x <= player.x + hradius + arrow_margin_h
                and target.y >= player.y - vradius - arrow_margin_v
                and target.y <= player.y + vradius + arrow_margin_v
            if in_player_scan then
                best = target
                in_action_range = target.x >= player.x - hradius
                    and target.x <= player.x + hradius
                    and target.y >= player.y - vradius
                    and target.y <= player.y + vradius
            end
        end
    end

    if best then
        self.preview_target = best
        local dx = best.x - player.x
        local dy = (best.y - player.y) * 1.8
        self.free_will_target_lerp = 1 - ((math.sqrt((dx * dx) + (dy * dy)) - 260) / 200)
        if not in_action_range then
            return nil
        end
    end
    return best
end

function PlatformActions:findNearestTarget(data, player)
    if not player then
        return
    end

    local best, best_dist
    local player_radius = data.player_radius or 300
    for _, target in ipairs(self:getTargets()) do
        if self:targetAvailable(target, data) then
            local dist = MathUtils.dist(player.x, player.y, target.x, target.y)
            if dist <= player_radius and (not best_dist or dist < best_dist) then
                best = target
                best_dist = dist
            end
        end
    end

    if best and best_dist then
        self.preview_target = best
        self.free_will_target_lerp = 1 - ((best_dist - 200) / 100)
        if best_dist > (data.trigger_distance or 200) then
            return nil
        end
    end
    return best
end

function PlatformActions:findTarget(data, player)
    if data.findTarget then
        return data.findTarget(self.state, self, player, data)
    end

    if data.target_search == "nearest" or data.search == "nearest" then
        return self:findNearestTarget(data, player)
    end
    return self:findLineTarget(data, player)
end

function PlatformActions:canAct(data, player, target)
    if not self:isCharacterReady() then
        return false
    end
    if data.free_will == false or not target then
        return false
    end
    if data.canAct then
        return data.canAct(self.state, self, player, target, data)
    end

    local player_state = player and player.platform_state
    return not player_state or (player_state.vspeed or 0) > -30
end

function PlatformActions:isCharacterReady()
    local fallen_in_pit = self.state.fallen_in_pit
    if type(fallen_in_pit) == "number" then
        fallen_in_pit = fallen_in_pit ~= 0
    end
    if self.active or self.act_busy or fallen_in_pit then
        return false
    end
    if self.state.isPlatformActionBlocked and self.state:isPlatformActionBlocked() then
        return false
    end
    if self.cooldown_timer > 0 then
        return false
    end
    if Featherfall.transition_timer > 0 then
        return false
    end
    return true
end

function PlatformActions:tryFreeWill(player)
    local data = self:getData()
    if not data then
        self.highlighted = false
        return false
    end

    self.preview_target = nil
    self.free_will_target_lerp = 0
    local target = self:findTarget(data, player)
    local visible_target = self.preview_target or target
    self.free_will_target = visible_target
    if visible_target then
        self.free_will_target_x = visible_target.x
        self.free_will_target_y = visible_target.y
    else
        local character = self:getCharacter()
        self.free_will_target_x = character and character.x or 0
        self.free_will_target_y = character and character.y or 0
    end
    self.highlighted = data.free_will ~= false

    local action_data = target and self:prepareTargetData(data, target) or data
    if self:canAct(action_data, player, target) then
        Assets.playSound(Featherfall.sounds.action_auto_select)
        local selected = true
        if target.select then
            selected = target:select(self.state, action_data) ~= false
        end
        if not selected then
            return false
        end
        if action_data.onAutoSelect then
            local handled = action_data.onAutoSelect(self.state, self, target, action_data)
            if handled ~= nil then
                return handled
            end
        end
        self:begin(target, action_data)
        return true
    end

    return false
end

function PlatformActions:begin(target, data)
    self.active = true
    self.act_busy = true
    self.phase = data and data.skip_approach and "ready" or "approach"
    self.timer = 0
    self.target = target
    self.data = data or self:getData() or {}
    self.ready_cued = false
    self.afterimage_frame = -1
    self.state.offscreen_despawn_cooldown = 100
    local character = self:getCharacter()
    if self.state.resetCaterpillarHistory and character then
        self.state:resetCaterpillarHistory(character.x, character.y)
    end
    if self.phase == "ready" then
        self:faceTarget(target)
        if self.state.entity and not self.data.quick_attack then
            self.state.entity.hspeed = 0
            self.state.entity.vspeed = math.max(self.state.entity.vspeed, 0)
        end
        if not self.data.suppress_charge_animation then
            self.state:setPlatformAnimation(self.data.charge_animation or self.data.ready_animation or "halt")
        end
        if not self.data.suppress_ready_sound then
            Assets.playSound(self.data.ready_sound or Featherfall.sounds.action_ready)
        end
    end
    if self.data.onStart then
        self.data.onStart(self.state, self, target, self.data)
    end
end

function PlatformActions:getAfterimageColor()
    local color = self.data and self.data.afterimage_color
    if type(color) == "table" then
        return color
    end
    color = self.data and (self.data.color or self.data.action_color or self.data.target_color)
    if type(color) == "table" then
        return color
    end
    if Featherfall and Featherfall.getActionColorTable then
        color = Featherfall:getActionColorTable(self.data and self.data.kind, self.target, self.state, self.data)
        if type(color) == "table" then
            return color
        end
    end
    return {1, 1, 1}
end

function PlatformActions:spawnActionAfterimage(frame, perform_timer)
    local character = self:getCharacter()
    if not (Game.world and PlatformActionAfterimage and character) then
        return
    end

    local progress = frame / math.max(perform_timer or 1, 1)
    local afterimage = PlatformActionAfterimage(character, self:getAfterimageColor(), progress, {
        solid = true,
        fade_speed = 0.04,
    })
    Game.world:addChild(afterimage)
end

function PlatformActions:updateActionAfterimages(previous_timer, current_timer, perform_timer)
    if self.data and self.data.suppress_action_afterimages then
        return
    end

    local last_frame = math.min(math.floor(current_timer), math.max((perform_timer or 1) - 1, 0))
    for frame = math.floor(previous_timer) + 1, last_frame do
        if frame > (self.afterimage_frame or -1) and (frame % 3) == 0 then
            self.afterimage_frame = frame
            self:spawnActionAfterimage(frame, perform_timer)
        end
    end
end

function PlatformActions:setCooldown(text, frames)
    self.cooldown_text = text or "RECHARGE"
    self.cooldown_timer = frames or 0
    self.cooldown_max = frames or 0
end

function PlatformActions:updateCooldown()
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.cooldown_timer = MathUtils.approach(self.cooldown_timer, 0, DTMULT)
    if self.cooldown_timer <= 0 then
        self.cooldown_text = nil
        self.cooldown_max = 0
    end
end

function PlatformActions:finish()
    local data = self.data
    if data and data.cooldown and data.cooldown > 0 then
        self:setCooldown(data.cooldown_text or "RECHARGE", data.cooldown)
    end
    if data and data.onFinish then
        data.onFinish(self.state, self, self.target, data)
    end

    self.active = false
    self.phase = nil
    self.timer = 0
    self.target = nil
    self.data = nil
    self.ready_cued = false
    self.act_busy = false
    if self.state.seedCaterpillarHistory then
        self.state:seedCaterpillarHistory(Game.world and Game.world.player)
    end
end

function PlatformActions:faceTarget(target)
    if not target then
        return
    end
    local character = self:getCharacter()
    if not character then
        return
    end
    local facing = target.x < character.x and "left" or "right"
    self.state.facing = facing
    character:setFacing(facing)
    character.sprite.flip_x = self.state.getPlatformFlipX and self.state:getPlatformFlipX() or facing == "left"
end

function PlatformActions:updateApproach(player)
    local state, target, data = self.state, self.target, self.data
    if not (target and target.parent) then
        self:finish()
        return true
    end
    local character = self:getCharacter()
    if not character then
        self:finish()
        return true
    end

    self.timer = self.timer + DTMULT
    local target_x = target.x + (data.follow_x_offset or 0)
    local distance = math.abs(character.x - target_x)
    local reached = distance < (data.approach_distance or 10)
    local timed_out = self.timer > (data.approach_timer or 40)
    local move = 0
    if not reached then
        move = character.x < target_x and 1 or -1
    end

    if move ~= 0 then
        state.facing = move < 0 and "left" or "right"
        character:setFacing(state.facing)
        character.sprite.flip_x = state.getPlatformFlipX and state:getPlatformFlipX() or state.facing == "left"
    end

    local press_jump = state.shouldJump and state:shouldJump(move, player) or false
    if state.entity then
        state.entity:updatePlayer({
            move = move,
            press_jump = press_jump,
            key_jump = press_jump or state.entity.jumping == 1 or state.entity.jumpsquat > 0,
            skip_moving_ground = state.applyGroundDifference ~= nil,
        })
    end
    state:syncFromEntity()
    if state.applyGroundDifference then
        state:applyGroundDifference()
    end

    if reached or timed_out then
        self.phase = "ready"
        self.timer = 0
        self:faceTarget(target)
        if state.entity then
            state.entity.hspeed = 0
        end
        Assets.playSound(data.ready_sound or Featherfall.sounds.action_ready)
    elseif state.updateMovementAnimationFlags and state.applyMovementAnimation then
        state:updateMovementAnimationFlags(move < 0, move > 0, move)
        state:applyMovementAnimation(move)
    end
    return true
end

function PlatformActions:perform()
    local state, target, data = self.state, self.target, self.data
    local party = state:getPartyMember()
    self:faceTarget(target)
    self.state:setPlatformAnimation(data.release_animation or "idle")
    if not data.suppress_release_sound then
        Assets.playSound(data.release_sound or Featherfall.sounds.action_release)
    end

    if data.onPerform then
        data.onPerform(state, self, target, data)
    elseif party and party.onPlatformFollowerAction then
        party:onPlatformFollowerAction(data.kind, state, target, data)
    elseif target and target.performFollowerAction then
        target:performFollowerAction(data.kind, state, data)
    end
end

function PlatformActions:updateActive(player)
    if not self.active then
        return false
    end
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return true
    end

    if self.data and self.data.update then
        return self.data.update(self.state, self, player, self.data) ~= false
    end

    if self.phase == "approach" then
        return self:updateApproach(player)
    elseif self.phase == "ready" then
        local previous_timer = self.timer
        self.timer = self.timer + DTMULT
        if self.state.entity then
            if self.data.quick_attack then
                local progress = math.min(self.timer / 10, 1)
                local gravity = self.state.entity.constants and self.state.entity.constants.gravity or 1.25
                self.state.entity.hspeed = MathUtils.lerp(self.state.entity.hspeed, 0, progress)
                self.state.entity.vspeed = MathUtils.lerp(self.state.entity.vspeed, -gravity, progress)
            else
                self.state.entity.hspeed = 0
                self.state.entity.vspeed = 0
            end
            self.state.entity:updatePhysics({
                skip_moving_ground = self.state.applyGroundDifference ~= nil,
            })
        end
        self.state:syncFromEntity()
        self:faceTarget(self.target)
        local cue_timer = self.data.ready_cue_timer or 30
        local perform_timer = self.data.perform_timer or self.data.ready_timer or 40
        self:updateActionAfterimages(previous_timer, self.timer, perform_timer)
        if self.timer >= cue_timer and not self.ready_cued then
            self.ready_cued = true
            self.state:setPlatformAnimation(self.data.attack_ready_animation or self.data.ready_animation or "halt")
        elseif not self.ready_cued then
            if not self.data.suppress_charge_animation then
                self.state:setPlatformAnimation(self.data.charge_animation or self.data.ready_animation or "halt")
            end
        else
            self.state:setPlatformAnimation(self.data.attack_ready_animation or self.data.ready_animation or "halt")
        end
        if self.timer >= perform_timer then
            self:perform()
            self.phase = "recover"
            self.timer = 0
        end
        return true
    elseif self.phase == "recover" then
        self.timer = self.timer + DTMULT
        if self.state.entity then
            self.state.entity.hspeed = 0
            self.state.entity:updatePhysics({
                skip_moving_ground = self.state.applyGroundDifference ~= nil,
            })
        end
        self.state:syncFromEntity()
        self:faceTarget(self.target)
        if not self.data.suppress_recover_animation then
            self.state:setPlatformAnimation(self.data.release_animation or "idle")
        end
        if self.timer >= (self.data.recover_timer or 22) then
            self:finish()
        end
        return true
    end

    self:finish()
    return true
end

function PlatformActions:update(player)
    local player_state = player and player.platform_state
    if player_state and player_state.targetmode then
        return false
    end

    self:updateCooldown()
    if self:updateActive(player) then
        return true
    end
    return self:tryFreeWill(player)
end

return PlatformActions
