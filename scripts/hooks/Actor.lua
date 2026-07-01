local Actor, super = HookSystem.hookScript(Actor)

local function spriteMeta(origin_x, origin_y, margin_bottom, margin_left, margin_right, margin_top)
    return {
        origin_x = origin_x,
        origin_y = origin_y,
        margin_left = margin_left or 0,
        margin_right = margin_right or 0,
        margin_top = margin_top or 0,
        margin_bottom = margin_bottom,
    }
end

local DEFAULT_PLATFORM_SPRITE_METADATA = {
    kris = {
        ["party/kris/platform/ball"] = spriteMeta(12, 11, 21, 0, 23, 0),
        ["party/kris/platform/crouch"] = spriteMeta(24, 18, 35, 15, 32, 11),
        ["party/kris/platform/halt"] = spriteMeta(24, 18, 35, 15, 33, 12),
        ["party/kris/platform/hurt_air"] = spriteMeta(13, 30, 48, 4, 22, 18),
        ["party/kris/platform/hurt_ground"] = spriteMeta(16, 30, 49, 5, 39, 21),
        ["party/kris/platform/idle"] = spriteMeta(24, 18, 35, 15, 32, 11),
        ["party/kris/platform/jump_down"] = spriteMeta(23, 21, 41, 6, 37, 0),
        ["party/kris/platform/jump_up"] = spriteMeta(32, 16, 36, 13, 47, 0),
        ["party/kris/platform/land"] = spriteMeta(36, 14, 32, 27, 45, 12),
        ["party/kris/platform/run"] = spriteMeta(25, 16, 31, 19, 33, 24),
        ["party/kris/platform/slash_air"] = spriteMeta(52, 41, 76, 22, 93, 5),
        ["party/kris/platform/slash_ground"] = spriteMeta(43, 43, 79, 18, 93, 0),
        ["party/kris/platform/turn"] = spriteMeta(17, 16, 33, 8, 26, 12),
    },
    ralsei = {
        ["party/ralsei/platform/climb"] = spriteMeta(14, 22, 39, 6, 23, 3),
        ["party/ralsei/platform/fall"] = spriteMeta(15, 23, 40, 0, 25, 4),
        ["party/ralsei/platform/falling"] = spriteMeta(25, 32, 49, 0, 37, 0),
        ["party/ralsei/platform/halt"] = spriteMeta(15, 23, 46, 2, 23, 8),
        ["party/ralsei/platform/idle"] = spriteMeta(10, 16, 39, 1, 18, 6),
        ["party/ralsei/platform/jump"] = spriteMeta(15, 23, 44, 7, 30, 2),
        ["party/ralsei/platform/land"] = spriteMeta(15, 23, 46, 0, 25, 15),
        ["party/ralsei/platform/run"] = spriteMeta(15, 23, 41, 0, 29, 17),
        ["party/ralsei/platform/splat"] = spriteMeta(23, -12, 15, 0, 46, 1),
        ["party/ralsei/platform/spell"] = spriteMeta(26, 22, 46, 0, 43, 0),
        ["party/ralsei/platform/spellready"] = spriteMeta(26, 22, 46, 5, 41, 2),
        ["party/ralsei/platform/turn"] = spriteMeta(15, 9, 33, 2, 29, 0),
    },
    susie = {
        ["party/susie/platform/attack"] = spriteMeta(40, 47, 70, 30, 49, 0),
        ["party/susie/platform/attackready"] = spriteMeta(40, 20, 40, 30, 46, 17),
        ["party/susie/platform/climb"] = spriteMeta(16, 24, 39, 7, 24, 3),
        ["party/susie/platform/fall"] = spriteMeta(19, 21, 41, 4, 33, 0),
        ["party/susie/platform/halt"] = spriteMeta(14, 21, 43, 0, 31, 0),
        ["party/susie/platform/idle"] = spriteMeta(13, 21, 42, 5, 20, 8),
        ["party/susie/platform/jump"] = spriteMeta(19, 21, 42, 1, 30, 0),
        ["party/susie/platform/land"] = spriteMeta(19, 21, 42, 3, 32, 15),
        ["party/susie/platform/run"] = spriteMeta(19, 21, 42, 0, 37, 4),
        ["party/susie/platform/spellready"] = spriteMeta(38, 38, 57, 21, 62, 2),
        ["party/susie/platform/spellready_unhappy"] = spriteMeta(38, 38, 57, 21, 62, 2),
        ["party/susie/platform/turn"] = spriteMeta(19, 21, 42, 0, 35, 3),
    },
}

