---@class PlatformFloortexFront : Event
local PlatformFloortexFront, super = Class(Event)

function PlatformFloortexFront:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floortex = true
    self.platform_floortex_front = true
    self.platform_collision = false
    self.source_prefix = self.properties["source_prefix"] or (Featherfall and Featherfall:getWallLayerPrefix())
    self.yorigin_id = self.properties["yorigin_id"]
    self.blend = self.properties["blend"] and TiledUtils.parseColorProperty(self.properties["blend"]) or COLORS.white
    Featherfall:setupFloortexProjection(self, self.properties)
end

function PlatformFloortexFront:update()
    super.update(self)
    Featherfall:syncFloortexProjectionLayer(self)
    Featherfall:syncFloortexSourceVisibility(self)
end

function PlatformFloortexFront:draw()
    Featherfall:drawFloortexProjection(self)
    super.draw(self)
end

function PlatformFloortexFront:onRemove(parent)
    Featherfall:restoreFloortexSourceVisibility(self)
    super.onRemove(self, parent)
end

return PlatformFloortexFront
