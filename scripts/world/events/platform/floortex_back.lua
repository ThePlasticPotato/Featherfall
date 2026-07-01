---@class PlatformFloortexBack : Event
local PlatformFloortexBack, super = Class(Event)

function PlatformFloortexBack:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floortex = true
    self.platform_floortex_back = true
    self.platform_collision = false
    self.source_prefix = self.properties["source_prefix"] or (Featherfall and Featherfall:getWallLayerPrefix())
    self.yorigin_id = self.properties["yorigin_id"]
    self.blend = self.properties["blend"] and TiledUtils.parseColorProperty(self.properties["blend"]) or (ColorUtils.hexToRGB("7F7F7F"))
    Featherfall:setupFloortexProjection(self, self.properties)
end

function PlatformFloortexBack:update()
    super.update(self)
    Featherfall:syncFloortexProjectionLayer(self)
    Featherfall:syncFloortexSourceVisibility(self)
end

function PlatformFloortexBack:draw()
    Featherfall:drawFloortexProjection(self)
    super.draw(self)
end

function PlatformFloortexBack:onRemove(parent)
    Featherfall:restoreFloortexSourceVisibility(self)
    super.onRemove(self, parent)
end

return PlatformFloortexBack
