---@class PlatformActionAfterimage : Object
local PlatformActionAfterimage, super = Class(Object)

function PlatformActionAfterimage:init(follower, color, progress, options)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    options = options or {}
    local sprite = follower.sprite
    self.texture = sprite and sprite:getTexture()
    self.color = color or {1, 1, 1}
    self.alpha = MathUtils.clamp(progress or 0, 0, 1)
    self.fade_speed = options.fade_speed or 0.1
    self.world_space = options.world_space or false
    self.solid = options.solid or false
    self.hspeed = options.hspeed or 0
    self.layer = (follower.layer or 0) - 0.01

    if self.world_space then
        self.x = follower.x
        self.y = follower.y
        if self.texture and sprite then
            self.snapshot = Sprite(self.texture, sprite.x, sprite.y, sprite.width, sprite.height)
            self.snapshot.origin_x = sprite.origin_x
            self.snapshot.origin_y = sprite.origin_y
            self.snapshot.origin_exact = sprite.origin_exact
            self.snapshot.rotation = sprite.rotation
            self.snapshot.scale_x = sprite.scale_x
            self.snapshot.scale_y = sprite.scale_y
            self.snapshot.flip_x = sprite.flip_x
            self.snapshot.flip_y = sprite.flip_y
            self.snapshot.alpha = sprite.alpha
        end
        return
    end

    if self.texture and sprite then
        self.canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
        Draw.pushCanvas(self.canvas)
        love.graphics.push()
        love.graphics.origin()
        love.graphics.clear()
        love.graphics.applyTransform(sprite:getFullTransform())
        local shader
        local last_shader = love.graphics.getShader()
        if options.solid then
            shader = Kristal.Shaders["AddColor"]
            love.graphics.setShader(shader)
            shader:send("inputcolor", {self.color[1] or 1, self.color[2] or 1, self.color[3] or 1})
            shader:send("amount", 1)
            Draw.setColor(1, 1, 1, 1)
        else
            Draw.setColor(self.color[1] or 1, self.color[2] or 1, self.color[3] or 1, 1)
        end
        Draw.draw(self.texture)
        if shader then
            love.graphics.setShader(last_shader)
        end
        Draw.setColor(1, 1, 1, 1)
        love.graphics.pop()
        Draw.popCanvas()
    end
end

function PlatformActionAfterimage:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    if self.world_space then
        self.x = self.x + ((self.hspeed or 0) * DTMULT)
    end
    self.alpha = self.alpha - (self.fade_speed * DTMULT)
    if self.alpha <= 0 then
        self:remove()
    end
end

function PlatformActionAfterimage:onRemove()
    if self.canvas then
        self.canvas:release()
        self.canvas = nil
    end
end

function PlatformActionAfterimage:applyTransformTo(transform)
    if self.parent and not self.world_space then
        transform:reset()
    end
    super.applyTransformTo(self, transform)
end

function PlatformActionAfterimage:draw()
    if self.world_space then
        if not self.snapshot then
            return
        end

        local shader
        local last_shader = love.graphics.getShader()
        if self.solid then
            shader = Kristal.Shaders["AddColor"]
            love.graphics.setShader(shader)
            shader:send("inputcolor", {self.color[1] or 1, self.color[2] or 1, self.color[3] or 1})
            shader:send("amount", 1)
            self.snapshot:setColor(1, 1, 1, self.alpha)
        else
            self.snapshot:setColor(self.color[1] or 1, self.color[2] or 1, self.color[3] or 1, self.alpha)
        end
        self.snapshot:drawSelf(true)
        if shader then
            love.graphics.setShader(last_shader)
        end
        Draw.setColor(1, 1, 1, 1)
        return
    end

    if not self.canvas then
        return
    end

    Draw.setColor(1, 1, 1, self.alpha)
    Draw.draw(self.canvas)
    Draw.setColor(1, 1, 1, 1)
end

return PlatformActionAfterimage
