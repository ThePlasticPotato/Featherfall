---@class PlatformFloortexFloor : Event
local PlatformFloortexFloor, super = Class(Event)

function PlatformFloortexFloor:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floortex = true
    self.platform_floortex_floor = true
    self.platform_floor = self.properties["collision"] ~= false
    self.platform_collision = self.platform_floor
    self.align_bottom_1tile = self.properties["align_bottom_1tile"] ~= false
    self.quicksand = self.properties["quicksand"] or 0
    self.conveyor_hspeed = self.properties["conveyor_hspeed"] or 0
    self.moving_platform = self.properties["moving_platform"] or false
    self.rideable = self.properties["rideable"] or false
    self.is_slope = false
    self.is_entity = false
    self.dif_x = 0
    self.dif_y = 0
    self.blend = self.properties["blend"] and TiledUtils.parseColorProperty(self.properties["blend"]) or COLORS.white
    Featherfall:setupFloortexProjection(self, self.properties)
    Featherfall:setupFloortexPlane(self, self.properties)
    Featherfall:setupPlatformMotion(self, self.properties)
end

function PlatformFloortexFloor:update()
    super.update(self)
    Featherfall:updatePlatformMotion(self)
    Featherfall:updatePlatformDifference(self)
    Featherfall:resolveFloortexPlane(self)
    Featherfall:syncFloortexProjectionLayer(self)
    Featherfall:syncFloortexSourceVisibility(self)
end

function PlatformFloortexFloor:draw()
    Featherfall:resolveFloortexPlane(self)
    Featherfall:drawFloortexProjection(self)
    super.draw(self)
end

function PlatformFloortexFloor:drawDebug()
    super.drawDebug(self)
    Featherfall:drawPlatformMotionDebug(self)
end

function PlatformFloortexFloor:onRemove(parent)
    Featherfall:restoreFloortexSourceVisibility(self)
    super.onRemove(self, parent)
end

return PlatformFloortexFloor
