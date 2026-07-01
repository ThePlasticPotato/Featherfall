---@class Object : Object
local Object, super = HookSystem.hookScript(Object)

local function shouldUsePlatformDrawTransform(object)
    if not (Featherfall and Featherfall.isPlatformModeActive and Featherfall:isPlatformModeActive()) then
        return false
    end
    local world = Game and Game.world
    if not world then
        return false
    end

    local current = object
    while current do
        if current == world then
            return true
        end
        current = current.parent
    end
    return false
end

function Object:update()
    if self ~= (Game and Game.world) then
        return super.update(self)
    end

    self:updatePhysicsTransform()
    self:updateGraphicsTransform()
    self:updateChildren()

    if Featherfall and Featherfall.updatePlatformMotionForPhysics then
        Featherfall:updatePlatformMotionForPhysics()
    end
    if Featherfall and Featherfall.updatePlatformCamera then
        Featherfall:updatePlatformCamera()
    end
    if Featherfall and Featherfall.updatePlatformPauseCoyote then
        Featherfall:updatePlatformPauseCoyote()
    end
    if Featherfall and Featherfall.updatePlatformHitstop then
        Featherfall:updatePlatformHitstop()
    end

    if self.camera then
        self.camera:update()
    end
end

function Object:preDraw(dont_transform)
    if not dont_transform and shouldUsePlatformDrawTransform(self) then
        local transform = love.graphics.getTransformRef()
        -- Deltarune platforming does not apply Kristal's inherited per-object
        -- pixel snap. Keep platform objects in the same subpixel reference frame;
        -- object-specific DR rounding should happen in the object/camera logic.
        self:applyTransformTo(transform)
        love.graphics.replaceTransform(transform)

        self._last_draw_scale_x = CURRENT_SCALE_X
        self._last_draw_scale_y = CURRENT_SCALE_Y

        CURRENT_SCALE_X = CURRENT_SCALE_X * self.scale_x
        CURRENT_SCALE_Y = CURRENT_SCALE_Y * self.scale_y
        if self.camera then
            CURRENT_SCALE_X = CURRENT_SCALE_X * self.camera.zoom_x
            CURRENT_SCALE_Y = CURRENT_SCALE_Y * self.camera.zoom_y
        end

        Draw.setColor(self:getDrawColor())
        Draw.pushScissor()
        self:applyScissor()
        return
    end

    return super.preDraw(self, dont_transform)
end

return Object
