--[[fokker_dr1_guns.lua

    Initializes everything needed for the Jemma Studios Fokker Dr.1 "Dreidecker" Triplane guns
    made famous by Manfred "The Red Baron" von Richthofen and his Flying Circus.

    The guns were Spandau "Maxim" LMG (light machine gun) 08/15 which fired a 7.92x57 Mauser round.
    It fired approximately 450 rounds/minute and a magazine capicity of 500 rounds for each gun

    The mechanism on all the aircraft LMG's include a small lever, forward of the cocking bolt, that would be
    flipped back to that the belt would feed with the the help of another gunner (a requirement of the
    tripod or zepplin mounted version) this would then need to be flipped forward for the gun to fire without
    jamming.  In addition, most Dr.1's had a safety lever that could be flipped up (Richthofen's certainly did)
    which lifted the bolt just enough to keep the gun from firing.  Each safety would be flipped down prior to
    engaging a target.
]]

-- constants
--[[The assist lever of the right Spandau LMG machine gun is in an ackward position
and cannot be seen from the pilot's standard view.  So this option let's the pilot
arm both assist levers by actuating the left Spandau assist lever.  For "study level"
nerds, set this to 2 and you'll need to set up a custom camera, or move the camera
to see the right side of the receiver of the right gun to actuate the assist lever]]
defineProperty("num_assist_levers", 1)
defineProperty("barrel_rounds_min", 10) -- number of rounds to fire before the barrel begins to heat
defineProperty("barrel_rounds_max", 60) -- number of rounds to fire before the barrel is fully heated.
defineProperty("barrel_cool_time", 10)  -- number of seconds to fully cool the barrel.
defineProperty("barrel_overheat_reset", 0.3)  -- the machine gun will reset when the heat ratio gets back down to this level.

assist_time = {0.20, 0.35}          -- how long does it take to swing the assist levers?
assist_on = 0               -- the cocking assist lever is engaged
assist_off = 1              -- the cocking assist lever is off
assist_on_ing = 2           -- the cocking assist lever is being flipped on
assist_off_ing = 3          -- the cocking assist lever is being flipped off
bolt_home = 0               -- bolt lever is home
bolt_moving_fwd = 1         -- bolt is moving forward
bolt_moving_back = 2        -- bolt is moving back
rounds_per_second = 7       -- number of rounds fired per second
cock_bolt_time = {.32, 0.35}        -- number of seconds it takes the bolt to cycle while manual cocking.
slide_zone = 0.2            -- how much the bolt rotates before the slide moves
safety_time = {0.30, 0.30}          -- how long does it take to swing the assist levers?
safety_threshold = 0.90     -- how far up does the lever have to be to stay up?
safety_off = 0              -- safety is off
safety_on = 1               -- safety if on
safety_dropping = 2         -- safety is dropping
bolt_safe_pos = 0.15        -- what cock_rat is when the safety is on.
cock_not = 0                -- not cocked
cock_fed = 1                -- round fed but not chambered
cock_chambered = 2          -- round chambered
IS_JAMMED = 3
IS_BROKEN = 2
IS_FIRING = 1

secs_per_round = 1/rounds_per_second -- how long it takes to fire one round
cock_bolt_fire_time = {secs_per_round, secs_per_round}
bolt_home_pos = {0, 0}           -- what the bolt home position is (will change if safety is on)
bolt_phase = {0, 0}              -- bolt phase [0:home,1:moving fwd,2:moving back]
cock_phase = {0, 0}              -- cocking phase [0:it's not,1:round in receiver,2:round chambered]
gun_fired = {0, 0}               -- gun is being fired [0: no it isn't, 1: yes it is]
gun_status = {0, 0}              -- weapon status [0:unloaded,1:ready to fire,2:jammed,3:broken]
gun_armed = {0, 0}               -- gun armed
safety_status = {0, 0}           -- status of safety lever [0: off, 1: on, 2: dropping]
rounds_fired = {0, 0}            -- number of rounds continuously fired used for barrel heat.
overheated_barrel = {0, 0}       -- are the barrels overheated? [0: nope, 1: yep]

xp_gun_armed = globalPropertyi("sim/cockpit/weapons/guns_armed")   -- [0:unarmed, 1:weapons hot]
xp_rounds_left = globalPropertyfa("sim/weapons/bul_rounds")         -- no. rounds in LMG's
xp_engine_running = globalPropertyiae("sim/flightmodel/engine/ENGN_running", 1)     -- 0:not running; 1:it's running
cid_xp_fire_guns = sasl.findCommand ("sim/weapons/fire_guns")
cid_xp_startup = sasl.findCommand("sim/starters/engage_starter_1")
cid_xp_fix_all = sasl.findCommand("sim/operation/fix_all_systems")
set(xp_rounds_left, {500, 500}, 1, 2)

gunfire = {}
gunfire[1] = sasl.al.loadSample ("sounds/wpn_fire_gun.wav")
gunfire[2] = sasl.al.loadSample ("sounds/wpn_fire_gun.wav")
sasl.al.setSamplePosition ( gunfire[1] , -0.12689, 0.547209, 0.12)
sasl.al.setSamplePosition ( gunfire[2] , 0.12689, 0.547209, 0.12)
sasl.al.setSampleGain ( gunfire[1] , 200)
sasl.al.setSampleGain ( gunfire[2] , 200)
sasl.al.setSampleRelative ( gunfire[1] , 0)
sasl.al.setSampleRelative ( gunfire[2] , 0)

cocking_sound = {}
cocking_sound[1] = sasl.al.loadSample ("sounds/cock_bolt.wav")
cocking_sound[2] = sasl.al.loadSample ("sounds/cock_bolt.wav")
sasl.al.setSamplePosition ( cocking_sound[1] , -0.12689, 0.547209, 1.12)
sasl.al.setSamplePosition ( cocking_sound[2] , 0.12689, 0.547209, 1.12)
sasl.al.setSampleGain ( cocking_sound[1] , 200)
sasl.al.setSampleGain ( cocking_sound[2] , 200)

cock_back = {}
cock_back[1] = sasl.al.loadSample ("sounds/cock_bolt_back.wav")
cock_back[2] = sasl.al.loadSample ("sounds/cock_bolt_back.wav")
sasl.al.setSamplePosition ( cock_back[1] , -0.12689, 0.547209, 1.12)
sasl.al.setSamplePosition ( cock_back[2] , 0.12689, 0.547209, 1.12)
sasl.al.setSampleGain ( cock_back[1] , 200)
sasl.al.setSampleGain ( cock_back[2] , 200)

function limit_ratio(tRat)
    -- enforces lower and upper limits for a float ratio between 0.00 and 1.00
    if tRat < 0 then tRat = 0 end   -- negative numbers force to 0
    if tRat > 1 then tRat = 1 end   -- anything above 1.00 forced to 1.00
    return tRat
end

function assist_handler()
    -- Ensures that changes to the dataref don't exceed the 0.00 thru 1.00 limit
    for i = 1, 2, 1
    do 
        set (assist_rat, limit_ratio(get(assist_rat, i)), i)
    end
end

function change_assist_lever(i)
    -- increments the cocking assist lever (either up or down)
    local assist_step = 1 / assist_time[i] * timer_lib.SIM_PERIOD

    if get(assist_status, i) == assist_off_ing then
        set (assist_rat, get(assist_rat, i) + assist_step, i)  -- if we're enganging it we increment up
        assist_handler()
        if get(assist_rat, i) == 1 then
            set(assist_status, assist_off, i)
            update_cock_status(i)
        end
    end
    if get(assist_status, i) == assist_on_ing then
        set(assist_rat, get(assist_rat, i) - assist_step, i)
        assist_handler()
        if get(assist_rat, i) == 0 then
            set(assist_status, assist_on, i)
            update_cock_status(i)
        end
    end
end

function assist_toggle_handler(i)
    if get(assist_status, i) == assist_on or get(assist_status, i) == assist_on_ing then      -- it's engaged so we'll disengage it
        set(assist_status, assist_off_ing, i)
        if get(num_assist_toggles) == 1 then -- we're using the left assist lever for both machine guns so...
            set(assist_status, assist_off_ing, 2)
        end                
    elseif get(assist_status, i) == assist_off or get(assist_status, i) == assist_off_ing then -- it's disengaged so we'll engage it
        set(assist_status, assist_on_ing, i)
        if get(num_assist_toggles) == 1 then -- we're using the left assist lever for both machine guns so...
            set(assist_status, assist_on_ing, 2)
        end                
    end
end

function assist_left_toggle_handler(phase)
    if phase == SASL_COMMAND_BEGIN then                    -- we only do this once per click
        assist_toggle_handler(1)
    end
    return 1
end

function assist_right_toggle_handler(phase)
    if phase == SASL_COMMAND_BEGIN then                    -- we only do this once per click
        assist_toggle_handler(2)
    end
    return 1
end

function cock_lever_handler(i)
    if bolt_phase[i] == bolt_home then
        bolt_phase[i] = bolt_moving_fwd
        sasl.al.playSample ( cocking_sound[i] )
    end
    if get(assist_status, i) == assist_off and get(guns_firing, i) == IS_JAMMED then
        if not sasl.al.isSamplePlaying ( cock_back[i]) then
            sasl.al.playSample ( cock_back[i] )
        end
        bolt_phase[i] = bolt_moving_back
        cock_phase[i] = cock_fed
        set(guns_armed, 0, i)
        set(guns_firing, 0, i)
    end
end

function cock_lever_left_toggle_handler(phase)
    if phase == SASL_COMMAND_BEGIN then                    -- we only do this once per click
        cock_lever_handler(1)
    end
    return 1
end

function cock_lever_right_toggle_handler(phase)
    if phase == SASL_COMMAND_BEGIN then                    -- we only do this once per click
        cock_lever_handler(2)
    end
    return 1
end

function safety_handler(i)
    -- Ensures that changes to the dataref don't exceed the 0.00 thru 1.00 limit
    set(safety_rat , limit_ratio(get(safety_rat, i)), i)
    set(cock_rat, get(safety_rat, i) * bolt_safe_pos, i)   -- if we moved the safety lever, we need to move the bolt lever
end

function safety_left_lever_up_handler(phase)
    local safety_step = 1 / safety_time[1] * timer_lib.SIM_PERIOD
    if phase < SASL_COMMAND_END then  -- if the mouse has been clicked or is held down
        set(safety_rat, get(safety_rat, 1) + safety_step, 1)   -- we'll increment the safety ratio
        safety_handler(1)                        -- we need to make sure it's not beyond limits
    else                      -- if the mouse is released
        if get(safety_rat, 1) < safety_threshold then   -- did they get the safety lever up far enough?
            safety_status[1] = safety_dropping     -- then we'll drop it
        else
            safety_status[1] = safety_on           -- otherwise the safety is on
            bolt_home_pos[1] = get(cock_rat, 1)            -- save the bolt position in case it gets moved
            set(guns_armed, 0, 1)                    -- if the safety is on, disable the weapon (duh)
        end
    end
end

function safety_left_lever_down_handler(phase)
    local safety_step = 1 / safety_time[1] * timer_lib.SIM_PERIOD
    if phase < SASL_COMMAND_END then    -- if the mouse has been clicked or is held down
        set(safety_rat, get(safety_rat, 1) - safety_step, 1)   -- we'll decrement the safety ratio
        safety_handler(1)                        -- and make sure it wasn't decremented beyond limits
    else                        -- if the mouse is released
        if get(safety_rat, 1) < safety_threshold then   -- did they get the safety lever up far enough?
            safety_status[1] = safety_dropping     -- then we'll drop it
        else
            safety_status[1] = safety_on           -- otherwise the safety is on
            bolt_home_pos[1] = get(cock_rat, 1)            -- save the bolt position in case it gets moved
            set(guns_armed, 0, 1)                    -- safety on, gun unarmed.
       end
    end
end

function safety_right_lever_up_handler(phase)
    local safety_step = 1 / safety_time[2] * timer_lib.SIM_PERIOD
    if phase < SASL_COMMAND_END then  -- if the mouse has been clicked or is held down
        set(safety_rat, get(safety_rat, 2) + safety_step, 2)   -- we'll increment the safety ratio
        safety_handler(2)                        -- we need to make sure it's not beyond limits
    else                      -- if the mouse is released
        if get(safety_rat, 2) < safety_threshold then   -- did they get the safety lever up far enough?
            safety_status[2] = safety_dropping     -- then we'll drop it
        else
            safety_status[2] = safety_on           -- otherwise the safety is on
            bolt_home_pos[2] = get(cock_rat, 2)            -- save the bolt position in case it gets moved
            set(guns_armed, 0, 2)                    -- if the safety is on, disable the weapon (duh)
        end
    end
end

function safety_right_lever_down_handler(phase)
    local safety_step = 1 / safety_time[2] * timer_lib.SIM_PERIOD
    if phase < SASL_COMMAND_END then    -- if the mouse has been clicked or is held down
        set(safety_rat, get(safety_rat, 2) - safety_step,2)   -- we'll decrement the safety ratio
        safety_handler(2)                        -- and make sure it wasn't decremented beyond limits
    else                        -- if the mouse is released
        if get(safety_rat, 2) < safety_threshold then   -- did they get the safety lever up far enough?
            safety_status[2] = safety_dropping     -- then we'll drop it
        else
            safety_status[2] = safety_on           -- otherwise the safety is on
            bolt_home_pos[2] = get(cock_rat, 2)            -- save the bolt position in case it gets moved
            set(guns_armed, 0, 2)                    -- safety on, gun unarmed.
       end
    end
end
function check_rounds (i)
    if get(xp_rounds_left, i) <= 0 then 
        set (xp_rounds_left, 0, i)
        set (guns_armed, 0, i)
    end
end

function update_cock_status(i)
    -- adjusts the status of the gun based on position of all the damn levers and prev. events
    -- called every time the bolt is activated.
    if get(assist_status, i) == assist_on then
        if cock_phase[i] == cock_chambered and get(guns_firing, i) == 0 then    -- well, we cycled the bolt with a round in the chamber so we'll lose it.
            set(xp_rounds_left, get(xp_rounds_left, i) - 1, i)
            check_rounds(i)
        end
        if cock_phase[i] == cock_chambered and safety_status[i] == safety_off and get(xp_rounds_left, i) >= 1 and get(xp_engine_running) == 1 then
            set (guns_armed, 1, i)
        end
        if cock_phase[i] == cock_fed then cock_phase[i] = cock_chambered end  -- if a round is fed, then it needs to be chambered.
        if cock_phase[i] == cock_not then cock_phase[i] = cock_fed end  -- if a round isn't fed, then it needs to be fed (into the receiver, not food)
    end
    if get(assist_status, i) == assist_off then
--        set (guns_armed, 0, i)
    end
    set (belt_rat, 1, i)                                 -- snap the belt to it's original position to fake a continuous feed.
end

function cock_handler(i)
    if get(cock_rat, i) < bolt_home_pos[i] then set(cock_rat, bolt_home_pos[i], i) end
    if get(cock_rat, i) > 1 then set(cock_rat, 1, i) end
end

function change_cock_lever(i)
    -- moves the cock lever forward then back
    local bStep 
    if gun_fired[i] == 0 or gun_fired[i] == IS_JAMMED then
        bStep = 1 / cock_bolt_time[i] * timer_lib.SIM_PERIOD
    else
        bStep = 1 / cock_bolt_fire_time[i] * timer_lib.SIM_PERIOD * 2 -- need to double it, so it'll go in and out at correct rounds/min.
    end
    if bolt_phase[i] == bolt_moving_fwd then
        set(cock_rat, get(cock_rat, i) + bStep, i)
        cock_handler(i)
        if get(assist_status, i) == assist_on then
            set (belt_rat, get(cock_rat, i), i)
            if get(cock_rat, i) > slide_zone then
                set(slide_rat, (get(cock_rat, i) - slide_zone) * (1/(1-slide_zone)), i)
            end
        elseif get(guns_firing, i) == IS_FIRING then
            set (belt_rat, get(cock_rat, i), i)
            set (slide_rat, 1 - get(cock_rat, i), i)
        end
        if get(cock_rat, i) >= 1 and get(guns_firing, i) ~= IS_JAMMED then
            if get(assist_status, i) == assist_on and get(guns_firing, i) == IS_FIRING then
                set(guns_firing, IS_JAMMED, i)
                gun_fired[i] = IS_JAMMED
            else
                update_cock_status(i)
                bolt_phase[i] = bolt_moving_back
            end
        end
    end
    if bolt_phase[i] == bolt_moving_back and get(guns_firing, i) ~= IS_JAMMED then
        set(cock_rat, get(cock_rat, i) - bStep, i)
        cock_handler(i)
        if get(assist_status, i) == assist_on then
            set(slide_rat, get(cock_rat, i), i)
        elseif get(guns_firing, i) == IS_FIRING or gun_fired[i] == IS_JAMMED then
            set(slide_rat, 1 - get(cock_rat, i), i)
        end
        if get(cock_rat, i) == bolt_home_pos[i] then
            bolt_phase[i] = bolt_home
            set(slide_rat, 0, i)
            if gun_fired[i] == 1 or gun_fired[i] == IS_JAMMED then
                gun_fired[i] = 0
            end
        end
    end
end

function fire_gun(i)
    set (trigger_state, 1, i)
    if get(xp_engine_running) == 1 and get(guns_armed, i) == 1 and get(guns_firing, i) <= 1 then
        set(guns_firing, 1, i)        
        if get(xp_rounds_left, i) >= 1 then
            if bolt_phase[i] == bolt_home then
                sasl.al.playSample(gunfire[i])
                bolt_phase[i] = bolt_moving_fwd
                gun_fired[i] = 1
                set(xp_rounds_left, get(xp_rounds_left, i) - 1, i)
                check_rounds(i)
                rounds_fired[i] = rounds_fired[i] + 1
            end
        else
            set(guns_firing, 0, i)
            rounds_fired[i] = 0
        end
    elseif get(guns_firing, i) < IS_BROKEN then
        set(guns_firing, 0, i)
        rounds_fired[i] = 0   
    end
end

function fire_both_guns_handler(phase)
    if phase < SASL_COMMAND_END then
        fire_gun(2)
        fire_gun(1)
    else
        for i = 1, 2, 1
        do
            set(trigger_state, 0, i)
            if get(guns_firing, i) < IS_BROKEN then
                set(guns_firing, 0, i)
            end
            rounds_fired[i] = 0
        end
    end
    return 0
end

function fire_left_gun_handler(phase)
    if phase < SASL_COMMAND_END then
        fire_gun(1)        
    else
        set(trigger_state, 0, 1)
        if get(guns_firing, 1) < IS_BROKEN then
            set(guns_firing, 0, 1)
        end
        rounds_fired[1] = 0
     end
    return 0
end

function fire_right_gun_handler(phase)
    if phase < SASL_COMMAND_END then
        fire_gun(2)        
    else
        set(trigger_state, 0, 2)
        if get(guns_firing, 2) < IS_BROKEN then
            set(guns_firing, 0, 2)
        end
        rounds_fired[2] = 0
     end
    return 0
end

function startup_engine_after_handler(phase)
    if phase == SASL_COMMAND_END then
        if get(xp_engine_running) == 1 then
            update_cock_status (1)
            update_cock_status (2)
        end
    end
    return 0
end

function fix_failure_after_handler(phase)
    if phase == SASL_COMMAND_BEGIN then
        for i=1, 2, 1
        do
            if get(guns_firing, i) == IS_JAMMED then
                set (slide_rat, 0, i)
            end
            set(guns_firing, 0, i)
            -- gun_status[i] = 0
            overheated_barrel[i] = 0
            xp_rounds_left[i] = 500
            set(barrel_heat, 0, i)
        end
    end
    return 0
end


assist_rat = createGlobalPropertyfa("Dr1/spandau/assist_lever_ratio", {1.0, 1.0})
assist_status = createGlobalPropertyia("Dr1/spandau/assist_lever_status", {assist_off, assist_off})              -- cocking assist lever status (0:on,1:off,2:on-ing,3:off-ing)
num_assist_toggles = createGlobalPropertyi("Dr1/spandau/num_assist_toggles", get(num_assist_levers))   -- number of assist toggles (1=just left, 2 = both left and right)
cock_rat = createGlobalPropertyfa("Dr1/spandau/cock_lever_ratio", {0.0, 0.0})         -- cock lever position ratio 
slide_rat = createGlobalPropertyfa("Dr1/spandau/bolt_slide_ratio", {0.0, 0.0})                     -- bolt slide position ratio
belt_rat = createGlobalPropertyfa("Dr1/spandau/belt_position_ratio", {0.0, 0.0})                   -- belt position ratio
safety_rat = createGlobalPropertyfa("Dr1/spandau/safety_ratio",{0.0, 0.0})         -- safety lever position ratio
guns_armed = createGlobalPropertyia("Dr1/spandau/guns_armed", {0, 0})               -- arming status of machine guns [0 = unarmed, 1 = armed]
guns_firing = createGlobalPropertyia("Dr1/spandau/guns_firing", {0, 0})               -- firing status of machine guns [0 = not firing, 1 = firing, 2 = jammed, 3 = broken]
trigger_state = createGlobalPropertyia ("Dr1/spandau/trigger_state", {0,0})
barrel_heat = createGlobalPropertyfa ("Dr1/spandau/barrel_heat_ratio", {0,0})
assist_toggle_left = sasl.createCommand("Dr1/guns/assist_toggle_left", "Toggles the left cocking assist lever")       
sasl.registerCommandHandler ( assist_toggle_left , 0, assist_left_toggle_handler )
assist_toggle_right = sasl.createCommand("Dr1/guns/assist_toggle_right", "Toggles the right cocking assist lever")       
sasl.registerCommandHandler ( assist_toggle_right , 0, assist_right_toggle_handler )
cock_toggle_left = sasl.createCommand("Dr1/guns/bolt_lever_left", "Cycles left bolt lever")
sasl.registerCommandHandler ( cock_toggle_left, 0, cock_lever_left_toggle_handler )
cock_toggle_right = sasl.createCommand("Dr1/guns/bolt_lever_right", "Cycles right bolt lever")
sasl.registerCommandHandler ( cock_toggle_right, 0, cock_lever_right_toggle_handler )
safety_left_up = sasl.createCommand("Dr1/guns/safety_left_lever_up", "Moves the left safety lever up")
sasl.registerCommandHandler( safety_left_up, 0, safety_left_lever_up_handler)
safety_left_down = sasl.createCommand("Dr1/guns/safety_left_lever_down", "Moves the left safety lever down")
sasl.registerCommandHandler( safety_left_down, 0, safety_left_lever_down_handler)
safety_right_up = sasl.createCommand("Dr1/guns/safety_right_lever_up", "Moves the right safety lever up")
sasl.registerCommandHandler( safety_right_up, 0, safety_right_lever_up_handler)
safety_right_down = sasl.createCommand("Dr1/guns/safety_right_lever_down", "Moves the right safety lever down")
sasl.registerCommandHandler( safety_right_down, 0, safety_right_lever_down_handler)
fire_left_gun = sasl.createCommand("Dr1/guns/fire_left_gun", "Fire left machine gun")
sasl.registerCommandHandler( fire_left_gun, 0, fire_left_gun_handler)
fire_right_gun = sasl.createCommand("Dr1/guns/fire_right_gun", "Fire right machine gun")
sasl.registerCommandHandler( fire_right_gun, 0, fire_right_gun_handler )
sasl.registerCommandHandler ( cid_xp_fire_guns, 1, fire_both_guns_handler )
sasl.registerCommandHandler ( cid_xp_startup, 0, startup_engine_after_handler )
sasl.registerCommandHandler ( cid_xp_fix_all, 0, fix_failure_after_handler )


function update_barrel_ratios()
    local cool_step = 1 / get(barrel_cool_time) * timer_lib.SIM_PERIOD
    local barrel_heat_step
    for i = 1, 2, 1
    do
        if get(barrel_heat, i) > 0 and get(guns_firing, i) ~= 1 then
            set(barrel_heat, get(barrel_heat, i) - cool_step, i)
            if get(barrel_heat, i) <= get(barrel_overheat_reset, i) then
                overheated_barrel[i] = 0
            end
            if get (barrel_heat, i) < 0 then
                set (barrel_heat, 0, i)
            end
        end
        if get(barrel_heat, i) > 0 and rounds_fired[i] == 1 then 
            rounds_fired[i] = math.floor((get(barrel_rounds_max)-get(barrel_rounds_min)) * get(barrel_heat, i)) + get(barrel_rounds_min)
        end
        if get(guns_firing, i) == IS_FIRING and rounds_fired[i] >= get(barrel_rounds_min, i) and get(barrel_heat, i) < 1.5 then
            set(barrel_heat, (rounds_fired[i] - get (barrel_rounds_min)) / (get(barrel_rounds_max) - get(barrel_rounds_min)), i)
        end
        if get(barrel_heat, i) >= 1.0 then
            overheated_barrel[i] = 1
            set (guns_firing, IS_BROKEN, i)
            -- gun_status[i] = 3 -- broken
        end
    end
end

function update()
    update_barrel_ratios()
    for i = 1, 2, 1
    do
        if get(assist_status, i) > assist_off then  -- anything above "on and off" means it's moving
            change_assist_lever(i)
        end
        if bolt_phase[i] > bolt_home then      -- the bolt is moving
            change_cock_lever(i)
        end   
        if safety_status[i] == safety_dropping then
            local safety_step = 1 / safety_time[1] * timer_lib.SIM_PERIOD
            set(safety_rat, get(safety_rat, i) - safety_step, i)   -- decrement the safety lever ratio
            safety_handler(i)                        -- verify it's not out of limits
            if get(safety_rat, i) == 0 then 
                safety_status[i] = safety_off
                bolt_home_pos[i] = 0                       -- restore bolt home position
                if cock_phase[i] == cock_chambered and get(xp_rounds_left, i) >= 1 and get(xp_engine_running) == 1 then    -- safety off with round chambered, good to go!
                    set(guns_armed, 1, i)
                end
             end
        end
    end

    updateAll(components)
end

