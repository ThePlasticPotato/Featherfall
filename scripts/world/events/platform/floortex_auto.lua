---@class PlatformFloortexAuto : Event
local PlatformFloortexAuto, super = Class(Event)

local function boolProperty(properties, key, default)
    local value = properties[key]
    if value == nil then
        return default
    end
    return value ~= false and value ~= 0 and value ~= "false"
end

local function numberProperty(properties, key, default)
    local value = properties[key]
    if value == nil then
        return default
    end
    return tonumber(value) or default
end

local function copyProperties(properties)
    local result = {}
    for key, value in pairs(properties or {}) do
        result[key] = value
    end
    return result
end

function PlatformFloortexAuto:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_floortex_auto = true
    self.platform_collision = false
    self.generated_floortex_events = {}
    self.visible = false
end

function PlatformFloortexAuto:getAnchorId()
    return self.properties["yorigin_id"]
        or self.properties["anchor_id"]
        or self.properties["id"]
        or self.data and self.data.name
        or ("auto_" .. tostring(self.object_id or "floortex"))
end

function PlatformFloortexAuto:getSourceRect()
    local properties = self.properties
    return numberProperty(properties, "source_x", self.x),
        numberProperty(properties, "source_y", self.y),
        numberProperty(properties, "source_width", self.width),
        numberProperty(properties, "source_height", self.height)
end

function PlatformFloortexAuto:makeEventData(name, x, y, width, height, properties)
    return {
        name = name,
        type = "",
        shape = "rectangle",
        x = x,
        y = y,
        width = width,
        height = height,
        rotation = 0,
        visible = true,
        properties = properties or {},
    }
end

function PlatformFloortexAuto:createGeneratedEvent(name, data)
    local map = self.world and self.world.map
    local event
    if map then
        event = map:loadObject(name, data)
    elseif Game.event_registry:has(name) then
        event = Game.event_registry:create(name, data)
    elseif Registry.getLegacyEvent(name) then
        event = Registry.createLegacyEvent(name, data)
    end

    if not event then
        error("Attempt to create non existent platform event \"" .. tostring(name) .. "\"")
    end

    event.object_id = nil
    event.unique_id = nil
    event.layer = self.layer
    event.layer_name = self.layer_name
    event.data = data
    event.generated_by_floortex_auto = self
    return event
end

function PlatformFloortexAuto:registerGeneratedEvent(event)
    if not (self.world and self.world.map and event) then
        return
    end

    self.world:addChild(event)

    local map = self.world.map
    table.insert(map.events, event)

    local name = event.data and event.data.name
    if name then
        map.events_by_name[name] = map.events_by_name[name] or {}
        table.insert(map.events_by_name[name], event)
    end
    if self.layer_name then
        map.events_by_layer[self.layer_name] = map.events_by_layer[self.layer_name] or {}
        table.insert(map.events_by_layer[self.layer_name], event)
    end

    table.insert(self.generated_floortex_events, event)
end

function PlatformFloortexAuto:spawnGeneratedEvent(name, x, y, width, height, properties)
    local data = self:makeEventData(name, x, y, width, height, properties)
    local event = self:createGeneratedEvent(name, data)
    self:registerGeneratedEvent(event)
    return event
end

function PlatformFloortexAuto:buildFloorProperties(anchor_id, source_x, source_y, source_width, source_height, yorigin, y_plat, height_plat)
    local properties = copyProperties(self.properties)
    properties["yorigin_id"] = anchor_id
    properties["source_x"] = source_x
    properties["source_y"] = source_y
    properties["source_width"] = source_width
    properties["source_height"] = source_height
    properties["yorigin"] = yorigin
    properties["y_ow"] = numberProperty(self.properties, "y_ow", source_y)
    properties["y_ow_anchor"] = source_y + yorigin
    properties["y_plat"] = y_plat
    properties["height_plat"] = height_plat
    properties["source_prefix"] = self.properties["floor_prefix"] or self.properties["source_prefix"] or (Featherfall and Featherfall:getFloorLayerPrefix())
    properties["projection_layer_offset"] = self.properties["floor_projection_layer_offset"] or self.properties["projection_layer_offset"]
    return properties
end

function PlatformFloortexAuto:buildFaceProperties(anchor_id, source_x, source_y, source_width, source_height, prefix, extra)
    local properties = copyProperties(self.properties)
    for key, value in pairs(extra or {}) do
        properties[key] = value
    end
    properties["yorigin_id"] = anchor_id
    properties["source_x"] = source_x
    properties["source_y"] = source_y
    properties["source_width"] = source_width
    properties["source_height"] = source_height
    properties["source_prefix"] = prefix
    properties["plane"] = false
    properties["collision"] = false
    return properties
