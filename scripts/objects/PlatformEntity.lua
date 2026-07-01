---@class PlatformEntity : Class
---@overload fun(owner: Object, constants?: table) : PlatformEntity
local PlatformEntity = Class()

function PlatformEntity:init(owner, constants)
    self.owner = owner
    self.constants = constants or {}

    self.hspeed = 0
    self.vspeed = 0
    self.grounded = false
    self.grounded_prev = false
    self.ground = nil
    self.landspd = 0
    self.wallhitspd = 0
    self.floorY = 0
    self.grounded_lastX = owner.x
    self.ignore_barriers = false
    self.wallcollision = true
    self.can_ride_entities = false
    self.climbing = false
    self.last_platform_dx = 0
    self.last_platform_dy = 0
    self.precarried_ground = nil
    self.precarried_dx = 0
    self.precarried_dy = 0

    self.hitbox = {0, 0, 20, 38}
    self.open_x = owner.x
    self.open_y = owner.y
    self.stuck_time = 0

    self.jumpbuffer = 0
    self.jump_coyote_time = 0
    self.jumpsquat = 0
    self.jump_time = 0
    self.jumping = 0
    self.launched_jump = false
    self.jump_ceiling_blocked = false
end

function PlatformEntity:reset(settings)
    settings = settings or {}

    self.hspeed = settings.hspeed or 0
    self.vspeed = settings.vspeed or 0
    self.grounded = settings.grounded or false
    self.grounded_prev = self.grounded
    self.ground = nil
    self.landspd = 0
    self.wallhitspd = 0
    self.floorY = 0
    self.grounded_lastX = self.owner.x
    self.ignore_barriers = settings.ignore_barriers or false
    self.wallcollision = settings.wallcollision ~= false
    self.can_ride_entities = settings.can_ride_entities or false
    self.climbing = settings.climbing or false
    self.last_platform_dx = 0
    self.last_platform_dy = 0
    self.precarried_ground = nil
    self.precarried_dx = 0
    self.precarried_dy = 0

    self.open_x = self.owner.x
    self.open_y = self.owner.y
    self.stuck_time = 0

    self.jumpbuffer = 0
    self.jump_coyote_time = 0
    self.jumpsquat = 0
    self.jump_time = 0
    self.jumping = 0
    self.launched_jump = false
    self.jump_ceiling_blocked = false
end

function PlatformEntity:setHitbox(x, y, width, height)
    self.hitbox = {x or 0, y or 0, width or 0, height or 0}
end

function PlatformEntity:getLocalRect(x_offset, y_offset, width, height)
    return self.hitbox[1] + (x_offset or 0),
        self.hitbox[2] + (y_offset or 0),
        width or self.hitbox[3],
        height or self.hitbox[4]
end

function PlatformEntity:getColliderAt(x, y, x_offset, y_offset, width, height)
    local left, top, hit_width, hit_height = self:getWorldBoundsAt(x, y, x_offset, y_offset, width, height)
    return Hitbox(self.owner.parent or Game.world, left, top, hit_width, hit_height)
end

function PlatformEntity:getWorldBoundsAt(x, y, x_offset, y_offset, width, height)
    local left, top, hit_width, hit_height = self:getLocalRect(x_offset, y_offset, width, height)
    local origin_x, origin_y = self.owner:getOriginExact()
    local world_left = x - origin_x + left
    local world_top = y - origin_y + top
    return world_left, world_top, hit_width, hit_height, world_left + hit_width, world_top + hit_height
end

function PlatformEntity:collidesWithEvent(event, x, y, x_offset, y_offset, width, height)
    if not (event and event.collider) then
        return false
    end
    return self:getColliderAt(x, y, x_offset, y_offset, width, height):collidesWith(event.collider)
end

function PlatformEntity:getEventTop(event)
    return event.y
end

function PlatformEntity:getEventLeft(event)
    return event.x
end

function PlatformEntity:getEventRight(event)
    return event.x + event.width
