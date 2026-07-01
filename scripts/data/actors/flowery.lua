local actor, super = Class(Actor, "flowery")

local function drOffset(origin_x, origin_y, base_margin_bottom, base_origin_y)
    return function(_, _, _, width, height)
        return (width / 2) - origin_x, (height - base_margin_bottom) + base_origin_y - origin_y
    end
end

local function platformOffset(origin_x, origin_y)
    return drOffset(origin_x, origin_y, 59, -1)
end

local function fixedOffset(x, y)
    return function()
        return x, y
    end
end

local function originOffset(origin_x, origin_y)
    return fixedOffset(10 - origin_x, 0 - origin_y)
end

local RAINBOW = {
    {1, 0, 0},
    {0, 177 / 255, 1},
    {0, 1, 1},
    {56 / 255, 230 / 255, 1},
    {1, 245 / 255, 0},
    {238 / 255, 92 / 255, 227 / 255},
    {1, 0, 242 / 255},
}

local function smoothRainbow()
    local phase = Kristal.getTime() * 1.8
    return {
        0.5 + (0.5 * math.sin(phase)),
        0.5 + (0.5 * math.sin(phase + ((math.pi * 2) / 3))),
        0.5 + (0.5 * math.sin(phase + ((math.pi * 4) / 3))),
    }
end

local FLOWERY_SPRITE_BOUNDS = {
    ["party/flowery/idle"] = {left = 0, right = 21, top = 0, bottom = 59},
    ["party/flowery/platform/crouch"] = {left = 7, right = 47, top = 43, bottom = 85},
    ["party/flowery/platform/idle"] = {left = 0, right = 52, top = 0, bottom = 56},
    ["party/flowery/platform/jarona"] = {left = 0, right = 56, top = 0, bottom = 26},
    ["party/flowery/platform/jarona_powerup"] = {left = 3, right = 37, top = 0, bottom = 57},
    ["party/flowery/platform/jump_down"] = {left = 0, right = 38, top = 4, bottom = 60},
    ["party/flowery/platform/jump_up"] = {left = 0, right = 38, top = 4, bottom = 60},
    ["party/flowery/platform/kick"] = {left = 0, right = 45, top = 13, bottom = 65},
    ["party/flowery/platform/kick_crescent"] = {left = 0, right = 69, top = 0, bottom = 74},
    ["party/flowery/platform/pose"] = {left = 3, right = 43, top = 4, bottom = 56},
    ["party/flowery/platform/run"] = {left = 0, right = 45, top = 2, bottom = 43},
    ["party/flowery/jarona/spr_flowery_fair"] = {left = 1, right = 46, top = 5, bottom = 46},
    ["party/flowery/jarona/spr_flowery_poweringup"] = {left = 0, right = 32, top = 0, bottom = 72},
    ["party/flowery/jarona/spr_flowery_punch_windup"] = {left = 0, right = 29, top = 0, bottom = 58},
    ["party/flowery/jarona/spr_flowery_puuunch"] = {left = 0, right = 57, top = 0, bottom = 46},
    ["party/flowery/walk/down"] = {left = 3, right = 21, top = 43, bottom = 60},
    ["party/flowery/walk/up"] = {left = 3, right = 21, top = 43, bottom = 60},
    ["party/flowery/walk/left"] = {left = 3, right = 21, top = 43, bottom = 60},
    ["party/flowery/walk/right"] = {left = 3, right = 21, top = 43, bottom = 60},
    ["party/flowery/walk/downleft"] = {left = 1, right = 21, top = 0, bottom = 60},
    ["party/flowery/walk/downright"] = {left = 0, right = 20, top = 0, bottom = 60},
    ["party/flowery/walk/upleft"] = {left = 1, right = 20, top = 0, bottom = 59},
    ["party/flowery/walk/upright"] = {left = 1, right = 20, top = 0, bottom = 59},
}

local FLOWERY_ANCHOR_OFFSETS = {
    action = {x = 0, y = -6},
    omega = {x = 0, y = 0},
}

local function getSpriteBounds(sprite)
    if not sprite then
        return
    end

    return FLOWERY_SPRITE_BOUNDS[sprite.full_sprite]
        or FLOWERY_SPRITE_BOUNDS[sprite.texture_path]
        or FLOWERY_SPRITE_BOUNDS[sprite.sprite]
end

local function getSpriteBoundsAnchor(character, kind)
    local sprite = character and character.sprite
    if not (sprite and sprite.getRelativePos) then
        return
    end

    local bounds = getSpriteBounds(sprite)
    local x, y
    if bounds then
        x = (bounds.left + bounds.right) / 2
        y = (bounds.top + bounds.bottom) / 2
    else
        x = (sprite.width or 0) / 2
        y = (sprite.height or 0) / 2
    end

    local offset = FLOWERY_ANCHOR_OFFSETS[kind] or FLOWERY_ANCHOR_OFFSETS.action
    return sprite:getRelativePos(x + (offset.x or 0), y + (offset.y or 0), Game.world or character.parent)
end

function actor:init()
    super.init(self)

    self.name = "Flowery"
    self.width = 20
    self.height = 38
    self.hitbox = {0, 0, 20, 38}
    self.color = {1, 1, 0}
    self.path = "party/flowery"
    self.default = "walk"
    --self.flip = "right"
    self.voice = "flowery/heyguys"
    self.portrait_path = "party/flowery/portraits"
    self.soul_offset = {10, 20}

    self.animations = {
        ["walk/down"] = {"walk/down", 0.15, true},
        ["walk/up"] = {"walk/up", 0.15, true},
        ["walk/left"] = {"walk/left", 0.15, true},
        ["walk/right"] = {"walk/right", 0.15, true},
        ["walk/downleft"] = {"walk/downleft", 0.15, true},
        ["walk/downright"] = {"walk/downright", 0.15, true},
        ["walk/upleft"] = {"walk/upleft", 0.15, true},
        ["walk/upright"] = {"walk/upright", 0.15, true},
    }

    self.platform_action_presentation = {
        flowery = {
            name = "Flowery",
            label = "JARONA!",
            color = smoothRainbow,
            gradient = RAINBOW,
        },
        flowery_omega = {
            name = "Flowery",
            label = "JARONA!",
            color = smoothRainbow,
            gradient = RAINBOW,
        },
    }

    self.platform = {
        size = {20, 38},
        hitbox = {0, 0, 20, 38},
        animations = {
            idle = {sprite = "party/flowery/idle", speed = 1 / (30 * 0.25), loop = true, invert_flip = true, offset = fixedOffset(-3, -21)},
            crouch = {sprite = "party/flowery/platform/crouch", offset = platformOffset(14, 27)},
            run = {sprite = "party/flowery/platform/run", speed = 1 / (30 * 0.35), loop = true, offset = platformOffset(8, -17)},
            jump_up = {sprite = "party/flowery/platform/jump_down", offset = platformOffset(4, -1)},
            jump_down = {sprite = "party/flowery/platform/jump_down", offset = platformOffset(4, -1)},
            land = {sprite = "party/flowery/platform/crouch", offset = platformOffset(14, 27)},
            turn = {sprite = "party/flowery/platform/pose", offset = platformOffset(9, -4)},
            halt = {sprite = "party/flowery/platform/crouch", offset = platformOffset(14, 27)},
            kick = {sprite = "party/flowery/platform/kick", offset = platformOffset(14, 27)},
            slash_ground = {sprite = "party/flowery/platform/slash_ground", manual = true, offset = platformOffset(34, 27)},
            slash_air = {sprite = "party/flowery/platform/kick_crescent", manual = true, offset = platformOffset(14, 27)},
            jarona_ready = {sprite = "party/flowery/jarona/spr_flowery_punch_windup", speed = 1 / (30 * 0.2), loop = true, offset = platformOffset(0, -3)},
            jarona_punch = {sprite = "party/flowery/jarona/spr_flowery_puuunch", offset = originOffset(26, 0)},
            jarona_fair = {sprite = "party/flowery/jarona/spr_flowery_fair", offset = originOffset(18, 0)},
            jarona_crescent = {sprite = "party/flowery/platform/kick_crescent", offset = originOffset(14, 15)},
            jarona_kick = {sprite = "party/flowery/platform/kick", offset = platformOffset(14, 27)},
            omega_poweringup = {sprite = "party/flowery/jarona/spr_flowery_poweringup", manual = true, offset = platformOffset(2, 13)},
            omega_powerup = {sprite = "party/flowery/platform/jarona_powerup", speed = 1 / (30 * 0.25), loop = true, offset = platformOffset(6, -1)},
            omega_jarona = {sprite = "party/flowery/platform/jarona", speed = 1 / (30 * 0.25), loop = true, offset = fixedOffset(-18, 0)},
        },
    }

    self.platform_follower_action = {
        kind = "flowery",
        target_kind = {"flowery", "flowery_omega"},
        free_will = false,
        skip_approach = true,
        ready_cue_timer = 8,
        perform_timer = 10,
        recover_timer = 50,
        cooldown = 120,
        cooldown_text = "JA-CHARGING",
        charge_animation = "jarona_ready",
        ready_animation = "jarona_ready",
        attack_ready_animation = "jarona_ready",
        release_animation = "jarona_kick",
        release_sound = "flowery/punchheavythunder",
        suppress_release_sound = true,
        suppress_action_afterimages = true,
        suppress_recover_animation = true,
        afterimage_color = {1, 1, 1},
        jarona_speed = 20,
        jarona_speed_limit = 36,
        jarona_speed_change = 3,
        jarona_crescent_distance = 48,
        jarona_recover_time = 20,
        omega_transform_time = 150,
        omega_charge_time = 80,
        jarona_voices = {
            "flowery/jarona1",
            "flowery/jarona2",
            "flowery/jarona3",
            "flowery/jarona4",
        },
        omega_voices = {
            "flowery/jarona1",
            "flowery/jarona2",
            "flowery/jarona3",
            "flowery/jarona4",
        },
    }
end

function actor:getPlatformActionAnchor(character)
    return getSpriteBoundsAnchor(character, "action")
end

function actor:getPlatformActionOmegaAnchor(character)
    return getSpriteBoundsAnchor(character, "omega")
end

return actor