local function drRelativeOffset(sprite, base_sprite)
    return function(actor, name, facing, width, height)
        local metadata = actor:getPlatformSpriteMetadata(sprite)
        local data = actor.getPlatformData and actor:getPlatformData()
        local base_metadata = actor:getPlatformSpriteMetadata(base_sprite or (data and data.base_sprite) or sprite)
        if metadata then
            local offset_x = (width / 2) - metadata.origin_x
            local offset_y = height - metadata.origin_y
            if base_metadata then
                offset_y = (height - base_metadata.margin_bottom) + base_metadata.origin_y - metadata.origin_y
            end
            return offset_x, offset_y
        end
        return 0, 0
    end
end

local function drAnimationSpeed(image_speed)
    return 1 / (30 * image_speed)
end

local function drRunSpeed(state)
    local hspeed = math.abs(state and state.hspeed or 0)
    local hspeed_max = (Featherfall and Featherfall.constants and Featherfall.constants.hspeed_max) or 9
    local image_speed = 0.15 + (0.25 * MathUtils.clamp(hspeed / hspeed_max, 0, 1))
    return drAnimationSpeed(image_speed)
end

local DR_ANIM_SPEED = drAnimationSpeed(0.25)
local DR_FAST_TURN_SPEED = drAnimationSpeed(0.5)

local function findLineTarget(state, actions, player, data)
    return actions:findLineTarget(data, player)
end

local function findNearestTarget(state, actions, player, data)
    return actions:findNearestTarget(data, player)
end

local function canActWhileFalling(state, actions, player, target, data)
    local player_state = player and player.platform_state
    return not player_state or (player_state.vspeed or 0) > -30
end

local function canActAsAirPlatform(state, actions, player, target, data)
    local player_state = player and player.platform_state
    if state.isActionPlatformActive and state:isActionPlatformActive() then
        if state.action_platform_mode ~= 3 or not state.player_stood_on_action_platform_recently then
            return false
        end
    end
    return player_state and not player_state.on_ground and (player_state.vspeed or 0) < 12
end

local function autoSelectActionPlatform(state, actions, target, data)
    if target and target.platform_action_override then
        return
    end
    if target and target.platform_action_target and state.turnIntoActionPlatform then
        return state:turnIntoActionPlatform(target, target.hang_xoffset or 0, target.hang_yoffset or 0, data)
    end
    if state.isActionPlatformActive and state:isActionPlatformActive() and state.dropOffActionPlatform then
        state:dropOffActionPlatform(true)
    end
end

local function actionPlatformFall(target, acting_state, action_data)
    local platform_state = target and target.getActionPlatformState and target:getActionPlatformState()
    if platform_state and platform_state.actionPlatformFallDown then
        return platform_state:actionPlatformFallDown((action_data and action_data.platform_fall_splat_duration) or 60)
    end
    return false
end

