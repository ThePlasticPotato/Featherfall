local PartyMember, super = HookSystem.hookScript(PartyMember)

local function spawnPlatformHealEffect(target)
    if not Game.world then
        return
    end
    if PlatformHealEffect then
        Game.world:addChild(PlatformHealEffect(target))
    end
end

local function performRudeBuster(member, follower_state, target, action_data)
    local character = follower_state and follower_state.getCharacter and follower_state:getCharacter() or follower_state and follower_state.follower
    if not (follower_state and character and target) then
        return false
    end
    action_data = action_data or {}

    local sx = character.x + (action_data.beam_x_offset or 40)
    local sy = character.y + (action_data.beam_y_offset or 30)
    local function hitTarget()
        target.last_platform_damage = action_data.beam_damage or 2
        target.last_platform_damage_bonus = 0
        target.last_platform_explodes = action_data.beam_explodes ~= false
        if target.platform_action_override and target.performFollowerAction then
            return target:performFollowerAction(action_data.kind or "susie", follower_state, action_data)
        elseif target.onPlatformRudeBuster then
            return target:onPlatformRudeBuster(follower_state, action_data)
        elseif target.performPlatformAction then
            return target:performPlatformAction(action_data.kind or "susie", follower_state, action_data)
        elseif target.performFollowerAction then
            return target:performFollowerAction(action_data.kind or "susie", follower_state, action_data)
        end
    end

    if Game.world and PlatformRudeBusterBeam then
        local beam = PlatformRudeBusterBeam(sx, sy, target, hitTarget, {
            red = action_data.red_buster == true,
            interim_target_reached = (action_data.beam_interim or 0) == 0,
            interim_target_x = action_data.beam_interim or 0,
        })
        beam.layer = WORLD_LAYERS["above_events"] + 1
        Game.world:addChild(beam)
        return true
    end
    return hitTarget()
end

local function performHealOrPlatform(member, follower_state, target, action_data)
    if not target then
        return false
    end
    if target.platform_action_override and target.performFollowerAction then
        return target:performFollowerAction(action_data and action_data.kind or "ralsei", follower_state, action_data)
    end
    if target.platform_action_target and follower_state and follower_state.turnIntoActionPlatform then
        return follower_state:turnIntoActionPlatform(target, target.hang_xoffset or 0, target.hang_yoffset or 0, action_data)
    end
    if follower_state and follower_state.isActionPlatformActive and follower_state:isActionPlatformActive() then
        follower_state:dropOffActionPlatform(true)
    end
    spawnPlatformHealEffect(target)
    if target.onPlatformHeal then
        return target:onPlatformHeal(follower_state, action_data)
    end
    if target.performPlatformAction then
        return target:performPlatformAction(action_data and action_data.kind or "ralsei", follower_state, action_data)
    end
    if target.performFollowerAction then
        return target:performFollowerAction(action_data and action_data.kind or "ralsei", follower_state, action_data)
    end
    return true
end

local DEFAULT_PLATFORM_ACTION_HANDLERS = {
    susie = {
        susie = performRudeBuster,
    },
    ralsei = {
        ralsei = performHealOrPlatform,
    },
}

local function getPlatformActionHandlers(member)
    if member.platform_actions ~= nil then
        return member.platform_actions
    end
    return DEFAULT_PLATFORM_ACTION_HANDLERS[member.id]
end

function PartyMember:onPlatformFollowerAction(kind, follower_state, target, action_data)
    kind = kind or (action_data and action_data.kind) or self.id

    if action_data and action_data.performAction then
        return action_data.performAction(self, follower_state, target, action_data)
    end

    local handlers = getPlatformActionHandlers(self)
    local handler = type(handlers) == "table" and (handlers[kind] or handlers.default)
    if type(handler) == "function" then
        return handler(self, follower_state, target, action_data)
    end

    if target and target.platform_action_override and target.performFollowerAction then
        return target:performFollowerAction(kind, follower_state, action_data)
    end
    if target and target.performPlatformAction then
        return target:performPlatformAction(kind, follower_state, action_data)
    end
    if target and target.performFollowerAction then
        return target:performFollowerAction(kind, follower_state, action_data)
    end
    return true
end

return PartyMember
