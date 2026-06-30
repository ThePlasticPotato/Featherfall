local Featherfall = {
    id = "featherfall",
    state = "FEATHERFALL",
    transition_timer = 0,
    transition_timemax = 20,
    transition_extra_time = 0,
    transition_mode = 0,
    transition_projection_hold = 0,
    transition_source = nil,
    transition_prop = nil,
    follower_transition_props = {},
    transition_visual_owner = nil,
    follower_visual_owners = {},
    statue_refusal_callback = nil,
    pending_platform = false,
    platforming = false,
    floortex_projection_layers = {},
    action_ui = nil,
    dynamic_platforms = {},
    petalwings = {},
    action_colors = {},
    action_gradients = {},
    action_labels = {},
}

_G.Featherfall = Featherfall

Featherfall.constants = {
    transition_timemax = 20,
    transition_platform_delay = 8,
    transition_extra_threshold = 10,
    transition_extra_time = 9,
    exit_prop_x_offset = 0,
    exit_prop_y_offset = 0,

    gravity = 1.25,
    fall_speed = 20,
    hspeed_max = 9,
    air_accel = 2,
    air_decel = 0.5,
    ground_accel = 2,
    ground_decel = 0.65,
    jumpheight = 20,
    jump_mintime = 4,
    coyote = 4,
    jumpbuffer = 4,
    jumpsquat = 2,
    dashspeed = 11,
}

Featherfall.assets = {
    effects = {
        landingdust = "effects/platform/landingdust",
        landingdust_new = "effects/platform/landingdust_new",
        petal_barrier = "effects/platform/petal/barrier",
        petalwing = "effects/platform/petalwing",
    },
    statue = {
        base = "world/statue/base",
        top = "world/statue/top",
        bottom = "world/statue/bottom",
        wings = "world/statue/wings",
        light = "world/statue/light",
        fall_cue = "world/statue/fall_cue",
    },
}

Featherfall.sounds = {
    enter = "platswap_2",
    exit = "platswap_1",
    statue_recover = "impact",
    pit_start = "firework_send",
    pit_jump = "jump",
    pit_wing = "wing",
    action_open = "spearrise",
    action_select = "plat_act_select",
    action_auto_select = "select",
    action_move = "plat_act_move",
    action_fail = "plat_act_move_fail",
    action_ready = "boost",
    action_release = "rudebuster_swing",
    action_heal = "power",
    action_axe_ready = "wallclaw",
    action_platform_grab = "grab",
    petal_grab = "grab",
    petal_drain = "petaldrain",
    attack_1 = "smallswing",
    attack_2 = "heavyswing",
    attack_3 = "ultraswing",
    landing = "noise",
    jump_launch = "smallswing",
}

function Featherfall:init()
    local aliases = {
        platform_statue = "platform/statue",
        platform_floor = "platform/floor",
        platform_block = "platform/block",
        platform_checkpoint = "platform/checkpoint",
        platform_followercue = "platform/followercue",
        platform_action_target = "platform/action_target",
        platform_floortex_floor = "platform/floortex_floor",
        platform_floortex_front = "platform/floortex_front",
        platform_floortex_back = "platform/floortex_back",
        platform_floortex_yplat = "platform/floortex_yplat",
        platform_floortex_yorigin = "platform/floortex_yorigin",
    }

    for alias, event_id in pairs(aliases) do
        Game:registerEvent(alias, function(data)
            return Registry.createLegacyEvent(event_id, data)
        end)
    end

    self:resetControllerState()
end

function Featherfall:resetControllerState()
    self:restorePlayerVisual()
    self:restoreAllFollowerVisuals()
    self:restoreAllFloortexSourceVisibility()
    if self.transition_prop and self.transition_prop.parent then
        self.transition_prop.suppress_finish = true
        self.transition_prop:remove()
    end
    for follower, prop in pairs(self.follower_transition_props or {}) do
        if prop and prop.parent then
            prop.suppress_finish = true
            prop:remove()
        end
        self.follower_transition_props[follower] = nil
    end
    self.transition_timer = 0
    self.transition_timemax = self.constants.transition_timemax
    self.transition_extra_time = 0
    self.transition_mode = 0
    self.transition_projection_hold = 0
    self.transition_source = nil
    self.transition_prop = nil
    self.follower_transition_props = {}
    self.transition_visual_owner = nil
    self.follower_visual_owners = {}
    self.pending_platform = false
    self.platforming = false
    self.dynamic_platforms = {}
    self:clearPetalWings(true)
    if self.action_ui and self.action_ui.parent then
        self.action_ui:remove()
    end
    self.action_ui = nil
end

function Featherfall:getConfig(key, default)
    local value = Kristal.getLibConfig(self.id, key)
    if value == nil then
        return default
    end
    return value
end

function Featherfall:getEnabledFlag()
    return self:getConfig("enabled_flag", "PLATFORMING_ENABLED")
end

function Featherfall:getMapProperties()
    local map = Game.world and Game.world.map
    return map and map.data and map.data.properties or {}
end

function Featherfall:getSourceProperties(source)
    return type(source) == "table" and source.properties or {}
end

function Featherfall:getPropertyFrom(properties, names)
    for _, name in ipairs(names) do
        if properties[name] ~= nil then
            return properties[name]
        end
    end
end

function Featherfall:getLayeredProperty(source, source_names, map_names, config_key, default)
    local value = self:getPropertyFrom(self:getSourceProperties(source), source_names or {})
    if value ~= nil then
        return value
    end

    value = self:getPropertyFrom(self:getMapProperties(), map_names or source_names or {})
    if value ~= nil then
        return value
    end

    if config_key then
        return self:getConfig(config_key, default)
    end

    return default
end

function Featherfall:getFloorLayerPrefix()
    return self:getConfig("floor_layer_prefix", "floors_")
end

function Featherfall:getWallLayerPrefix()
    return self:getConfig("wall_layer_prefix", "walls_")
end

function Featherfall:getAttackPressMode(source)
    local value = self:getLayeredProperty(
        source,
        {"attack_press_mode", "platform_attack_press_mode"},
        {"platform_attack_press_mode"},
        "attack_press_mode",
        0
    )
    if value == true then
        return 1
    elseif value == false then
        return 0
    end
    return tonumber(value) or 0
end

function Featherfall:getActionStateForKind(kind, target)
    local player = Game.world and Game.world.player
    local player_state = player and player.platform_state
    if player_state and player_state.getActionState then
        local character, state, data = player_state:getActionState(kind, target)
        return character, state, data
    end
end

function Featherfall:getActionPresentation(kind, target, state, data)
    kind = PlatformActionUtils.normalizeKind(kind)
    local presentation = {}
    PlatformActionUtils.copyPresentation(presentation, PlatformActionUtils.default_presentation[kind])

    local registered_color = self.action_colors and self.action_colors[kind]
    local registered_gradient = self.action_gradients and self.action_gradients[kind]
    local registered_label = self.action_labels and self.action_labels[kind]
    if registered_color ~= nil then
        presentation.color = registered_color
    end
    if registered_gradient ~= nil then
        presentation.gradient = registered_gradient
    end
    if registered_label ~= nil then
        presentation.label = registered_label
    end

    if not state then
        local _, resolved_state, resolved_data = self:getActionStateForKind(kind, target)
        state = resolved_state
        data = data or resolved_data
    end

    local actor = state and state.getPlatformActor and state:getPlatformActor()
    if actor and actor.getPlatformActionPresentation then
        PlatformActionUtils.copyPresentation(presentation, actor:getPlatformActionPresentation(kind, state, target, data))
    end

    if target and target.getPlatformActionPresentation then
        PlatformActionUtils.copyPresentation(presentation, target:getPlatformActionPresentation(kind, state, data))
    end

    presentation.color = PlatformActionUtils.resolveValue(presentation.color, kind, target, state, data)
    presentation.label_color = PlatformActionUtils.resolveValue(presentation.label_color, kind, target, state, data)
    presentation.gradient = PlatformActionUtils.resolveValue(presentation.gradient, kind, target, state, data)
    presentation.label = PlatformActionUtils.resolveValue(presentation.label, kind, target, state, data)
    if not presentation.color and presentation.gradient then
        presentation.color = PlatformActionUtils.sampleGradient(presentation.gradient)
    end
    if not presentation.label_color then
        presentation.label_color = presentation.color
    end

    return presentation
end

function Featherfall:getActionColor(kind, target, state, data)
    local color = self:getActionColorTable(kind, target, state, data)
    if color then
        return (math.floor(color[1] * 255) * 65536) + (math.floor(color[2] * 255) * 256) + math.floor(color[3] * 255)
    end
    return 16776960
end

function Featherfall:getActionColorTable(kind, target, state, data)
    local presentation = self:getActionPresentation(kind, target, state, data)
    return presentation and presentation.color
end

function Featherfall:registerActionColor(kind, color)
    kind = PlatformActionUtils.normalizeKind(kind)
    self.action_colors = self.action_colors or {}
    self.action_colors[kind] = color
end

function Featherfall:getActionGradient(kind, target, state, data)
    local presentation = self:getActionPresentation(kind, target, state, data)
    return presentation and presentation.gradient
end

function Featherfall:registerActionGradient(kind, gradient)
    kind = PlatformActionUtils.normalizeKind(kind)
    self.action_gradients = self.action_gradients or {}
    self.action_gradients[kind] = gradient
end

function Featherfall:getActionLabel(kind, target, state, data)
    local presentation = self:getActionPresentation(kind, target, state, data)
    return presentation and presentation.label
end

function Featherfall:registerActionLabel(kind, label)
    kind = PlatformActionUtils.normalizeKind(kind)
    self.action_labels = self.action_labels or {}
    self.action_labels[kind] = label
end

function Featherfall:makeRipple(x, y, options)
    if not Game.world then
        return
    end
    local ripple = PlatformRipple(x, y, options)
    Game.world:spawnObject(ripple, ripple.layer)
    return ripple
end

function Featherfall:registerPetalWing(petalwing)
    if not petalwing then
        return
    end
    self.petalwings = self.petalwings or {}
    for _, existing in ipairs(self.petalwings) do
        if existing == petalwing then
            return
        end
    end
    table.insert(self.petalwings, petalwing)
end

function Featherfall:unregisterPetalWing(petalwing)
    for index = #(self.petalwings or {}), 1, -1 do
        if self.petalwings[index] == petalwing then
            table.remove(self.petalwings, index)
        end
    end
end

function Featherfall:clearPetalWings(silent)
    if silent then
        local petalwings = self.petalwings or {}
        self.petalwings = {}
        for index = #petalwings, 1, -1 do
            local petalwing = petalwings[index]
            if petalwing and petalwing.parent then
                petalwing:remove()
            end
        end
        return
    end

    for index = #(self.petalwings or {}), 1, -1 do
        local petalwing = self.petalwings[index]
        if petalwing and petalwing.parent then
            if petalwing.disperse and not petalwing.dispersing then
                petalwing:disperse()
                petalwing.dispersing = true
            end
        else
            table.remove(self.petalwings, index)
        end
    end
end

function Featherfall:spawnPetalWing(x, y, options)
    if not (Game.world and PetalWing) then
        return
    end

    local petalwing = PetalWing(x, y, options)
    local spawned = Game.world:spawnObject(petalwing, petalwing.layer)
    self:registerPetalWing(spawned)
    return spawned
end

function Featherfall:makeRingHitRipple(x, y, color, layer)
    local ripples = {}
    local configs = {
        {life = 80, radmax = 280, radstart = 2, thickness = 20},
        {life = 120, radmax = 480, radstart = 2, thickness = 15},
        {life = 160, radmax = 680, radstart = 2, thickness = 10},
    }
    for _, config in ipairs(configs) do
        config.color = color or 16777215
        config.curve = 1
        config.yratio = 0.8
        config.layer = layer or WORLD_LAYERS["above_events"]
        local ripple = self:makeRipple(x, y, config)
        if ripple then
            table.insert(ripples, ripple)
        end
    end
    return ripples
end

function Featherfall:makeDust(x, y, direction, sprite)
    if not Game.world then
        return
    end
    local dust = PlatformDust(x, y, direction, sprite)
    Game.world:spawnObject(dust, WORLD_LAYERS["above_events"])
    return dust
end

function Featherfall:getTileLayersByPrefix(prefix, map)
    prefix = (prefix or ""):lower()
    local layers = {}

    map = map or (Game.world and Game.world.map)
    if not map then
        return layers
    end

    for _, layer in ipairs(map.tile_layers or {}) do
        if layer.name and StringUtils.startsWith(layer.name:lower(), prefix) then
            table.insert(layers, layer)
        end
    end

    return layers
end

function Featherfall:getFloorLayers(map)
    return self:getTileLayersByPrefix(self:getFloorLayerPrefix(), map)
end

function Featherfall:getWallLayers(map)
    return self:getTileLayersByPrefix(self:getWallLayerPrefix(), map)
end

function Featherfall:isPlatformModeActive()
    local player = Game.world and Game.world.player
    return self.platforming or (player and player.state == self.state) or false
end

function Featherfall:getActionTargets()
    local map = Game.world and Game.world.map
    if not map then
        return {}
    end

    local targets = {}
    for _, event in ipairs(map.events or {}) do
        if event.platform_action_target_event then
            table.insert(targets, event)
        end
    end
    return targets
end

function Featherfall:addDynamicPlatform(platform)
    self.dynamic_platforms = self.dynamic_platforms or {}
    table.insert(self.dynamic_platforms, platform)
end

function Featherfall:removeDynamicPlatform(platform)
    for index = #(self.dynamic_platforms or {}), 1, -1 do
        if self.dynamic_platforms[index] == platform then
            table.remove(self.dynamic_platforms, index)
        end
    end
end

function Featherfall:getDynamicPlatforms()
    local platforms = {}
    for index = #(self.dynamic_platforms or {}), 1, -1 do
        local platform = self.dynamic_platforms[index]
        if platform and platform.parent then
            table.insert(platforms, 1, platform)
        else
            table.remove(self.dynamic_platforms, index)
        end
    end
    return platforms
end

function Featherfall:isMenuTargetAvailable(target, player)
    if not (target and target.parent and target.opens_menu) then
        return false
    end
    if target.isMenuTargetAvailable then
        return target:isMenuTargetAvailable(player) ~= false
    end
    if not (target.active and not target.blocked) then
        return false
    end

    player = player or (Game.world and Game.world.player)
    if not player then
        return true
    end

    local margin = target.menu_margin or target.menu_radius or 24
    local left = target.x - margin
    local right = target.x + (target.width or 0) + margin
    local top = target.y - margin
    local bottom = target.y + (target.height or 0) + margin
    return player.x >= left and player.x <= right and player.y >= top and player.y <= bottom
end

function Featherfall:hasMenuTarget(player)
    for _, target in ipairs(self:getActionTargets()) do
        if self:isMenuTargetAvailable(target, player) then
            return true
        end
    end
    return false
end

function Featherfall:updateActionUI()
    if not (Game.world and self:isPlatformModeActive() and PlatformActionUI) then
        if self.action_ui and self.action_ui.parent then
            self.action_ui:remove()
        end
        self.action_ui = nil
        return
    end

    if not (self.action_ui and self.action_ui.parent) then
        self.action_ui = Game.world:spawnObject(PlatformActionUI(), WORLD_LAYERS["ui"])
    end
end

function Featherfall:easeInOutPower(value, power)
    value = MathUtils.clamp(value, 0, 1)
    power = power or 3
    if value < 0.5 then
        return (((value * 2) ^ power) / 2)
    end
    return 1 - ((((1 - value) * 2) ^ power) / 2)
end

function Featherfall:getFloortexTransition()
    if self.transition_timer <= 0 then
        local mult = self:isPlatformModeActive() and 1 or 0
        return mult, MathUtils.lerp(1, 0.1, mult)
    end

    local mode = self.transition_mode or 0
    local delay = 0
    if self.transition_timemax == self.constants.transition_timemax and mode == 1 then
        delay = self.constants.transition_platform_delay
    end

    local mult
    if mode == 1 then
        mult = 1 - ((self.transition_timer - delay) / self.transition_timemax)
    else
        mult = (self.transition_timer - delay) / self.transition_timemax
    end

    mult = self:easeInOutPower(mult, 3)
    return mult, MathUtils.lerp(1, 0.1, mult)
end

function Featherfall:getTransitionLerpProgress()
    if self.transition_timer <= 0 then
        return self:isPlatformModeActive() and 1 or 0
    end

    local offset = self.transition_mode == 1 and self.transition_extra_time or 0
    local progress
    if self.transition_mode == 1 then
        progress = 1 - ((self.transition_timer - offset) / self.transition_timemax)
    else
        progress = self.transition_timer / self.transition_timemax
    end
    return self:easeInOutPower(progress, 3)
end

function Featherfall:setupFloortexProjection(object, properties)
    properties = properties or object.properties or {}

    object.platform_floortex_projection = properties["projection"] ~= false
    object.source_prefix = properties["source_prefix"] or object.source_prefix or self:getFloorLayerPrefix()
    object.projection_always = properties["always_project"] == true
    object.projection_hide_source = properties["hide_source"] ~= false
    object.projection_source_visibility = object.projection_source_visibility or {}
end

function Featherfall:getFloortexProjectionLayerOffset(object)
    local properties = object.properties or {}
    if properties["projection_layer_offset"] ~= nil then
        return tonumber(properties["projection_layer_offset"]) or 0
    end
    if object.platform_floortex_front then
        return -0.001
    end
    if object.platform_floortex_back then
        return -0.002
    end
    return -0.001
