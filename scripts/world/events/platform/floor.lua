---@class PlatformFloor : Event
local PlatformFloor, super = Class(Event)

local function propertyBool(properties, key)
    local value = properties[key]
    return value == true or value == 1 or value == "true"
end

local function configureSlope(event, data)
    local properties = event.properties or {}
    local points = data.polyline or data.polygon
    local has_points = type(points) == "table" and #points >= 2
    local is_slope = propertyBool(properties, "slope")
        or propertyBool(properties, "is_slope")
        or propertyBool(properties, "platform_slope")
        or data.name == "platform_slope"

    if not is_slope then
        return
    end

    local p1 = has_points and points[1] or nil
    local p2 = has_points and points[#points] or nil
    event.is_slope = true
    event.platform_slope = true
    event.plattype = properties["plattype"] or properties["slope_type"] or 0
    event.slope_type = event.plattype
    event.slope_anchor = properties["slope_anchor"]
    event.x1 = event.x + (properties["x1"] or properties["slope_x1"] or (p1 and p1.x) or 0)
    event.y1 = event.y + (properties["y1"] or properties["slope_y1"] or (p1 and p1.y) or event.height)
    event.x2 = event.x + (properties["x2"] or properties["slope_x2"] or (p2 and p2.x) or event.width)
    event.y2 = event.y + (properties["y2"] or properties["slope_y2"] or (p2 and p2.y) or 0)
    event.image_xscale = properties["image_xscale"] or properties["xscale"] or properties["scale_x"] or 1
end

function PlatformFloor:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floor = true
    self.platform_collision = true
    self.is_slope = false
    self.is_entity = false
    self.moving_platform = self.properties["moving_platform"] or self.properties["moving"] or false
    self.rideable = self.properties["rideable"] or false
    self.quicksand = self.properties["quicksand"] or 0
    self.conveyor_hspeed = self.properties["conveyor_hspeed"] or 0
    self.dif_x = 0
    self.dif_y = 0
    configureSlope(self, data)
    Featherfall:setupPlatformMotion(self, self.properties)
    Featherfall:setupFloortexProjection(self, self.properties)
end

function PlatformFloor:update()
    super.update(self)
    Featherfall:updatePlatformMotion(self)
    Featherfall:updatePlatformDifference(self)
    Featherfall:syncFloortexSourceVisibility(self)
end

function PlatformFloor:draw()
    Featherfall:drawFloortexProjection(self)
    super.draw(self)
end

function PlatformFloor:drawDebug()
    super.drawDebug(self)
    Featherfall:drawPlatformMotionDebug(self)
end

function PlatformFloor:onRemove(parent)
    Featherfall:restoreFloortexSourceVisibility(self)
    super.onRemove(self, parent)
end

return PlatformFloor
