---@class PlatformFallCue : Event
local PlatformFallCue, super = Class(Event)

function PlatformFallCue:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_fall_cue = true
    self.platform_collision = false
    self.depth_behind = self.properties["depth_behind"]
    self.visible = self.properties["visible"] == true
end

function PlatformFallCue:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformFallCue
