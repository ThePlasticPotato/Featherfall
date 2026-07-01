local Follower, super = HookSystem.hookScript(Follower)

local FollowerPlatformState = libRequire("featherfall", "scripts.world.states.FollowerPlatformState")

function Follower:init(chara, x, y, target)
    super.init(self, chara, x, y, target)

    self.platform_state = FollowerPlatformState(self)
    self.state_manager:addState("FEATHERFALL", self.platform_state)
end

function Follower:isPlatforming()
    return self.state_manager and self.state_manager.state == "FEATHERFALL"
end

function Follower:requestPlatformAction(target, data)
    if self.platform_state then
        return self.platform_state:requestAction(target, data)
    end
    return false
end

-- function Follower:updateHistory(moved, auto)
--     if moved then
--         self.blush_timer = 0
--     end
--     local target = self:getTarget()

--     local auto_move = auto or self:isAutoMoving()

--     if moved or auto_move then
--         self.history_time = self.history_time + DT

--         table.insert(self.history, 1, { x = target.x, y = target.y, facing = target.facing, time = self.history_time, state = target.state, state_args = target.state_manager.args, auto = auto })
--         while (self.history_time - self.history[#self.history].time) > (Game.max_followers * FOLLOW_DELAY) do
--             table.remove(self.history, #self.history)
--         end

--         if self.following and not self.physics.move_target then
--             self:moveToTarget()
--         end
--     end
-- end

-- function Follower:update()
--     self:updateIndex()

--     if #self.history == 0 then
--         table.insert(self.history, { x = self.x, y = self.y, time = 0 })
--     end

--     if self.returning and not self.physics.move_target then
--         local dx, dy = self:moveToTarget(self.return_speed)
--         if dx == 0 and dy == 0 then
--             self.returning = false
--             self.following = true
--         end
--     end

--     -- self.state_manager:update()

--     local can_blush = self.actor.can_blush
--     local can_move = Game.world and Game.world.player and Game.world.player:isMovementEnabled()
--     local using_walk_sprites = self.sprite.sprite == "walk" or self.sprite.sprite == "walk_blush"

--     if can_blush and using_walk_sprites and can_move then
--         self.blush_timer = self.blush_timer + DT

--         local player = Game.world.player
--         local player_x, player_y = player:getRelativePos(player.width / 2, player.height / 2, Game.world)
--         local follower_x, follower_y = self:getRelativePos(self.width / 2, self.height / 2, Game.world)
--         local distance_x = (player_x - follower_x)
--         local distance_y = (player_y - follower_y)
--         if ((math.abs(distance_x) <= 20) and (math.abs(distance_y) <= 14)) then
--             if (distance_x <= 0 and (player:getFacing() == "right")) then
--                 self.blush_timer = self.blush_timer + DT
--             elseif (distance_x >= 0 and (player:getFacing() == "left")) then
--                 self.blush_timer = self.blush_timer + DT
--             end
--         else
--             self.blush_timer = 0
--         end

--         if self.blush_timer >= 10 then
--             if not self.blushing then
--                 self.sprite:set("walk_blush")
--             end
--             self.blushing = true
--         end
--     else
--         self.blush_timer = 0
--     end

--     if (self.blush_timer < 10) and using_walk_sprites then
--         if self.blushing then
--             self.sprite:set("walk")
--         end
--         self.blushing = false
--     end

--     super.super.update(self)
-- end

return Follower
