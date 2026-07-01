---@class Player : Character
---@field platform_state PlayerPlatformState
local Player, super = HookSystem.hookScript(Player)

local PlayerPlatformState = libRequire("featherfall", "scripts.world.states.PlayerPlatformState")

function Player:init(chara, x, y)
    super.init(self, chara, x, y)

    self.platform_state = PlayerPlatformState(self)
    self.state_manager:addState("FEATHERFALL", self.platform_state)
end

function Player:isPlatforming()
    return self.state_manager and self.state_manager.state == "FEATHERFALL"
end

function Player:isCameraAttachable()
    if self:isPlatforming() then
        return false
    end
    return super.isCameraAttachable(self)
end

function Player:requestPlatformAction(target, data)
    if self.platform_state then
        return self.platform_state:requestAction(target, data)
    end
    return false
end

function Player:draw()
    super.draw(self)
    if self:isPlatforming() and self.platform_state and self.platform_state.drawHoverUI then
        self.platform_state:drawHoverUI()
    end
end

return Player