local DEFAULT_PLATFORM_DATA = {
    kris = {
        size = {20, 38},
        hitbox = {0, 0, 20, 38},
        base_sprite = "party/kris/platform/idle",
        animations = {
            idle = {sprite = "party/kris/platform/idle", speed = DR_ANIM_SPEED, loop = true},
            crouch = {sprite = "party/kris/platform/crouch"},
            run = {sprite = "party/kris/platform/run", speed = drRunSpeed, loop = true},
            jump_up = {sprite = "party/kris/platform/jump_up"},
            jump_down = {sprite = "party/kris/platform/jump_down"},
            land = {sprite = "party/kris/platform/land", speed = DR_ANIM_SPEED, loop = true},
            turn = {sprite = "party/kris/platform/turn", speed = DR_ANIM_SPEED, loop = true},
            halt = {sprite = "party/kris/platform/halt", speed = DR_ANIM_SPEED, loop = true},
            hurt_air = {sprite = "party/kris/platform/hurt_air"},
            hurt_ground = {sprite = "party/kris/platform/hurt_ground"},
            slash_ground = {
                sprite = "party/kris/platform/slash_ground",
                manual = true,
                offset = drRelativeOffset("party/kris/platform/slash_ground"),
            },
            slash_air = {
                sprite = "party/kris/platform/slash_air",
                manual = true,
                offset = drRelativeOffset("party/kris/platform/slash_air"),
            },
        },
    },
    susie = {
        size = {20, 38},
        hitbox = {0, 0, 20, 38},
        base_sprite = "party/susie/platform/idle",
        animations = {
            idle = {sprite = "party/susie/platform/idle", speed = DR_ANIM_SPEED, loop = true},
            run = {
                sprite = "party/susie/platform/run",
                speed = drRunSpeed,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/run", "party/susie/platform/idle"),
            },
            jump_up = {
                sprite = "party/susie/platform/jump",
                offset = drRelativeOffset("party/susie/platform/jump", "party/susie/platform/idle"),
            },
            jump_down = {
                sprite = "party/susie/platform/fall",
                offset = drRelativeOffset("party/susie/platform/fall", "party/susie/platform/idle"),
            },
            land = {
                sprite = "party/susie/platform/land",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/land", "party/susie/platform/idle"),
            },
            turn = {
                sprite = "party/susie/platform/turn",
                speed = DR_FAST_TURN_SPEED,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/turn", "party/susie/platform/idle"),
            },
            halt = {
                sprite = "party/susie/platform/halt",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/halt", "party/susie/platform/idle"),
            },
            spellready = {
                sprite = "party/susie/platform/spellready",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/spellready", "party/susie/platform/idle"),
            },
            spellready_unhappy = {
                sprite = "party/susie/platform/spellready_unhappy",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/spellready_unhappy", "party/susie/platform/idle"),
            },
            attackready = {
                sprite = "party/susie/platform/attackready",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/susie/platform/attackready", "party/susie/platform/idle"),
            },
            attack = {
                sprite = "party/susie/platform/attack",
                speed = DR_ANIM_SPEED,
                loop = false,
                offset = drRelativeOffset("party/susie/platform/attack", "party/susie/platform/idle"),
            },
        },
    },
    ralsei = {
        size = {20, 38},
        hitbox = {0, 0, 20, 38},
        base_sprite = "party/ralsei/platform/idle",
        follow_distance_bonus = 40,
        animations = {
            idle = {sprite = "party/ralsei/platform/idle", speed = DR_ANIM_SPEED, loop = true},
            run = {
                sprite = "party/ralsei/platform/run",
                speed = drRunSpeed,
                loop = true,
                offset = drRelativeOffset("party/ralsei/platform/run", "party/ralsei/platform/idle"),
            },
            jump_up = {
                sprite = "party/ralsei/platform/jump",
                offset = drRelativeOffset("party/ralsei/platform/jump", "party/ralsei/platform/idle"),
            },
            jump_down = {
                sprite = "party/ralsei/platform/fall",
                offset = drRelativeOffset("party/ralsei/platform/fall", "party/ralsei/platform/idle"),
            },
            land = {
                sprite = "party/ralsei/platform/land",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/ralsei/platform/land", "party/ralsei/platform/idle"),
            },
            splat = {
                sprite = "party/ralsei/platform/splat",
                loop = true,
                offset = drRelativeOffset("party/ralsei/platform/splat", "party/ralsei/platform/idle"),
            },
            turn = {
                sprite = "party/ralsei/platform/turn",
                speed = DR_FAST_TURN_SPEED,
                loop = true,
                offset = drRelativeOffset("party/ralsei/platform/turn", "party/ralsei/platform/idle"),
            },
            halt = {
                sprite = "party/ralsei/platform/halt",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/ralsei/platform/halt", "party/ralsei/platform/idle"),
            },
            spellready = {
                sprite = "party/ralsei/platform/spellready",
                speed = DR_ANIM_SPEED,
                loop = true,
                offset = drRelativeOffset("party/ralsei/platform/spellready", "party/ralsei/platform/idle"),
            },
            spell = {
                sprite = "party/ralsei/platform/spell",
                speed = DR_ANIM_SPEED,
                loop = false,
                offset = drRelativeOffset("party/ralsei/platform/spell", "party/ralsei/platform/idle"),
            },
        },
    },
}

