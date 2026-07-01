---@class PlatformCheckpoint : Event
local PlatformCheckpoint, super = Class(Event)

function PlatformCheckpoint:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_checkpoint = true
    self.platform_collision = false
    self.visible = self.properties["visible"] == true
    self.respawn_target_extflag = self.properties["respawn_target_extflag"] or self.properties["target"] or ""
end

function PlatformCheckpoint:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformCheckpoint
