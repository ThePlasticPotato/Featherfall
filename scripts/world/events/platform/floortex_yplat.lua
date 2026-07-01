---@class PlatformFloortexYPlat : Event
local PlatformFloortexYPlat, super = Class(Event)

function PlatformFloortexYPlat:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floortex = true
    self.platform_floortex_yplat = true
    self.platform_floor = self.properties["collision"] == true
    self.platform_collision = self.platform_floor
    self.source_prefix = self.properties["source_prefix"] or (Featherfall and Featherfall:getFloorLayerPrefix())
    self.yorigin_id = self.properties["yorigin_id"]
    self.quicksand = self.properties["quicksand"] or 0
    self.conveyor_hspeed = self.properties["conveyor_hspeed"] or 0
    self.moving_platform = self.properties["moving_platform"] or false
    self.rideable = self.properties["rideable"] or false
    self.is_slope = false
    self.is_entity = false
    self.dif_x = 0
    self.dif_y = 0
end

function PlatformFloortexYPlat:update()
    super.update(self)
    Featherfall:updatePlatformDifference(self)
end

function PlatformFloortexYPlat:draw()
    super.draw(self)
end

return PlatformFloortexYPlat
