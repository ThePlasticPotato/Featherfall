---@class PlatformBulletEmitter : Event
local PlatformBullet = libRequire("featherfall", "scripts.world.events.platform.bullet")
local PlatformBulletEmitter, super = Class(Event)

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

function PlatformBulletEmitter:init(data)
    super.init(self, data)

    self.properties = data and data.properties or {}
    self.platform_bullet_emitter = true
    self.solid = false
    self.active = propertyBool(self.properties["active"], true)
    self.timer = tonumber(self.properties["timer"]) or 0
    self.rate = tonumber(self.properties["rate"] or self.properties["fire_rate"]) or 60
    self.initial_delay = tonumber(self.properties["initial_delay"]) or self.rate
    self.timer = self.initial_delay
    self.direction = tonumber(self.properties["direction"] or self.properties["angle"]) or 0
    self.speed = tonumber(self.properties["speed"]) or 4
    self.damage = tonumber(self.properties["damage"]) or 1
    self.bullet_lifetime = tonumber(self.properties["bullet_lifetime"]) or 180
    self.count = math.max(1, math.floor(tonumber(self.properties["count"]) or 1))
    self.spread = tonumber(self.properties["spread"]) or 0
    self.sprite_path = self.properties["sprite"] or self.properties["sprite_path"] or "world/platform/bullets/blue"
    self.draw_debug_marker = propertyBool(self.properties["draw_debug_marker"], true)
end

function PlatformBulletEmitter:update()
    super.update(self)
    if not self.active then
        return
    end
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    if not (Featherfall and Featherfall.isPlatformModeActive and Featherfall:isPlatformModeActive()) then
        return
    end

    self.timer = self.timer - DTMULT
    while self.timer <= 0 do
        self:fire()
        self.timer = self.timer + self.rate
    end
end

function PlatformBulletEmitter:getSpawnPosition()
    return self.x + ((self.width or 0) / 2), self.y + ((self.height or 0) / 2)
end

function PlatformBulletEmitter:fire()
    if not Game.world then
        return
    end
    local x, y = self:getSpawnPosition()
    local start_angle = self.direction - (self.spread / 2)
    local step = self.count > 1 and (self.spread / (self.count - 1)) or 0
    for i = 1, self.count do
        local angle = start_angle + ((i - 1) * step)
        local bullet = PlatformBullet({
            x = x,
            y = y,
            width = 32,
            height = 32,
            properties = {
                direction = angle,
                speed = self.speed,
                damage = self.damage,
                lifetime = self.bullet_lifetime,
                sprite = self.sprite_path,
            },
        })
        Game.world:spawnObject(bullet, (self.layer or WORLD_LAYERS["above_events"]) + 0.01)
    end
end

function PlatformBulletEmitter:draw()
    if DEBUG_RENDER and self.draw_debug_marker then
        Draw.setColor(0.2, 0.5, 1, 0.5)
        love.graphics.rectangle("line", 0, 0, self.width or 16, self.height or 16)
        Draw.setColor(1, 1, 1, 1)
    end
end

return PlatformBulletEmitter
