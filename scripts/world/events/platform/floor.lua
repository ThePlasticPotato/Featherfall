---@class PlatformFloor : Event
local PlatformFloor, super = Class(Event)

function PlatformFloor:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floor = true
    self.platform_collision = true
    self.is_slope = false
    self.is_entity = false
    self.moving_platform = false
    self.quicksand = self.properties["quicksand"] or 0
    self.conveyor_hspeed = self.properties["conveyor_hspeed"] or 0
    Featherfall:setupFloortexProjection(self, self.properties)
end

function PlatformFloor:update()
    super.update(self)
    Featherfall:syncFloortexSourceVisibility(self)
end

function PlatformFloor:draw()
    Featherfall:drawFloortexProjection(self)
    super.draw(self)
end

function PlatformFloor:onRemove(parent)
    Featherfall:restoreFloortexSourceVisibility(self)
    super.onRemove(self, parent)
end

return PlatformFloor