end

function Featherfall:getFloortexProjectionBaseLayer(object)
    local properties = object.properties or {}
    if properties["projection_layer"] ~= nil then
        return tonumber(properties["projection_layer"]) or object.layer or 0
    end
    if object.platform_floortex_front then
        local map = Game.world and Game.world.map
        if map and map.object_layer then
            return map.object_layer
        end
    end
    return object.floortex_base_layer or object.layer or 0
end

function Featherfall:syncFloortexProjectionLayer(object)
    if not (object and object.setLayer) then
        return
    end
    if not object.floortex_base_layer then
        object.floortex_base_layer = object.layer or 0
    end
    object:setLayer(self:getFloortexProjectionBaseLayer(object) + self:getFloortexProjectionLayerOffset(object))
end

function Featherfall:setupFloortexPlane(object, properties)
    properties = properties or object.properties or {}

    object.floortex_plane_enabled = properties["plane"] ~= false
    object.floortex_source_x = properties["source_x"] or object.x
    object.floortex_source_y = properties["source_y"] or object.y
    object.floortex_source_width = properties["source_width"] or object.width
    object.floortex_source_height = properties["source_height"] or object.height
    object.floortex_original_x = object.x
    object.floortex_original_y = object.y
    object.floortex_original_width = object.width
    object.floortex_original_height = object.height
    object.yorigin_id = properties["yorigin_id"] or properties["anchor_id"] or object.yorigin_id
    object.yorigin = properties["yorigin"]
    object.y_ow = properties["y_ow"] or object.y
    object.y_plat = properties["y_plat"]
    object.y_ow_anchor = properties["y_ow_anchor"]
    object.y_plat_anchor = properties["y_plat_anchor"]
    object.floortex_plane_dirty = true
end

function Featherfall:getFloortexEvents()
    local map = Game.world and Game.world.map
    return map and map.events or {}
end

function Featherfall:markerMatchesFloortex(marker, object, kind)
    if not (marker and object and marker ~= object) then
        return false
    end
    if kind and not marker[kind] then
        return false
    end

    local object_id = object.yorigin_id or object.properties and (object.properties["yorigin_id"] or object.properties["anchor_id"])
    if object_id then
        return marker.yorigin_id == object_id
            or marker.name == object_id
            or marker.properties and (marker.properties["id"] == object_id or marker.properties["yorigin_id"] == object_id)
    end

    local marker_left = marker.x
    local marker_right = marker.x + math.max(marker.width or 0, 1)
    local object_left = object.floortex_original_x or object.x
    local object_right = object_left + (object.floortex_original_width or object.width)
    return marker_right >= object_left and marker_left <= object_right
end

function Featherfall:findFloortexMarker(object, kind, y, tolerance)
    tolerance = tolerance or 2
    local best, best_dist
    for _, marker in ipairs(self:getFloortexEvents()) do
        if self:markerMatchesFloortex(marker, object, kind) then
            local marker_y = marker.y
            local dist = math.abs(marker_y - y)
            if dist <= tolerance and (not best_dist or dist < best_dist) then
                best = marker
                best_dist = dist
            end
        end
    end
    return best
end

function Featherfall:resolveFloortexPlane(object)
    if not (object and object.floortex_plane_enabled and object.floortex_plane_dirty) then
        return
    end

    local source_y = object.floortex_source_y or object.y
    local source_height = object.floortex_source_height or object.height
    local yorigin = object.yorigin
    local center_y = source_y + (source_height / 2)
    local yorigin_marker = self:findFloortexMarker(object, "platform_floortex_yorigin", center_y, source_height / 2)

    if yorigin_marker then
        yorigin = yorigin_marker.y - source_y
    end
    yorigin = yorigin or (source_height / 2)

    local anchor_y = object.y_ow_anchor or (source_y + yorigin)
    local y_plat_marker = self:findFloortexMarker(object, "platform_floortex_yplat", anchor_y, 4)
    local y_plat = object.y_plat or (y_plat_marker and y_plat_marker.y) or (anchor_y - (0.1 * yorigin))
    local height_plat = object.properties["height_plat"] or math.max(1, source_height * 0.1)

    object.yorigin = yorigin
    object.y_ow = object.y_ow or source_y
    object.y_ow_anchor = anchor_y
    object.y_plat = y_plat
    object.y_plat_anchor = object.y_plat_anchor or (y_plat + (0.1 * ((object.y_ow or source_y) - source_y)))
    object.height_ow = source_height
    object.height_plat = height_plat
    object.x = object.properties["x_plat"] or object.x
    object.y = y_plat
    object.height = height_plat
    object.floortex_plane_dirty = false
    Object.uncache(object)
end

function Featherfall:shouldDrawFloortexProjection(object)
    if not (object and object.platform_floortex_projection) then
        return false
    end
    return object.projection_always or self:isPlatformModeActive() or self.transition_timer > 0 or self.transition_projection_hold > 0
end

function Featherfall:findFloortexFloorForAttachment(object)
    if not object then
        return
    end

    for _, event in ipairs(self:getFloortexEvents()) do
        if event.platform_floortex_floor and self:markerMatchesFloortex(object, event) then
            self:resolveFloortexPlane(event)
            return event
        end
    end
end

function Featherfall:findFloortexFloorAt(x, y)
    local best, best_dist
    for _, event in ipairs(self:getFloortexEvents()) do
        if event.platform_floortex_floor then
            self:resolveFloortexPlane(event)
            local left = event.floortex_original_x or event.x
            local width = event.floortex_original_width or event.width
            local top = event.y_ow or event.floortex_source_y or event.y
            local height = event.height_ow or event.floortex_source_height or event.height
            if x >= left and x <= left + width and y >= top and y <= top + height then
                local dist = math.abs(y - ((event.y_ow_anchor or top) or y))
                if not best_dist or dist < best_dist then
                    best = event
                    best_dist = dist
                end
            end
        end
    end
    return best
end

function Featherfall:getFloortexProjectionRect(object, source_x, source_y, source_width, source_height)
    local properties = object.properties or {}

    if object.floortex_plane_enabled then
        self:resolveFloortexPlane(object)
        local mult = self:getTransitionLerpProgress()
        local y_ow = object.y_ow or source_y
        local y_plat = object.y_plat or object.y
        local height_ow = object.height_ow or source_height
        local height_plat = object.height_plat or object.height or math.max(1, source_height * 0.1)
        local visual_y_offset = properties["visual_y_offset"]
        if visual_y_offset == nil and object.platform_floortex_floor then
            visual_y_offset = -(height_plat / 2)
        end
        visual_y_offset = visual_y_offset or 0
        return properties["dest_x"] or object.x,
            properties["dest_y"] or MathUtils.lerp(y_ow, y_plat + visual_y_offset, mult),
            properties["dest_width"] or object.width or source_width,
            properties["dest_height"] or MathUtils.lerp(height_ow, height_plat, mult)
    end

    if object.platform_floortex_front or object.platform_floortex_back then
        local floor = self:findFloortexFloorForAttachment(object)
        if floor then
            local floor_source_x, floor_source_y, floor_source_width, floor_source_height =
                self:getFloortexSourceBounds(floor, self:getFloortexProjectionLayers(floor))
            local floor_x, floor_y, floor_width, floor_height =
                self:getFloortexProjectionRect(floor, floor_source_x, floor_source_y, floor_source_width, floor_source_height)
            local dest_height = properties["dest_height"] or object.height or source_height
            local dest_y = floor_y + floor_height + 1
            if object.platform_floortex_back then
                dest_y = floor_y - dest_height
            end
            return properties["dest_x"] or floor_x,
                properties["dest_y"] or dest_y,
                properties["dest_width"] or floor_width,
                dest_height
        end
    end

    return properties["dest_x"] or object.x,
        properties["dest_y"] or object.y,
        properties["dest_width"] or object.width,
        properties["dest_height"] or object.height
end

function Featherfall:getFloortexProjectionLayers(object)
    return self:getTileLayersByPrefix(object.source_prefix or self:getFloorLayerPrefix())
end

function Featherfall:getFloortexSourceBounds(object, layers)
    local properties = object.properties or {}
    local source_x = properties["source_x"] or object.floortex_source_x
    local source_y = properties["source_y"] or object.floortex_source_y
    local source_width = properties["source_width"] or object.floortex_source_width
    local source_height = properties["source_height"] or object.floortex_source_height

    if source_x and source_y and source_width and source_height then
        return source_x, source_y, source_width, source_height
    end

    local map = Game.world and Game.world.map
    if not map then
        return object.x, object.y, object.width, object.height
    end

    local tile_width = map.tile_width
    local tile_height = map.tile_height
    local scan_left = source_x or object.x
    local scan_right = scan_left + (source_width or object.width)
    local scan_top = source_y or (object.y - (properties["source_scan_above"] or 160))
    local scan_bottom = source_y and (source_y + (source_height or object.height))
        or (object.y + object.height + (properties["source_scan_below"] or object.height))
    local min_x, min_y, max_x, max_y

    for _, layer in ipairs(layers or self:getFloortexProjectionLayers(object)) do
        local start_x = math.max(0, math.floor((scan_left - layer.x) / tile_width))
        local end_x = math.min(layer.map_width - 1, math.floor(((scan_right - 1) - layer.x) / tile_width))
        local start_y = math.max(0, math.floor((scan_top - layer.y) / tile_height))
        local end_y = math.min(layer.map_height - 1, math.floor(((scan_bottom - 1) - layer.y) / tile_height))

        for ty = start_y, end_y do
            for tx = start_x, end_x do
                local index = tx + (ty * layer.map_width) + 1
                local gid = layer.tile_data[index] or 0
                if TiledUtils.parseTileGid(gid) ~= 0 then
                    local tile_x = layer.x + (tx * tile_width)
                    local tile_y = layer.y + (ty * tile_height)
                    min_x = min_x and math.min(min_x, tile_x) or tile_x
                    min_y = min_y and math.min(min_y, tile_y) or tile_y
                    max_x = max_x and math.max(max_x, tile_x + tile_width) or (tile_x + tile_width)
                    max_y = max_y and math.max(max_y, tile_y + tile_height) or (tile_y + tile_height)
                end
            end
        end
    end

    if not min_x then
        return object.x, object.y, object.width, object.height
    end

    return source_x or min_x, source_y or min_y, source_width or (max_x - min_x), source_height or (max_y - min_y)
end

function Featherfall:syncFloortexSourceVisibility(object)
    if not object.projection_hide_source then
        return
    end

    local active = self:shouldDrawFloortexProjection(object)
    for _, layer in ipairs(self:getFloortexProjectionLayers(object)) do
        local entry = self.floortex_projection_layers[layer]
        if active then
            if not entry then
                entry = {
                    visible = layer.visible,
                    objects = {},
                }
                self.floortex_projection_layers[layer] = entry
            end
            entry.objects[object] = true
            layer.visible = false
        elseif entry and entry.objects[object] then
            entry.objects[object] = nil
            if not next(entry.objects) then
                layer.visible = entry.visible
                self.floortex_projection_layers[layer] = nil
            end
        end
    end
end

function Featherfall:restoreFloortexSourceVisibility(object)
    for layer, entry in pairs(self.floortex_projection_layers) do
        if entry.objects[object] then
            entry.objects[object] = nil
            if not next(entry.objects) then
                layer.visible = entry.visible
                self.floortex_projection_layers[layer] = nil
            end
        end
    end
    object.projection_source_visibility = {}
end

function Featherfall:restoreAllFloortexSourceVisibility()
    for layer, entry in pairs(self.floortex_projection_layers or {}) do
        if layer then
            layer.visible = entry.visible
        end
    end
    self.floortex_projection_layers = {}
end

function Featherfall:drawFloortexProjection(object)
    if not self:shouldDrawFloortexProjection(object) then
        return
    end

    local map = Game.world and Game.world.map
    if not map then
        return
    end

    local layers = self:getFloortexProjectionLayers(object)
    if #layers == 0 then
        return
    end

    local source_x, source_y, source_width, source_height = self:getFloortexSourceBounds(object, layers)
    if source_width <= 0 or source_height <= 0 then
        return
    end

    local dest_x, dest_y, dest_width, dest_height =
        self:getFloortexProjectionRect(object, source_x, source_y, source_width, source_height)
    local scale_x = dest_width / source_width
    local scale_y = dest_height / source_height
    local tile_width = map.tile_width
    local tile_height = map.tile_height

    for _, layer in ipairs(layers) do
        local r, g, b, a = layer:getDrawColor()
        local projection_opacity = object.properties and object.properties["projection_opacity"]
        if projection_opacity == nil then
            projection_opacity = object.properties and object.properties["opacity"]
        end
        Draw.setColor(r, g, b, projection_opacity or a or 1)

        local start_x = math.max(0, math.floor((source_x - layer.x) / tile_width))
        local end_x = math.min(layer.map_width - 1, math.floor(((source_x + source_width - 1) - layer.x) / tile_width))
        local start_y = math.max(0, math.floor((source_y - layer.y) / tile_height))
        local end_y = math.min(layer.map_height - 1, math.floor(((source_y + source_height - 1) - layer.y) / tile_height))

        for ty = start_y, end_y do
            for tx = start_x, end_x do
                local index = tx + (ty * layer.map_width) + 1
                local gid, flip_x, flip_y, flip_diag = TiledUtils.parseTileGid(layer.tile_data[index] or 0)
                local tileset, tile_id = map:getTileset(gid)
                if tileset then
                    local tile_x = layer.x + (tx * tile_width)
                    local tile_y = layer.y + (ty * tile_height)
                    local draw_x = (dest_x + ((tile_x - source_x) * scale_x)) - object.x
                    local draw_y = (dest_y + ((tile_y - source_y) * scale_y)) - object.y

                    love.graphics.push()
                    love.graphics.translate(draw_x, draw_y)
                    love.graphics.scale(scale_x, scale_y)
                    tileset:drawGridTile(tile_id, 0, 0, tile_width, tile_height, flip_x, flip_y, flip_diag)
                    love.graphics.pop()
                end
            end
        end
    end

    Draw.setColor(1, 1, 1)
end

function Featherfall:isEnabled(source)
    local explicit_enabled = self:getPropertyFrom(self:getSourceProperties(source), {"enabled", "platform_enabled"})
    if explicit_enabled == false then
        return false
    end

    local default = self:getLayeredProperty(
        source,
        {"enabled_by_default", "default_enabled", "platform_default_enabled"},
        {"platform_default_enabled"},
        "enabled_by_default",
        true
    )
    local flag = self:getLayeredProperty(
        source,
        {"enabled_flag", "platform_enabled_flag"},
        {"platform_enabled_flag"},
        "enabled_flag",
        "PLATFORMING_ENABLED"
    )
    local expected = self:getLayeredProperty(
        source,
        {"enabled_value", "platform_enabled_value"},
        {"platform_enabled_value"}
    )
    local value = Game:getFlag(flag, default)

    if expected ~= nil then
        return value == expected
    end

    return value and true or false
end

function Featherfall:setEnabled(value)
    Game:setFlag(self:getEnabledFlag(), value)
end

function Featherfall:setStatueRefusalCallback(callback)
    self.statue_refusal_callback = callback
end

function Featherfall:showStatueRefusal(source, player, text)
    if source and source.onPlatformRefused then
        source:onPlatformRefused(player, text)
    elseif text and Game.world and Game.world.showText then
        Game.world:showText(text)
    end
end

function Featherfall:shouldRefuseStatueUse(source, player)
    local properties = self:getSourceProperties(source)
    local callback = properties["refuse_callback"] or properties["platform_refuse_callback"] or self.statue_refusal_callback
    if type(callback) == "function" then
        local refused, text = callback(source, player)
        if refused then
            self:showStatueRefusal(source, player, text)
            return true
        end
    end

    local item = self:getPropertyFrom(properties, {"refuse_if_has_item", "refuse_item", "platform_refuse_item"})
    if item and Game.inventory and Game.inventory.hasItem and Game.inventory:hasItem(item) then
        self:showStatueRefusal(source, player, properties["refuse_text"] or properties["platform_refuse_text"])
        return true
    end

    return false
end

function Featherfall:beginTransition(source, target_mode)
    self.transition_source = source
    self.transition_timemax = type(source) == "table" and source.timer_max or self.constants.transition_timemax
    self.transition_extra_time = 0
    self.transition_mode = target_mode or self.transition_mode or 0

    if self.transition_mode == 1 and self.transition_timemax > self.constants.transition_extra_threshold then
        self.transition_extra_time = self.constants.transition_extra_time
    end

    self.transition_timer = self.transition_timemax + self.transition_extra_time
    self.transition_projection_hold = 0
end

function Featherfall:getPlayerFacing()
    if not (Game.world and Game.world.player) then
        return "right"
    end
    local facing = Game.world.player:getFacing()
    return facing == "left" and "left" or "right"
end

function Featherfall:getPlayerTransitionAnimation(default)
    local player = Game.world and Game.world.player
    local platform_state = player and player.platform_state
    return (platform_state and platform_state.current_animation) or default or "idle"
end

function Featherfall:getPlayerTransitionFrame()
    local player = Game.world and Game.world.player
    local platform_state = player and player.platform_state
    if platform_state and platform_state.attacking then
        return math.floor(platform_state.attack_frame) + 1
    end
end

function Featherfall:hidePlayerVisual()
    local player = Game.world and Game.world.player
    local sprite = player and player.sprite
    if not sprite then
        return
    end

    if self.transition_visual_owner and self.transition_visual_owner.sprite == sprite then
        sprite.visible = false
        return
    end

    self.transition_visual_owner = {
        sprite = sprite,
        visible = sprite.visible,
    }
    sprite.visible = false
end

function Featherfall:restorePlayerVisual()
    local owner = self.transition_visual_owner
    if owner and owner.sprite then
        owner.sprite.visible = owner.visible
    end
    self.transition_visual_owner = nil
end

function Featherfall:hideFollowerVisual(follower)
    if not follower then
        return
    end

    local owner = self.follower_visual_owners[follower]
    if owner then
        follower.visible = false
        return
    end

    self.follower_visual_owners[follower] = {
        visible = follower.visible,
        alpha = follower.alpha,
    }
    follower.visible = false
end

function Featherfall:restoreFollowerVisual(follower)
    local owner = self.follower_visual_owners[follower]
    if owner then
        follower.visible = owner.visible
        follower.alpha = owner.alpha or 1
        self.follower_visual_owners[follower] = nil
    end
end

function Featherfall:restoreAllFollowerVisuals()
    for follower, owner in pairs(self.follower_visual_owners or {}) do
        if follower then
            follower.visible = owner.visible
            follower.alpha = owner.alpha or 1
        end
    end
    self.follower_visual_owners = {}
end

function Featherfall:isFollowerVisualOwned(follower)
    return self.follower_visual_owners and self.follower_visual_owners[follower] ~= nil
end

function Featherfall:onTransitionPropFinished(prop)
    if prop ~= self.transition_prop then
        return
    end

    self.transition_prop = nil
    self:restorePlayerVisual()
end

function Featherfall:onFollowerTransitionPropFinished(follower, prop)
    if self.follower_transition_props[follower] ~= prop then
        return
    end

    self.follower_transition_props[follower] = nil
    self:restoreFollowerVisual(follower)
end

function Featherfall:getPlatformEnterPosition(source, player)
    if type(source) == "table" and source.getPlatformEnterPosition then
        return source:getPlatformEnterPosition(player)
    end
end

function Featherfall:getOverworldExitPosition(source, player)
    if type(source) == "table" and source.getPlatformOverworldExitPosition then
        return source:getPlatformOverworldExitPosition(player)
    end
    if type(source) == "table" and source.getOverworldExitPosition then
        return source:getOverworldExitPosition(player)
    end
end

function Featherfall:getOverworldExitPropPosition(source, player, exit_x, exit_y)
    if type(source) == "table" and source.getPlatformOverworldExitPropPosition then
        return source:getPlatformOverworldExitPropPosition(player, exit_x, exit_y)
    end
    if type(source) == "table" and source.getOverworldExitPropPosition then
        return source:getOverworldExitPropPosition(player, exit_x, exit_y)
    end
    if exit_x and exit_y then
        return exit_x + self.constants.exit_prop_x_offset, exit_y + self.constants.exit_prop_y_offset
    end
end

function Featherfall:spawnTransitionProp(animation_name, target_x, target_y, start_frame, options)
    if self.transition_prop and self.transition_prop.parent then
        self.transition_prop.suppress_finish = true
        self.transition_prop:remove()
    end
    self.transition_prop = nil

    if not (Game.world and Game.world.player and PlatformTransitionProp) then
        return nil
    end

    local player = Game.world.player
    local prop = PlatformTransitionProp(
        player.actor,
        player.x,
        player.y,
        self:getPlayerFacing(),
        animation_name or "jump_down",
        self.transition_timemax,
        target_x,
        target_y,
        start_frame,
        options
    )
    prop.on_finish = function(transition_prop)
        self:onTransitionPropFinished(transition_prop)
    end
    self.transition_prop = Game.world:spawnObject(prop)
    if Game.world.map and Game.world.map.object_layer then
        self.transition_prop:setLayer(Game.world.map.object_layer)
    else
        self.transition_prop:setLayer(player.layer)
    end
    self:hidePlayerVisual()
    return self.transition_prop
end

function Featherfall:spawnFollowerTransitionProp(follower, animation_name, start_x, start_y, target_x, target_y, start_frame, options)
    options = options or {}
    if not (Game.world and follower and PlatformTransitionProp) then
        return nil
    end

    local old_prop = self.follower_transition_props[follower]
    if old_prop and old_prop.parent then
        old_prop.suppress_finish = true
        old_prop:remove()
    end
    self.follower_transition_props[follower] = nil

    local facing = follower:getFacing()
    facing = facing == "left" and "left" or "right"
    local prop = PlatformTransitionProp(
        follower.actor,
        start_x or follower.x,
        start_y or follower.y,
        facing,
        animation_name or "jump_down",
        self.transition_timemax,
        target_x or follower.x,
        target_y or follower.y,
        start_frame,
        options
    )
    prop.on_finish = function(transition_prop)
        self:onFollowerTransitionPropFinished(follower, transition_prop)
    end

    self.follower_transition_props[follower] = Game.world:spawnObject(prop)
    self.follower_transition_props[follower]:setLayer(follower.layer)
    self:hideFollowerVisual(follower)
    return self.follower_transition_props[follower]
end

function Featherfall:putPlayerInState(source)
    if Game.world and Game.world.player and Game.world.player.state_manager:hasState(self.state) then
        Game.world.player:setState(self.state, { source = source })
        if self.transition_prop and self.transition_prop.parent then
            self.transition_prop:setTarget(Game.world.player.x, Game.world.player.y, self.constants.transition_platform_delay, "linear")
        end
        self.platforming = true
        return true
    end
    return false
end

function Featherfall:getPlatformFollowerIndex(follower)
    for index, other in ipairs(Game.world and Game.world.followers or {}) do
        if other == follower then
            return index
        end
    end
    return follower and follower.index or 1
end

function Featherfall:getPlatformFollowerOffset(follower, index)
    index = index or self:getPlatformFollowerIndex(follower)
    local spacing = self:getConfig("follower_spawn_spacing", 40)
    local side = index % 2 == 1 and -1 or 1
    local ring = math.floor((index + 1) / 2)
    return side * ring * spacing
end

function Featherfall:getPlatformFollowerHistoryDistance(follower, index)
    index = index or self:getPlatformFollowerIndex(follower)
    return math.max(index, 1) * 6
end

function Featherfall:putFollowersInState(source)
    if not (Game.world and Game.world.followers) then
        return
    end

    for index, follower in ipairs(Game.world.followers) do
        if follower.state_manager and follower.state_manager:hasState(self.state) then
            follower.state_manager:setState(self.state, {
                source = source,
                index = index,
                x_offset = self:getPlatformFollowerOffset(follower, index),
            })
        else
            follower.visible = false
            follower.alpha = 0
        end
    end
end

function Featherfall:restoreFollowersFromState()
    if not (Game.world and Game.world.followers) then
        return
    end

    for _, follower in ipairs(Game.world.followers) do
        if follower.state_manager and follower.state_manager.state == self.state then
            follower.state_manager:setState("WALK")
        end
        if not self:isFollowerVisualOwned(follower) then
            follower.visible = true
            follower.alpha = 1
        end
    end
end

function Featherfall:getOverworldFollowerPosition(index, player, facing)
    player = player or (Game.world and Game.world.player)
    if not player then
        return
    end

    facing = facing or (player.getFacing and player:getFacing()) or player.facing
    index = index or 1

    local offset_x, offset_y = 0, 0
    if facing == "left" then
        offset_x = 1
    elseif facing == "right" then
        offset_x = -1
    elseif facing == "up" then
        offset_y = 1
    elseif facing == "down" then
        offset_y = -1
    end

    local delay = FOLLOW_DELAY or 0
    local dist = (((index * delay) / (1 / 30)) * 4)
    return player.x + (offset_x * dist), player.y + (offset_y * dist), facing
end

function Featherfall:getFollowerOverworldExitPosition(follower, source)
    if type(source) == "table" and source.getPlatformFollowerOverworldExitPosition then
        local x, y = source:getPlatformFollowerOverworldExitPosition(follower)
        if x and y then
            return x, y
        end
    end
    if type(source) == "table" and source.getFollowerOverworldExitPosition then
        local x, y = source:getFollowerOverworldExitPosition(follower)
        if x and y then
            return x, y
        end
    end
    return self:getOverworldFollowerPosition(follower and follower.index or 1)
end

function Featherfall:resetFollowerHistoryForOverworld(state)
    local player = Game.world and Game.world.player
    if not (player and player.history) then
        return
    end

    local history_time = player.history_time or 0
    local facing = player.getFacing and player:getFacing() or player.facing
    local delay = FOLLOW_DELAY or 0
    local max_followers = Game.max_followers or #(Game.world.followers or {})

    player.history = {}
    table.insert(player.history, {
        x = player.x,
        y = player.y,
        facing = facing,
        time = history_time,
        state = state or "WALK",
        state_args = {},
    })
    for index = 1, max_followers do
        local x, y = self:getOverworldFollowerPosition(index, player, facing)
        table.insert(player.history, {
            x = x,
            y = y,
            facing = facing,
            time = history_time - (index * delay),
            state = state or "WALK",
            state_args = {},
        })
    end

    if player.resetFollowerHistory then
        player:resetFollowerHistory()
    end
end

function Featherfall:enterPlatformMode(source)
    if not self:isEnabled(source) then
        return false
    end
    if not (Game.world and Game.world.player) then
        return false
    end
    if Game.world.player.state == self.state then
        return true
    end

    self:beginTransition(source, 1)
    Assets.playSound(self.sounds.enter)
    local target_x, target_y = self:getPlatformEnterPosition(source, Game.world.player)
    self:spawnTransitionProp("jump_down", target_x, target_y, nil, {kind = "enter", manual_speed = 0.25})
    self.pending_platform = true
    return true
end

function Featherfall:exitPlatformMode(source, options)
    options = options or {}
    if not (Game.world and Game.world.player) then
        return false
    end
    if Game.world.player.state ~= self.state then
        return true
    end

    local target_x, target_y = self:getOverworldExitPosition(source, Game.world.player)
    local prop_target_x, prop_target_y = self:getOverworldExitPropPosition(source, Game.world.player, target_x, target_y)
    self:beginTransition(source, 0)
    Assets.playSound(self.sounds.exit)
    local animation_name = options.animation_name or self:getPlayerTransitionAnimation("idle")
    local start_frame = options.start_frame or self:getPlayerTransitionFrame()
    self:spawnTransitionProp(animation_name, prop_target_x, prop_target_y, start_frame, {kind = "exit", manual_speed = 0.25})
    if target_x and target_y then
        Game.world.player.x = target_x
        Game.world.player.y = target_y
        Object.uncache(Game.world.player)
    end
    self.pending_platform = false
    self.platforming = false
    Game.world.player:setState("WALK")
    if self.transition_prop and self.transition_prop.parent then
        self:hidePlayerVisual()
    end
    return true
end

function Featherfall:togglePlatformMode(source)
    if Game.world and Game.world.player and Game.world.player.state == self.state then
        return self:exitPlatformMode(source)
    else
        return self:enterPlatformMode(source)
    end
end

function Featherfall:postUpdate()
    self:updateActionUI()

    if self.transition_timer <= 0 then
        self.transition_projection_hold = MathUtils.approach(self.transition_projection_hold, 0, DTMULT)
        return
    end

    local was_transitioning = self.transition_timer > 0
    self.transition_timer = MathUtils.approach(self.transition_timer, 0, DTMULT)
    if was_transitioning and self.transition_timer <= 0 and self.transition_mode == 0 then
        self.transition_projection_hold = 2
    end
    if self.pending_platform and self.transition_timer <= self.transition_timemax - self.constants.transition_platform_delay then
        self.pending_platform = false
        self:putPlayerInState(self.transition_source)
    end
end

function Featherfall:unload()
    self:resetControllerState()
end

function Featherfall:cleanup()
    self:resetControllerState()
end

return Featherfall
