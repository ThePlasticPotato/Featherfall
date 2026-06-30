---@class PlatformActionUI : Object
local PlatformActionUI, super = Class(Object)

local TARGET_SPRITES = {
    arrow = "ui/platform/action/arrow",
    reticle = "ui/platform/action/reticle",
    circle = "ui/platform/action/circle",
    cross = "ui/platform/action/cross",
    soul = "player/heart_dodge",
}

local TARGET_SPRITE_METADATA = {
    [TARGET_SPRITES.arrow] = {origin_x = 9, origin_y = 9},
    [TARGET_SPRITES.reticle] = {origin_x = 65, origin_y = 65},
    [TARGET_SPRITES.circle] = {origin_x = 3, origin_y = 3},
    [TARGET_SPRITES.cross] = {origin_x = 10, origin_y = 10},
}

local function sampleGradient(gradient, ratio, alpha)
    if not gradient or #gradient == 0 then
        return 1, 1, 1, alpha or 1
    end
    if #gradient == 1 then
        local color = gradient[1]
        return color[1], color[2], color[3], alpha or (color[4] or 1)
    end

    ratio = ratio % 1
    local scaled = ratio * #gradient
    local index = math.floor(scaled) + 1
    local next_index = (index % #gradient) + 1
    local lerp = scaled - math.floor(scaled)
    local a = gradient[index]
    local b = gradient[next_index]
    return MathUtils.lerp(a[1], b[1], lerp),
        MathUtils.lerp(a[2], b[2], lerp),
        MathUtils.lerp(a[3], b[3], lerp),
        alpha or MathUtils.lerp(a[4] or 1, b[4] or 1, lerp)
end

local function getPlayerState()
    local player = Game.world and Game.world.player
    return player and player.platform_state
end

function PlatformActionUI:init()
    super.init(self, 0, 0)
    self.layer = WORLD_LAYERS["ui"]
    self.parallax_x = 1
    self.parallax_y = 1
    self:setOrigin(0, 0)
    self.visible = true
    self.soul_x = nil
    self.soul_y = nil
    self.soul_target_key = nil
    self.soul_afterimages = {}
end

function PlatformActionUI:getTargets()
    if Featherfall and Featherfall.getActionTargets then
        return Featherfall:getActionTargets()
    end
    return {}
end

function PlatformActionUI:getColor(target)
    local color = Featherfall and Featherfall.getActionColorTable and Featherfall:getActionColorTable(target.action_kind, target)
    color = color or {1, 1, 0}
    return color[1], color[2], color[3]
end

function PlatformActionUI:getGradient(target)
    if Featherfall and Featherfall.getActionGradient then
        return Featherfall:getActionGradient(target.action_kind, target)
    end
end

function PlatformActionUI:getCenter(target)
    local x = target.cx or target.target_x or (target.x + ((target.width or 0) / 2))
    local y = target.cy or target.target_y or (target.y + ((target.height or 0) / 2))
    return x, y
end

function PlatformActionUI:getActionStateForTarget(target)
    local state = getPlayerState()
    if state and state.getActorForTarget and target and target.action_kind ~= "soul" then
        return state:getActorForTarget(target)
    end
end

function PlatformActionUI:getActionState(kind)
    local state = getPlayerState()
    if state and state.getActionState then
        return state:getActionState(kind)
    end
end

function PlatformActionUI:getAnchor(target)
    local state = getPlayerState()
    local character, ff_state = self:getActionStateForTarget(target)
    if character and ff_state then
        return self:getPlatformSpriteOrigin(character, ff_state)
    elseif character then
        return character.x, character.y
    end
    if state then
        return self:getPlatformSpriteOrigin(state.player, state)
    end
    return 0, 0
end

function PlatformActionUI:drawArrowTrain(ax, ay, x, y, r, g, b, alpha_scale, gradient)
    local dist = MathUtils.dist(ax, ay, x, y)
    local dir = Utils.angle(ax, ay, x, y)
    local phase = (Kristal.getTime() * 10) % 20
    local gradient_phase = (Kristal.getTime() * 0.25) % 1
    alpha_scale = alpha_scale or 1
    for i = 20, dist - 20, 20 do
        local step = i + phase
        local alpha = 1
        if step < 40 then
            alpha = (step - 20) / 20
        elseif step > dist - 40 then
            alpha = (dist - 20 - step) / 20
        end
        local alpha2 = MathUtils.clamp(alpha - (phase / 20), 0, 1) / 3
        local step2 = step + (phase * 0.75)
        local rr, gg, bb = r, g, b
        if gradient then
            rr, gg, bb = sampleGradient(gradient, gradient_phase + (step / math.max(dist, 1)))
        end
        self:drawSprite(TARGET_SPRITES.arrow, 1, ax + math.cos(dir) * step2, ay + math.sin(dir) * step2, 1, 1, dir, rr, gg, bb, alpha2 * alpha_scale)
        self:drawSprite(TARGET_SPRITES.arrow, 1, ax + math.cos(dir) * step, ay + math.sin(dir) * step, 1, 1, dir, rr, gg, bb, MathUtils.clamp(alpha, 0, 1) * alpha_scale)
    end
end

function PlatformActionUI:drawGradientSprite(path, frame, x, y, sx, sy, angle, gradient, alpha)
    local phase = (Kristal.getTime() * 0.2) % 1
    local r, g, b = sampleGradient(gradient, phase, alpha)
    self:drawSprite(path, frame, x, y, sx, sy, angle or 0, r, g, b, alpha or 1)
end

function PlatformActionUI:drawSprite(path, frame, x, y, sx, sy, angle, r, g, b, alpha)
    local frames = Assets.getFrames(path)
    local texture = frames and frames[math.max(1, math.min(#frames, frame or 1))] or Assets.getTexture(path)
    if not texture then
        return
    end

    local metadata = TARGET_SPRITE_METADATA[path]
    local origin_x = metadata and metadata.origin_x or (texture:getWidth() / 2)
    local origin_y = metadata and metadata.origin_y or (texture:getHeight() / 2)
    Draw.setColor(r or 1, g or 1, b or 1, alpha or 1)
    Draw.draw(texture, x, y, angle or 0, sx or 1, sy or sx or 1, origin_x, origin_y)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformActionUI:drawHeartSprite(x, y, alpha)
    local texture = Assets.getTexture(TARGET_SPRITES.soul)
    if not texture then
        return
    end

    local r, g, b = Game:getSoulColor()
    Draw.setColor(r, g, b, alpha or 1)
    Draw.draw(texture, x, y)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformActionUI:getPlatformSpriteOrigin(character, state)
    if state and state.getPlatformActionAnchor then
        local x, y = state:getPlatformActionAnchor()
        if x and y then
            return x, y
        end
    end

    local animation_name = state.current_animation or "idle"
    local animation = state.getPlatformAnimation and state:getPlatformAnimation(animation_name)
    local metadata = animation and animation.sprite and state.getPlatformSpriteMetadata and state:getPlatformSpriteMetadata(animation.sprite)

    if metadata and character.sprite and character.sprite.getRelativePos then
        return character.sprite:getRelativePos(metadata.origin_x, metadata.origin_y, Game.world)
    end

    return character.x, character.y
end

function PlatformActionUI:drawTarget(target)
    local state = getPlayerState()
    local targetmode = state and state.targetmode
    if not (target.active and target.blocked ~= true and target.blocked ~= 1) then
        return
    end
    if not (targetmode or (target.selected_timer and target.selected_timer > 0) or target.hovered) then
        return
    end

    local x, y = self:getCenter(target)
    local r, g, b = self:getColor(target)
    local gradient = self:getGradient(target)
    local selected = target.selected_timer and target.selected_timer > 0
    local hover = selected or target.hovered
    local hover_lerp = target.hoverlerp or (hover and 1 or 0)
    target.angle = target.angle or 0

    if targetmode and hover then
        local ax, ay = self:getAnchor(target)
        self:drawArrowTrain(ax, ay, x, y, r, g, b, nil, gradient)
    end

    if targetmode then
        target.angle = target.angle + ((6 - (hover_lerp * 6)) * DTMULT)
    end
    local character_active = target._character_active ~= false
    local snap_angle = (((math.floor(target.angle / 90) % 4) * 90) + 45) - (character_active and 45 or 0)
    local angle = MathUtils.lerp(target.angle, snap_angle, hover_lerp)

    if target.blocked or target._character_active == false then
        self:drawSprite(TARGET_SPRITES.cross, 1, x, y, 2, 2, 0, r, g, b, 1)
    elseif targetmode and target.is_valid_target then
        local frame = math.floor((hover_lerp * 7) + 1)
        if gradient then
            self:drawGradientSprite(TARGET_SPRITES.reticle, frame, x, y, 1, 1, math.rad(-angle), gradient, 1)
            self:drawGradientSprite(TARGET_SPRITES.circle, 1, x, y, 2, 2, 0, gradient, 1)
        else
            self:drawSprite(TARGET_SPRITES.reticle, frame, x, y, 1, 1, math.rad(-angle), r, g, b, 1)
            self:drawSprite(TARGET_SPRITES.circle, 1, x, y, 2, 2, 0, r, g, b, 1)
        end
    end

    if selected and not targetmode then
        local frame = math.floor((1 - (target.selected_timer / 8)) * 7) + 1
        if gradient then
            self:drawGradientSprite(TARGET_SPRITES.reticle, frame, x, y, 1, 1, math.rad(-angle), gradient, 1)
        else
            self:drawSprite(TARGET_SPRITES.reticle, frame, x, y, 1, 1, math.rad(-angle), r, g, b, 1)
        end
    end
end

function PlatformActionUI:drawFollowerFreeWillArrows()
    local state = getPlayerState()
    if state and state.targetmode then
        return
    end

    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        local ff_state = follower.platform_state
        local actions = ff_state and ff_state.actions
        local target = actions and actions.free_will_target
        if target and target.parent then
            local kind = ff_state:getFollowerKind()
            local r, g, b = self:getColor({action_kind = kind})
            r = MathUtils.lerp(r, 0.5, 0.5)
            g = MathUtils.lerp(g, 0.5, 0.5)
            b = MathUtils.lerp(b, 0.5, 0.5)
            local alpha = MathUtils.clamp(actions.free_will_target_lerp or 0, 0, 1)
            self:drawArrowTrain(follower.x, follower.y, actions.free_will_target_x, actions.free_will_target_y, r, g, b, alpha)
        end
    end
end

function PlatformActionUI:getSoulDrawPosition(state)
    local target = state.act_targets and state.act_targets[state.targetindex]
    if target then
        local x, y = self:getCenter(target)
        return x - 9, y - 8, target
    end

    local ox, oy = self:getPlatformSpriteOrigin(state.player, state)
    return ox - 10, oy - 10 + 6, "self"
end

function PlatformActionUI:addSoulAfterimages(from_x, from_y, to_x, to_y)
    local dist = MathUtils.dist(from_x, from_y, to_x, to_y)
    if dist <= 0 then
        return
    end

    local dir = Utils.angle(from_x, from_y, to_x, to_y)
    local step = 0.5 * dist
    while step < dist do
        local ratio = step / dist
        table.insert(self.soul_afterimages, {
            x = from_x + (math.cos(dir) * step),
            y = from_y + (math.sin(dir) * step),
            alpha = MathUtils.lerp(0.8, 0, 1 - (ratio * 0.5)),
        })
        step = step + 24
    end
end

function PlatformActionUI:updateSoulAfterimages()
    for index = #self.soul_afterimages, 1, -1 do
        local afterimage = self.soul_afterimages[index]
        afterimage.alpha = afterimage.alpha - (0.1 * DTMULT)
        if afterimage.alpha <= 0 then
            table.remove(self.soul_afterimages, index)
        end
    end
end

function PlatformActionUI:drawSoulAfterimages()
    for _, afterimage in ipairs(self.soul_afterimages) do
        self:drawHeartSprite(afterimage.x, afterimage.y, afterimage.alpha)
    end
end

function PlatformActionUI:drawSoul(state)
    self:updateSoulAfterimages()

    local target_x, target_y, target_key = self:getSoulDrawPosition(state)
    if self.soul_x == nil or self.soul_y == nil then
        self.soul_x = target_x
        self.soul_y = target_y
        self.soul_target_key = target_key
    elseif target_key ~= self.soul_target_key then
        self:addSoulAfterimages(self.soul_x, self.soul_y, target_x, target_y)
        self.soul_target_key = target_key
    end

    self.soul_x = target_x
    self.soul_y = target_y

    self:drawSoulAfterimages()
    self:drawHeartSprite(self.soul_x, self.soul_y, 1)
end

function PlatformActionUI:getActionCooldownMeter(character, ff_state)
    local actions = ff_state.actions
    if not (actions and actions.cooldown_timer and actions.cooldown_timer > 0) then
        return
    end

    local max_timer = math.max(actions.cooldown_max or actions.cooldown_timer, 1)
    local kind = ff_state.getActionKind and ff_state:getActionKind() or (ff_state.getFollowerKind and ff_state:getFollowerKind())
    return {
        text = actions.cooldown_text or "RECHARGE",
        value = actions.cooldown_timer,
        max_value = max_timer,
        color = {self:getColor({action_kind = kind})},
    }
end

function PlatformActionUI:getMeters(character, ff_state)
    local meters = {}
    local cooldown_meter = self:getActionCooldownMeter(character, ff_state)
    if cooldown_meter then
        table.insert(meters, cooldown_meter)
    end
    if ff_state.getPlatformMeters then
        for _, meter in ipairs(ff_state:getPlatformMeters() or {}) do
            table.insert(meters, meter)
        end
    end
    return meters
end

function PlatformActionUI:drawMeters(character, ff_state)
    if not PlatformMeter then
        return
    end

    for index, meter_data in ipairs(self:getMeters(character, ff_state)) do
        meter_data.stack_index = index - 1
        PlatformMeter(character, meter_data):draw()
    end
end

function PlatformActionUI:drawFollowerCooldowns()
    local player = Game.world and Game.world.player
    local player_state = player and player.platform_state
    if player_state and player.isPlatforming and player:isPlatforming() then
        self:drawMeters(player, player_state)
    end
    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        local ff_state = follower.platform_state
        if ff_state and follower.isPlatforming and follower:isPlatforming() then
            self:drawMeters(follower, ff_state)
        end
    end
end

function PlatformActionUI:drawTargetModeOverlay()
    local camera = Game.world and Game.world.camera
    if not camera then
        return
    end

    local x, y, width, height = camera:getRect(false)
    Draw.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x, y, width, height)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformActionUI:drawPlatformPartyMember(character)
    if not (character and character.visible and character.parent) then
        return
    end

    love.graphics.push()
    character:fullDraw(false)
    love.graphics.pop()
end

function PlatformActionUI:drawPlatformPartyOverOverlay()
    local members = {}
    local player = Game.world and Game.world.player
    if player and player.isPlatforming and player:isPlatforming() then
        table.insert(members, player)
    end
    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        if follower.isPlatforming and follower:isPlatforming() then
            table.insert(members, follower)
        end
    end

    table.sort(members, function(a, b)
        if a.layer == b.layer then
            return a.y < b.y
        end
        return a.layer < b.layer
    end)

    for _, member in ipairs(members) do
        self:drawPlatformPartyMember(member)
    end
    Draw.setColor(1, 1, 1, 1)
end

function PlatformActionUI:drawTargetModeText(state)
    local camera = Game.world and Game.world.camera
    if not camera then
        return
    end

    local camera_x, camera_y, camera_width = camera:getRect(false)
    local strip_y = camera_y + 380
    local font = Assets.getFont("main")
    local old_font = love.graphics.getFont()
    if font then
        love.graphics.setFont(font)
    end

    Draw.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", camera_x, strip_y, camera_width, 100)

    if state.hlit_target ~= nil and state.hlit_target >= -1 then
        local label = state.hlit_label or "No ACT"
        local color = state.hlit_label_color or {0.5, 0.5, 0.5}
        Draw.setColor(color[1], color[2], color[3], 1)
        love.graphics.print(label, camera_x + 20, strip_y + 10)

        Draw.setColor(1, 1, 1, 1)
        if state.targetindex and state.targetindex >= 1 then
            love.graphics.print("-->  " .. (state.hlit_name or ""), camera_x + 20 + (16 * (#label + 1)), strip_y + 10)
        end

        local desc
        if (not state.targetindex or state.targetindex < 1) and state.getNoTargetDescription then
            desc = state:getNoTargetDescription()
        elseif #(state.act_targets or {}) == 0 then
            desc = "* No ACTs are available."
        elseif not state.targetindex or state.targetindex < 1 then
            desc = "* Press a direction to select an ACT."
        else
            desc = "* " .. (state.hlit_blocked and "The enemy is guarding against ACTS!" or (state.hlit_desc or ""))
        end
        love.graphics.print(desc, camera_x + 20, strip_y + 40)
    end

    if old_font then
        love.graphics.setFont(old_font)
    end
    Draw.setColor(1, 1, 1, 1)
end

function PlatformActionUI:draw()
    if not (Featherfall and Featherfall.isPlatformModeActive and Featherfall:isPlatformModeActive()) then
        return
    end

    local state = getPlayerState()
    if state and state.targetmode then
        self:drawTargetModeOverlay()
        self:drawPlatformPartyOverOverlay()
    end

    for _, target in ipairs(self:getTargets()) do
        if target.parent then
            self:drawTarget(target)
        end
    end

    self:drawFollowerFreeWillArrows()
    self:drawFollowerCooldowns()

    if state and state.targetmode then
        self:drawSoul(state)
        self:drawTargetModeText(state)
    else
        self.soul_x = nil
        self.soul_y = nil
        self.soul_target_key = nil
        self.soul_afterimages = {}
    end
end

return PlatformActionUI