end

function PlatformEntity:getEventBottom(event)
    return event.y + event.height
end

function PlatformEntity:getPlatformEvents()
    if not (Game.world and Game.world.map) then
        return {}
    end
    local events = {}
    for _, event in ipairs(Game.world.map.events or {}) do
        table.insert(events, event)
    end
    if Featherfall and Featherfall.getDynamicPlatforms then
        for _, platform in ipairs(Featherfall:getDynamicPlatforms()) do
            table.insert(events, platform)
        end
    end
    return events
end

function PlatformEntity:isBlockEvent(event)
    return event
        and event.platform_collision ~= false
        and event.platform_block
end

function PlatformEntity:isFloorEvent(event)
    return event
        and event.platform_collision ~= false
        and (
        event.platform_floor
        or event.platform_floortex_floor
        or event.platform_floortex_yplat
    )
end

function PlatformEntity:isRideableEvent(event)
    return event
        and event.platform_collision ~= false
        and event.rideable
        and event.is_entity
end

function PlatformEntity:getBlocks()
    local blocks = {}
    for _, event in ipairs(self:getPlatformEvents()) do
        if self:isBlockEvent(event) then
            table.insert(blocks, event)
        end
    end
    return blocks
end

function PlatformEntity:getFloors()
    local floors = {}
    for _, event in ipairs(self:getPlatformEvents()) do
        if self:isFloorEvent(event) then
            table.insert(floors, event)
        end
    end
    return floors
end

function PlatformEntity:getRideables()
    local rideables = {}
    for _, event in ipairs(self:getPlatformEvents()) do
        if self:isRideableEvent(event) then
            table.insert(rideables, event)
        end
    end
    return rideables
end

function PlatformEntity:getSlopeSampleX(ground, x, y)
    local left, _, _, _, right = self:getWorldBoundsAt(x or self.owner.x, y or self.owner.y)
    local x1 = ground.x1 or ground.slope_x1 or ground.x
    local x2 = ground.x2 or ground.slope_x2 or (ground.x + ground.width)
    local min_x, max_x = math.min(x1, x2), math.max(x1, x2)

    if (ground.plattype or ground.slope_type or 0) == 1 then
        local origin_x = x or self.owner.x
        if origin_x >= min_x and origin_x <= max_x then
            return origin_x
        end
        return nil
    end

    if ground.slope_anchor == "left" then
        return left >= min_x and left <= max_x and left or nil
    elseif ground.slope_anchor == "center" then
        local center = (left + right) / 2
        return center >= min_x and center <= max_x and center or nil
    elseif ground.slope_anchor == "right" then
        return right >= min_x and right <= max_x and right or nil
    end

    if (ground.image_xscale or ground.scale_x or 1) >= 0 then
        if right >= min_x and right <= max_x then
            return right
        elseif left >= min_x and left <= max_x then
            return left
        end
    else
        if left >= min_x and left <= max_x then
            return left
        elseif right >= min_x and right <= max_x then
            return right
        end
    end
end

function PlatformEntity:getGroundTopAt(ground, x, y)
    if not ground then
        return
    end

    if ground.is_slope or ground.platform_slope then
        local x1 = ground.x1 or ground.slope_x1 or ground.x
        local y1 = ground.y1 or ground.slope_y1 or ground.y
        local x2 = ground.x2 or ground.slope_x2 or (ground.x + ground.width)
        local y2 = ground.y2 or ground.slope_y2 or ground.y
        if x1 == x2 then
            return math.min(y1, y2)
        end

        local floor_x = self:getSlopeSampleX(ground, x, y)
        if not floor_x then
            return
        end

        if (ground.plattype or ground.slope_type or 0) == 1 then
            local span = math.max(math.abs(x1 - x2), 0.001)
            local height = y2 - y1
            return ground.y - (math.sin((math.pi * (floor_x - x1)) / span) * math.abs(height))
        end

        local t = (floor_x - x1) / (x2 - x1)
        local floor_y = y1 + ((y2 - y1) * t)
        return MathUtils.clamp(floor_y, math.min(y1, y2), math.max(y1, y2))
    end

    if ground.is_entity and ground.bbox_top_r then
        return ground.y - ground.bbox_top_r
    end
    return self:getEventTop(ground)
