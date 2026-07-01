---@class PlayerPlatformState : PlatformActorState
---@field player Player
local PlatformActorState = libRequire("featherfall", "scripts.world.states.PlatformActorState")
local PlatformActions = libRequire("featherfall", "scripts.world.states.PlatformActions")
local PlayerPlatformState, super = Class(PlatformActorState)

local function normalizeTargetKinds(kinds)
    if type(kinds) ~= "table" then
        return string.lower(tostring(kinds or "any"))
    end

    local result = {}
    for _, kind in ipairs(kinds) do
        table.insert(result, string.lower(tostring(kind or "any")))
    end
    return result
end

local function targetKindMatches(kind, target_kind)
    if type(target_kind) ~= "table" then
        return target_kind == kind
    end
    for _, candidate in ipairs(target_kind) do
        if candidate == kind then
            return true
        end
    end
    return false
end

local function targetAvailableForAny(target, target_kind)
    if not (target and target.isAvailableFor) then
        return true
    end
    if type(target_kind) ~= "table" then
        return target:isAvailableFor(target_kind)
    end
    for _, candidate in ipairs(target_kind) do
        if target:isAvailableFor(candidate) then
            return true
        end
    end
    return false
end

local function propertyBool(value)
    return value == true or value == 1 or value == "true"
end

local function firstProperty(properties, ...)
    for _, key in ipairs({...}) do
        if properties[key] ~= nil then
            return properties[key]
        end
    end
end

local function drawCircularBar(x, y, value, max_value, color, radius, alpha, thickness)
    local progress = MathUtils.clamp((value or 0) / math.max(max_value or 1, 1), 0, 1)
    if progress <= 0 then
        return
    end
    local old_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(thickness or 3)
    Draw.setColor(color or {1, 1, 1}, alpha or 1)
    love.graphics.arc("line", "open", x, y, radius or 50, -math.pi / 2, (-math.pi / 2) + (math.pi * 2 * progress), 48)
    love.graphics.setLineWidth(old_width)
    Draw.setColor(1, 1, 1, 1)
end

---todo: holy mess batman
function PlayerPlatformState:init(player)
    self.player = player
    self.hspeed = 0
    self.vspeed = 0
    self.on_ground = false
    self.timer = 0
    self.coyote_timer = 0
    self.jump_timer = 0
    self.jumpsquat_timer = 0
    self.time_since_ground = 0
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    self.facing = "right"
    self.exit_cooldown = 0
    self.current_animation = nil
    self.current_sprite_facing = nil
    self.entity = nil
    self.attackbuffer = 0
    self.attacking = false
    self.attack_hitbox = 0
    self.attack_frame = 0
    self.attack_canceleable = 1
    self.attack_buffered = false
    self.attack_press_buffer = 0
    self.attack_press_mode = 0
    self.attack_press_timer = 0
    self.key_attack = false
    self.press_attack = false
    self.attack_end_visible = false
    self.jumpbutton_hover = false
    self.max_hovers = 5
    self.hovers_remaining = self.max_hovers
    self.jumphovering = false
    self.jumphover_meter = 140
    self.jumphover_max = self.jumphover_meter
    self.jumphover_min = 5
    self.jumphover_time = 0
    self.jumphover_chargevfx = 0
    self.jumphover_chargevfx_max = 15
    self.jumphover_chargevfx_white = 0
    self.jumphover_chargevfx_whitemax = 20
    self.hover_movespeed = 6
    self.jumphover_shiftmode = true
    self.heart_xoffset = 0
    self.heart_yoffset = 0
    self.heart_offset_max = 25
    self.hover_keeps_momentum = false
    self.jumphover_iframes_requirement = 10
    self.heart_mode = 0
    self.heart_retreating = false
    self.key_left = false
    self.key_right = false
    self.checkpoint_x = 0
    self.checkpoint_y = 0
    self.respawn_leap_enabled = true
    self.respawn_leap_style = 0
    self.fallen_in_pit = 0
    self.pit_timer = 0
    self.pit_lerp_time = 0
    self.pit_lerp_start_x = 0
    self.pit_leap_time = 0
    self.act_button_held = false
    self.act_buffer = false
    self.targetmode = false
    self.menu_pause_active = false
    self.targetmode_sprite_pause = nil
    self.act_targets = {}
    self.targetindex = -1
    self.hlit_target = -1
    self.hlit_name = ""
    self.hlit_desc = ""
    self.hlit_blocked = false
    self.hlit_label = "No ACT"
    self.hlit_label_color = {0.5, 0.5, 0.5}
    self.actions = PlatformActions(self)
end

function PlayerPlatformState:registerEvents()
    self:registerEvent("enter", self.onEnter)
    self:registerEvent("update", self.onUpdate)
    self:registerEvent("leave", self.onExit)
    self:registerEvent("drawDebug", self.drawDebug)
    self:registerEvent("getDebugInfo", self.getDebugInfo)
end

function PlayerPlatformState:getDebugInfo(info)
    table.insert(info, string.format("Featherfall speed: %.2f, %.2f", self.hspeed, self.vspeed))
    table.insert(info, "Featherfall grounded: " .. (self.on_ground and "True" or "False"))
    if self.entity then
        table.insert(info, string.format("Featherfall jump: buffer %.2f, coyote %.2f, squat %.2f", self.entity.jumpbuffer, self.entity.jump_coyote_time, self.entity.jumpsquat))
    end
end

function PlayerPlatformState:setPlayerAnimation(name)
    return self:setPlatformAnimation(name)
end

function PlayerPlatformState:syncFromEntity()
    if not self.entity then
        return
    end

    self.hspeed = self.entity.hspeed
    self.vspeed = self.entity.vspeed
    self.on_ground = self.entity.grounded
    self.coyote_timer = self.entity.jump_coyote_time
    self.jump_timer = self.entity.jump_time
    self.jumpsquat_timer = self.entity.jumpsquat
    if self.entity.grounded then
        self.time_since_ground = 0
    else
        self.time_since_ground = (self.time_since_ground or 0) + DTMULT
    end
end

function PlayerPlatformState:updateCheckpoint()
    if self.fallen_in_pit ~= 0 or not (Game.world and Game.world.map) then
        return
    end

    for _, event in ipairs(Game.world.map.events or {}) do
        if event.platform_checkpoint and event.collider and self.player:collidesWith(event.collider) then
            self.checkpoint_x = event.x
            self.checkpoint_y = event.y
            return
        end
    end
end

function PlayerPlatformState:getTargetCenter(target)
    if not target then
        return self.player.x, self.player.y
    end
    return target.cx or target.target_x or (target.x + ((target.width or 0) / 2)),
        target.cy or target.target_y or (target.y + ((target.height or 0) / 2))