local DEFAULT_FOLLOWER_ACTION_DATA = {
    susie = {
        kind = "susie",
        target_kind = "susie",
        name = "Susie",
        label = "S-Action",
        color = {1, 0, 1},
        label_color = {1, 0, 1},
        afterimage_color = {1, 0, 1},
        inactive_message = "Susie is recharging.",
        free_will = true,
        horizontal_radius = 260,
        vertical_radius = 160,
        horizontal_margin = 100,
        vertical_margin = 40,
        minimum_target_age = 20,
        approach_distance = 10,
        approach_timer = 40,
        ready_cue_timer = 30,
        perform_timer = 40,
        recover_timer = 22,
        cooldown = 120,
        cooldown_text = "RECHARGE",
        skip_approach = true,
        beam_x_offset = 40,
        beam_y_offset = -12,
        beam_damage = 2,
        beam_explodes = true,
        beam_interim = 0,
        charge_animation = "spellready",
        attack_ready_animation = "attackready",
        ready_animation = "spellready",
        release_animation = "attack",
        ready_sound = "boost",
        release_sound = "rudebuster_swing",
        findTarget = findLineTarget,
        canAct = canActWhileFalling,
    },
    ralsei = {
        kind = "ralsei",
        target_kind = "ralsei",
        name = "Ralsei",
        label = "R-Action",
        color = {0, 1, 0},
        label_color = {0, 1, 0},
        afterimage_color = {0, 1, 0},
        inactive_message = "Ralsei is recharging.",
        free_will = true,
        player_radius = 300,
        trigger_distance = 200,
        minimum_target_age = 60,
        approach_distance = 10,
        approach_timer = 40,
        ready_cue_timer = 30,
        perform_timer = 40,
        recover_timer = 22,
        charge_animation = "spellready",
        attack_ready_animation = "spell",
        ready_animation = "spellready",
        release_animation = "spell",
        ready_sound = "spellcast",
        release_sound = "power",
        findTarget = findNearestTarget,
        canAct = canActAsAirPlatform,
        onAutoSelect = autoSelectActionPlatform,
        action_platform_target_override = {
            kind = "susie",
            objectname = "Ralsei Fall",
            description = "I'll cut down Ralsei.",
            perform = actionPlatformFall,
        },
    },
}

local function normalizeAnimation(animation)
    if type(animation) == "string" then
        return {sprite = animation}
    elseif type(animation) == "table" then
        if animation.sprite then
            return animation
        elseif type(animation[1]) == "string" then
            return {
                sprite = animation[1],
                speed = animation[2],
                loop = animation[3],
                offset = animation.offset,
                metadata = animation.metadata,
            }
        end
    end
end

local function copyPresentationFields(target, source)
    if type(source) ~= "table" then
        return
    end

    for _, key in ipairs({
        "label",
        "name",
        "color",
        "label_color",
        "gradient",
        "afterimage_color",
        "inactive_message",
    }) do
        if source[key] ~= nil then
            target[key] = source[key]
        end
    end
