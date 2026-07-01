---@class PlatformCameraSteadyZone : Event
local PlatformCameraSteadyZone, super = Class(Event)

function PlatformCameraSteadyZone:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_collision = false
    self.platform_cam_steadyzone = true
    self.visible = self.properties["visible"] == true
end

function PlatformCameraSteadyZone:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformCameraSteadyZone
