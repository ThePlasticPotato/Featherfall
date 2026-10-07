local DarkConfigFeatherOption, super = Class(DarkConfigOption)

function DarkConfigFeatherOption:init(menu, name, callback, default_value)
    super.init(self, menu, name, callback)

    self.inverted = default_value
end

function DarkConfigFeatherOption:setInverted(inverted)
    self.inverted = inverted
end

function DarkConfigFeatherOption:draw()
    super.draw(self)

    Draw.setColor(PALETTE["world_text"])
    love.graphics.setFont(Assets.getFont("main"))
    love.graphics.print("Jump: " .. (self.inverted and "Confirm" or "Cancel") .. "\nAttack: " .. (self.inverted and "Cancel" or "Confirm"), 348, -4, 0, 0.5, 0.5)
end

return DarkConfigFeatherOption