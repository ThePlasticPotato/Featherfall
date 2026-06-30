local World, super = HookSystem.hookScript(World)

function World:canOpenMenu()
    if Featherfall and Featherfall.isPlatformModeActive and Featherfall:isPlatformModeActive() then
        if not Featherfall:hasMenuTarget(self.player) then
            return false
        end
    end
    return super.canOpenMenu(self)
end

return World
