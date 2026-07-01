---@class PlatformAttackHitbox : Object
local PlatformAttackHitbox, super = Class(Object)

local SLASH_POLYGONS = {
    ["party/kris/platform/slash_ground"] = {
        [0] = {{-18, 15}, {-9, -6}, {-8, -8}, {-4, -15}, {30, -27}, {32, -27}, {35, -24}, {37, -20}, {39, -10}, {39, 0}, {37, 6}, {35, 9}, {31, 14}, {30, 15}, {26, 18}, {22, 20}, {16, 22}, {12, 23}, {-4, 23}, {-13, 20}, {-15, 19}, {-18, 16}},
        [1] = {{-13, 14}, {-8, -4}, {-5, -12}, {12, -33}, {15, -36}, {17, -37}, {25, -37}, {28, -36}, {34, -30}, {36, -25}, {37, -21}, {39, -4}, {39, -1}, {38, 3}, {37, 6}, {35, 11}, {33, 15}, {31, 18}, {28, 22}, {24, 27}, {19, 33}, {-13, 17}},
        [2] = {{-24, -33}, {-18, -37}, {-10, -41}, {-7, -42}, {-1, -43}, {13, -43}, {17, -42}, {23, -40}, {29, -37}, {32, -35}, {41, -26}, {43, -23}, {47, -15}, {48, -12}, {49, -6}, {49, 0}, {47, 8}, {46, 11}, {45, 13}, {40, 18}, {33, 22}, {23, 27}, {20, 28}, {15, 29}, {-13, 17}, {-24, -29}},
    },
    ["party/kris/platform/slash_air"] = {
        [0] = {{-20, 15}, {-11, -6}, {-10, -8}, {-6, -15}, {28, -27}, {30, -27}, {33, -24}, {35, -20}, {37, -10}, {37, -1}, {35, 5}, {34, 7}, {32, 10}, {29, 14}, {28, 15}, {22, 19}, {13, 22}, {9, 23}, {-1, 23}, {-7, 22}, {-11, 21}, {-14, 20}, {-18, 18}, {-20, 16}},
        [1] = {{-12, 18}, {-10, -4}, {-7, -12}, {10, -33}, {13, -36}, {15, -37}, {23, -37}, {26, -36}, {32, -30}, {34, -25}, {35, -21}, {37, -4}, {37, -1}, {36, 3}, {35, 6}, {33, 11}, {31, 15}, {29, 18}, {26, 22}, {22, 27}, {17, 33}, {-11, 22}, {-12, 21}},
        [2] = {{-30, -7}, {-29, -11}, {-24, -21}, {-15, -30}, {-9, -33}, {-6, -34}, {-1, -35}, {13, -35}, {17, -34}, {20, -33}, {24, -31}, {30, -27}, {35, -22}, {40, -12}, {41, -8}, {41, 3}, {40, 7}, {35, 17}, {32, 22}, {23, 31}, {20, 33}, {18, 34}, {16, 34}, {-22, 17}, {-26, 13}, {-29, 7}, {-30, 3}},
    },
    ["party/flowery/platform/slash_ground"] = {
        [0] = {{8, -20}, {56, -20}, {62, -14}, {62, 18}, {54, 26}, {10, 24}},
        [1] = {{0, -20}, {50, -20}, {58, -10}, {58, 26}, {48, 34}, {0, 30}},
        [2] = {{-5, -34}, {64, -34}, {70, -24}, {70, 36}, {58, 48}, {-5, 38}},
    },
    ["party/flowery/platform/kick_crescent"] = {
        [0] = {{-5, -34}, {64, -34}, {70, -24}, {70, 36}, {58, 48}, {-5, 38}},
        [1] = {{-5, -34}, {64, -34}, {70, -24}, {70, 36}, {58, 48}, {-5, 38}},
        [2] = {{-5, -34}, {64, -34}, {70, -24}, {70, 36}, {58, 48}, {-5, 38}},
    },
}

local SLASH_ANCHOR_OFFSETS = {
    ["party/kris/platform/slash_ground"] = {0, -17},
    ["party/kris/platform/slash_air"] = {0, -17},
}

function PlatformAttackHitbox:init(owner, facing, animation, hitbox_index, image_index, animation_name)
    super.init(self, owner.x, owner.y)

    self.owner = owner
    self.facing = facing or "right"
    self.animation = animation
    self.animation_name = animation_name
    self.hitbox_index = hitbox_index or 0
    self.image_index = image_index or ({[0] = 1, [1] = 5, [2] = 9})[self.hitbox_index] or 0
    self.lifetime = 3
    self.platform_attack_hitbox = true
    self.hit_targets = {}
    self.visible = true
    self.collidable = true
    self:setScale(math.abs(owner.scale_x or 1), math.abs(owner.scale_y or owner.scale_x or 1))

    self:setSlashHitbox(animation)
end

function PlatformAttackHitbox:mirrorPoints(points)
    local mirrored = {}
    for i = #points, 1, -1 do
        table.insert(mirrored, {-points[i][1], points[i][2]})
    end
    return mirrored
end

function PlatformAttackHitbox:copyPoints(points)
    local copied = {}
    for _, point in ipairs(points) do
        table.insert(copied, {point[1], point[2]})
    end
    return copied
end

function PlatformAttackHitbox:offsetPoints(points, x, y)
    if (x or 0) == 0 and (y or 0) == 0 then
        return points
    end

    for _, point in ipairs(points) do
        point[1] = point[1] + (x or 0)
        point[2] = point[2] + (y or 0)
    end
    return points
end

function PlatformAttackHitbox:getOwnerState()
    return self.owner and self.owner.platform_state
end

function PlatformAttackHitbox:getDefaultHitstop()
    local state = self:getOwnerState()
    local entity = state and state.entity
    local grounded = entity and entity.grounded
    if self.hitbox_index == 2 then
        return grounded and 7 or 8
    end
    return grounded and 4 or 3
end

function PlatformAttackHitbox:getAnimationMetadata(animation)
    if animation and animation.metadata then
        return animation.metadata
    end
    local state = self:getOwnerState()
    if state and state.getPlatformSpriteMetadata and animation and animation.sprite then
        return state:getPlatformSpriteMetadata(animation.sprite)
    end
end

function PlatformAttackHitbox:getFallbackPolygon(animation)
    local metadata = self:getAnimationMetadata(animation)
    if metadata then
        local left = metadata.margin_left - metadata.origin_x
        local right = metadata.margin_right - metadata.origin_x
        local top = metadata.margin_top - metadata.origin_y
        local bottom = metadata.margin_bottom - metadata.origin_y
        return {
            {left, top},
            {right, top},
            {right, bottom},
            {left, bottom},
        }
    end

    return {
        {-25, -43},
        {50, -43},
        {50, 36},
        {-25, 36},
    }
end

function PlatformAttackHitbox:getSlashPolygon(animation)
    local by_sprite = animation and animation.sprite and SLASH_POLYGONS[animation.sprite]
    local points = by_sprite and (by_sprite[self.hitbox_index] or by_sprite[2])
    points = points and self:copyPoints(points) or self:getFallbackPolygon(animation)
    local anchor_offset = animation and animation.sprite and SLASH_ANCHOR_OFFSETS[animation.sprite]
    if anchor_offset then
        points = self:offsetPoints(points, anchor_offset[1], anchor_offset[2])
    end

    if self.facing == "left" then
        points = self:mirrorPoints(points)
    end

    return points
end

function PlatformAttackHitbox:setDebugRectFromPoints(points)
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    for _, point in ipairs(points) do
        min_x = math.min(min_x, point[1])
        min_y = math.min(min_y, point[2])
        max_x = math.max(max_x, point[1])
        max_y = math.max(max_y, point[2])
    end

    self.debug_rect = {min_x, min_y, max_x - min_x, max_y - min_y}
end

function PlatformAttackHitbox:setSlashHitbox(animation)
    local points = self:getSlashPolygon(animation)
    self.collider = PolygonCollider(self, points)
    self:setDebugRectFromPoints(points)
end

function PlatformAttackHitbox:isOwnerAttacking()
    local state = self.owner and self.owner.platform_state
    if state then
        return self.owner.state == Featherfall.state and state.attacking
    end
    return true
end

function PlatformAttackHitbox:update()
    super.update(self)

    if not self.owner or self.owner.removed or self.owner.parent == nil then
        self:remove()
        return
    end
    if not self:isOwnerAttacking() then
        self:remove()
        return
    end

    self.x = self.owner.x
    self.y = self.owner.y
    Object.uncache(self)

    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    self:checkAttackables()

    self.lifetime = self.lifetime - DTMULT
    if self.lifetime <= 0 then
        self:remove()
    end
end

function PlatformAttackHitbox:checkAttackables()
    if not Game.world then
        return
    end

    for _, obj in ipairs(Game.world.children) do
        local hit_callback = obj.onPlatformAttackHit
        if obj.platform_attackable and hit_callback and not self.hit_targets[obj] and self:collidesWith(obj) then
            self.hit_targets[obj] = true
            hit_callback(obj, self)
        end
    end
end

function PlatformAttackHitbox:doHit(hitstop)
    self.lifetime = math.min(self.lifetime, 1)
    if hitstop == nil then
        hitstop = self:getDefaultHitstop()
    end
    if hitstop and hitstop > 0 and Featherfall and Featherfall.requestPlatformHitstop then
        Featherfall:requestPlatformHitstop(hitstop)
    end
end

function PlatformAttackHitbox:drawDebug()
    if self.collider then
        self.collider:draw(1, 0.85, 0.1, 0.85)
    end
end

function PlatformAttackHitbox:draw()
    if DEBUG_RENDER then
        self:drawDebug()
    end
end

return PlatformAttackHitbox
