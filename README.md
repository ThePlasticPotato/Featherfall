# Featherfall
###### jarona
Featherfall is a faithful port of Deltarune Chapter 5's platforming mechanic to the Kristal fangame engine. It's still a work in progress, so contributions are appreciated!

Features:
- Platforming physics
- Easy floor/wall/moving platform setup in tiled
- Modular character actions for party members
- A whole lot of variables good god

If you want to contribute, open a PR! The main goal of this lib is accuracy where possible, keep that in mind!

Below are the notes I took on the Platforming mechanic in Deltarune, and how it works:

# OBJECTS
- `obj_platswap` controls the platforming trigger, 0 is rpg view and 1 is platforming
- `obj_platswap_statue` is the statue trigger that calls platswap
- `obj_plat_player` is the platforming Kris controller and inherits from `obj_plat_entity`
- `obj_plat_game` owns platforming room state, pausing, respawn style etc etc basically
- `obj_plat_floor` and `obj_plat_block` are collision objects p sure floor is static and block is not
- `obj_plat_floortex_*` part of the weird rendering shit, projects out the floor/wall textures from the tiles i think?
- `obj_platswap_helper` helper class that transforms overworld objects to platform view
- `obj_platswap_prop` is the essentially dark_transition from kristal, it handles swappin the chars between without them like vanishing/reappearing
- `obj_plat_follower` converts Susie/Ralsei from `obj_caterpillarchara` into platforming characters

# TIMING
- it takes 20 frames to transition max
- if it takes longer than 10 frames it lerps for like 9? i have no idea wtf its doing there
- if youre in platform mode and youre transitioning back then it applies 8frame delay until the ground gets unsquished
- it uses basic ease inout with 3 second input i think, i think thats kristal equivalent EaseInOutSine
- `obj_plat_floortex` exists = platform floor scale targets 0.1 when transitioning back, otherwise it stays 1
- `scr_platswap_lerp` records the lerps into `transition_info` and then `obj_platswap` plays them out

# ENTERING (object order)
- it hides kris and then destroys them after setup transition
- platform kris's position is set to overworld kris's position but with `x+19` and `y+38`
- if a statue is within 120 pixels during noninstant, kris snaps to the statue's pos
- if a floortex is under kris and vertical speed is 0, they get snapped to it but y-38
- if kris starts inside an object/block then it moves them up by 4 pixels up to 60 times before giving up
- ground gets checked and if it gets found then kris snaps to it
- transitions follwoers get obliterated and made into `obj_plat_follower`
- camera object switches to `obj_plat_camera`

# EXITING (object order maybe?)
- overworld kris gets un thanos snapped at x-19, y-38
- if`obj_platswap_overh_ystart` is there and Kris is grounded, that object's `y` is used for overworld height
- if a floortex is under kris, overworld y is snapped to `floortex.y_ow - 76` (so its overworld y - 76)
- if a statue is the transitioner it repositions kris around its y
- if overworld kris would be inside a solid object it searches 12 steps around for a free space
- destroys platform player, platform followers convert

# OTHER WEIRD QUIRKS
- theres a susie trigger for hittign a floating statue with her axe that i think is unused? i dont remember that at all
- statues cancel out bascially all platform logic
- if kris is holding a watering can you cant activate statues (watering cant...)
- the whole system treats platforming characters as basically entirely separate objects... for kristal id honestly use a state but idk...

# Motion code collision detection order
1. horizontal collision correction
2. ground checks
3. slope checks
4. moving entity checks (like ralsei hang)
5. does some weird ground snapping probably for snappiness
6. movement adjustment thingies aka external forces moving the player
7. ceiling check
8. vertical velocity clamp

# Default Variables
### `obj_plat_entity`
- `entity_gravity = 0.5`
- `max_fallspeed = 15`
### `obj_plat_player`
- `entity_gravity = 1.25`
- `max_fallspeed = 20`
- `hspeed_max = 9`
- `air_accel = 2`
- `air_decel = 0.5`
- `ground_accel = 2`
- `ground_decel = 0.65`
- `jumpheight = 20`
- `jump_mintime = 4`
- `jump_coyote_time_max = 4`
- `jumpsquat_max = 2`
- `dashspeed = 11`
- `jumpbuffer = 4`
- `max_hovers = 5`
- `jumphover_meter = 140`
- `jumphover_min = 5`
- `hover_movespeed = 6`
- `heart_offset_max = 25`
- `jumphover_iframes_requirement = 10`
