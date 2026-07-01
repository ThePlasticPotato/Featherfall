---@class PlatformFloortexYOrigin : Event
local PlatformFloortexYOrigin, super = Class(Event)

function PlatformFloortexYOrigin:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floortex = true
    self.platform_floortex_yorigin = true
    self.platform_collision = false
    self.yorigin_id = self.properties["yorigin_id"] or self.properties["id"] or self.name
end

function PlatformFloortexYOrigin:draw()
    super.draw(self)
end

return PlatformFloortexYOrigin
