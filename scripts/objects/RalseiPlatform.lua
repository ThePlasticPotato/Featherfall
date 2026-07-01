---@class RalseiPlatform : Object
local RalseiPlatform, super = Class(Object)

local SPRITES = {
    hanging = "effects/platform/spr_plat_ralsei_hanging",
    head = "party/ralsei/platform/hanging_head",
    torso = "party/ralsei/platform/hanging_torso",
    long_1 = "effects/platform/spr_plat_ralsei_hanging_long_1",
    long_2 = "effects/platform/spr_plat_ralsei_hanging_long_2",
    long_3 = "effects/platform/spr_plat_ralsei_hanging_long_3",
}

local SPRITE_METADATA = {
    [SPRITES.hanging] = {origin_x = 25, origin_y = 32},
    [SPRITES.head] = {origin_x = 0, origin_y = 0},
    [SPRITES.torso] = {origin_x = 25, origin_y = 32},
    [SPRITES.long_1] = {origin_x = 0, origin_y = 0, width = 36},
    [SPRITES.long_2] = {origin_x = 0, origin_y = 0, width = 36},
    [SPRITES.long_3] = {origin_x = 0, origin_y = 0, width = 36},
}

local function getFrame(path, frame)
    local frames = Assets.getFrames(path)
    if frames and #frames > 0 then
        return frames[math.floor(MathUtils.clamp(frame or 1, 1, #frames))]
    end
    return Assets.getTexture(path)
end

function RalseiPlatform:init(state)
    super.init(self, 0, 0, 54, 8)
    self.state = state
    self.platform_floor = true
    self.platform_collision = state and (state.action_platform_mode or state.ralsei_platform_mode) == 3
    self.moving_platform = true
    self.rideable = true
    self.is_entity = true
    self.dif_x = 0
    self.dif_y = 0
    self.collider = Hitbox(self, 0, 0, self.width, self.height)
    self.layer = state and state.follower and state.follower.layer or WORLD_LAYERS["events"]
    self.visible = true
    if Featherfall and Featherfall.addDynamicPlatform then
        Featherfall:addDynamicPlatform(self)
    end
end

function RalseiPlatform:syncFromState(record_motion)
    local state = self.state
    if not (state and state.follower and (state.action_platform_mode or state.ralsei_platform_mode or 0) > 0) then
        return false
    end

    local mode = state.action_platform_mode or state.ralsei_platform_mode or 0
    self.x = state.follower.x - (self.width / 2)
    self.y = state.follower.y + 4
    self.layer = state.follower.layer + 0.01
    self.platform_collision = mode == 3 or (mode == 4 and (state.ralsei_fall_timer or 0) <= 15)
    Object.uncache(self)
    if record_motion and Featherfall and Featherfall.updatePlatformDifference then
        Featherfall:updatePlatformDifference(self)
    end
    return true
end

function RalseiPlatform:update()
    super.update(self)
    if not self:syncFromState(false) then
        self:remove()
    end
end

function RalseiPlatform:onRemove(parent)
    if Featherfall and Featherfall.removeDynamicPlatform then
        Featherfall:removeDynamicPlatform(self)
    end
    super.onRemove(self, parent)
end

function RalseiPlatform:drawSprite(path, frame, x, y, sx, sy, r, g, b, alpha)
    local texture = getFrame(path, frame)
    if not texture then
        return
    end
    local metadata = SPRITE_METADATA[path]
    local origin_x = metadata and metadata.origin_x or (texture:getWidth() / 2)
    local origin_y = metadata and metadata.origin_y or (texture:getHeight() / 2)
    Draw.setColor(r or 1, g or 1, b or 1, alpha or 1)
    Draw.draw(texture, x - self.x, y - self.y, 0, sx or 1, sy or 1, origin_x, origin_y)
    Draw.setColor(1, 1, 1, 1)
end

function RalseiPlatform:getHeadFrame()
    local state = self.state
    local frame = 1
    local player = Game.world and Game.world.player
    if player and state and player.x < state.follower.x - 11 then
        frame = 2
    end
    if state and state.ralsei_platform_stand_count and state.ralsei_platform_stand_count > 0 then
        frame = 3
    end
    return frame
end

function RalseiPlatform:getLongSprite()
    local state = self.state
    local frame = MathUtils.clamp((state and state.ralsei_platform_stand_count or 0) + 1, 1, 3)
    return ({SPRITES.long_1, SPRITES.long_2, SPRITES.long_3})[frame]
end

function RalseiPlatform:getStandFrame()
    return MathUtils.clamp((self.state and self.state.ralsei_platform_stand_count or 0) + 1, 1, 3)
end

function RalseiPlatform:drawNormalHang(x, y, image_xscale, image_yscale, r, g, b, alpha)
    local stand_count = self.state and self.state.ralsei_platform_stand_count or 0
    local frame = self:getStandFrame()

    self:drawSprite(SPRITES.torso, frame, x, y, image_xscale, image_yscale, r, g, b, alpha)
    self:drawSprite(
        SPRITES.head,
        self:getHeadFrame(),
        x - (11 * image_xscale),
        (y - (11 * image_yscale)) + (4 * stand_count),
        image_xscale,
        image_yscale,
        r,
        g,
        b,
        alpha
    )
end

function RalseiPlatform:drawLongHang(x, y, image_xscale, image_yscale, r, g, b, alpha)
    local long = 1
    local sprite = self:getLongSprite()
    local metadata = SPRITE_METADATA[sprite] or {}
    local sprite_width = metadata.width or 36
    local stand_count = self.state and self.state.ralsei_platform_stand_count or 0
    local xoffset = -10 + (-32 * long)
    local yy = ((y - 16) + (2 * stand_count) - 4) + (2 * stand_count)

    for index = 0, 4 do
        local sx = image_xscale
        local xx = ((x + xoffset) - 40) + 10
        if index == 1 or index == 3 then
            sx = sx * ((1 + long) * 0.85)
            if index == 1 then
                xx = xx - (0.1 * sprite_width * sx)
            else
                xx = xx + (0.2 * sprite_width * sx)
            end
        end
        if index == 2 then
            xx = (x - 60) + 10
        elseif index == 4 then
            xx = x - 60 - xoffset
            yy = yy + 2
        elseif index == 0 then
            xx = xx - 8
        end
        self:drawSprite(sprite, index + 1, xx, yy, sx, image_yscale, r, g, b, alpha)
    end
end

function RalseiPlatform:draw()
    local state = self.state
    local mode = state and (state.action_platform_mode or state.ralsei_platform_mode) or 0
    if not (state and state.follower and (mode == 3 or (mode == 4 and (state.ralsei_fall_timer or 0) <= 15))) then
        return
    end
    self:syncFromState()

    local follower = state.follower
    local alpha = follower.alpha or 1
    local blend = state.important_blend or 1
    local gray = 143 / 255
    local value = MathUtils.lerp(gray, 1, blend)
    local image_xscale = 2
    local image_yscale = 2
    local x = follower.x
    local y = follower.y

    if state.action_platform_long or state.ralsei_platform_long then
        self:drawLongHang(x, y, image_xscale, image_yscale, value, value, value, alpha)
        return
    end

    self:drawNormalHang(x, y, image_xscale, image_yscale, value, value, value, alpha)
end

return RalseiPlatform
