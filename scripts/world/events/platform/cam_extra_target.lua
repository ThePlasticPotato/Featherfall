---@class PlatformCameraExtraTarget : Event
local PlatformCameraExtraTarget, super = Class(Event)

function PlatformCameraExtraTarget:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_collision = false
    self.platform_cam_extra_target = true
    self.visible = self.properties["visible"] == true
end

function PlatformCameraExtraTarget:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformCameraExtraTarget
