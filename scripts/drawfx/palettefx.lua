local PaletteFX, super = Class(FXBase)

function PaletteFX:init(palette_tex, palette_index, transformed, priority)
    super.init(self, priority or 0)

    self.shader = Assets.getShader("palette")
	self:setPaletteTexture(palette_tex)
	self.palette_index = palette_index or 0
end

function PaletteFX:setPaletteIndex(index)
	self.palette_index = index or nil
end

function PaletteFX:setPaletteTexture(tex)
    if not tex then
        self.palette_tex = nil
        return
    end

    local frames = Assets.getFrames(tex)
	self.palette_tex = Assets.getTexture(tex) or (frames and frames[1]) or nil
end

function PaletteFX:isActive()
    return super.isActive(self) and self.palette_tex and self.palette_index
end

function PaletteFX:draw(texture)
    Draw.pushShader(self.shader)
	self.shader:send("palette_tex", self.palette_tex)
	local palw, palh = self.palette_tex:getWidth(), self.palette_tex:getHeight()
	self.shader:send("palette_uvs", {(1.0 / palw) * 0.5, (1.0 / palh) * 0.5, 1, 1})
	self.shader:send("pixel_size", {1.0 / palw, 1.0 / palh})
	self.shader:send("palette_id", self.palette_index)
    Draw.drawCanvas(texture)
    Draw.popShader()
end

return PaletteFX
