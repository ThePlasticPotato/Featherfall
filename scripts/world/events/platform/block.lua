---@class PlatformBlock : Event
local PlatformBlock, super = Class(Event)

function PlatformBlock:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_block = true
    self.platform_collision = true
    self.is_slope = false
    self.is_entity = false
    self.is_barrier = self.properties["is_barrier"] or false
    self.moving_platform = self.properties["moving_platform"] or false
    self.rideable = self.properties["rideable"] or false
    self.quicksand = self.properties["quicksand"] or 0
    self.conveyor_hspeed = self.properties["conveyor_hspeed"] or 0
    self.dif_x = 0
    self.dif_y = 0
    Featherfall:setupPlatformMotion(self, self.properties)
end

function PlatformBlock:update()
    super.update(self)
    Featherfall:updatePlatformMotion(self)
    Featherfall:updatePlatformDifference(self)
end

function PlatformBlock:draw()
    super.draw(self)
end

function PlatformBlock:drawDebug()
    super.drawDebug(self)
    Featherfall:drawPlatformMotionDebug(self)
end

return PlatformBlock
