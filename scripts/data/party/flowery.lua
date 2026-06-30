local party, super = Class(PartyMember, "flowery")

function party:init()
    super.init(self)

    self.name = "Flowery"
    self.title = "Best Friend"
    self.actor = "flowery"
    self.color = {1, 1, 0}
    self.soul_color = {1, 0, 0}
    self.has_act = true
    self.has_spells = false
    self.health = 999
    self.lw_health = 999
    self.stats = {
        health = 999,
        attack = 12,
        defense = 1,
        magic = 0,
    }
    self.lw_stats = {
        health = 999,
        attack = 10,
        defense = 10,
    }
    self.menu_icon = "party/flowery/menu/spr_dmenu_items_flowery"
    self.head_icons = "party/flowery/menu/spr_dmenu_items_floweryhead"
    self.name_sprite = "party/flowery/menu/spr_bnameflowery"
    self.attack_sprite = "party/flowery/platform/kick"
    self.attack_sound = "flowery/punchheavythunder"
end

function party:onPlatformFollowerAction(kind, follower_state, target, action_data)
    if kind ~= "flowery" and kind ~= "flowery_omega" then
        if super.onPlatformFollowerAction then
            return super.onPlatformFollowerAction(self, kind, follower_state, target, action_data)
        end
        return true
    end
    if not (Game.world and Jarona and follower_state and target) then
        return target and target.performFollowerAction and target:performFollowerAction(kind, follower_state, action_data)
    end

    action_data = action_data or {}
    action_data.omega = kind == "flowery_omega" or (target and target.action_kind == "flowery_omega") or action_data.omega == true
    action_data.release_animation = action_data.omega and "omega_jarona" or "jarona_kick"
    local character = follower_state and follower_state.getCharacter and follower_state:getCharacter()
    local target_x = target.cx or target.target_x or target.x or (character and character.x) or 0
    local target_y = target.cy or target.target_y or target.y or (character and character.y) or 0
    local distance = character and MathUtils.dist(character.x, character.y, target_x, target_y) or 0

    if action_data.omega then
        action_data.recover_timer = (action_data.omega_transform_time or 150)
            + (action_data.omega_charge_time or 80)
            + 12
            + (action_data.jarona_recover_time or 20)
            + 5
    else
        local speed_limit = math.max(action_data.jarona_speed_limit or action_data.jarona_speed or 20, 1)
        action_data.recover_timer = (action_data.jarona_windup_time or 14)
            + math.ceil(distance / speed_limit)
            + 8
            + (action_data.jarona_bounce_time or 10)
            + 3
    end
    local jarona = Jarona(follower_state, target, action_data)
    Game.world:addChild(jarona)
    return true
end

return party
