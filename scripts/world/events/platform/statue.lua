---@class PlatformStatue : PlatformAttackable
local PlatformAttackable = libRequire("featherfall", "scripts.world.events.platform.attackable")
local PaletteFX = libRequire("featherfall", "scripts.drawfx.palettefx")
local PlatformStatue, super = Class(PlatformAttackable)

local STATUE_SPRITE_METADATA = {
    ["world/statue/base"] = {origin_x = 20, origin_y = 40},
    ["world/statue/bottom"] = {origin_x = 20, origin_y = 40},
    ["world/statue/fall_cue"] = {origin_x = 40, origin_y = 40},
    ["world/statue/light"] = {origin_x = 30, origin_y = 80},
    ["world/statue/top"] = {origin_x = 20, origin_y = 40},
    ["world/statue/wings"] = {origin_x = 69, origin_y = 125},
}

function PlatformStatue:init(data)
    super.init(self, data)

    self.platform_statue = true
    self.properties = self.properties or (data and data.properties) or {}
    self.interact_buffer = 8 / 30
    self.floating = self.properties["floating"] == true
    self.timer = 0
    self.timer_max = self.properties["timer_max"] or Featherfall.constants.transition_timemax
    self.platform_snap_range = self.properties["platform_snap_range"] or 120
    self.platform_x = self.properties["platform_x"]
    self.platform_y = self.properties["platform_y"]
    self.yorigin_id = self.properties["yorigin_id"] or self.properties["anchor_id"]
    self.y_ow = self.properties["y_ow"] or (self.y + self.height)
    self.y_plat = self.properties["y_plat"]
    self.y_plat_offset = self.properties["y_plat_offset"] or 0
    self.yscale_ow = self.properties["yscale_ow"] or 2
    self.yscale_plat = self.properties["yscale_plat"] or (self.floating and 2 or 0.5)
    self.exit_x = self.properties["exit_x"]
    self.exit_y = self.properties["exit_y"]
    self.exit_x_offset = self.properties["exit_x_offset"] or -18
    self.exit_y_offset = self.properties["exit_y_offset"] or 0
    self.hit_cooldown = 0
    self.image_index = 0
    self.image_xscale = self.properties["image_xscale"] or 2
    self.image_yscale = self.yscale_ow
    self.pal_index = 0
    self.shine_alpha = 0
    self.shine_timer = 0
    self.statue_sprite = self.properties["sprite"] or Featherfall.assets.statue.top
    self.palette_sprite = self.properties["palette"] or Featherfall.assets.statue.palette
    self.palette_fx = PaletteFX(self.palette_sprite, 0)
    self.wings_timer = 0
    self.wings_timemax = 0
    self.base_layer = nil
end

function PlatformStatue:getCenter()
    return self.x + (self.width / 2), self.y + (self.height / 2)
end

function PlatformStatue:getPlatformEnterPosition(player)
    local center_x = self.x + (self.width / 2)
    local target_x = self.platform_x or center_x
    local target_y = self.platform_y

    if player and self.platform_snap_range then
        local distance = MathUtils.dist(player.x, player.y, center_x, self.y_ow)
        if distance >= self.platform_snap_range then
            target_x = nil
        end
    end

    return target_x, target_y
end

function PlatformStatue:getPlatformOverworldExitPosition(player)
    return self.exit_x or (self.x + self.exit_x_offset),
        self.exit_y or (self.y_ow + self.exit_y_offset)
end

function PlatformStatue:getLinkedFloortex()
    if self.yorigin_id then
        local floor = Featherfall:findFloortexFloorForAttachment(self)
        if floor then
            return floor
        end
    end
    return Featherfall:findFloortexFloorAt(self.x + (self.width / 2), self.y_ow)
end

function PlatformStatue:resolvePlatformTransform()
    if self.properties["y_plat"] ~= nil then
        self.y_plat = self.properties["y_plat"]
        return
    end

    local floortex = self:getLinkedFloortex()
    if floortex then
        local floor_y_plat = floortex.y_plat or floortex.y
        self.y_plat = floor_y_plat - 3 + self.y_plat_offset
    else
        self.y_plat = self.y_ow + self.y_plat_offset
    end
end

function PlatformStatue:updatePlatformTransform()
    self:resolvePlatformTransform()

    local progress = Featherfall:getTransitionLerpProgress()
    local anchor_y = MathUtils.lerp(self.y_ow, self.y_plat or self.y_ow, progress)
    self.image_yscale = MathUtils.lerp(self.yscale_ow, self.yscale_plat, progress)
    if not self.base_layer then
        self.base_layer = self.layer
    end
    local player = Game.world and Game.world.player
    if Featherfall:isPlatformModeActive() and player then
        self:setLayer(player.layer - 0.001)
    else
        self:setLayer(self.base_layer)
    end

    local new_y = anchor_y - self.height
    if self.y ~= new_y then
        self.y = new_y
        Object.uncache(self)
    end
end

function PlatformStatue:update()
    super.update(self)
    self:updatePlatformTransform()
    if Featherfall and Featherfall.isPlatformPaused and Featherfall:isPlatformPaused() then
        return
    end
    self.wings_timer = MathUtils.approach(self.wings_timer, 0, DTMULT)

    local max_frame = 0
    local frames = Assets.getFrames(self.statue_sprite)
    if Featherfall:isPlatformModeActive() and frames then
        max_frame = #frames - 1
    end
    self.image_index = MathUtils.approach(self.image_index, max_frame, 0.25 * DTMULT)
    self.pal_index = MathUtils.wrap(self.pal_index + (0.2 * DTMULT), 0, 6)

    if self.timer > 0 then
        self.timer = self.timer - DTMULT
        if self.timer <= 0 then
            self.hit = 0
            self.can_hit = true
            Assets.stopAndPlaySound(Featherfall.sounds.statue_recover, 1, 1.25)
        end
    end

    local ys = Featherfall:getFloortexTransition()
    if ys > 0.5 and self.can_hit then
        self.shine_alpha = math.min(self.shine_alpha + (0.1 * DTMULT), 1)
    else
        self.shine_alpha = math.max(self.shine_alpha - (0.1 * DTMULT), 0)
    end
    self.shine_timer = self.shine_timer + DTMULT
end

-- function PlatformStatue:onPlatformAttackCooldownEnd()
--     local was_locked = not self.can_hit
--     super.onPlatformAttackCooldownEnd(self)
--     if was_locked and self.can_hit then
--         Assets.stopAndPlaySound(Featherfall.sounds.statue_recover, nil, 1.25)
--     end
-- end

function PlatformStatue:getPaletteIndex()
    if not self.can_hit or not Featherfall:isEnabled(self) then
        return 7
    end
    return self.pal_index
end

function PlatformStatue:lockAllStatuesForHit()
    local map = Game.world and Game.world.map
    if not map then
        self.hit = 1
        self.can_hit = false
        self.hit_cooldown = self.timer_max
        return
    end

    for _, event in ipairs(map.events or {}) do
        if event.platform_statue then
            event.hit = 1
            event.can_hit = false
            event.hit_cooldown = event.timer_max or self.timer_max
        end
    end
end

function PlatformStatue:drawPalettedTexture(texture, x, y, sx, sy, origin_x, origin_y, palette_index, alpha)
    if not (self.palette_fx and self.palette_fx:isActive()) then
        return false
    end

    self.palette_fx:setPaletteIndex(palette_index)

    local source = Draw.pushCanvas(texture:getWidth(), texture:getHeight())
    Draw.setColor(1, 1, 1, alpha or 1)
    Draw.draw(texture, 0, 0)
    Draw.popCanvas(true)

    local mapped = Draw.pushCanvas(texture:getWidth(), texture:getHeight())
    Draw.setColor(1, 1, 1, 1)
    self.palette_fx:draw(source)
    Draw.popCanvas(true)

    Draw.setColor(1, 1, 1, 1)
    Draw.drawCanvas(mapped, x, y, 0, sx or 1, sy or sx or 1, origin_x, origin_y)
    Draw.unlockCanvas(source)
    Draw.unlockCanvas(mapped)
    return true
end

function PlatformStatue:beginEnterEffects()
    self.wings_timemax = (self.timer_max or Featherfall.constants.transition_timemax) * 3
    self.wings_timer = self.wings_timemax

    local fixate = Featherfall.transition_prop and Featherfall.transition_prop.parent and Featherfall.transition_prop or nil
    local petal_x = (self.x + (self.width / 2))
    local petal_y = (self.y + (self.height / 2))
    local layer = WORLD_LAYERS["above_events"]

    Featherfall:clearPetalWings(true)
    local petalwing = Featherfall:spawnPetalWing(petal_x, petal_y, {
        fixate = fixate,
        transition_time = Featherfall.transition_timemax,
        layer = layer,
    })
    Assets.playSound(Featherfall.sounds.petal_grab, nil, 1.25)
    Featherfall:makeRipple(petal_x, petal_y, {
        life = 8,
        color = 16777215,
        radmax = 50,
        radstart = 15,
        thickness = 20,
        curve = 0,
        banding = 2,
        fading = false,
        layer = ((petalwing and petalwing.layer) or layer) - 0.001,
    })
end

function PlatformStatue:onInteract(player, dir)
    local world_player = Game.world and Game.world.player
    if world_player and Featherfall:isEnabled(self) then
        if not self.can_hit or self.hit_cooldown > 0 or self.timer > 0 then
            return false
        end
        if world_player.state == Featherfall.state then
            return false
        end
        if world_player.state ~= Featherfall.state and not Featherfall:shouldRefuseStatueUse(self, player) then
            if Featherfall:enterPlatformMode(self) then
                self:lockAllStatuesForHit()
                self.timer = self.timer_max
                self:beginEnterEffects()
                return true
            end
        end
    end
    return false
end

function PlatformStatue:canPlatformAttackHit(hitbox)
    if not super.canPlatformAttackHit(self, hitbox) then
        return false
    end
    if self.floating then
        return false
    end
    if not Featherfall:isEnabled(self) then
        return false
    end
    return true
end

function PlatformStatue:onPlatformAttack(hitbox)
    self:lockAllStatuesForHit()
    Featherfall:makeRipple(self.x + (self.width / 2), self.y + (self.height / 2), {
        life = 8,
        color = 16777215,
        radmax = 50,
        radstart = 15,
        thickness = 20,
        curve = 0,
        banding = 2,
        fading = false,
        layer = self.layer - 0.001,
    })
    Featherfall:clearPetalWings(false)
    local start_frame = hitbox and hitbox.image_index and (math.floor(hitbox.image_index) + 1)
    Featherfall:exitPlatformMode(self, {
        animation_name = hitbox and hitbox.animation_name,
        start_frame = start_frame,
    })
    if hitbox and hitbox.doHit then
        hitbox:doHit()
    end
    self.timer = self.timer_max
    Assets.playSound(Featherfall.sounds.petal_grab, nil, 1.25)
    return true
end

function PlatformStatue:drawStatueSprite(path, frame, x, y, sx, sy, r, g, b, a, palette_index)
    local texture = nil
    local frames = Assets.getFrames(path)
    if frames then
        texture = frames[math.max(1, math.min(#frames, frame or 1))]
    else
        texture = Assets.getTexture(path)
    end
    if not texture then
        return
    end

    local metadata = STATUE_SPRITE_METADATA[path]
    local origin_x = metadata and metadata.origin_x or (texture:getWidth() / 2)
    local origin_y = metadata and metadata.origin_y or texture:getHeight()

    if palette_index ~= nil and self:drawPalettedTexture(texture, x, y, sx, sy, origin_x, origin_y, palette_index, a) then
        return
    end

    Draw.setColor(r or 1, g or 1, b or 1, a or 1)
    Draw.draw(texture, x, y, 0, sx or 1, sy or sx or 1, origin_x, origin_y)
    Draw.setColor(1, 1, 1, 1)
end

function PlatformStatue:draw()
    local anchor_x = self.width / 2
    local anchor_y = self.height
    local ys = Featherfall:getFloortexTransition()
    local shine = self.shine_alpha * ys * (0.5 + (0.15 * math.sin(self.shine_timer * 0.02)))

    if self.wings_timer > 0 and Featherfall:getConfig("draw_wings", true) then
        local frames = Assets.getFrames(Featherfall.assets.statue.wings)
        local frame_count = frames and #frames or 1
        local progress = 1 - (self.wings_timer / math.max(self.wings_timemax, 1))
        local frame = math.floor(progress * math.max(frame_count - 1, 0)) + 1
        self:drawStatueSprite(Featherfall.assets.statue.wings, frame, anchor_x, anchor_y + 60, 2, 2)
    end

    if shine > 0 then
        local light_xscale = 1.35 + (0.15 * math.sin(self.shine_timer * 0.03))
        local light_yscale = 1.35 + (0.15 * math.cos(self.shine_timer * 0.015))
        self:drawStatueSprite(Featherfall.assets.statue.light, 1, anchor_x, anchor_y, light_xscale, light_yscale, 0, 1, 0, shine)
    end

    local frame = math.floor(self.image_index) + 1
    local palette_index = self:getPaletteIndex()
    if self.palette_fx and self.palette_fx:isActive() then
        self:drawStatueSprite(self.statue_sprite, frame, anchor_x, anchor_y, self.image_xscale, 2, nil, nil, nil, nil, palette_index)
    elseif self.can_hit then
        self:drawStatueSprite(self.statue_sprite, frame, anchor_x, anchor_y, self.image_xscale, 2)
    else
        self:drawStatueSprite(self.statue_sprite, frame, anchor_x, anchor_y, self.image_xscale, 2, 0.6, 0.6, 0.6, 1)
    end

    super.draw(self)
end

return PlatformStatue
