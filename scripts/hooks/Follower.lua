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

return Follower
