---@class PlatformDialogueBox : Textbox
local PlatformDialogueBox, super = Class(Textbox)

local function propertyBool(value, default)
    if value == nil then
        return default
    elseif value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
    value = string.lower(tostring(value))
    return value == "true" or value == "1" or value == "yes"
end

local function normalizeText(text)
    if type(text) == "table" then
        return text
    end
    text = tostring(text or "")
    local messages = {}
    for message in string.gmatch(text, "([^/]+)") do
        table.insert(messages, message)
    end
    if #messages == 0 then
        messages[1] = text
    end
    return messages
end

local function normalizeSide(value)
    if value == nil then
        return nil
    end
    if value == true or value == 1 or value == "1" or value == "bottom" then
        return 1
    end
    if value == false or value == 0 or value == "0" or value == "top" then
        return 0
    end
    return nil
end

function PlatformDialogueBox:init(text, options)
    options = options or {}
    self.messages = normalizeText(text)
    self.dynamic_side = propertyBool(options.dynamic_side, false)
    self.forced_side = normalizeSide(options.side)
    if self.forced_side == nil and propertyBool(options.bottom, false) then
        self.forced_side = 1
    elseif self.forced_side == nil and not self.dynamic_side then
        self.forced_side = 1
    end

    self.small = propertyBool(options.small, false)
    self.draw_bg = propertyBool(options.draw_bg, true)
    self.draw_box = propertyBool(options.draw_box, true)
    self.skippable = propertyBool(options.skippable, true)
    self.advance = propertyBool(options.advance, true)
    self.auto = propertyBool(options.auto, false)
    self.xoff = tonumber(options.xoff or options.x) or 0
    self.yoff = tonumber(options.yoff or options.y) or 0
    self.charcon = propertyBool(options.charcon, true)
    self.panel_height = self:getDRPanelHeight()
    self.face_wing_width = tonumber(options.face_width) or 110
    self.face_wing_extra = tonumber(options.face_wing_extra)
    self.face_offset_x = 0
    self.face_offset_y = 0
    self.slope_texture = Assets.getTexture("ui/platform/dialogue/gradient_triangle")
        or (Assets.getFrames("ui/platform/dialogue/gradient_triangle") or {})[1]
    self.side_gradient_texture = Assets.getTexture("ui/platform/dialogue/gradient20")
        or (Assets.getFrames("ui/platform/dialogue/gradient20") or {})[1]
    self.alpha = 1

    super.init(self, self.xoff, self:getPanelY(), SCREEN_WIDTH, self.panel_height, options.font or "main_mono", options.font_size, false)

    self:setParallax(0, 0)
    self.layer = options.layer or WORLD_LAYERS["textbox"]
    self.box.visible = false
    self.battle_box = false
    self.text_x = 28
    self.text_y = 10
    self.wrap_add_w = 0

    local actor = options.actor or options.speaker
    if actor then
        self:setActor(actor)
    end

    local face_name = options.face or options.portrait or options.portrait_face
    if face_name and face_name ~= "" then
        self:setFace(face_name, tonumber(options.face_x) or 0, tonumber(options.face_y) or 0)
    end

    self:setSkippable(self.skippable)
    self:setAdvance(self.advance)
    self:setAuto(self.auto)
    self:setText(self.messages, function()
        self:remove()
    end)
    self:updatePlacement()
end

function PlatformDialogueBox:isPlayerInBottomZone()
    local map = Game.world and Game.world.map
    local player = Game.world and Game.world.player
    if not (map and player) then
        return false
    end

    for _, event in ipairs(map.events or {}) do
        if event.platform_text_at_bottom_zone and event.collider and player:collidesWith(event.collider) then
            return true
        end
    end
    return false
end

function PlatformDialogueBox:getSide()
    if self.forced_side ~= nil then
        return self.forced_side
    end
    if self.dynamic_side then
        return self:isPlayerInBottomZone() and 1 or 0
    end
    return 1
end

function PlatformDialogueBox:getDRPanelHeight()
    local side = self:getSide()
    local height = 100
    if side == 1 and (self.charcon or self.small) then
        height = height + 50
    end
    return height
end

function PlatformDialogueBox:getFaceWingExtra()
    if self.face_wing_extra then
        return self.face_wing_extra
    end
    return (self:getSide() == 1 and self.small and self.charcon) and 60 or 20
end

function PlatformDialogueBox:getDRSideMod()
    local side = self:getSide()
    local sidemod = side * 380
    if side == 1 then
        if self.small then
            sidemod = sidemod + 50
        end
        if self.charcon or self.small then
            sidemod = sidemod - 50
        end
    end
    return sidemod
end

function PlatformDialogueBox:getPanelY()
    return self.yoff + self:getDRSideMod()
end

function PlatformDialogueBox:getTextY()
    local side = self:getSide()
    local sidemod = 190 * side
    if self.small then
        sidemod = sidemod + (25 * side)
    end
    local charcon_triggered = self.small and self.charcon and side == 1
    if charcon_triggered then
        sidemod = sidemod - 25
    end

    local y = ((20 * 2) + self.yoff - 30) + (sidemod * 2)
    if side == 1 and self.small then
        if not charcon_triggered then
            y = y - 50
        end
    elseif side == 1 and not self.small and self.charcon then
        y = y - 50
    end
    return y - self:getPanelY()
end

function PlatformDialogueBox:getFaceY()
    local side = self:getSide()
    local sidemod = 190 * side
    if self.small then
        sidemod = sidemod + (25 * side)
    end
    local charcon_triggered = self.small and self.charcon and side == 1
    if charcon_triggered then
        sidemod = sidemod - 25
    end

    local y = (2 * sidemod) + 6 - (10 * side)
    if side == 1 and self.small then
        y = y - 50
    elseif side == 1 and not self.small and self.charcon then
        y = y - 50
    end
    return y - self:getPanelY()
end

function PlatformDialogueBox:updatePlacement()
    self.panel_height = self:getDRPanelHeight()
    self:setPosition(self.xoff, self:getPanelY())
    self.width = SCREEN_WIDTH
    self.height = self.panel_height
    self:updateTextBounds()
    self.box.visible = false
    self.text.y = self:getTextY()
    if self.face.texture then
        self.face:setPosition(18 + self.face_offset_x, self:getFaceY() + self.face_offset_y)
    end
end

function PlatformDialogueBox:updateTextBounds()
    if self.face.texture then
        self.text.x = self.text_x + 116
        self.text.width = self.width - self.text.x - 20
    else
        self.text.x = self.text_x
        self.text.width = self.width - self.text.x - 20
    end
    if self.text.align == "right" then
        self.text.x = self.text.x - self.wrap_add_w
    end
end

function PlatformDialogueBox:setFace(face, ox, oy)
    self.face_offset_x = ox or 0
    self.face_offset_y = oy or 0
    super.setFace(self, face, ox, oy)
    self.face:setPosition(18 + self.face_offset_x, self:getFaceY() + self.face_offset_y)
end

function PlatformDialogueBox:update()
    local player_state = Game.world and Game.world.player and Game.world.player.platform_state
    self.alpha = (player_state and player_state.targetmode) and 0 or 1
    self.text:setPaused(Featherfall:isPlatformPaused())
    self.text.alpha = self.alpha
    self.face.alpha = self.alpha
    self:updatePlacement()

    super.update(self)
end

function PlatformDialogueBox:drawPlatformBackground()
    if not (self.draw_box and self.draw_bg) then
        return
    end

    if self.face.texture then
        Draw.setColor(0, 0, 0, self.alpha)
        if self:getSide() == 1 then
            local wing_extra = self:getFaceWingExtra()
            local wing_y = -wing_extra
            love.graphics.rectangle("fill", 0, wing_y, self.face_wing_width, self.panel_height + wing_extra)
            if self.slope_texture then
                Draw.draw(self.slope_texture, self.face_wing_width, 0, 0, 1, 1, 0, 20)
            end
        else
            local wing_extra = self:getFaceWingExtra()
            love.graphics.rectangle("fill", 0, 0, self.face_wing_width, self.panel_height + wing_extra)
            if self.slope_texture then
                Draw.draw(self.slope_texture, self.face_wing_width, self.panel_height, 0, 1, -1, 0, 20)
            end
        end
        if self.side_gradient_texture then
            Draw.draw(self.side_gradient_texture, self.face_wing_width, 0, math.rad(90), self.panel_height / 20, 2, 0, 20)
        end
    end

    Draw.setColor(0, 0, 0, 0.7 * self.alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, self.panel_height)
    Draw.setColor(1, 1, 1, self.alpha)
end

function PlatformDialogueBox:draw()
    if self.alpha <= 0 then
        return
    end
    self:drawPlatformBackground()
    super.draw(self)
end

return PlatformDialogueBox