end

function PlatformFloortexAuto:generate()
    if self.generated_floortex_done or not (self.world and self.world.map) then
        return
    end
    self.generated_floortex_done = true

    local properties = self.properties
    local source_x, source_y, source_width, source_height = self:getSourceRect()
    local anchor_id = self:getAnchorId()
    local front_enabled = boolProperty(properties, "front", true)
    local back_enabled = boolProperty(properties, "back", false)
    local front_height = numberProperty(properties, "front_height", numberProperty(properties, "face_height", 0))
    local back_height = numberProperty(properties, "back_height", numberProperty(properties, "face_height", front_height))
    local compression = numberProperty(properties, "compression", 0.1)
    local default_yorigin = front_enabled and front_height > 0 and (source_height - front_height) or (source_height / 2)
    local yorigin = numberProperty(properties, "yorigin", numberProperty(properties, "origin_y", default_yorigin))
    yorigin = MathUtils.clamp(yorigin, 0, source_height)

    local anchor_y = source_y + yorigin
    local height_plat = numberProperty(properties, "height_plat", math.max(1, source_height * compression))
    local y_plat = numberProperty(properties, "y_plat", anchor_y - (compression * yorigin) + numberProperty(properties, "y_plat_offset", 0))

    self:spawnGeneratedEvent(
        "platform_floortex_floor",
        source_x,
        source_y,
        source_width,
        source_height,
        self:buildFloorProperties(anchor_id, source_x, source_y, source_width, source_height, yorigin, y_plat, height_plat)
    )

    self:spawnGeneratedEvent(
        "platform_floortex_yorigin",
        source_x,
        anchor_y,
        source_width,
        2,
        {id = anchor_id, yorigin_id = anchor_id}
    )

    self:spawnGeneratedEvent(
        "platform_floortex_yplat",
        source_x,
        y_plat,
        source_width,
        math.max(1, height_plat),
        {
            yorigin_id = anchor_id,
            source_prefix = properties["floor_prefix"] or properties["source_prefix"],
            collision = false,
        }
    )

    local wall_prefix = properties["wall_prefix"] or (Featherfall and Featherfall:getWallLayerPrefix())
    if front_enabled and front_height > 0 then
        local front_x = numberProperty(properties, "front_x", source_x)
        local front_y = numberProperty(properties, "front_y", anchor_y)
        local front_width = numberProperty(properties, "front_width", source_width)
        self:spawnGeneratedEvent(
            "platform_floortex_front",
            front_x,
            front_y,
            front_width,
            front_height,
            self:buildFaceProperties(
                anchor_id,
                numberProperty(properties, "front_source_x", source_x),
                numberProperty(properties, "front_source_y", anchor_y),
                numberProperty(properties, "front_source_width", source_width),
                numberProperty(properties, "front_source_height", front_height),
                properties["front_prefix"] or wall_prefix,
                {
                    projection_layer_offset = properties["front_projection_layer_offset"],
                    dest_height = properties["front_dest_height"],
                }
            )
        )
    end

    if back_enabled and back_height > 0 then
        local back_x = numberProperty(properties, "back_x", source_x)
        local back_y = numberProperty(properties, "back_y", source_y - back_height)
        local back_width = numberProperty(properties, "back_width", source_width)
        self:spawnGeneratedEvent(
            "platform_floortex_back",
            back_x,
            back_y,
            back_width,
            back_height,
            self:buildFaceProperties(
                anchor_id,
                numberProperty(properties, "back_source_x", source_x),
                numberProperty(properties, "back_source_y", source_y - back_height),
                numberProperty(properties, "back_source_width", source_width),
                numberProperty(properties, "back_source_height", back_height),
                properties["back_prefix"] or wall_prefix,
                {
                    projection_layer_offset = properties["back_projection_layer_offset"],
                    dest_height = properties["back_dest_height"],
                }
            )
        )
    end
end

function PlatformFloortexAuto:onLoad()
    self:generate()
end

function PlatformFloortexAuto:onRemove(parent)
    for _, event in ipairs(self.generated_floortex_events or {}) do
        if event.parent then
            event:remove()
        end
    end
    self.generated_floortex_events = {}
    super.onRemove(self, parent)
end

return PlatformFloortexAuto
