---@class PlatformToriiGate : Event
local PlatformToriiGate, super = Class(Event)

local FRONT_SPRITE = "world/platform/torii/perspective"
local BACK_SPRITE = "world/platform/torii/back"
local SPRITE_ORIGIN_X = 26
local SPRITE_ORIGIN_Y = 190
local SPRITE_DRAW_ORIGIN_Y = 190
local TRIGGER_MASKS = {
    ["world/platform/torii/perspective"] = {left = 36, right = 37, top = 117, bottom = 185},
    ["world/platform/torii/perspective_small"] = {left = 18, right = 37, top = 117, bottom = 185},
    ["world/platform/torii/perspective_dark"] = {left = 36, right = 37, top = 117, bottom = 185},
}
local FRONT_FRAME_BOTTOMS = {
    ["world/platform/torii/perspective"] = {189, 186, 185, 179},
    ["world/platform/torii/perspective_dark"] = {189, 186, 185, 179},
    ["world/platform/torii/perspective_small"] = {169},
}
local BACK_FRAME_BOTTOMS = {
    ["world/platform/torii/back"] = {190, 190, 190, 174},
    ["world/platform/torii/back_dark"] = {190, 190, 190, 174},
    ["world/platform/torii/back_small"] = {190},
}
local BACK_DRAW_Y_TRIM = -10

