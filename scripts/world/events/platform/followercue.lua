---@class PlatformFollowerCue : Event
local PlatformFollowerCue, super = Class(Event)

function PlatformFollowerCue:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_followercue = true
    self.platform_collision = false
    self.visible = self.properties["visible"] == true

    local mode = self.properties["mode"] or self.properties["dothing"] or self.properties["cue"] or 0
    if mode == "edge" then
        self.dothing = 1
    elseif mode == "jump" then
        self.dothing = 0
    else
        self.dothing = tonumber(mode) or 0
    end
end

function PlatformFollowerCue:draw()
    if self.visible then
        super.draw(self)
    end
end

return PlatformFollowerCue