end

function PlatformEntity:isAboveGround(ground, x, y, extra)
    extra = extra or 0
    local _, _, _, _, _, bottom = self:getWorldBoundsAt(x, y)
    local ground_y = self:getGroundTopAt(ground, x, y)
    if not ground_y then
        return false
    end
    return bottom <= ground_y + extra and bottom + extra >= ground_y
end

function PlatformEntity:overlapsRect(event, x, y)
    return self:collidesWithEvent(event, x, y)
end

function PlatformEntity:findBlockAt(x, y, ignored)
    for _, block in ipairs(self:getBlocks()) do
        if block ~= ignored and not (block.is_barrier and self.ignore_barriers) and self:overlapsRect(block, x, y) then
            return block
        end
    end
end

function PlatformEntity:findEmbeddedBlockAt(x, y)
    local _, _, width, height = self:getLocalRect()
    local inset = 1
    if width <= inset * 2 or height <= inset * 2 then
        return self:findBlockAt(x, y)
    end

    for _, block in ipairs(self:getBlocks()) do
        if not (block.is_barrier and self.ignore_barriers)
            and self:collidesWithEvent(block, x, y, inset, inset, width - (inset * 2), height - (inset * 2))
        then
            return block
        end
    end
end

function PlatformEntity:findGroundAt(x, y, extra)
    extra = extra or 0
    local _, _, width, height = self:getLocalRect()
    local best = nil
    local best_y = math.huge
    for _, floor in ipairs(self:getFloors()) do
        local floor_top = self:getGroundTopAt(floor, x, y)
        local slope = floor.is_slope or floor.platform_slope
        local check_extra = extra
        if slope then
            check_extra = math.max(check_extra, math.ceil(math.abs(self.hspeed or 0) + math.abs(self.vspeed or 0) + 6))
        end
        local collides = slope or self:collidesWithEvent(floor, x, y, 0, height - 1, width, extra + 2)
        if floor_top and collides then
            if self:isAboveGround(floor, x, y, check_extra) and floor_top < best_y then
                best = floor
                best_y = floor_top
            end
        end
    end

    for _, block in ipairs(self:getBlocks()) do
        local block_top = self:getGroundTopAt(block, x, y)
        if block_top and not (block.is_barrier and self.ignore_barriers) and self:collidesWithEvent(block, x, y, 0, height - 1, width, extra + 2) then
            if self:isAboveGround(block, x, y, extra) and block_top < best_y then
                best = block
                best_y = block_top
            end
        end
    end

    if self.can_ride_entities then
        for _, rideable in ipairs(self:getRideables()) do
            local ride_top = self:getGroundTopAt(rideable, x, y)
            if ride_top and self:collidesWithEvent(rideable, x, y, 0, height - 1, width, extra + 2) then
                if self:isAboveGround(rideable, x, y, extra) and ride_top < best_y then
                    best = rideable
                    best_y = ride_top
                end
            end
        end
    end

    return best
end

function PlatformEntity:updateOpenPosition()
    if not self.wallcollision then
        return
    end

    if self:findEmbeddedBlockAt(self.owner.x, self.owner.y) then
        self.stuck_time = self.stuck_time + DTMULT
        if self.stuck_time >= 3 then
            self.stuck_time = 0
            self.owner.x = self.open_x
            self.owner.y = self.open_y
            Object.uncache(self.owner)
            if self:findEmbeddedBlockAt(self.owner.x, self.owner.y) then
                local wall = self:findEmbeddedBlockAt(self.owner.x, self.owner.y)
                if wall and wall.moving_platform then
                    self.vspeed = 0
                    self.ground = wall
                    self:snapToGround(wall)
                else
                    self.vspeed = 0
                end
            end
        end
    else
        self.open_x = self.owner.x
        self.open_y = self.owner.y
        self.stuck_time = 0
    end
