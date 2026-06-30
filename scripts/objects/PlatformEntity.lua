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
    self.ignore_barriers = false
    self.wallcollision = true

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
    self.ignore_barriers = settings.ignore_barriers or false
    self.wallcollision = settings.wallcollision ~= false

    self.open_x = self.owner.x
    self.open_y = self.owner.y
    self.stuck_time = 0

    self.jumpbuffer = 0
    self.jump_coyote_time = 0
    self.jumpsquat = 0
    self.jump_time = 0
    self.jumping = 0
    self.launched_jump = false
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

function PlatformEntity:withOwnerPosition(x, y, callback)
    local old_x, old_y = self.owner.x, self.owner.y
    if x then
        self.owner.x = x
    end
    if y then
        self.owner.y = y
    end
    Object.uncache(self.owner)

    local results = {callback()}

    self.owner.x = old_x
    self.owner.y = old_y
    Object.uncache(self.owner)

    return unpack(results)
end

function PlatformEntity:getColliderAt(x, y, x_offset, y_offset, width, height)
    local left, top, hit_width, hit_height = self:getLocalRect(x_offset, y_offset, width, height)
    return Hitbox(self.owner, left, top, hit_width, hit_height)
end

function PlatformEntity:getWorldBoundsAt(x, y, x_offset, y_offset, width, height)
    return self:withOwnerPosition(x, y, function()
        local left, top, hit_width, hit_height = self:getLocalRect(x_offset, y_offset, width, height)
        local transform = self.owner:getFullTransform()
        local x1, y1 = transform:transformPoint(left, top)
        local x2, y2 = transform:transformPoint(left + hit_width, top)
        local x3, y3 = transform:transformPoint(left + hit_width, top + hit_height)
        local x4, y4 = transform:transformPoint(left, top + hit_height)
        local min_x = math.min(x1, x2, x3, x4)
        local max_x = math.max(x1, x2, x3, x4)
        local min_y = math.min(y1, y2, y3, y4)
        local max_y = math.max(y1, y2, y3, y4)
        return min_x, min_y, max_x - min_x, max_y - min_y, max_x, max_y
    end)
end

function PlatformEntity:collidesWithEvent(event, x, y, x_offset, y_offset, width, height)
    if not (event and event.collider) then
        return false
    end
    return self:withOwnerPosition(x, y, function()
        return self:getColliderAt(x, y, x_offset, y_offset, width, height):collidesWith(event.collider)
    end)
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

function PlatformEntity:overlapsRect(event, x, y)
    return self:collidesWithEvent(event, x, y)
end

function PlatformEntity:findBlockAt(x, y)
    for _, block in ipairs(self:getBlocks()) do
        if not (block.is_barrier and self.ignore_barriers) and self:overlapsRect(block, x, y) then
            return block
        end
    end
end

function PlatformEntity:findGroundAt(x, y, extra)
    extra = extra or 0
    local _, _, width, height = self:getLocalRect()
    local _, _, _, _, _, bottom = self:getWorldBoundsAt(x, y)

    local best = nil
    local best_y = math.huge
    for _, floor in ipairs(self:getFloors()) do
        local floor_top = self:getEventTop(floor)
        if self:collidesWithEvent(floor, x, y, 0, height - 1, width, extra + 2) then
            if bottom <= floor_top + extra and bottom + extra >= floor_top and floor_top < best_y then
                best = floor
                best_y = floor_top
            end
        end
    end

    for _, block in ipairs(self:getBlocks()) do
        local block_top = self:getEventTop(block)
        if not (block.is_barrier and self.ignore_barriers) and self:collidesWithEvent(block, x, y, 0, height - 1, width, extra + 2) then
            if bottom <= block_top + extra and bottom + extra >= block_top and block_top < best_y then
                best = block
                best_y = block_top
            end
        end
    end

    return best
end

function PlatformEntity:updateOpenPosition()
    if not self.wallcollision then
        return
    end

    if self:findBlockAt(self.owner.x, self.owner.y) then
        self.stuck_time = self.stuck_time + DTMULT
        if self.stuck_time >= 3 then
            self.stuck_time = 0
            self.owner.x = self.open_x
            self.owner.y = self.open_y
            if self:findBlockAt(self.owner.x, self.owner.y) then
                self.vspeed = 0
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
            if step > 0 then
                self.owner.x = self.owner.x + ((self:getEventLeft(block) - 2) - right)
            else
                self.owner.x = self.owner.x + ((self:getEventRight(block) + 2) - left)
            end
            self.hspeed = 0
            return
        end

        self.owner.x = next_x
        remaining = remaining - math.abs(step)
    end
end

function PlatformEntity:landOn(ground)
    self.grounded = true
    self.ground = ground
    self.landspd = self.vspeed
    self.vspeed = 0
    local _, _, _, _, _, bottom = self:getWorldBoundsAt(self.owner.x, self.owner.y)
    self.owner.y = self.owner.y + ((self:getEventTop(ground) - 1) - bottom)
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
            if ground and old_bottom <= self:getEventTop(ground) + math.abs(step) then
                self:landOn(ground)
                return
            end
        else
            local block = self.wallcollision and self:findBlockAt(self.owner.x, next_y) or nil
            if block then
                local _, top = self:getWorldBoundsAt(self.owner.x, self.owner.y)
                self.owner.y = self.owner.y + ((self:getEventBottom(block) + 2) - top)
                self.vspeed = 0
                return
            end
        end

        self.owner.y = next_y
        remaining = remaining - math.abs(step)
    end
end

function PlatformEntity:applyGroundEffects()
    if not (self.grounded and self.ground) then
        return
    end

    if self.ground.quicksand and self.ground.quicksand ~= 0 then
        self.owner.y = self.owner.y + self.ground.quicksand * DTMULT
    end

    if self.ground.conveyor_hspeed and self.ground.conveyor_hspeed ~= 0 then
        local change = self.ground.conveyor_hspeed * DTMULT
        if not self:findBlockAt(self.owner.x + change, self.owner.y) then
            self.owner.x = self.owner.x + change
        end
    end
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
    local decel = self.grounded and (constants.ground_decel or 0.65) or (constants.air_decel or 0.5)
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
        if math.abs(self.hspeed) < 0.01 then
            self.hspeed = 0
        end
    end
end

function PlatformEntity:updateJumpInput(press_jump, key_jump)
    local constants = self.constants
    self.launched_jump = false

    if press_jump then
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

    if (self.jumpbuffer > 0 or self.jumpsquat > 0) and (self.grounded or (self.jump_coyote_time > 0 and self.vspeed > -1)) then
        self.jumpsquat = math.max(self.jumpsquat + DTMULT, 1)
        self.jumpbuffer = 0

        if self.jumpsquat > (constants.jumpsquat or 2) then
            self.jumpsquat = 0
            self.jump_coyote_time = 0
            self.grounded = false
            self.ground = nil
            self.vspeed = -(constants.jumpheight or 20)
            self.owner.y = self.owner.y - 1
            self.jumping = 1
            self.jump_time = 0
            self.launched_jump = true
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
    self:updateJumpInput(input.press_jump or false, input.key_jump or false)
    self:updatePhysics()
end

function PlatformEntity:updatePhysics()
    local constants = self.constants

    self.grounded_prev = self.grounded
    self.grounded = false
    self.ground = nil
    self.landspd = 0
    self.wallhitspd = 0

    self:moveX(self.hspeed * DTMULT)
    self:moveY(self.vspeed * DTMULT)

    if not self.grounded then
        local ground = self:findGroundAt(self.owner.x, self.owner.y, 4)
        if ground and self.vspeed >= 0 then
            self:landOn(ground)
        end
    end

    self:applyGroundEffects()

    if not self.grounded then
        self.vspeed = math.min(self.vspeed + (constants.gravity or 0.5) * DTMULT, constants.fall_speed or 15)
    end
end

return PlatformEntity
