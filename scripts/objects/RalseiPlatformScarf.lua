---@class RalseiPlatformScarf : Object
local RalseiPlatformScarf, super = Class(Object)

local SPRITES = {
    back = "party/ralsei/platform/hanging_back",
    back_loop = "party/ralsei/platform/hanging_back_loop",
}

local SPRITE_METADATA = {
    [SPRITES.back] = {origin_x = 25, origin_y = 32},
    [SPRITES.back_loop] = {origin_x = 25, origin_y = 0},
}

local function getFrame(path, frame)
    local frames = Assets.getFrames(path)
    if frames and #frames > 0 then
        return frames[math.floor(MathUtils.clamp(frame or 1, 1, #frames))]
    end
    return Assets.getTexture(path)
end

function RalseiPlatformScarf:init(state)
    super.init(self, 0, 0, 54, 8)
    self.state = state
    self.visible = true
    self.layer = state and state.follower and state.follower.layer or WORLD_LAYERS["events"]
end

function RalseiPlatformScarf:syncFromState()
    local state = self.state
    if not (state and state.follower and (state.action_platform_mode or state.ralsei_platform_mode or 0) > 0) then
        return false
    end

    self.x = state.follower.x - (self.width / 2)
    self.y = state.follower.y + 4
    self.layer = state.follower.layer - 0.01
    Object.uncache(self)
    return true
end

function RalseiPlatformScarf:update()
    super.update(self)
    if not self:syncFromState() then
        self:remove()
    end
end

function RalseiPlatformScarf:drawSprite(path, frame, x, y, sx, sy, r, g, b, alpha)
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

function RalseiPlatformScarf:getStandFrame()
    return MathUtils.clamp((self.state and self.state.ralsei_platform_stand_count or 0) + 1, 1, 3)
end

function RalseiPlatformScarf:draw()
    local state = self.state
    local mode = state and (state.action_platform_mode or state.ralsei_platform_mode) or 0
    if not (state and state.follower and not (state.action_platform_long or state.ralsei_platform_long) and (mode == 3 or (mode == 4 and (state.ralsei_fall_timer or 0) <= 15))) then
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
    local frame = self:getStandFrame()

    self:drawSprite(SPRITES.back_loop, 1, x, y - 20, image_xscale, image_yscale * 20, value, value, value, alpha)
    self:drawSprite(SPRITES.back, frame, x, y, image_xscale, image_yscale, value, value, value, alpha)
end

return RalseiPlatformScarf