end

function PlatformEntity:moveX(amount)
    if amount == 0 then
        return
    end

    local sign = MathUtils.sign(amount)
    local remaining = math.abs(amount)
    while remaining > 0 do
        local step = math.min(1, remaining) * sign
        local next_x = self.owner.x + step
        local block = self.wallcollision and self:findBlockAt(next_x, self.owner.y) or nil

        if block then
            self.wallhitspd = self.hspeed
            local left, _, _, _, right = self:getWorldBoundsAt(self.owner.x, self.owner.y)
            local rounded_x = MathUtils.round(self.owner.x)
            if step > 0 then
                self.owner.x = self:getEventLeft(block) - (right - rounded_x) - 2
            else
                self.owner.x = self:getEventRight(block) + (rounded_x - left) + 2
            end
            Object.uncache(self.owner)
            self.hspeed = 0
            return
        end

        self.owner.x = next_x
        Object.uncache(self.owner)
        remaining = remaining - math.abs(step)
    end
end

function PlatformEntity:resolveHorizontalBlocks(move_amount)
    if not self.wallcollision then
        return
    end

    local checks = math.ceil(math.abs(move_amount or self.hspeed or 0))
    local distcheck = 2
    for _ = 1, checks do
        local wall = self:findBlockAt(self.owner.x - distcheck, self.owner.y)
        if wall and self.hspeed <= 0 then
            if self.hspeed < 0 then
                self.wallhitspd = self.hspeed
                self.hspeed = 0
            end
            local left = self:getWorldBoundsAt(self.owner.x, self.owner.y)
            if self.owner.x > self:getEventRight(wall) then
                self.owner.x = self:getEventRight(wall) + (MathUtils.round(self.owner.x) - left) + 2
                Object.uncache(self.owner)
            end
        end

        wall = self:findBlockAt(self.owner.x + distcheck, self.owner.y)
        if wall and self.hspeed >= 0 then
            if self.hspeed > 0 then
                self.wallhitspd = self.hspeed
                self.hspeed = 0
            end
            local _, _, _, _, right = self:getWorldBoundsAt(self.owner.x, self.owner.y)
            if self.owner.x < self:getEventLeft(wall) then
                self.owner.x = self:getEventLeft(wall) - (right - MathUtils.round(self.owner.x)) - 2
                Object.uncache(self.owner)
            end
        end

        distcheck = distcheck + 1
    end
end

function PlatformEntity:resolveCeilingBlock(move_amount)
    if not self.wallcollision or (self.vspeed or 0) >= 0 then
        return false
    end

    local check_y = self.owner.y - math.abs(move_amount or self.vspeed or 0)
    local block = self:findBlockAt(self.owner.x, check_y)
    if block and not (block.is_barrier and self.ignore_barriers) then
        self.vspeed = 0
        self.owner.y = self.owner.y + (2 * DTMULT)
        Object.uncache(self.owner)
        return true
    end

    return false
end

function PlatformEntity:landOn(ground)
    self.grounded = true
    self.ground = ground
    self.grounded_lastX = self.owner.x
    self.landspd = self.vspeed
    self.vspeed = 0
    self:snapToGround(ground)
end

function PlatformEntity:preCarryMovingGroundX(ground)
    self.precarried_ground = nil
    self.precarried_dx = 0
    self.precarried_dy = 0

    if not (ground and (ground.moving_platform or ground.rideable)) then
        return
    end

    local dx = ground.dif_x or 0
    if dx == 0 then
        return
    end

    local start_x = self.owner.x
    local target_x = self.owner.x + dx
    if not self:findBlockAt(target_x, self.owner.y, ground) then
        self.owner.x = target_x
        Object.uncache(self.owner)
    end

    self.precarried_dx = self.owner.x - start_x
    if self.precarried_dx ~= 0 then
        self.precarried_ground = ground
    end
