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
    self.quicksand = self.properties["quicksand"] or 0
    self.conveyor_hspeed = self.properties["conveyor_hspeed"] or 0
end

function PlatformBlock:draw()
    super.draw(self)
end

return PlatformBlock
