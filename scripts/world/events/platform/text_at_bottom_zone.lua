---@class PlatformTextAtBottomZone : Event
local PlatformTextAtBottomZone, super = Class(Event)

function PlatformTextAtBottomZone:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_collision = false
    self.platform_text_at_bottom_zone = true
    self.visible = self.properties["visible"] == true
end

function PlatformTextAtBottomZone:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformTextAtBottomZone
