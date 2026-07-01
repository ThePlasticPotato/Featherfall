---@class PlatformSlashpusherAnchor : Event
local PlatformSlashpusherAnchor, super = Class(Event)

local SPRITE = "world/platform/slashpusher/leaves"

function PlatformSlashpusherAnchor:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.platform_slashpusher_anchor = true
    self.solid = false
    self.index = tonumber(self.properties["index"] or self.properties["anchor_index"]) or 0
    self.flower = nil
    self.flower_rotate_speed = 0
    self.start_x = self.x
    self.start_y = self.y
    self.image_xscale = tonumber(self.properties["image_xscale"] or self.properties["xscale"]) or 2
    self.image_yscale = tonumber(self.properties["image_yscale"] or self.properties["yscale"]) or 2
    self.image_angle = tonumber(self.properties["image_angle"] or self.properties["angle"]) or 0
end

function PlatformSlashpusherAnchor:getAnchorLocalPosition()
    return (self.width or 40) / 2, tonumber(self.properties["anchor_y"] or self.properties["origin_y"]) or 11
end

function PlatformSlashpusherAnchor:getAnchorPosition()
    local x, y = self:getAnchorLocalPosition()
    return self.x + x, self.y + y
end

function PlatformSlashpusherAnchor:spinFromWater()
    if self.flower then
        self.flower_rotate_speed = math.min(self.flower_rotate_speed + 1, 10)
    end
end

function PlatformSlashpusherAnchor:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    if self.flower_rotate_speed > 0 and self.flower and self.flower.parent then
        self.flower.angle = (self.flower.angle or 0) + (self.flower_rotate_speed * DTMULT)
        self.flower_rotate_speed = self.flower_rotate_speed - (0.8 * DTMULT)
        if self.flower_rotate_speed <= 0 then
            self.flower_rotate_speed = 0
        end
    end
end

function PlatformSlashpusherAnchor:draw()
    local frames = Assets.getFrames(SPRITE)
    local texture = frames and frames[1] or Assets.getTexture(SPRITE)
    if not texture then
        return
    end
    local x, y = self:getAnchorLocalPosition()
    Draw.setColor(1, 1, 1, self.alpha or 1)
    Draw.draw(texture, x, y, math.rad(-self.image_angle), self.image_xscale, self.image_yscale, 20, 11)
    Draw.setColor(1, 1, 1, 1)
    super.draw(self)
end

return PlatformSlashpusherAnchor
