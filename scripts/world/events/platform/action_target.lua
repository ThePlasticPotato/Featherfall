---@class PlatformActionTarget : Event
local PlatformActionTarget, super = Class(Event)

local function propertyBool(value, default)
    if value == nil then
        return default
    elseif value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
    value = string.lower(tostring(value))
    return value == "true" or value == "1" or value == "yes"
end

function PlatformActionTarget:init(data)
    super.init(self, data)

    self.properties = data.properties or {}
    self.solid = false
    self.platform_action_target_event = true
    self.visible = self.properties["visible"] == true
    self.active = self.properties["active"] ~= false
    self.free_will = self.properties["free_will"] == true
        or self.properties["auto_act"] == true
        or self.properties["freewill"] == true
    local blocked = self.properties["blocked"]
    self.blocked = blocked == true and true or (tonumber(blocked) or false)
    self.protected = self.properties["protected"] == true
    self.button1_activated = self.properties["button1_activated"] == true
    self.opens_menu = self.properties["opens_menu"] == true
        or self.properties["menu_target"] == true
        or self.properties["closet"] == true
    self.platform_action_target = propertyBool(self.properties["platform_action"], false)
    self.hang_xoffset = tonumber(
        self.properties["hang_xoffset"]
        or self.properties["platform_hang_xoffset"]
    ) or 0
    self.hang_yoffset = tonumber(
        self.properties["hang_yoffset"]
        or self.properties["platform_hang_yoffset"]
    ) or 0
    self.platform_long = propertyBool(self.properties["platform_long"], false)
    local action_kind = self.properties["action"]
        or self.properties["kind"]
        or self.properties["character"]
        or self.properties["char"]
    if self.opens_menu and (action_kind == nil or self:normalizeKind(action_kind) == "none") then
        action_kind = "soul"
    end
    self.base_action_kind = self:normalizeKind(
        action_kind or "any"
    )
    self.action_kind = self.base_action_kind
    self.menu_margin = tonumber(self.properties["menu_margin"] or self.properties["menu_radius"])
    self.objectname = self.properties["objectname"] or self.properties["object_name"] or "AN_OBJECT"
    self.description = self.properties["description"] or "DESCRIPTION_UNSET"
    self.action_label = self.properties["action_label"] or self.properties["label"]
    self.action_color = PlatformActionUtils.parseColor(self.properties["action_color"] or self.properties["target_color"] or self.properties["color"])
    self.action_label_color = PlatformActionUtils.parseColor(self.properties["action_label_color"] or self.properties["label_color"])
    self.base_objectname = self.objectname
    self.base_description = self.description
    self.base_action_label = self.action_label
    self.base_action_color = self.action_color
    self.base_action_label_color = self.action_label_color
    self.newx = tonumber(self.properties["target_x"] or self.properties["newx"]) or -1
    self.newy = tonumber(self.properties["target_y"] or self.properties["newy"]) or -1
    self.target_x = self.newx ~= -1 and self.newx or nil
    self.target_y = self.newy ~= -1 and self.newy or nil
    self.activetimer = 0
    self.selected_timer = 0
    self.hovered = false
    self.last_hovered = false
    self.hoverlerp = 0
    self.angle = 0
    self.is_valid_target = false
    self.cx = self.target_x or (self.x + ((self.width or 0) / 2))
    self.cy = self.target_y or (self.y + ((self.height or 0) / 2))
    self.last_action_kind = nil
    self.last_action_state = nil
    self.ripple_index = nil
    self.ripple_timer = 0
    self.ripple = nil
    self.attached_platform = nil
    self.platform_action_override = nil
end

function PlatformActionTarget:getPlatformActionPresentation(kind, state, data)
    local presentation = {}
    if self.action_label ~= nil then
        presentation.label = self.action_label
    end
    if self.action_color ~= nil then
        presentation.color = self.action_color
    end
    if self.action_label_color ~= nil then
        presentation.label_color = self.action_label_color
    end
    if next(presentation) then
        return presentation
    end
end

function PlatformActionTarget:normalizeKind(kind)
    return string.lower(tostring(kind or "any"))
end

function PlatformActionTarget:isAvailableFor(kind)
    if not (self.active and not self.blocked) then
        return false
    end
    kind = self:normalizeKind(kind)
    return self.action_kind == "any" or self.action_kind == "all" or self.action_kind == kind
end

function PlatformActionTarget:update()
    super.update(self)
    self:updateActionPlatformState()
    self.cx = self.target_x or (self.x + ((self.width or 0) / 2))
    self.cy = self.target_y or (self.y + ((self.height or 0) / 2))
    local paused = Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused()
    if not paused then
        if self.active and not self.blocked then
            self.activetimer = self.activetimer + DTMULT
        else
            self.activetimer = 0
        end
    end
    self.last_hovered = self.hovered
    self.hoverlerp = MathUtils.approach(self.hoverlerp, self.hovered and 1 or 0, 0.25 * DTMULT)
    if not paused then
        self.selected_timer = MathUtils.approach(self.selected_timer, 0, DTMULT)
        self:updateRipple()
    elseif self.ripple and self.ripple.parent then
        self.ripple.visible = false
    end
end

function PlatformActionTarget:getActionPlatformState()
    if not self.platform_action_target then
        return
    end
    for _, follower in ipairs(Game.world and Game.world.followers or {}) do
        local state = follower.platform_state
        if state
            and state.action_platform_target == self
            and (state.action_platform_mode or 0) > 0
        then
            return state
        end
    end
