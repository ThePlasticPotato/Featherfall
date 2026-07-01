---@class PlatformActorState : StateClass
local PlatformActorState, super = Class(StateClass)

local function resolveAnimationSpeed(animation, state)
    if type(animation.speed) == "function" then
        return animation.speed(state, animation)
    end
    return animation.speed
end

function PlatformActorState:getCharacter()
    return self.character or self.player or self.follower
end

function PlatformActorState:getPlatformActor()
    local character = self:getCharacter()
    return character and character.actor
end

function PlatformActorState:getPartyMember()
    local character = self:getCharacter()
    if character and character.getPartyMember then
        return character:getPartyMember()
    end
    if character and character.party then
        return Game:getPartyMember(character.party)
    end
end

function PlatformActorState:getCharacterId(value)
    if type(value) == "table" and value.id then
        value = value.id
    end
    if value ~= nil then
        return string.lower(tostring(value))
    end
end

function PlatformActorState:getActionKind()
    local actor = self:getPlatformActor()
    local party = self:getPartyMember()
    local actor_id = self:getCharacterId(actor)
    local party_id = self:getCharacterId(party)
    local actor_name = self:getCharacterId(actor and actor.name)

    return party_id or actor_id or actor_name
end

function PlatformActorState:getPlatformAnimation(name)
    local actor = self:getPlatformActor()
    if actor and actor.getPlatformAnimation then
        return actor:getPlatformAnimation(name)
    end
end

function PlatformActorState:getPlatformSpriteMetadata(sprite)
    local actor = self:getPlatformActor()
    if actor and actor.getPlatformSpriteMetadata then
        return actor:getPlatformSpriteMetadata(sprite)
    end
end

function PlatformActorState:getPlatformOffset(name)
    local actor = self:getPlatformActor()
    local character = self:getCharacter()
    if actor and actor.getPlatformOffset and character then
        return actor:getPlatformOffset(name, self.facing, character.width, character.height)
    end
    return 0, 0
end

function PlatformActorState:getPlatformFlipX()
    local actor = self:getPlatformActor()
    local facing = self.facing or "right"
    if actor and actor.getPlatformFlipX then
        return actor:getPlatformFlipX(facing, self:getCharacter(), self)
    end

    local data = actor and actor.platform
    local animation = self.current_animation and self:getPlatformAnimation(self.current_animation)
    local flip_x = facing == "left"
    if animation and animation.invert_flip ~= nil then
        return animation.invert_flip and not flip_x or flip_x
    end
    if data and data.invert_flip then
        return not flip_x
    end
    return flip_x
end

function PlatformActorState:setPlatformAnimation(name)
    local character = self:getCharacter()
    local animation = self:getPlatformAnimation(name)
    if not (character and character.sprite and animation and animation.sprite) then
        return
    end

    local changed_sprite = self.current_animation ~= name
    local changed_facing = self.current_sprite_facing ~= self.facing
    if changed_sprite or changed_facing then
        self.current_animation = name
        self.current_sprite_facing = self.facing
        local offset_x, offset_y = self:getPlatformOffset(name)
        character.sprite:setCustomSprite(animation.sprite, offset_x, offset_y, not changed_sprite)
        character.sprite:setOrigin(0, 0)
        character.sprite.last_flippable = false
        character.sprite.flip_x = self:getPlatformFlipX()
        local speed = resolveAnimationSpeed(animation, self)
        if animation.manual and changed_sprite then
            character.sprite:stop()
        elseif speed and changed_sprite then
            character.sprite:play(speed, animation.loop ~= false)
        elseif speed then
            character.sprite.anim_delay = speed
        end
    else
        character.sprite.flip_x = self:getPlatformFlipX()
        local speed = resolveAnimationSpeed(animation, self)
        if speed then
            character.sprite.anim_delay = speed
        end
    end
end

function PlatformActorState:setPlatformAnimationHoldFrame(name, frame)
    self:setPlatformAnimation(name)

    local character = self:getCharacter()
    local animation = self:getPlatformAnimation(name)
    local frames = animation and animation.sprite and Assets.getFrames(animation.sprite)
    local sprite = character and character.sprite
    if not (frames and sprite) then
        return
    end

    sprite:setFrame(frame or 1)
    sprite:pause()
end