end

function PlatformEntity:recordMovingGroundPreCarry(ground, start_x, start_y)
    if not (ground and (ground.moving_platform or ground.rideable)) then
        return
    end

    local dx = self.owner.x - (start_x or self.owner.x)
    local dy = self.owner.y - (start_y or self.owner.y)
    self.precarried_dx = dx
    self.precarried_dy = dy
    self.precarried_ground = (dx ~= 0 or dy ~= 0) and ground or nil
end

function PlatformEntity:snapToGround(ground)
    ground = ground or self.ground
    if not ground then
        return
    end

    local _, _, _, _, _, bottom = self:getWorldBoundsAt(self.owner.x, self.owner.y)
    local ground_y = self:getGroundTopAt(ground, self.owner.x, self.owner.y)
    if not ground_y then
        return
    end

    self.floorY = ground_y
    local snap_offset = 1
    if ground.is_slope or ground.platform_slope then
        snap_offset = ((ground.plattype or ground.slope_type or 0) == 1) and 0 or 2
    end
    if ground.quicksand and ground.quicksand ~= 0 then
        snap_offset = 1
    end
    local new_y = self.owner.y + ((ground_y - snap_offset) - bottom)

    if not self:findBlockAt(self.owner.x, new_y) then
        self.owner.y = new_y
        Object.uncache(self.owner)
    end
end

function PlatformEntity:moveY(amount)
    if amount == 0 then
        return
    end

    local sign = MathUtils.sign(amount)
    local remaining = math.abs(amount)
    while remaining > 0 do
        local step = math.min(1, remaining) * sign
        local old_y = self.owner.y
        local next_y = self.owner.y + step

        if step > 0 then
            local ground = self:findGroundAt(self.owner.x, next_y, math.abs(step))
            local _, _, _, _, _, old_bottom = self:getWorldBoundsAt(self.owner.x, old_y)
            local ground_top = ground and self:getGroundTopAt(ground, self.owner.x, next_y)
            if ground and ground_top and old_bottom <= ground_top + math.abs(step) then
                self:landOn(ground)
                return
            end
        end

        self.owner.y = next_y
        Object.uncache(self.owner)
        remaining = remaining - math.abs(step)
    end
end

function PlatformEntity:applyGroundEffects()
    self.last_ground_effect_dx = 0
    self.last_ground_effect_dy = 0
    self.last_ground_effect_ground = nil
    if not (self.grounded and self.ground) then
        return
    end

    local start_x, start_y = self.owner.x, self.owner.y
    if self.ground.quicksand and self.ground.quicksand ~= 0 then
        self.owner.y = self.owner.y + self.ground.quicksand * DTMULT
        Object.uncache(self.owner)
    end

    if self.ground.conveyor_hspeed and self.ground.conveyor_hspeed ~= 0 then
        local change = self.ground.conveyor_hspeed * DTMULT
        if not self:findBlockAt(self.owner.x + change, self.owner.y) then
            self.owner.x = self.owner.x + change
            Object.uncache(self.owner)
        end
    end

    self.last_ground_effect_dx = self.owner.x - start_x
    self.last_ground_effect_dy = self.owner.y - start_y
    if self.last_ground_effect_dx ~= 0 or self.last_ground_effect_dy ~= 0 then
        self.last_ground_effect_ground = self.ground
    end
end

