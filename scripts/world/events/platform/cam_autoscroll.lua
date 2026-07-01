---@class PlatformCameraAutoscroll : Event
local PlatformCameraAutoscroll, super = Class(Event)

local function numberProperty(properties, key, default)
    local value = properties[key]
    if value == nil then
        return default
    end
    return tonumber(value) or default
end

function PlatformCameraAutoscroll:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_collision = false
    self.platform_cam_autoscroll = true
    self.visible = self.properties["visible"] == true
    self.autoscroll_speed = numberProperty(self.properties, "speed", numberProperty(self.properties, "autoscroll_speed", 3.46))
end

function PlatformCameraAutoscroll:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformCameraAutoscroll
