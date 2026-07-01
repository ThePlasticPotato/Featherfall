---@class PlatformToriiGate : Event
local PlatformToriiGate, super = Class(Event)

local FRONT_SPRITE = "world/platform/torii/perspective"
local BACK_SPRITE = "world/platform/torii/back"
local SPRITE_ORIGIN_X = 26
local SPRITE_ORIGIN_Y = 190

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
    self.just_initiated = false
    self.just_initiated_timer = 0
    self.deathcon = 0
    self.timer = 0
    self.image_index = 1
    self.image_xscale = tonumber(self.properties["image_xscale"] or self.properties["xscale"]) or 2
    self.image_yscale = tonumber(self.properties["image_yscale"] or self.properties["yscale"]) or 2
    self.front_sprite = self.properties["front_sprite"] or FRONT_SPRITE
    self.back_sprite = self.properties["back_sprite"] or BACK_SPRITE
end

function PlatformToriiGate:getGateOrigin()
    return self.x + ((self.width or 53) / 2), self.y + (self.height or 190)
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
        self.usable = false
    end
end

function PlatformToriiGate:markInitiated()
    self.just_initiated = true
    self.just_initiated_timer = 30
end

function PlatformToriiGate:update()
    super.update(self)

    if self.just_initiated_timer > 0 then
        self.just_initiated_timer = self.just_initiated_timer - DTMULT
        if self.just_initiated_timer <= 0 then
            self.just_initiated = false
        end
    end

    if self.deathcon == 1 then
        self.timer = self.timer + DTMULT
        if self.timer >= 30 then
            self:remove()
        end
    end
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

function PlatformToriiGate:drawSprite(sprite, frame, alpha)
    local frames = Assets.getFrames(sprite)
    local texture = frames and frames[math.max(1, math.min(#frames, frame or 1))] or Assets.getTexture(sprite)
    if not texture then
        return
    end

    local ox, oy = self:getGateOrigin()
    Draw.setColor(1, 1, 1, alpha or self.alpha or 1)
    Draw.draw(texture, ox - self.x, oy - self.y, 0, self.image_xscale, self.image_yscale, SPRITE_ORIGIN_X, SPRITE_ORIGIN_Y)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformToriiGate:draw()
    local frame = self:getFrame()
    self:drawSprite(self.back_sprite, frame)
    self:drawSprite(self.front_sprite, frame)

    if self.deathcon == 1 then
        self:drawSprite(self.back_sprite, frame, MathUtils.clamp(self.timer / 15, 0, 1))
        self:drawSprite(self.front_sprite, frame, MathUtils.clamp(self.timer / 15, 0, 1))
    end
end

function PlatformToriiGate:drawDebug()
    super.drawDebug(self)
    love.graphics.setColor(0, 1, 1, 0.4)
    love.graphics.rectangle("line", 0, 0, self.width or 0, self.height or 0)
    love.graphics.setColor(1, 1, 1, 1)
end

return PlatformToriiGate
