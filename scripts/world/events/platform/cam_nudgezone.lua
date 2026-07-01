---@class PlatformCameraNudgeZone : Event
local PlatformCameraNudgeZone, super = Class(Event)

local function numberProperty(properties, key, default)
    local value = properties[key]
    if value == nil then
        return default
    end
    return tonumber(value) or default
end

function PlatformCameraNudgeZone:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_collision = false
    self.platform_cam_nudgezone = true
    self.visible = self.properties["visible"] == true
    self.nudgex = numberProperty(self.properties, "nudgex", numberProperty(self.properties, "x", 0))
    self.nudgey = numberProperty(self.properties, "nudgey", numberProperty(self.properties, "y", 0))
    self.nudgerate = numberProperty(self.properties, "nudgerate", 8)
    self.mode = self.properties["mode"] or "Constant"
end

function PlatformCameraNudgeZone:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformCameraNudgeZone
