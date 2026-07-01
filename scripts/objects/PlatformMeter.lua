---@class PlatformMeter : Object
local PlatformMeter, super = Class(Object)

function PlatformMeter:init(target, options)
    options = options or {}
    super.init(self, 0, 0, 0, 0)

    self.target = target
    self.text = options.text or "COOLDOWN"
    self.value = options.value or options.timer or 0
    self.max_value = options.max_value or options.max or options.timer_max or self.value
    self.color = options.color or {1, 1, 1}
    self.alpha = options.alpha
    self.width = options.width or 60
    self.height = options.height or 12
    self.border = options.border or 2
    self.fill_inset = options.fill_inset or 4
    self.fill_height = options.fill_height or 4
    self.above = options.above or 40
    self.stack_spacing = options.stack_spacing or 24
    self.stack_index = options.stack_index or 0
    self.font = options.font or "main"
    self.font_size = options.font_size or 16
    self.follow_target = options.follow_target ~= false
    self.remove_when_done = options.remove_when_done == true
    self.layer = options.layer or WORLD_LAYERS["ui"]
end

function PlatformMeter:setValue(value, max_value)
    self.value = value or self.value or 0
    self.max_value = max_value or self.max_value or self.value
end

function PlatformMeter:getProgress()
    return MathUtils.clamp((self.value or 0) / math.max(self.max_value or self.value or 1, 1), 0, 1)
end

function PlatformMeter:getTargetTop()
    if not self.target then
        return self.y
    end
    return self.target.y - (self.target.height or 0)
end

function PlatformMeter:getDrawPosition()
    if not (self.follow_target and self.target) then
        return self.x, self.y
    end
    return self.target.x, self:getTargetTop() - self.above - ((self.stack_index or 0) * self.stack_spacing)
end

function PlatformMeter:update()
    super.update(self)
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end

    if self.remove_when_done then
        self.value = MathUtils.approach(self.value or 0, 0, DTMULT)
        if (self.value or 0) <= 0 then
            self:remove()
        end
    end
end

function PlatformMeter:drawAt(x, y)
    local color = self.color or {1, 1, 1}
    local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
    local alpha = self.alpha or color[4] or 1
    local width = self.width or 60
    local height = self.height or 12
    local border = self.border or 2
    local fill_inset = self.fill_inset or 4
    local fill_height = self.fill_height or 4
    local font = Assets.getFont(self.font or "main", self.font_size or 16)
    local old_font = love.graphics.getFont()
    if font then
        love.graphics.setFont(font)
    end

    Draw.setColor(r, g, b, alpha)
    love.graphics.printf(self.text or "", x - width, y - (font and font:getHeight() or 0), width * 2, "center")
    love.graphics.rectangle("fill", x - (width / 2), y, width, height)
    Draw.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", x - (width / 2) + border, y + border, width - (border * 2), height - (border * 2))
    Draw.setColor(r, g, b, alpha)
    love.graphics.rectangle("fill", x - (width / 2) + fill_inset, y + fill_inset, (width - (fill_inset * 2)) * self:getProgress(), fill_height)

    if old_font then
        love.graphics.setFont(old_font)
    end
    Draw.setColor(1, 1, 1, 1)
end

function PlatformMeter:draw()
    local x, y = self:getDrawPosition()
    self:drawAt(x, y)
end

return PlatformMeter