function PlatformEntity:applyMovingGround()
    self.last_platform_dx = 0
    self.last_platform_dy = 0
    if not (self.grounded and self.ground and (self.ground.moving_platform or self.ground.rideable)) then
        self.precarried_ground = nil
        self.precarried_dx = 0
        self.precarried_dy = 0
        return
    end

    local pre_dx = 0
    local pre_dy = 0
    if self.precarried_ground == self.ground then
        pre_dx = self.precarried_dx or 0
        pre_dy = self.precarried_dy or 0
    end
    self.precarried_ground = nil
    self.precarried_dx = 0
    self.precarried_dy = 0

    local dx = (self.ground.dif_x or 0) - pre_dx
    local dy = (self.ground.dif_y or 0) - pre_dy
    if dx == 0 and dy == 0 then
        self.last_platform_dx = pre_dx
        self.last_platform_dy = pre_dy
        return
    end

    local start_x, start_y = self.owner.x, self.owner.y
    local target_x = self.owner.x + dx
    local target_y = self.owner.y + dy
    if self:findBlockAt(target_x, target_y, self.ground) then
        if not self:findBlockAt(target_x, self.owner.y, self.ground) then
            self.owner.x = target_x
        end
        if not self:findBlockAt(self.owner.x, target_y, self.ground) then
            self.owner.y = target_y
        end
    else
        self.owner.x = target_x
        self.owner.y = target_y
    end
    Object.uncache(self.owner)

    if self.grounded then
        self:snapToGround(self.ground)
    end
    self.last_platform_dx = pre_dx + (self.owner.x - start_x)
    self.last_platform_dy = pre_dy + (self.owner.y - start_y)
end

function PlatformEntity:updateHorizontalInput(input)
    input = input or {}
    if type(input) ~= "table" then
        input = {move = input}
    end

    local constants = self.constants
    local move = input.move or 0
    local key_left = input.key_left
    local key_right = input.key_right
    if key_left == nil then
        key_left = move < 0
    end
    if key_right == nil then
        key_right = move > 0
    end
    local hspeed_max = input.hspeed_max or constants.hspeed_max or 9
    local hspeed_min = input.hspeed_min or -hspeed_max
    local accel = self.grounded and (constants.ground_accel or 2) or (constants.air_accel or 2)
    local decel = input.decel or (self.grounded and (constants.ground_decel or 0.65) or (constants.air_decel or 0.5))
    local dont_accel = input.dont_accel or false
    local force_decel = input.force_decel or false

    if key_left and self.wallcollision and self:findBlockAt(self.owner.x - 8 - math.abs(self.hspeed), self.owner.y) then
        dont_accel = true
    end
    if key_right and self.wallcollision and self:findBlockAt(self.owner.x + 8 + math.abs(self.hspeed), self.owner.y) then
        dont_accel = true
    end
    if not self.grounded and math.abs(self.hspeed) > (hspeed_max + 2.1) then
        decel = 1
    end

    local decel_factor = decel ^ DTMULT

    if not dont_accel and key_left then
        local last_hspeed = self.hspeed
        self.hspeed = self.hspeed - accel * DTMULT
        if last_hspeed <= hspeed_min then
            self.hspeed = MathUtils.clamp(self.hspeed * decel_factor, last_hspeed, hspeed_min)
        end
    end
    if not dont_accel and key_right then
        local last_hspeed = self.hspeed
        self.hspeed = self.hspeed + accel * DTMULT
        if last_hspeed >= hspeed_max then
            self.hspeed = MathUtils.clamp(self.hspeed * decel_factor, hspeed_max, last_hspeed)
        end
    end

    if ((not key_left and not key_right) or (key_left and key_right) or force_decel) then
        self.hspeed = self.hspeed * decel_factor
    end
end

function PlatformEntity:updateJumpInput(press_jump, key_jump, options)
    options = options or {}
    local constants = self.constants
    self.launched_jump = false
    self.jump_ceiling_blocked = false
    local can_jump = options.can_jump ~= false
    local block_jump = options.block_jump or false

    if press_jump and can_jump then
        self.jumpbuffer = constants.jumpbuffer or 4
    else
        self.jumpbuffer = math.max(self.jumpbuffer - DTMULT, 0)
    end

    if self.grounded then
        self.jump_coyote_time = constants.coyote or 4
        self.jumping = 0
        self.jump_time = 0
    elseif self.jumpbuffer <= 0 and self.jumpsquat <= 0 and self.jump_coyote_time > 0 then
        self.jump_coyote_time = math.max(self.jump_coyote_time - DTMULT, 0)
    end

    if (self.jumpbuffer > 0 or self.jumpsquat > 0) and (self.grounded or (self.jump_coyote_time > 0 and self.vspeed > -1)) and not block_jump then
        local squat_inc = DTMULT
        local ceiling_blocked = self.wallcollision and self:findBlockAt(self.owner.x, self.owner.y - 8)
        if ceiling_blocked then
            squat_inc = 0.5 * DTMULT
            if self.jumpsquat == 0 then
                self.jump_ceiling_blocked = true
            end
        end
        self.jumpsquat = math.max(self.jumpsquat + squat_inc, 1)
        self.jumpbuffer = 0

        if self.jumpsquat > (constants.jumpsquat or 2) then
            self.jumpsquat = 0
            self.jump_coyote_time = 0
            if not ceiling_blocked then
                self.grounded = false
                self.ground = nil
                self.vspeed = -(constants.jumpheight or 20)
                self.owner.y = self.owner.y - 1
                self.jumping = 1
                self.jump_time = 0
                self.launched_jump = true
            end
        end
    else
        self.jumpsquat = 0
    end

    if self.jumping == 1 and self.vspeed > 0 then
        self.jumping = 2
    end
    if self.jumping ~= 0 then
        self.jump_time = self.jump_time + DTMULT
    end
    if not key_jump and self.jumping == 1 and self.jump_time >= (constants.jump_mintime or 4) and self.vspeed < 0 then
        self.vspeed = self.vspeed * (0.5 ^ DTMULT)
    end
end

function PlatformEntity:updatePlayer(input)
    input = input or {}

    self:updateOpenPosition()
    self:updateHorizontalInput(input)
    self:updateJumpInput(input.press_jump or false, input.key_jump or false, input)
    self:updatePhysics(input)
end

function PlatformEntity:updatePhysics(options)
    options = options or {}
    local constants = self.constants
    local previous_ground = self.ground

    self.grounded_prev = self.grounded
    self.grounded = false
    self.ground = nil
    self.landspd = 0
    self.wallhitspd = 0

    local move_x = self.hspeed * DTMULT
    self:resolveHorizontalBlocks(move_x)
    self:moveX(self.hspeed * DTMULT)

    local ground_extra = MathUtils.clamp((previous_ground and (previous_ground.dif_y or 0) or 0) * 4, 4, 18)
    if self.vspeed > 0 then
        ground_extra = math.ceil(math.abs(self.vspeed) + 4)
    end
    if not self.grounded then
        local ground = self:findGroundAt(self.owner.x, self.owner.y, ground_extra)
        if ground and self.vspeed >= 0 and not self.climbing then
            self:landOn(ground)
        end
    end

    if not self.grounded then
        local move_y = self.vspeed * DTMULT
        if not self:resolveCeilingBlock(move_y) then
            self:moveY(move_y)
        end
    end

    self:applyGroundEffects()

    if not self.grounded then
        self.vspeed = math.min(self.vspeed + (constants.gravity or 0.5) * DTMULT, constants.fall_speed or 15)
    end

    if not options.skip_moving_ground then
        self:applyMovingGround()
    end
end

function PlatformEntity:getDebugLines()
    local ground = self.ground
    local ground_name = "none"
    if ground then
        ground_name = ground.name or ground.id or ground.objectname or tostring(ground)
    end
    return {
        string.format("spd %.2f %.2f", self.hspeed or 0, self.vspeed or 0),
        string.format("gnd %s %s", self.grounded and "1" or "0", tostring(ground_name)),
        string.format("land %.2f wall %.2f", self.landspd or 0, self.wallhitspd or 0),
        string.format("plat %.2f %.2f", self.last_platform_dx or 0, self.last_platform_dy or 0),
    }
end

return PlatformEntity