end

local function resolvePresentationTable(presentation, kind, actor, state, target, data)
    if type(presentation) == "function" then
        return presentation(actor, kind, state, target, data)
    elseif type(presentation) == "table" then
        local by_kind = presentation[kind]
        if type(by_kind) == "function" then
            return by_kind(actor, kind, state, target, data)
        elseif type(by_kind) == "table" then
            return by_kind
        elseif presentation.color or presentation.label or presentation.gradient then
            return presentation
        end
    end
end

function Actor:getPlatformData()
    if self.platform then
        return self.platform
    end
    return DEFAULT_PLATFORM_DATA[self.id]
end

function Actor:getPlatformAnimation(name)
    local data = self:getPlatformData()
    if not data then
        return nil
    end

    local animation = data.animations and (data.animations[name] or data.animations.default)
    if not animation and data.sprites then
        animation = data.sprites[name] or data.sprites.default
    end

    return normalizeAnimation(animation)
end

function Actor:getPlatformSpriteMetadata(sprite)
    local data = self:getPlatformData()
    if data and data.sprite_metadata and data.sprite_metadata[sprite] then
        return data.sprite_metadata[sprite]
    end
    if data and data.metadata and data.metadata[sprite] then
        return data.metadata[sprite]
    end
    if data and data.animations then
        for _, animation in pairs(data.animations) do
            local normalized = normalizeAnimation(animation)
            if normalized and normalized.sprite == sprite and normalized.metadata then
                return normalized.metadata
            end
        end
    end

    local defaults = DEFAULT_PLATFORM_SPRITE_METADATA[self.id]
    return defaults and defaults[sprite]
end

function Actor:getPlatformSize()
    local data = self:getPlatformData()
    if data and data.size then
        return data.size[1], data.size[2]
    end
    return 20, 38
end

function Actor:getPlatformHitbox()
    local data = self:getPlatformData()
    if data and data.hitbox then
        return unpack(data.hitbox)
    end

    local width, height = self:getPlatformSize()
    return 0, 0, width, height
end

function Actor:getPlatformOffset(name, facing, width, height)
    local data = self:getPlatformData()
    local animation = self:getPlatformAnimation(name)

    if not data or not animation then
        return 0, 0
    end

    local offset = animation.offset
    if data.offsets then
        offset = data.offsets[name] or data.offsets[animation.sprite] or offset
    end

    if type(offset) == "function" then
        return offset(self, name, facing, width, height)
    elseif type(offset) == "table" then
        local facing_offset = offset[facing]
        if type(facing_offset) == "table" then
            return facing_offset[1] or 0, facing_offset[2] or 0
        end
        return offset[1] or 0, offset[2] or 0
    end

    local metadata = self:getPlatformSpriteMetadata(animation.sprite)
    if metadata then
        return (width / 2) - metadata.origin_x, height - metadata.margin_bottom
    end

    return 0, 0
end

function Actor:getPlatformFollowerActionData(kind, state)
    if self.platform_follower_action ~= nil then
        return self.platform_follower_action
    end
    if self.platform_action ~= nil then
        return self.platform_action
    end
    if self.platform and self.platform.follower_action ~= nil then
        return self.platform.follower_action
    end
    return DEFAULT_FOLLOWER_ACTION_DATA[self.id] or DEFAULT_FOLLOWER_ACTION_DATA[kind]
end

function Actor:getPlatformActionPresentation(kind, state, target, data)
    kind = string.lower(tostring(kind or "any"))
    local result = {}

    data = data or self:getPlatformFollowerActionData(kind, state)
    copyPresentationFields(result, data)

    local custom = self.platform_action_presentation
        or self.platform_action
        or (self.platform and (self.platform.action_presentation or self.platform.action))
    copyPresentationFields(result, resolvePresentationTable(custom, kind, self, state, target, data))

    if next(result) then
        return result
    end
end

return Actor