end

function PlatformActionTarget:restoreBaseActionState()
    self.platform_action_override = nil
    self.action_kind = self.base_action_kind
    self.objectname = self.base_objectname
    self.description = self.base_description
    self.action_label = self.base_action_label
    self.action_color = self.base_action_color
    self.action_label_color = self.base_action_label_color
end

function PlatformActionTarget:applyPlatformActionOverride(override)
    self.platform_action_override = override
    self.action_kind = self:normalizeKind(override.kind or override.action or override.target_kind or "none")
    self.objectname = override.objectname or override.object_name or override.name or self.base_objectname
    self.description = override.description or self.base_description
    self.action_label = override.action_label or override.label or self.base_action_label
    self.action_color = PlatformActionUtils.parseColor(override.action_color or override.target_color or override.color) or self.base_action_color
    self.action_label_color = PlatformActionUtils.parseColor(override.action_label_color or override.label_color) or self.base_action_label_color
end

function PlatformActionTarget:updateActionPlatformState()
    if not self.platform_action_target then
        return
    end

    local state = self:getActionPlatformState()
    local mode = state and state.action_platform_mode or 0
    local attached = state and mode > 0 and {
        state = state,
        mode = mode,
        ready = mode == 3,
    } or nil
    self.attached_platform = attached

    if attached and attached.ready then
        local override = state.getActionPlatformTargetOverride and state:getActionPlatformTargetOverride(self)
        attached.override = override
        if override then
            self:applyPlatformActionOverride(override)
        else
            self.platform_action_override = nil
            self.action_kind = "none"
            self.objectname = self.base_objectname
            self.description = self.base_description
            self.action_label = self.base_action_label
            self.action_color = self.base_action_color
            self.action_label_color = self.base_action_label_color
        end
    else
        self:restoreBaseActionState()
    end

    if attached and attached.ready and self.blocked and state.dropOffActionPlatform then
        state:dropOffActionPlatform(false)
    end
end

function PlatformActionTarget:getRippleIndex()
    if self.ripple_index then
        return self.ripple_index
    end

    local index = 0
    for _, target in ipairs(Featherfall:getActionTargets()) do
        index = index + 1
        if target == self then
            self.ripple_index = index
            return index
        end
    end
    return 1
end

function PlatformActionTarget:canShowRipple()
    if not (Featherfall and Featherfall.isPlatformModeActive and Featherfall:isPlatformModeActive()) then
        return false
    end
    local player = Game.world and Game.world.player
    local player_state = player and player.platform_state
    if player_state and player_state.targetmode then
        return false
    end
    if not (self.active and self.blocked ~= true and self.blocked ~= 1) then
        return false
    end
    if self.protected or self.blocked == 2 or self.action_kind == "none" then
        return false
    end
    if player_state and player_state.isActionKindReady and not player_state:isActionKindReady(self.action_kind) then
        return false
    end
    return true
end

function PlatformActionTarget:updateRipple()
    if self.ripple and self.ripple.parent then
        self.ripple.x = self.cx
        self.ripple.y = self.cy
    end
    if not self:canShowRipple() then
        if self.ripple and self.ripple.parent then
            self.ripple.visible = false
        end
        return
    end
    if self.ripple and self.ripple.parent then
        self.ripple.visible = true
    end

    local old_timer = self.ripple_timer
    self.ripple_timer = self.ripple_timer + DTMULT
    if self.ripple and self.ripple.parent then
        return
    end

    local index = self:getRippleIndex()
    local phase = (index * 15) % 60
    for frame = math.floor(old_timer) + 1, math.floor(self.ripple_timer) do
        if frame > 0 and (frame % 60) == phase then
            local color = Featherfall:getActionColor(self.action_kind, self)
            self.ripple = Featherfall:makeRipple(self.cx, self.cy, {
                life = 100,
                color = color,
                radmax = 32,
                radstart = 4,
                thickness = 12,
                curve = 0,
                yratio = 1,
                blend = 1,
                banding = 2,
                fading = true,
                layer = WORLD_LAYERS["above_events"],
            })
            break
        end
    end
end

function PlatformActionTarget:select(follower_state, action_data)
    self.selected_timer = 8
    if self.opens_menu and Game.world and Game.world.openMenu then
        Game.world:openMenu(nil, WORLD_LAYERS["ui"] + 1)
        return true
    end
    if self.onPlatformSelect then
        return self:onPlatformSelect(follower_state, action_data)
    end
    return true
end

function PlatformActionTarget:performFollowerAction(kind, follower_state, action_data)
    self.last_action_kind = kind
    self.last_action_state = follower_state
    kind = self:normalizeKind(kind)
    local override = self.platform_action_override
    if override then
        local callback = override.perform or override.onPerform or override.onAction
        if callback then
            return callback(self, follower_state, action_data, kind, override)
        end
    end
    if self.onPlatformAction then
        return self:onPlatformAction(kind, follower_state, action_data)
    end
    return true
end

function PlatformActionTarget:draw()
    if not DEBUG_RENDER then
        return
    end

    local alpha = self.selected_timer > 0 and 0.85 or 0.45
    love.graphics.setColor(0.35, 0.9, 1, alpha)
    love.graphics.rectangle("line", 0, 0, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
end

return PlatformActionTarget