end

function PlayerPlatformState:clearTargetModeHighlights()
    self.targetmode_highlighted = false
    self.targetmode_outline_kind = nil
    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        local state = follower.platform_state
        if state then
            state.targetmode_highlighted = false
            state.targetmode_outline_kind = nil
        end
    end
end

function PlayerPlatformState:updateTargetModeOutline()
    local should_outline = self.targetmode and self.targetmode_highlighted
    local fx = self.player:getFX("platform_targetmode_outline")

    if not should_outline then
        if fx then
            self.player:removeFX(fx)
        end
        return
    end

    if not fx then
        fx = self.player:addFX(OutlineFX({0, 1, 1, 1}, {thickness = 1}), "platform_targetmode_outline")
    end

    local color
    if self.targetmode_outline_kind and self.targetmode_outline_kind ~= "soul" then
        color = Featherfall and Featherfall.getActionColorTable and Featherfall:getActionColorTable(self.targetmode_outline_kind)
    end
    local r, g, b = self:getOutlineBaseColor()
    if color then
        r, g, b = color[1], color[2], color[3]
    end
    local amount = 0.8 + (math.sin(Kristal.getTime() * 10) * 0.2)
    fx:setColor(MathUtils.lerp(r, 1, amount), MathUtils.lerp(g, 1, amount), MathUtils.lerp(b, 1, amount), 1)
end

function PlayerPlatformState:isTargetValid(target, camera_x, camera_y, camera_width, camera_height)
    if not (target and target.parent and target.active and not target.protected and target.blocked ~= true and target.blocked ~= 1) then
        return false
    end

    local cx, cy = self:getTargetCenter(target)
    local buffer = 10
    local pad_bottom = buffer + 20
    return cx >= camera_x + buffer
        and cx <= camera_x + camera_width - buffer
        and cy >= camera_y + buffer
        and cy <= camera_y + camera_height - pad_bottom
end

function PlayerPlatformState:clearTargetModeTargets(reset_hover)
    reset_hover = reset_hover ~= false
    self:clearTargetModeHighlights()
    for _, target in ipairs(Featherfall:getActionTargets()) do
        if reset_hover then
            target.hovered = false
            target.last_hovered = false
        end
        target.is_valid_target = false
        target._character_active = nil
    end
end

function PlayerPlatformState:getPlatformActionStates()
    local states = {}
    if self.actions then
        local data = self.actions:getData()
        if data then
            table.insert(states, {
                character = self.player,
                state = self,
                data = data,
                leader = true,
            })
        end
    end

    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        local state = follower.platform_state
        if state and follower.isPlatforming and follower:isPlatforming() then
            local data = state.actions and state.actions:getData()
            if data then
                table.insert(states, {
                    character = follower,
                    state = state,
                    data = data,
                    leader = false,
                })
            end
        end
    end
    return states
end

function PlayerPlatformState:getActionState(kind, target)
    kind = string.lower(tostring(kind or "any"))
    for _, entry in ipairs(self:getPlatformActionStates()) do
        local data = entry.data
        local data_kind = string.lower(tostring(data.kind or "any"))
        local target_kind = normalizeTargetKinds(data.target_kind or data_kind)
        local kind_matches = kind == "any"
            or kind == "all"
            or data_kind == kind
            or targetKindMatches(kind, target_kind)
        local target_matches = not target
            or not target.isAvailableFor
            or targetAvailableForAny(target, target_kind)
        if kind_matches and target_matches then
            return entry.character, entry.state, data, entry
        end
    end
end

function PlayerPlatformState:getFollowerActionState(kind)
    local _, state, data = self:getActionState(kind)
    if state ~= self then
        return state, data
    end
end

function PlayerPlatformState:isActionKindReady(kind)
    kind = string.lower(tostring(kind or "any"))
    if kind == "soul" or kind == "none" or kind == "dog" then
        return true
    end
    local _, state = self:getActionState(kind)
    return state and state.actions and state.actions:isCharacterReady() or false
end

function PlayerPlatformState:getActionKindInactiveMessage(kind, target)
    local _, state, data = self:getActionState(kind, target)
    if data and data.inactive_message then
        return data.inactive_message
    end
    if state and state.actions and state.actions.cooldown_text then
        return state.actions.cooldown_text
    end
    return target and target.inactive_message or "Can't act right now"
end

function PlayerPlatformState:getActionDisplayName(kind, target)
    if Featherfall and Featherfall.getActionPresentation then
        local presentation = Featherfall:getActionPresentation(kind, target)
        if presentation and presentation.name then
            return presentation.name
        end
        if presentation and presentation.label then
            return presentation.label
        end
    end
    return tostring(kind or "The party")
end