local function getSpriteTexture(sprite, frame)
    local frames = Assets.getFrames(sprite)
    return frames and frames[math.max(1, math.min(#frames, frame or 1))] or Assets.getTexture(sprite)
end

local function drawGateSprite(owner, sprite, frame, alpha, r, g, b, force_white)
    local texture = getSpriteTexture(sprite, frame)
    if not texture then
        return
    end

    local ox, oy = owner:getGateOrigin()
    if owner.getSpriteDrawYOffset then
        oy = oy + owner:getSpriteDrawYOffset(sprite, frame)
    end
    local last_shader
    local shader = force_white and Kristal.Shaders["AddColor"] or nil
    if shader then
        last_shader = love.graphics.getShader()
        love.graphics.setShader(shader)
        shader:send("inputcolor", {1, 1, 1})
        shader:send("amount", 1)
    end
    Draw.setColor(r or 1, g or 1, b or 1, alpha or owner.alpha or 1)
    Draw.draw(texture, ox - owner.x, oy - owner.y, 0, owner.image_xscale, owner.image_yscale, SPRITE_ORIGIN_X, SPRITE_DRAW_ORIGIN_Y)
    if shader then
        love.graphics.setShader(last_shader)
    end
    Draw.setColor(1, 1, 1, 1)
end

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

local ToriiBack, backSuper = Class(Object)

function ToriiBack:init(owner)
    backSuper.init(self, owner.x, owner.y)
    self.owner = owner
    self:setSize(owner.width or 53, owner.height or 190)
end

function ToriiBack:update()
    backSuper.update(self)
    local owner = self.owner
    if not (owner and owner.parent and owner.visible) then
        self:remove()
        return
    end
    self.x = owner.x
    self.y = owner.y
    local layer = owner:getBackLayer()
    if self.layer ~= layer then
        self.layer = layer
        if self.parent then
            self.parent.update_child_list = true
        end
    end
end

function ToriiBack:draw()
    local owner = self.owner
    if not (owner and owner.parent) then
        return
    end
    local frame = owner:getFrame()
    drawGateSprite(owner, owner.back_sprite, frame)
    owner:drawBackPerspectiveLine(frame)
    if owner.deathcon == 1 then
        drawGateSprite(owner, owner.back_sprite, frame, MathUtils.clamp(owner.timer / 15, 0, 1), 1, 1, 1, true)
    end
end

local ToriiAfterimage, afterimageSuper = Class(Object)

function ToriiAfterimage:init(owner, sprite, frame, layer)
    afterimageSuper.init(self, owner.x, owner.y)
    self.sprite = sprite
    self.frame = frame or 1
    self.image_xscale = owner.image_xscale
    self.image_yscale = owner.image_yscale
    local ox, oy = owner:getGateOrigin()
    self.draw_x = ox - owner.x
    self.draw_y = oy - owner.y
    if owner.getSpriteDrawYOffset then
        self.draw_y = self.draw_y + owner:getSpriteDrawYOffset(sprite, frame)
    end
    self.alpha = 1
    self.layer = layer or owner.layer
end

function ToriiAfterimage:update()
    afterimageSuper.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.alpha = self.alpha - (0.05 * DTMULT)
    if self.alpha <= 0 then
        self:remove()
    end
end

function ToriiAfterimage:draw()
    local texture = getSpriteTexture(self.sprite, self.frame)
    if not texture then
        return
    end
    local shader = Kristal.Shaders["AddColor"]
    local last_shader = love.graphics.getShader()
    if shader then
        love.graphics.setShader(shader)
        shader:send("inputcolor", {1, 1, 1})
        shader:send("amount", 1)
    end
    Draw.setColor(1, 1, 1, self.alpha)
    Draw.draw(texture, self.draw_x, self.draw_y, 0, self.image_xscale, self.image_yscale, SPRITE_ORIGIN_X, SPRITE_DRAW_ORIGIN_Y)
    if shader then
        love.graphics.setShader(last_shader)
    end
    Draw.setColor(1, 1, 1, 1)
end

function PlatformToriiGate:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.platform_torii_gate = true
    self.platform_dash_gate = true
    self.platform_collision = false
    self.solid = false
    self.usable = propertyBool(self.properties["usable"], true)
    self.single_use = propertyBool(self.properties["single_use"], false)
    self.viable_directions = tonumber(self.properties["viable_directions"] or self.properties["direction"]) or 0
    self.dash_speed_multiplier = tonumber(self.properties["dash_speed_multiplier"] or self.properties["speed_multiplier"]) or 1
    self.static_dash = propertyBool(self.properties["static_dash"], false)
    self.spawn_dashlines = propertyBool(self.properties["spawn_dashlines"], true)
    self.just_initiated = false
    self.just_initiated_timer = 0
    self.deathcon = 0
    self.timer = 0
    self.death_last_timer = 0
    self.image_index = 1
    self.image_xscale = tonumber(self.properties["image_xscale"] or self.properties["xscale"]) or 2
    self.image_yscale = tonumber(self.properties["image_yscale"] or self.properties["yscale"]) or 2
    self.front_sprite = self.properties["front_sprite"] or FRONT_SPRITE
    self.back_sprite = self.properties["back_sprite"] or BACK_SPRITE
    self.back_object = nil
    self.torii_base_layer = tonumber(self.properties["base_layer"])
    self.front_layer_offset = tonumber(self.properties["front_layer_offset"]) or 0.04
    self.back_layer_offset = tonumber(self.properties["back_layer_offset"]) or -0.02
    self:updateTriggerCollider()
end

function PlatformToriiGate:getGateOrigin()
    return self.x + ((self.width or 53) / 2), self.y + (self.height or 190)
end

function PlatformToriiGate:getLocalGateOrigin()
    return (self.width or 53) / 2, self.height or 190
end

function PlatformToriiGate:getTriggerMask()
    return TRIGGER_MASKS[self.front_sprite] or {
        left = tonumber(self.properties["trigger_left"]) or 36,
        right = tonumber(self.properties["trigger_right"]) or 37,
        top = tonumber(self.properties["trigger_top"]) or 117,
        bottom = tonumber(self.properties["trigger_bottom"]) or 185,
    }
end

function PlatformToriiGate:getTriggerRect()
    local mask = self:getTriggerMask()
    local ox, oy = self:getLocalGateOrigin()
    local sx = tonumber(self.properties["trigger_xscale"]) or (self.image_xscale or 2)
    local sy = tonumber(self.properties["trigger_yscale"]) or (self.image_yscale or 2)

    local left = (mask.left - SPRITE_ORIGIN_X) * sx
    local right = ((mask.right + 1) - SPRITE_ORIGIN_X) * sx
    local top = (mask.top - SPRITE_ORIGIN_Y) * sy
    local bottom = ((mask.bottom + 1) - SPRITE_ORIGIN_Y) * sy

    local x = ox + math.min(left, right)
    local y = oy + math.min(top, bottom)
    return x, y, math.max(1, math.abs(right - left)), math.max(1, math.abs(bottom - top))
end

function PlatformToriiGate:getSpriteDrawYOffset(sprite, frame)
    local back_bottoms = BACK_FRAME_BOTTOMS[sprite]
    local bottoms = FRONT_FRAME_BOTTOMS[sprite] or back_bottoms
    local bottom = bottoms and bottoms[math.max(1, math.min(#bottoms, frame or 1))]
    if not bottom then
        return 0
    end
    local offset = (SPRITE_ORIGIN_Y - bottom) * math.abs(self.image_yscale or 1)
    if back_bottoms then
        offset = offset + BACK_DRAW_Y_TRIM
    end
    return math.max(0, offset)
end

function PlatformToriiGate:updateTriggerCollider()
    self.collider = Hitbox(self, self:getTriggerRect())
end

function PlatformToriiGate:getDashPosition()
    local x, y = self:getGateOrigin()
    return x, y + 62
end

function PlatformToriiGate:matchesDirection(direction)
    return self.viable_directions == 0 or self.viable_directions == direction
end

function PlatformToriiGate:consume()
    if self.single_use then
        self.deathcon = 1
        self.timer = 0
        self.death_last_timer = 0
        self.usable = false
    end
end

function PlatformToriiGate:markInitiated()
    self.just_initiated = true
    self.just_initiated_timer = 30
end

function PlatformToriiGate:update()
    super.update(self)
    self:ensureBackObject()
    self:updateLayering()
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    if self.just_initiated_timer > 0 then
        self.just_initiated_timer = self.just_initiated_timer - DTMULT
        if self.just_initiated_timer <= 0 then
            self.just_initiated = false
        end
    end

    if self.deathcon == 1 then
        local previous_timer = self.timer
        self.timer = self.timer + DTMULT
        if previous_timer < 2 and self.timer >= 2 then
            Assets.playSound(Featherfall.sounds.torii_sparkle)
        end
        self:spawnDeathLeaves(previous_timer, self.timer)
        if self.timer >= 30 then
            self:spawnDeathAfterimages()
            self:remove()
        end
        self.death_last_timer = self.timer
    end
end

function PlatformToriiGate:onRemove(parent)
    if self.back_object and self.back_object.parent then
        self.back_object:remove()
    end
    super.onRemove(self, parent)
end

function PlatformToriiGate:ensureBackObject()
    if self.back_object and self.back_object.parent then
        return
    end
    if Game.world and self.visible then
        self.back_object = Game.world:spawnObject(ToriiBack(self), self:getBackLayer())
    end
end

function PlatformToriiGate:getBaseLayer()
    if self.torii_base_layer == nil then
        self.torii_base_layer = self.layer or WORLD_LAYERS["events"]
    end
    return self.torii_base_layer
end

function PlatformToriiGate:getBackLayer()
    return self:getBaseLayer() + self.back_layer_offset
end

function PlatformToriiGate:getFrontLayer()
    local player = Game.world and Game.world.player
    local origin_x = self:getGateOrigin()
    if Featherfall and Featherfall:isPlatformModeActive() and player and player.x > origin_x + 20 then
        return self:getBaseLayer() + self.front_layer_offset
    end
    return self:getBaseLayer()
end

function PlatformToriiGate:updateLayering()
    local layer = self:getFrontLayer()
    if self.layer ~= layer then
        self.layer = layer
        if self.parent then
            self.parent.update_child_list = true
        end
    end
end

function PlatformToriiGate:spawnDeathLeaves(previous_timer, current_timer)
    if not (Game.world and PlatformDust) then
        return
    end
    local start = math.max(6, math.floor(previous_timer) + 1)
    local stop = math.floor(current_timer)
    if stop < start then
        return
    end

    local ox, oy = self:getGateOrigin()
    local width = 53 * math.abs(self.image_xscale or 1)
    local height = 190 * math.abs(self.image_yscale or 1)
    for frame = start, stop do
        if frame > 5 and frame % 2 == 0 then
            for _ = 1, 1 + math.floor(0.1 * frame) do
                local size = love.math.random() + 1
                local delay = love.math.random(60, 180)
                local leaf = PlatformDust(
                    ox + (love.math.random(-30, 30) / 100 * width),
                    oy - (love.math.random() * 0.8 * height),
                    1,
                    "effects/platform/leaf_fall",
                    {
                        image_speed = love.math.random(15, 30) / 100,
                        image_xscale = 0,
                        image_yscale = 0,
                        grow_to_x = size,
                        grow_to_y = size,
                        grow_time = 9,
                        hspeed = love.math.random(-300, 300) / 100,
                        vspeed = love.math.random(-300, 300) / 100,
                        gravity_direction = 135,
                        gravity = 0.2,
                        alpha = 2,
                        fade_speed = 2 / delay,
                        max_life = delay,
                        loop = true,
                    }
                )
                Game.world:spawnObject(leaf, (self.layer or WORLD_LAYERS["above_events"]) + 0.01)
            end
        end
    end
end

function PlatformToriiGate:spawnDeathAfterimages()
    if not (Game.world and ToriiAfterimage) then
        return
    end
    local frame = self:getFrame()
    Game.world:spawnObject(ToriiAfterimage(self, self.back_sprite, frame, self:getBackLayer()), self:getBackLayer())
    Game.world:spawnObject(ToriiAfterimage(self, self.front_sprite, frame, self.layer), self.layer)
end

function PlatformToriiGate:getFrame()
    local frames = Assets.getFrames(self.front_sprite)
    if not frames then
        return 1
    end
    local yscale = 0
    if Featherfall and Featherfall.getFloortexTransition then
        local transition_mult
        transition_mult, yscale = Featherfall:getFloortexTransition()
        yscale = (1 - yscale) / 0.9
    end
    return math.max(1, math.min(#frames, math.floor(Utils.lerp(0, #frames - 1, yscale + 0.2)) + 1))
end

function PlatformToriiGate:drawBackPerspectiveLine(frame)
    if self.back_sprite == "world/platform/torii/back_small" then
        return
    end

    local _, yscale = Featherfall:getFloortexTransition()
    local ys = yscale
    local ox, oy = self:getGateOrigin()
    oy = oy + self:getSpriteDrawYOffset(self.back_sprite, frame)
    local old_width = love.graphics.getLineWidth()
    Draw.setColor(0, 1, 0, 0.75)
    love.graphics.setLineWidth(4)
    love.graphics.line(
        ox - self.x - (3 * self.image_xscale),
        oy - self.y - 30 + (10 * ys),
        ox - self.x + (15 * self.image_xscale),
        oy - self.y - 20 - (126 * ys)
    )
    love.graphics.setLineWidth(old_width)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformToriiGate:draw()
    local frame = self:getFrame()
    drawGateSprite(self, self.front_sprite, frame)

    if self.deathcon == 1 then
        drawGateSprite(self, self.front_sprite, frame, MathUtils.clamp(self.timer / 15, 0, 1), 1, 1, 1, true)
    end
end

function PlatformToriiGate:drawDebug()
    super.drawDebug(self)
    love.graphics.setColor(0, 1, 1, 0.4)
    love.graphics.rectangle("line", 0, 0, self.width or 0, self.height or 0)
    local x, y, w, h = self:getTriggerRect()
    love.graphics.setColor(1, 0.75, 0, 0.8)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return PlatformToriiGate