function PlatformActorState:getAnimationDuration(name, image_speed)
    local animation = self:getPlatformAnimation(name)
    local frames = animation and animation.sprite and Assets.getFrames(animation.sprite)
    local frame_count = frames and #frames or 1
    if not image_speed and animation then
        image_speed = animation.image_speed
    end
    if not image_speed and animation and type(animation.speed) == "number" and animation.speed > 0 then
        image_speed = 1 / (30 * animation.speed)
    end
    return frame_count / math.max(image_speed or 0.25, 0.01)
end

function PlatformActorState:setTargetModeSpritePaused(paused)
    local character = self:getCharacter()
    local sprite = character and character.sprite
    if not sprite then
        return
    end

    if paused then
        if not self.targetmode_sprite_pause then
            self.targetmode_sprite_pause = {
                playing = sprite.playing,
                walking = sprite.walking,
                was_walking = sprite.was_walking,
                walk_frame = sprite.walk_frame,
                frame = sprite.frame,
            }
            sprite.walking = false
            sprite.was_walking = false
            sprite:pause()
        end
    elseif self.targetmode_sprite_pause then
        sprite.walking = self.targetmode_sprite_pause.walking
        sprite.was_walking = self.targetmode_sprite_pause.was_walking
        if self.targetmode_sprite_pause.walk_frame then
            sprite.walk_frame = self.targetmode_sprite_pause.walk_frame
        end
        if self.targetmode_sprite_pause.frame and sprite.setFrame then
            sprite:setFrame(self.targetmode_sprite_pause.frame)
        end
        if self.targetmode_sprite_pause.playing then
            sprite:resume()
        end
        self.targetmode_sprite_pause = nil
    end
end

function PlatformActorState:getCameraRect()
    local camera = Game.world and Game.world.camera
    if camera then
        return camera:getRect(false)
    end
    return 0, 0, Game.world and Game.world.width or SCREEN_WIDTH, Game.world and Game.world.height or SCREEN_HEIGHT
end

function PlatformActorState:getPlatformActionAnchor()
    local character = self:getCharacter()
    if not character then
        return
    end

    local actor = self:getPlatformActor()
    if actor and actor.getPlatformActionAnchor then
        local x, y = actor:getPlatformActionAnchor(character, self)
        if x and y then
            return x, y
        end
    end
    local data = actor and actor.platform
    local anchor = data and data.action_anchor
    if type(anchor) == "function" then
        local x, y = anchor(actor, character, self)
        if x and y then
            return x, y
        end
    elseif type(anchor) == "table" then
        return character.x + (anchor[1] or anchor.x or 0), character.y + (anchor[2] or anchor.y or 0)
    end
end

function PlatformActorState:getActionAnchor()
    local x, y = self:getPlatformActionAnchor()
    if x and y then
        return x, y
    end

    local character = self:getCharacter()
    if not character then
        return 0, 0
    end

    return character.x, character.y - ((character.height or 0) / 2)
end

function PlatformActorState:getOutlineBaseColor()
    local color = Featherfall and Featherfall.getActionColorTable and Featherfall:getActionColorTable(self:getActionKind())
    if color then
        return color[1], color[2], color[3]
    end
    local party = self:getPartyMember()
    if party and party.getColor then
        local r, g, b = party:getColor()
        if r then
            return r, g, b
        end
    end
    local actor = self:getPlatformActor()
    if actor and actor.getColor then
        local r, g, b = actor:getColor()
        if r then
            return r, g, b
        end
    end
    return 1, 1, 1
end

function PlatformActorState:drawPlatformDebug(r, g, b)
    local character = self:getCharacter()
    if self.entity then
        local x, y, width, height = self.entity:getLocalRect()
        love.graphics.setColor(r, g, b, 0.6)
        love.graphics.rectangle("line", x, y, width, height)
        if self.entity.ground then
            love.graphics.setColor(1, 0.95, 0.25, 0.7)
            love.graphics.line(width / 2, height, width / 2, height + 10)
        end
        if self.entity.getDebugLines then
            local lines = self.entity:getDebugLines()
            if Featherfall then
                table.insert(lines, string.format(
                    "mode %s swap %.2f",
                    Featherfall.platforming and "platform" or "world",
                    Featherfall.transition_timer or 0
                ))
            end
            love.graphics.setColor(1, 1, 1, 0.85)
            for index, line in ipairs(lines) do
                love.graphics.print(line, x, y - 10 - ((#lines - index) * 10), 0, 0.5, 0.5)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    if character then
        love.graphics.setColor(r, g, b, 0.6)
        love.graphics.rectangle("line", 0, 0, character.width, character.height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return PlatformActorState
