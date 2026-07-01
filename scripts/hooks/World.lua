local World, super = HookSystem.hookScript(World)

local function isPlatformTransitioning()
    return Featherfall
        and Featherfall.isTransitioning
        and Featherfall:isTransitioning()
end

local function isPlatformingActive()
    return Featherfall
        and Featherfall.isPlatformModeActive
        and Featherfall:isPlatformModeActive()
end

function World:canInteract()
    if isPlatformTransitioning() then
        return false
    end
    if isPlatformingActive() then
        return false
    end
    return super.canInteract(self)
end

function World:canOpenMenu()
    if isPlatformTransitioning() then
        return false
    end
    if isPlatformingActive() then
        if not Featherfall:hasMenuTarget(self.player) then
            return false
        end
    end
    return super.canOpenMenu(self)
end

return World
