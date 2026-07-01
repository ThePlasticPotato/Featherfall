---@class PlatformCameraClampZone : Event
local PlatformCameraClampZone, super = Class(Event)

local function numberProperty(properties, key, default)
    local value = properties[key]
    if value == nil then
        return default
    end
    return tonumber(value) or default
end

function PlatformCameraClampZone:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_collision = false
    self.platform_cam_clampzone = true
    self.visible = self.properties["visible"] == true
    self.xmin = numberProperty(self.properties, "xmin", -4)
    self.xmax = numberProperty(self.properties, "xmax", -4)
    self.ymin = numberProperty(self.properties, "ymin", -4)
    self.ymax = numberProperty(self.properties, "ymax", -4)
    self.mode = self.properties["mode"] or "Constant"
    self.extflag = self.properties["extflag"] or ""
    self.gradual_extflag = self.properties["gradual_extflag"] or self.properties["gradual_target"] or ""
    self.lerpstrength = numberProperty(self.properties, "lerpstrength", -1)
end

function PlatformCameraClampZone:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformCameraClampZone
