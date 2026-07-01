local World, super = HookSystem.hookScript(World)

local function isPlatformTransitioning()
    return Featherfall
        and Featherfall.isTransitioning
        and Featherfall:isTransitioning()
end

function World:canInteract()
    if isPlatformTransitioning() then
        return false
    end
    return super.canInteract(self)
end

function World:canOpenMenu()
    if isPlatformTransitioning() then
        return false
    end
    if Featherfall and Featherfall.isPlatformModeActive and Featherfall:isPlatformModeActive() then
        if not Featherfall:hasMenuTarget(self.player) then
            return false
        end
    end
    return super.canOpenMenu(self)
end

return World