function PlayerPlatformState:formatActionNameList(names)
    if #names == 0 then
        return "The party"
    elseif #names == 1 then
        return names[1]
    elseif #names == 2 then
        return names[1] .. " and " .. names[2]
    end

    local text = names[1]
    for index = 2, #names - 1 do
        text = text .. ", " .. names[index]
    end
    return text .. ", and " .. names[#names]
end

function PlayerPlatformState:getNoTargetDescription()
    if #(self.act_targets or {}) == 0 then
        return "* No ACTs are available."
    end

    local blocked2 = false
    local seen_kinds = {}
    local unavailable_names = {}
    local ready_names = {}
    for _, target in ipairs(self.act_targets) do
        if target.blocked == 2 then
            blocked2 = true
        end
        local kind = target.action_kind
        if kind ~= "soul"
            and kind ~= "none"
            and kind ~= "any"
            and kind ~= "all"
            and not seen_kinds[kind]
        then
            seen_kinds[kind] = true
            local name = self:getActionDisplayName(kind, target)
            if self:isActionKindReady(kind) then
                table.insert(ready_names, name)
            else
                table.insert(unavailable_names, name)
            end
        end
    end

    if blocked2 then
        return "* The enemy is guarding against ACTS!"
    end

    if #unavailable_names > 0 then
        local verb = #unavailable_names == 1 and " is" or " are"
        local text = "* " .. self:formatActionNameList(unavailable_names) .. verb .. " recharging."
        if #ready_names > 0 then
            local ready_verb = #ready_names == 1 and " is" or " are"
            text = text .. " " .. self:formatActionNameList(ready_names) .. ready_verb .. " ready."
        end
        return text
    end
    return "* Press a direction to select an ACT."
end

function PlayerPlatformState:collectActionTargets(preserve_hover)
    local camera_x, camera_y, camera_width, camera_height = self:getCameraRect()
    local targets = {}

    self:clearTargetModeTargets(not preserve_hover)
    for _, target in ipairs(Featherfall:getActionTargets()) do
        if self:isTargetValid(target, camera_x, camera_y, camera_width, camera_height) then
            target.is_valid_target = true
            table.insert(targets, target)
        end
    end

    return targets
end

function PlayerPlatformState:beginTargetMode()
    self.targetmode = true
    Assets.playSound(Featherfall.sounds.action_open)
    self:setTargetModeSpritePaused(true)
    self.targetindex = -1
    self.last_targetindex = -1
    self.heart_lerp_timer = 0
    self.hlit_target = -1
    self.hlit_name = ""
    self.hlit_desc = ""
    self.hlit_blocked = false
    self.hlit_label = "No ACT"
    self.hlit_label_color = {0.5, 0.5, 0.5}
    for _, target in ipairs(Featherfall:getActionTargets()) do
        target.hovered = false
        target.last_hovered = false
        target.hoverlerp = 0
    end
    self.act_targets = self:collectActionTargets()
    if #self.act_targets == 0 then
        self.hlit_target = -0.5
    end
    if Featherfall and Featherfall.updateActionUI then
        Featherfall:updateActionUI()
    end
end

function PlayerPlatformState:endTargetMode(select_target)
    local target = self.act_targets[self.targetindex]
    if target then
        target.hovered = false
    end

    self:setTargetModeSpritePaused(false)
    self.targetmode = false
    self.targetindex = -1
    self.hlit_target = -1
    self.hlit_name = ""
    self.hlit_desc = ""
    self.hlit_blocked = false
    self.hlit_label = "No ACT"
    self.hlit_label_color = {0.5, 0.5, 0.5}
    self:clearTargetModeTargets()
    self:updateTargetModeOutline()

    if select_target and target then
        self:selectActionTarget(target)
        self.attackbuffer = 0
        self.attack_press_timer = 0
        self.attack_buffered = false
        if self.entity then
            self.entity.jumpbuffer = 0
        end
    end
end

function PlayerPlatformState:isWorldMenuPaused()
    return Game.world and Game.world.state == "MENU" and Game.world.menu
end

function PlayerPlatformState:updateWorldMenuPause()
    local paused = self:isWorldMenuPaused()
    if paused then
        self.menu_pause_active = true
        self:setTargetModeSpritePaused(true)
        self.attack_press_timer = 0
        self.attackbuffer = 0
        self.attack_buffered = false
        self.key_left = false
        self.key_right = false
        return true
    elseif self.menu_pause_active then
        self.menu_pause_active = false
        self:setTargetModeSpritePaused(false)
    end
    return false
end

function PlayerPlatformState:getDirectionPressed()
    local dx, dy = 0, 0
    if Input.pressed("right") then
        dx = 1
    elseif Input.pressed("left") then
        dx = -1
    end
    if Input.pressed("down") then
        dy = 1
    elseif Input.pressed("up") then
        dy = -1
    end
    if dx ~= 0 or dy ~= 0 then
        return dx, dy
    end
end

function PlayerPlatformState:chooseTargetInDirection(dx, dy)
    local from = self.act_targets[self.targetindex]
    local from_x, from_y
    if from then
        from_x, from_y = self:getTargetCenter(from)
    else
        from_x = self.player.x
        from_y = self.player.y - (self.player.height / 2)
    end

    local best, best_index, best_score
    local input_len = math.sqrt((dx * dx) + (dy * dy))
    if input_len <= 0 then
        return
    end
    dx = dx / input_len
    dy = dy / input_len

    for index, target in ipairs(self.act_targets) do
        if target ~= from then
            local tx, ty = self:getTargetCenter(target)
            local vx = tx - from_x
            local vy = ty - from_y
            local dist = math.sqrt((vx * vx) + (vy * vy))
            if dist > 0 then
                local dot = ((vx / dist) * dx) + ((vy / dist) * dy)
                if dot >= math.cos(math.rad(#self.act_targets == 1 and 85 or 65)) then
                    local score = dist - (dot * 24)
                    if not best_score or score < best_score then
                        best = target
                        best_index = index
                        best_score = score
                    end
                end
            end
        end
    end

    return best, best_index
end

function PlayerPlatformState:getTargetPresentation(target, state, data)
    if Featherfall and Featherfall.getActionPresentation then
        return Featherfall:getActionPresentation(target and target.action_kind, target, state, data) or {}
    end
    return {}
end

function PlayerPlatformState:setHoveredTarget(index, silent)
    local old_index = self.targetindex
    local old_target = self.act_targets[self.targetindex]
    if old_target then
        old_target.hovered = false
    end
    self:clearTargetModeHighlights()

    self.targetindex = index or -1
    if old_index ~= self.targetindex then
        self.last_targetindex = old_index
        self.heart_lerp_timer = 0
    end
    local target = self.act_targets[self.targetindex]
    if target then
        target.hovered = true
        self.hlit_name = target.objectname or ""
        local character, state, data = self:getActorForTarget(target)
        local presentation = self:getTargetPresentation(target, state, data)
        self.hlit_target = 1
        self.hlit_label = presentation.label or "ACT"
        self.hlit_label_color = presentation.label_color or presentation.color or {1, 1, 0}
        local character_active = target.opens_menu or (state and state.actions and state.actions:isCharacterReady()) or self:isActionKindReady(target.action_kind)
        target._character_active = character_active
        self.hlit_desc = target.description or ""
        if not character_active then
            self.hlit_desc = self:getActionKindInactiveMessage(target.action_kind, target)
        end
        self.hlit_blocked = target.blocked == 2
        if state then
            state.targetmode_highlighted = true
            state.targetmode_outline_kind = target.action_kind
        elseif target.action_kind == "soul" or target.action_kind == "all" or target.action_kind == "kris" then
            self.targetmode_highlighted = true
            self.targetmode_outline_kind = target.action_kind
        end
        if not silent and old_index ~= self.targetindex then
            Assets.playSound((target.blocked == 2 or not character_active) and Featherfall.sounds.action_fail or Featherfall.sounds.action_move)
        end
    else
        self.hlit_target = -1
        self.hlit_name = ""
        self.hlit_desc = ""
        self.hlit_blocked = false
        self.hlit_label = "No ACT"
        self.hlit_label_color = {0.5, 0.5, 0.5}
        self.targetmode_highlighted = true
        if not silent and old_index ~= self.targetindex and #self.act_targets > 0 then
            Assets.playSound(Featherfall.sounds.action_fail)
        end
    end
    self:updateTargetModeOutline()
end

function PlayerPlatformState:getActorForTarget(target)
    if not target then
        return
    end

    local kind = target.action_kind
    if kind == "any" or kind == "all" then
        kind = nil
    end

    return self:getActionState(kind or "any", target)
end

function PlayerPlatformState:getFollowerForTarget(target)
    local character, state, data = self:getActorForTarget(target)
    if character ~= self.player then
        return character, state, data
    end
end

function PlayerPlatformState:selectActionTarget(target)
    if not (target and target.parent) then
        return false
    end

    if target.opens_menu or target.action_kind == "soul" then
        Assets.playSound(Featherfall.sounds.action_select)
        return target:select(nil, nil) ~= false
    end

    local character, state, data = self:getActorForTarget(target)
    if not (character and state and data) then
        Assets.playSound(Featherfall.sounds.action_fail)
        return false
    end
    if not (state.actions and state.actions:isCharacterReady()) then
        Assets.playSound(Featherfall.sounds.action_fail)
        return false
    end
    if state.actions.prepareTargetData then
        data = state.actions:prepareTargetData(data, target)
    end

    local selected = true
    if target.select then
        selected = target:select(state, data) ~= false
    end
    if selected then
        Assets.playSound(Featherfall.sounds.action_select)
        return character:requestPlatformAction(target, data)
    end
    Assets.playSound(Featherfall.sounds.action_fail)
    return false
end

function PlayerPlatformState:requestAction(target, data)
    data = data or (self.actions and self.actions:getData())
    if not (target and data and self.actions) then
        return false
    end
    if self.actions.prepareTargetData then
        data = self.actions:prepareTargetData(data, target)
    end
    self.actions:begin(target, data)
    return true
end

function PlayerPlatformState:updateTargetMode()
    local menu_down = Input.down("menu")
    self.act_button_held = menu_down

    local in_targetmode = menu_down and Featherfall.transition_timer <= 0 and self.fallen_in_pit == 0
    if in_targetmode and not self.targetmode then
        self:beginTargetMode()
    elseif not in_targetmode and self.targetmode then
        self:endTargetMode(true)
        return true
    end

    if not self.targetmode then
        return false
    end

    local previous_target = self.act_targets[self.targetindex]
    self.act_targets = self:collectActionTargets(true)
    if self.targetindex > #self.act_targets then
        self.targetindex = -1
    end
    if previous_target and (not previous_target.parent or not previous_target.is_valid_target) then
        previous_target.hovered = false
        self.targetindex = -1
    elseif previous_target then
        local found = false
        for index, target in ipairs(self.act_targets) do
            if target == previous_target then
                self.targetindex = index
                found = true
                break
            end
        end
        if not found then
            previous_target.hovered = false
            self.targetindex = -1
        end
    end
    if self.targetindex >= 1 and self.act_targets[self.targetindex] then
        self:setHoveredTarget(self.targetindex, true)
    elseif self.targetmode then
        self:setHoveredTarget(-1, true)
    end

    local dx, dy = self:getDirectionPressed()
    if dx then
        local _, index = self:chooseTargetInDirection(dx, dy)
        if index then
            self:setHoveredTarget(index)
        elseif #self.act_targets > 0 then
            self:setHoveredTarget(-1)
        end
    elseif Input.pressed("cancel") and #self.act_targets > 0 then
        self:setHoveredTarget(-1)
    end

    local target = self.act_targets[self.targetindex]
    if Input.pressed("confirm") and target and target.button1_activated then
        self:endTargetMode(true)
    end

    return true
end

function PlayerPlatformState:playEntityFeedbackSounds()
    if not self.entity then
        return
    end

    local landed = self.entity.grounded and not self.entity.grounded_prev
    if landed and not self.attacking and (self.time_since_ground or 0) > 2 then
        self:beginLandAnimation()
        Assets.playSound(Featherfall.sounds.landing, nil, 1.2)
        self:spawnDust(-1, Featherfall.assets.effects.landingdust_new)
        self:spawnDust(1, Featherfall.assets.effects.landingdust_new)
    end
    if self.entity.launched_jump then
        Assets.playSound(Featherfall.sounds.jump_launch, nil, 1.5)
    end
end

function PlayerPlatformState:spawnDust(direction, sprite)
    if not self.entity then
        return
    end

    local _, _, _, _, _, bottom = self.entity:getWorldBoundsAt(self.player.x, self.player.y)
    Featherfall:makeDust(self.player.x + (20 * direction), bottom, direction, sprite or Featherfall.assets.effects.landingdust)
end

function PlayerPlatformState:beginPitRespawn()
    if self.fallen_in_pit ~= 0 or not self.respawn_leap_enabled then
        return
    end

    self.fallen_in_pit = 1
    self.pit_timer = 0
    self.pit_lerp_start_x = self.player.x
    self.pit_lerp_time = 10 + math.ceil(math.abs(self.player.x - self.checkpoint_x) / 200)
    self.attacking = false
    self.attackbuffer = 0
    if self.entity then
        self.entity.hspeed = 0
        self.entity.vspeed = 0
        self.entity.grounded = false
        self.entity.ground = nil
    end
    self:syncFromEntity()
end

function PlayerPlatformState:updatePitRespawn()
    local _, camera_y, _, camera_height = self:getCameraRect()
    if self.fallen_in_pit == 0 then
        self:updateCheckpoint()
        if self.player.y > camera_y + camera_height + 120 + (self.player.height * 0.5) then
            self:beginPitRespawn()
        else
            return false
        end
    end

    if self.fallen_in_pit == 1 then
        self.pit_timer = self.pit_timer + DTMULT
        local progress = MathUtils.clamp(self.pit_timer / math.max(self.pit_lerp_time, 1), 0, 1)
        self.player.x = Utils.ease(self.pit_lerp_start_x, self.checkpoint_x, progress, "inOutCubic")
        Object.uncache(self.player)
        if progress >= 1 then
            self.fallen_in_pit = 2
        end
        if self.entity then
            self.entity.hspeed = 0
            self.entity.vspeed = 0
        end
        self:syncFromEntity()
        return true
    end

    if self.fallen_in_pit == 2 then
        self.player.x = self.checkpoint_x
        Object.uncache(self.player)
        self.pit_leap_time = 5 + math.floor(math.abs(self.checkpoint_y - self.player.y) / 30)
        self.pit_timer = 0
        Assets.playSound(Featherfall.sounds.pit_wing, 1, 0.3)
        if self.entity then
            local gravity = Featherfall.constants.gravity or 1.25
            self.entity.hspeed = 0
            self.entity.vspeed = (self.checkpoint_y - self.player.y - (0.5 * gravity * self.pit_leap_time * self.pit_leap_time)) / self.pit_leap_time
            self.entity.grounded = false
            self.entity.ground = nil
            self.entity.jumping = 1
        end
        self.fallen_in_pit = 3
        self:syncFromEntity()
        return true
    end

    if self.fallen_in_pit == 3 then
        self.pit_timer = self.pit_timer + DTMULT
        if self.entity then
            self.entity:updatePhysics()
        end
        self:syncFromEntity()
        if self.pit_timer >= self.pit_leap_time then
            self.fallen_in_pit = 4
        end
        return true
    end

    if self.fallen_in_pit == 4 then
        if self.entity then
            self.entity:updatePhysics()
        end
        self:syncFromEntity()
        if self.on_ground or self.player.y > self.checkpoint_y + 60 then
            self.fallen_in_pit = 0
        end
        return true
    end

    return self.fallen_in_pit ~= 0
end

function PlayerPlatformState:startAttack()
    self.attackbuffer = 0
    self.attack_hitbox = 0
    self.attack_frame = 0
    self.attack_canceleable = 1
    self.attacking = true
    self.attack_end_visible = false
    self.attack_press_buffer = 0
    self.attack_buffered = false

    if self.entity and not self.entity.grounded then
        self.attack_hitbox = 2
        self.attack_frame = 8
        self.attack_canceleable = 0
    end
end

function PlayerPlatformState:updateAttackInput()
    if Input.pressed("confirm") then
        self.attack_press_timer = 1
    end
    self.press_attack = self.attack_press_timer > 0
    self.key_attack = Input.down("confirm")
    self.attackbuffer = math.max(0, self.attackbuffer - DTMULT)
    if self.press_attack then
        self.attackbuffer = 4
    end

    if self.attackbuffer > 0 and not self.attacking and self.jumpsquat_timer <= 0 then
        self:startAttack()
    end
end

function PlayerPlatformState:getAttackAnimationName()
    if self.entity and self.entity.grounded then
        return "slash_ground"
    end
    return "slash_air"
end

function PlayerPlatformState:getAirAnimationName()
    if self.entity and self.entity.jumping and self.entity.jumping < 2 then
        return "jump_up"
    end
    return "jump_down"
end

function PlayerPlatformState:beginLandAnimation()
    self.land_anim = true
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = self:getAnimationDuration("land", 0.25)
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
end

function PlayerPlatformState:beginTurnAnimation()
    self.turn_anim = true
    self.turn_anim_timer = self:getAnimationDuration("turn")
end

function PlayerPlatformState:beginRunstopAnimation()
    self.runstop_anim = true
    self.turn_anim = false
    self.runstop_anim_timer = self:getAnimationDuration("halt", 0.25)
    self.turn_anim_timer = 0
end

function PlayerPlatformState:updateMovementAnimationFlags(key_left, key_right, move)
    if self.attacking or not self.on_ground then
        self.land_anim = false
        self.turn_anim = false
        self.runstop_anim = false
        self.land_anim_timer = 0
        self.turn_anim_timer = 0
        self.runstop_anim_timer = 0
        return
    end

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
        end
    end
    if self.runstop_anim then
        self.runstop_anim_timer = self.runstop_anim_timer - DTMULT
        if self.runstop_anim_timer <= 0 or key_left or key_right then
            self.runstop_anim = false
        end
    end

    if not self.land_anim then
        if key_left and not self.turn_anim and self.hspeed > 0.1 then
            self:beginTurnAnimation()
        elseif key_right and not self.turn_anim and self.hspeed < -0.1 then
            self:beginTurnAnimation()
        elseif move == 0 and not self.runstop_anim and not self.turn_anim and self.current_animation == "run" then
            self:beginRunstopAnimation()
        end
    end
end

function PlayerPlatformState:applyAttackAnimation()
    local attack_animation = self:getPlatformAnimation(self:getAttackAnimationName())
    if attack_animation then
        self:setPlayerAnimation(self:getAttackAnimationName())
        local frames = attack_animation.sprite and Assets.getFrames(attack_animation.sprite)
        local frame = self.attack_frame + 1
        if frames then
            frame = math.min(frame, #frames)
        end
        self.player.sprite:setFrame(frame)
    end
end

function PlayerPlatformState:spawnAttackHitbox()
    local animation_name = self:getAttackAnimationName()
    local animation = self:getPlatformAnimation(animation_name)
    if Game.world and animation then
        Game.world:spawnObject(PlatformAttackHitbox(self.player, self.facing, animation, self.attack_hitbox, self.attack_frame, animation_name))
    end
end

function PlayerPlatformState:updateAttack()
    if not self.attacking then
        return
    end

    local animation = self:getPlatformAnimation(self:getAttackAnimationName())
    local frames = animation and animation.sprite and Assets.getFrames(animation.sprite)
    local frame_count = frames and #frames or (self.entity and self.entity.grounded and 13 or 17)
    local image_index = self.attack_frame

    if self.attack_press_mode == 0 and self.attack_canceleable ~= 0 then
        if image_index >= 3.5 and image_index < 5 and not self.key_attack then
            self.attacking = false
            return
        end
        if image_index >= 7.5 and image_index < 9 and not self.key_attack then
            self.attacking = false
            return
        end
        if self.attack_hitbox >= 3 and self.press_attack then
            self.attack_buffered = true
        end
        if self.attack_buffered and image_index >= (frame_count - 1.2) then
            self.attack_frame = 0
            self.attack_hitbox = 0
            self.attack_buffered = false
        end
    elseif self.attack_press_mode == 1 and self.attack_canceleable ~= 0 then
        if self.attack_hitbox == 3 and self.attack_press_buffer == 2 then
            if image_index > 7 and image_index < frame_count and self.press_attack then
                self.attack_frame = 1
                self.attack_hitbox = 0
                self.attack_press_buffer = 0
            end
        elseif self.attack_hitbox == 2 and self.attack_press_buffer == 1 then
            if image_index > 3 and image_index <= 6 and self.press_attack then
                self.attack_press_buffer = self.attack_press_buffer + 1
            elseif image_index >= 6 then
                self.attacking = false
                return
            end
        elseif self.attack_hitbox == 1 and self.attack_press_buffer == 0 then
            if image_index > 1 and image_index <= 3 and self.press_attack then
                self.attack_press_buffer = self.attack_press_buffer + 1
            elseif image_index >= 3 then
                self.attacking = false
                return
            end
        end
    end

    self.attack_frame = self.attack_frame + (0.6 * DTMULT)
    local frame = math.floor(self.attack_frame)

    if frame >= 1 and self.attack_hitbox == 0 then
        Assets.playSound(Featherfall.sounds.attack_1)
        self:spawnAttackHitbox()
        self.attack_hitbox = self.attack_hitbox + 1
    end
    if frame >= 5 and self.attack_hitbox == 1 then
        Assets.playSound(Featherfall.sounds.attack_2, nil, 1.1)
        self:spawnAttackHitbox()
        self.attack_hitbox = self.attack_hitbox + 1
    end
    if frame >= 9 and self.attack_hitbox == 2 then
        Assets.playSound(Featherfall.sounds.attack_3, nil, 1.1)
        self:spawnAttackHitbox()
        self.attack_hitbox = self.attack_hitbox + 1
    end

    if frame >= frame_count then
        self.attacking = false
        self.attack_end_visible = true
    end
end

function PlayerPlatformState:getHoverEnabled()
    local source_props = Featherfall:getSourceProperties(self.source)
    local map_props = Featherfall:getMapProperties()
    local source_value = firstProperty(source_props, "hover_enabled", "platform_hover_enabled", "jumpbutton_hover")
    if source_value ~= nil then
        return propertyBool(source_value)
    end
    local map_value = firstProperty(map_props, "platform_hover_enabled", "jumpbutton_hover")
    if map_value ~= nil then
        return propertyBool(map_value)
    end
    return Featherfall:getConfig("hover_enabled", false) == true
end

function PlayerPlatformState:moveDuringHover(dx, dy)
    if not self.entity then
        return
    end
    if dx ~= 0 and not self.entity:findBlockAt(self.player.x + dx, self.player.y) then
        self.player.x = self.player.x + dx
    end
    if dy ~= 0 and not self.entity:findBlockAt(self.player.x, self.player.y + dy) then
        self.player.y = self.player.y + dy
    end
    Object.uncache(self.player)
end

function PlayerPlatformState:startJumpHover(key_left, key_right, key_up, key_down)
    local penalty = ((self.max_hovers - self.hovers_remaining) / self.max_hovers) * 10
    self.jumphover_meter = self.jumphover_meter - penalty
    if self.jumphover_meter <= 0 then
        self.jumphover_meter = 1
    end
    self.hovers_remaining = self.hovers_remaining - 1
    Assets.playSound(Featherfall.sounds.action_open)
    self.jumphovering = true
    self.jumphover_time = 0
    if self.entity then
        self.entity.jumpbuffer = 0
    end
    if not self.attacking then
        self:setPlayerAnimation("jump_up")
    end
    if key_left then
        self.heart_xoffset = -self.heart_offset_max
    end
    if key_right then
        self.heart_xoffset = self.heart_offset_max
    end
    if key_up then
        self.heart_yoffset = -self.heart_offset_max
    end
    if key_down then
        self.heart_yoffset = self.heart_offset_max
    end
end

function PlayerPlatformState:updateJumpHover(press_jump, key_jump, key_left, key_right, key_up, key_down)
    if self.jumphovering and ((not key_jump or self.on_ground or not self.jumpbutton_hover) and self.jumphover_time >= self.jumphover_min) then
        self.jumphovering = false
    end
    if self.on_ground then
        self.hovers_remaining = self.max_hovers
    end
    if press_jump and not self.on_ground and self.jumpbutton_hover and not self.jumphovering
        and self.jumphover_meter > 0 and self.coyote_timer <= 0 and self.hovers_remaining > 0
        and self.fallen_in_pit == 0
    then
        self:startJumpHover(key_left, key_right, key_up, key_down)
    end

    if self.jumphovering then
        self.jumphover_time = self.jumphover_time + DTMULT
        if self.entity then
            self.entity.hspeed = self.entity.hspeed * (0.5 ^ DTMULT)
            self.entity.vspeed = self.entity.vspeed * (0.5 ^ DTMULT)
        end
        local pull = false
        if not self.jumphover_shiftmode then
            local hinput = (key_right and 1 or 0) - (key_left and 1 or 0)
            local vinput = (key_down and 1 or 0) - (key_up and 1 or 0)
            if hinput ~= 0 or vinput ~= 0 then
                local length = math.sqrt((hinput * hinput) + (vinput * vinput))
                local move_x = (hinput / length) * self.hover_movespeed * DTMULT
                local move_y = (vinput / length) * self.hover_movespeed * DTMULT
                local old_x, old_y = self.player.x, self.player.y
                self:moveDuringHover(move_x, move_y)
                pull = self.player.x ~= old_x or self.player.y ~= old_y
            end
            if not Featherfall:isPlatformPaused() then
                self.jumphover_meter = self.jumphover_meter - DTMULT
                if pull then
                    self.jumphover_meter = self.jumphover_meter - DTMULT
                end
            end
        end
        if self.jumphover_meter <= 0 then
            self.jumphovering = false
        end
    end

    if self.jumphover_shiftmode then
        local pull = false
        if self.jumphovering and self.heart_mode == 1 then
            local hinput = (key_right and 1 or 0) - (key_left and 1 or 0)
            local vinput = (key_down and 1 or 0) - (key_up and 1 or 0)
            self.heart_xoffset = self.heart_xoffset + (hinput * self.hover_movespeed * DTMULT)
            self.heart_yoffset = self.heart_yoffset + (vinput * self.hover_movespeed * DTMULT)
            local max_offset = self.heart_offset_max
            local move_speed = 4 * DTMULT
            if self.heart_xoffset < -max_offset then
                self:moveDuringHover(-math.abs(move_speed), 0)
                pull = true
            end
            if self.heart_xoffset > max_offset then
                self:moveDuringHover(math.abs(move_speed), 0)
                pull = true
            end
            if self.heart_yoffset < -max_offset then
                self:moveDuringHover(0, -math.abs(move_speed))
                pull = true
            end
            if self.heart_yoffset > max_offset then
                self:moveDuringHover(0, math.abs(move_speed))
                pull = true
            end
            if not Featherfall:isPlatformPaused() then
                self.jumphover_meter = self.jumphover_meter - DTMULT
                if pull then
                    self.jumphover_meter = self.jumphover_meter - DTMULT
                end
            end
            self.heart_xoffset = MathUtils.clamp(self.heart_xoffset, -max_offset, max_offset)
            self.heart_yoffset = MathUtils.clamp(self.heart_yoffset, -max_offset, max_offset)
        else
            if self.jumphover_time >= self.jumphover_iframes_requirement then
                self.heart_retreating = true
            end
            self.heart_xoffset = self.heart_xoffset * (0.5 ^ DTMULT)
            self.heart_yoffset = self.heart_yoffset * (0.5 ^ DTMULT)
            if math.abs(MathUtils.round(self.heart_xoffset)) < 3 then
                self.heart_xoffset = 0
            end
            if math.abs(MathUtils.round(self.heart_yoffset)) < 3 then
                self.heart_yoffset = 0
            end
            if self.heart_xoffset == 0 and self.heart_yoffset == 0 then
                self.heart_retreating = false
            end
        end
    end

    self.jumphover_chargevfx = MathUtils.approach(self.jumphover_chargevfx, 0, DTMULT)
    if self.on_ground or self.fallen_in_pit ~= 0 then
        if self.jumphover_meter < self.jumphover_max then
            if self.jumphover_meter < (self.jumphover_max * 0.9) then
                self.jumphover_chargevfx = ((self.jumphover_max - self.jumphover_meter) / self.jumphover_max) * self.jumphover_chargevfx_max
                self.jumphover_chargevfx_white = self.jumphover_chargevfx_whitemax
            end
            self.jumphover_meter = self.jumphover_max
        end
    end

    self.heart_mode = self.jumphovering and 1 or 0
    self:syncFromEntity()
end

function PlayerPlatformState:drawHoverUI()
    if self.targetmode then
        return
    end

    local meter_radius = 50
    local meter_thickness = 3
    if self.jumphovering then
        drawCircularBar(0, 0, self.jumphover_meter, self.jumphover_max, {0, 0, 1}, meter_radius, 1, meter_thickness)
    elseif self.jumphover_chargevfx > 0 then
        local max_charge = self.jumphover_chargevfx_max
        local color = {
            self.jumphover_chargevfx / max_charge,
            (max_charge - self.jumphover_chargevfx) / max_charge,
            0,
        }
        drawCircularBar(0, 0, max_charge - self.jumphover_chargevfx, max_charge, color, meter_radius, 1, meter_thickness)
    elseif self.jumphover_chargevfx_white > 0 then
        drawCircularBar(0, 0, self.jumphover_chargevfx_max, self.jumphover_chargevfx_max, {1, 1, 1}, meter_radius, self.jumphover_chargevfx_white / self.jumphover_chargevfx_whitemax, meter_thickness)
        self.jumphover_chargevfx_white = MathUtils.approach(self.jumphover_chargevfx_white, 0, DTMULT)
    end

    if self.heart_mode ~= 1 and self.heart_xoffset == 0 and self.heart_yoffset == 0 then
        return
    end

    local heart = Assets.getTexture("player/heart_dodge")
    if heart then
        Draw.setColor(1, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, 6, self.heart_xoffset, self.heart_yoffset + 6)
        Draw.draw(heart, self.heart_xoffset - 10, self.heart_yoffset - 4)
        love.graphics.setLineWidth(1)
        Draw.setColor(1, 1, 1, 1)
    end
end

function PlayerPlatformState:onEnter(old_state, settings)
    settings = settings or {}

    local sprite_ox, sprite_oy = self.player.sprite:getOrigin()
    local player_ox, player_oy = self.player:getOrigin()
    self.restore_state = {
        width = self.player.width,
        height = self.player.height,
        origin_x = player_ox,
        origin_y = player_oy,
        origin_exact = self.player.origin_exact,
        collider = self.player.collider,
        sprite_origin_x = sprite_ox,
        sprite_origin_y = sprite_oy,
        sprite_origin_exact = self.player.sprite.origin_exact,
        sprite_flip_x = self.player.sprite.flip_x,
    }

    self.old_state = old_state
    self.source = settings.source
    self.timer = 0
    self.hspeed = settings.hspeed or 0
    self.vspeed = settings.vspeed or 0
    self.on_ground = false
    self.coyote_timer = 0
    self.jump_timer = 0
    self.jumpsquat_timer = 0
    self.time_since_ground = 0
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    self.exit_cooldown = 10
    self.current_animation = nil
    self.current_sprite_facing = nil
    self.attackbuffer = 0
    self.attacking = false
    self.attack_hitbox = 0
    self.attack_frame = 0
    self.attack_canceleable = 1
    self.attack_buffered = false
    self.attack_press_buffer = 0
    self.attack_press_mode = Featherfall:getAttackPressMode(self.source)
    self.attack_press_timer = 0
    self.key_attack = false
    self.press_attack = false
    self.attack_end_visible = false
    self.jumpbutton_hover = self:getHoverEnabled()
    self.max_hovers = 5
    self.hovers_remaining = self.max_hovers
    self.jumphovering = false
    self.jumphover_meter = 140
    self.jumphover_max = self.jumphover_meter
    self.jumphover_min = 5
    self.jumphover_time = 0
    self.jumphover_chargevfx = 0
    self.jumphover_chargevfx_max = 15
    self.jumphover_chargevfx_white = 0
    self.jumphover_chargevfx_whitemax = 20
    self.hover_movespeed = 6
    self.jumphover_shiftmode = true
    self.heart_xoffset = 0
    self.heart_yoffset = 0
    self.heart_offset_max = 25
    self.hover_keeps_momentum = false
    self.jumphover_iframes_requirement = 10
    self.heart_mode = 0
    self.heart_retreating = false
    self.key_left = false
    self.key_right = false
    self.facing = self.player:getFacing() == "left" and "left" or "right"

    local actor = self:getPlatformActor()
    local width, height = 20, 38
    if actor and actor.getPlatformSize then
        width, height = actor:getPlatformSize()
    end

    self.player:setSize(width, height)
    self.player:setOrigin(0.5, 1)

    if Featherfall and Featherfall.getPlatformEnterPosition then
        local enter_x, enter_y = Featherfall:getPlatformEnterPosition(self.source, self.player)
        if enter_x then
            self.player.x = enter_x
        end
        if enter_y then
            self.player.y = enter_y
        end
        Object.uncache(self.player)
    end

    local hitbox = {0, 0, width, height}
    if actor and actor.getPlatformHitbox then
        hitbox = {actor:getPlatformHitbox()}
        self.player.collider = Hitbox(self.player, unpack(hitbox))
    else
        self.player.collider = Hitbox(self.player, unpack(hitbox))
    end

    self.entity = self.entity or PlatformEntity(self.player, Featherfall.constants)
    self.entity:reset({
        hspeed = self.hspeed,
        vspeed = self.vspeed,
        grounded = self.on_ground,
    })
    self.entity:setHitbox(unpack(hitbox))
    if self.vspeed == 0 then
        local ground = self.entity:findGroundAt(self.player.x, self.player.y, 706)
        if ground then
            self.entity:landOn(ground)
            self.entity.grounded_prev = true
            self.on_ground = true
        end
    end
    self:syncFromEntity()

    self.checkpoint_x = self.player.x
    self.checkpoint_y = self.player.y - 60
    self.respawn_leap_enabled = true
    self.respawn_leap_style = 0
    self.fallen_in_pit = 0
    self.pit_timer = 0
    self.pit_lerp_time = 0
    self.pit_lerp_start_x = self.player.x
    self.pit_leap_time = 0
    self.act_button_held = false
    self.act_buffer = false
    self.targetmode = false
    self.act_targets = {}
    self.targetindex = -1
    self.hlit_target = -1
    self.hlit_name = ""
    self.hlit_desc = ""
    self.hlit_blocked = false
    self.hlit_label = "No ACT"
    self.hlit_label_color = {0.5, 0.5, 0.5}
    self.targetmode_highlighted = false
    self.actions:reset()

    self:setPlayerAnimation("idle")

    Game.world:detachFollowers()
    self.player:cancelFollowerTweens()
    Featherfall:putFollowersInState(self.source)
end

function PlayerPlatformState:onUpdate()
    self.timer = self.timer + DTMULT
    self.exit_cooldown = MathUtils.approach(self.exit_cooldown, 0, DTMULT)
    self:updateTargetModeOutline()
    if not (Featherfall.transition_prop and Featherfall.transition_prop.parent) then
        self.player.sprite.visible = true
    end

    if self:updatePitRespawn() then
        if self.vspeed < 0 then
            self:setPlayerAnimation("jump_up")
        else
            self:setPlayerAnimation("jump_down")
        end
        return
    end

    if self:updateWorldMenuPause() then
        return
    end

    if self:updateTargetMode() then
        self.attack_press_timer = MathUtils.approach(self.attack_press_timer, 0, DTMULT)
        return
    end
    self.actions:updateCooldown()
    if self.actions:updateActive(self.player) then
        self.attack_press_timer = MathUtils.approach(self.attack_press_timer, 0, DTMULT)
        return
    end

    local key_left = false
    local key_right = false
    local key_up = false
    local key_down = false
    local press_jump = false
    local key_jump = false
    local press_left = false
    local press_right = false

    if self.player:isPlatMovementEnabled() then
        key_left = Input.down("left")
        key_right = Input.down("right")
        key_up = Input.down("up")
        key_down = Input.down("down")
        press_jump = Input.pressed("cancel")
        key_jump = Input.down("cancel")
        press_left = Input.pressed("left")
        press_right = Input.pressed("right")
    end

    if key_left and key_right then
        if self.key_left and key_left then
            key_right = false
        end
        if self.key_right and key_right then
            key_left = false
        end
    end

    local move = 0
    if key_left then
        move = move - 1
    end
    if key_right then
        move = move + 1
    end

    if move ~= 0 then
        self.facing = move < 0 and "left" or "right"
        self.player:setFacing(self.facing)
        self.player.sprite.flip_x = self:getPlatformFlipX()
    end

    self:updateAttackInput()

    local grounded_attack = self.attacking and self.entity and self.entity.grounded
    if self.on_ground and not grounded_attack then
        if key_left and press_left then
            self:spawnDust(1)
        end
        if key_right and press_right then
            self:spawnDust(-1)
        end
    end
    if Input.down("cancel") and grounded_attack then
        if self.entity then
            self.entity.jumpbuffer = 4
        end
        local attack_image = math.floor(self.attack_frame or 0)
        if attack_image >= 5 and self.attack_hitbox == 1 then
            self.attacking = false
        elseif attack_image >= 9 and self.attack_hitbox == 2 then
            self.attacking = false
        end
    end
    self.entity:updatePlayer({
        move = move,
        key_left = key_left,
        key_right = key_right,
        dont_accel = grounded_attack,
        force_decel = grounded_attack,
        block_jump = self.attacking or self.jumphovering,
        press_jump = press_jump,
        key_jump = key_jump,
    })
    if self.entity.jump_ceiling_blocked then
        Assets.playSound(Featherfall.sounds.landing)
        self:spawnDust(-1, Featherfall.assets.effects.landingdust_new)
        self:spawnDust(1, Featherfall.assets.effects.landingdust_new)
    end
    self:playEntityFeedbackSounds()
    self:syncFromEntity()
    self:updateMovementAnimationFlags(key_left, key_right, move)
    if self.attacking then
        self:applyAttackAnimation()
    end
    self:updateAttack()
    self:updateJumpHover(press_jump, key_jump, key_left, key_right, key_up, key_down)

    if self.attacking or self.attack_end_visible then
        self:applyAttackAnimation()
    elseif not self.on_ground then
        self:setPlayerAnimation(self:getAirAnimationName())
    elseif self.land_anim then
        self:setPlayerAnimation("land")
    elseif self.jumpsquat_timer > 0 then
        self:setPlayerAnimation("land")
    elseif self.turn_anim then
        self:setPlayerAnimation("turn")
    elseif self.runstop_anim then
        self:setPlayerAnimation("halt")
    elseif math.abs(self.hspeed) > 0.1 then
        self:setPlayerAnimation("run")
    elseif key_down and self:getPlatformAnimation("crouch") then
        self:setPlayerAnimation("crouch")
    else
        self:setPlayerAnimation("idle")
    end

    self.attack_press_timer = MathUtils.approach(self.attack_press_timer, 0, DTMULT)
    self.attack_end_visible = false
    self.key_left = key_left
    self.key_right = key_right
end

function PlayerPlatformState:onExit(next_state)
    if self.targetmode then
        self:endTargetMode(false)
    else
        self:clearTargetModeTargets()
    end
    self.menu_pause_active = false
    self:setTargetModeSpritePaused(false)
    self.player:removeFX("platform_targetmode_outline")
    self.targetmode_highlighted = false
    self.actions:reset()

    self.player:resetSprite()
    self.current_animation = nil
    self.current_sprite_facing = nil
    self.land_anim = false
    self.turn_anim = false
    self.runstop_anim = false
    self.land_anim_timer = 0
    self.turn_anim_timer = 0
    self.runstop_anim_timer = 0
    self.entity = nil

    local restore = self.restore_state or {}
    if restore.width and restore.height then
        self.player:setSize(restore.width, restore.height)
    end
    if restore.origin_x and restore.origin_y then
        if restore.origin_exact then
            self.player:setOriginExact(restore.origin_x, restore.origin_y)
        else
            self.player:setOrigin(restore.origin_x, restore.origin_y)
        end
    end
    if restore.collider then
        self.player.collider = restore.collider
    end
    if restore.sprite_origin_x and restore.sprite_origin_y then
        if restore.sprite_origin_exact then
            self.player.sprite:setOriginExact(restore.sprite_origin_x, restore.sprite_origin_y)
        else
            self.player.sprite:setOrigin(restore.sprite_origin_x, restore.sprite_origin_y)
        end
    end
    self.player.sprite.flip_x = restore.sprite_flip_x
    self.restore_state = nil

    if Game.world then
        Game.world:setCameraAttached(true, true)
    end

    self.player:cancelFollowerTweens()
    Featherfall:restoreFollowersFromState()
    Featherfall:resetFollowerHistoryForOverworld("WALK")
    Game.world:attachFollowersImmediate()
end

function PlayerPlatformState:drawDebug()
    self:drawPlatformDebug(0.2, 0.75, 1)
end

return PlayerPlatformState
