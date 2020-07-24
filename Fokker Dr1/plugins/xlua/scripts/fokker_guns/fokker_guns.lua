--[[
    fokker_guns.lua
    by Jeffory J. Beckers
    16 June 2020
    Creative Commons CC BY-SA-NC

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

-- Assign constants

safety_step = 0.05          -- how much we change the ratio for each command sent
safety_threshold = 0.90     -- how far up does the lever have to be to stay up?
assist_step = 0.06          -- how much we change the ratio for each command sent
bolt_step = 0.05            -- how much we change the charging bolt for each command sent
rounds_per_second = 7       -- how many rounds per second is the gun fired.
bolt_safe_pos = 0.15        -- what cock_rat is when the safety is on.
slide_zone = 0.2           -- how much the bolt rotates before the slide moves
pressed = 0                 -- a manipulator was just clicked
holding = 1                 -- the manipulator is being held down
released = 2                -- the manipulator was released
safety_off = 0              -- safety is off
safety_on = 1               -- safety if on
safety_dropping = 2         -- safety is dropping
assist_on = 0               -- the cocking assist lever is engaged
assist_off = 1              -- the cocking assist lever is off
assist_on_ing = 2           -- the cocking assist lever is being flipped on
assist_off_ing = 3          -- the cocking assist lever is being flipped off
bolt_home = 0               -- bolt lever is home
bolt_moving_fwd = 1         -- bolt is moving forward
bolt_moving_back = 2        -- bolt is moving back
cock_not = 0                -- not cocked
cock_fed = 1                -- round fed but not chambered
cock_chambered = 2          -- round chambered
gun_unloaded = 0            -- gun unloaded
gun_ready = 1               -- gun ready to fire
gun_jammed = 2              -- gun jammed
gum_broken = 3              -- gun broken
isOn = 1                    -- generic true
isOff = 0                   -- generic false

-- Define global variables
bolt_home_pos = 0           -- what the bolt home position is (will change if safety is on)
bolt_phase = 0              -- bolt phase [0:home,1:moving fwd,2:moving back]
cock_phase = 0              -- cocking phase [0:it's not,1:round in receiver,2:round chambered]
gun_status = 0              -- weapon status [0:unloaded,1:ready to fire,2:jammed,3:broken]\
gun_fired = 0               -- gun is being fired [0: no it isn't, 1: yes it is]

-- Assign the datarefs we need
xp_gun_armed = find_dataref("sim/cockpit/weapons/guns_armed")   -- [0:unarmed, 1:weapons hot]
xp_rounds_left = find_dataref("sim/weapons/bul_rounds[0]")         -- no. rounds in left LMG
xp_engine_running = find_dataref("sim/flightmodel/engine/ENGN_running[0]")     -- 0:not running; 1:it's running

-- Create functions used by custom datarefs & custom commands
function limit_ratio(tRat)
    -- enforces lower and upper limits for a float ratio between 0.00 and 1.00
    if tRat < 0 then tRat = 0 end   -- negative numbers force to 0
    if tRat > 1 then tRat = 1 end   -- anything above 1.00 forced to 1.00
    return tRat
end

function safety_handler()
    -- Ensures that changes to the dataref don't exceed the 0.00 thru 1.00 limit
    safety_rat = limit_ratio(safety_rat)
    cock_rat = safety_rat * bolt_safe_pos   -- if we moved the safety lever, we need to move the bolt lever
end

function assist_handler()
    -- Ensures that changes to the dataref don't exceed the 0.00 thru 1.00 limit
    assist_rat = limit_ratio(assist_rat)
end

function cock_handler()
    if cock_rat < bolt_home_pos then cock_rat = bolt_home_pos end
    if cock_rat > 1 then cock_rat = 1 end
end

function change_assist_lever()
    -- increments the cocking assist lever (either up or down)
    if assist_status == assist_off_ing then
        assist_rat = assist_rat + assist_step  -- if we're enganging it we increment up
        assist_handler()
        if assist_rat == 1 then
            assist_status = assist_off
            update_cock_status()
        end
    end
    if assist_status == assist_on_ing then
        assist_rat = assist_rat - assist_step
        assist_handler()
        if assist_rat == 0 then
            assist_status = assist_on
            update_cock_status()
        end
    end
end

function check_rounds ()
    if xp_rounds_left <= 0 then 
        xp_rounds_left = 0
        xp_gun_armed = 0
    end
end

function update_cock_status()
    -- adjusts the status of the gun based on position of all the damn levers and prev. events
    -- called every time the bolt is activated.
    if assist_status == assist_on then
        if cock_phase == cock_chambered and gun_fired == 0 then    -- well, we cycled the bolt with a round in the chamber so we'll lose it.
            xp_rounds_left = xp_rounds_left - 1
            check_rounds()
        end
        if cock_phase == cock_fed then cock_phase = cock_chambered end  -- if a round is fed, then it needs to be chambered.
        if cock_phase == cock_not then cock_phase = cock_fed end  -- if a round isn't fed, then it needs to be fed (into the receiver, not food)
        if cock_phase == cock_chambered and safety_status == safety_off and xp_rounds_left >= 1 and xp_engine_running == 1 then
            xp_gun_armed = 1
        end
    end
    if assist_status == assist_off then
        xp_gun_armed = 0
    end
    belt_rat = 1                                 -- snap the belt to it's original position to fake a continuous feed.
end

function change_cock_lever()
    -- moves the cock lever forward then back
    local bStep 
    if gun_fired == 0 then
        bStep = bolt_step
    else
        bStep = .1428
    end
    if bolt_phase == bolt_moving_fwd then
        cock_rat = cock_rat + bStep
        cock_handler()
        if assist_status == assist_on then
            belt_rat = cock_rat
            if cock_rat > slide_zone then
                slide_rat = (cock_rat - slide_zone) * (1/(1-slide_zone))
            end
        end
        if cock_rat == 1 then
            update_cock_status()
            bolt_phase = bolt_moving_back
        end
    end
    if bolt_phase == bolt_moving_back then
        cock_rat = cock_rat - bStep
        cock_handler()
        if assist_status == assist_on then
            slide_rat = cock_rat
        end
        if cock_rat == bolt_home_pos then
            bolt_phase = bolt_home
            if gun_fired == 1 then
                gun_fired = 0
            end
        end
    end
end

function safety_lever_up_handler(phase, duration)
    if phase < released then  -- if the mouse has been clicked or is held down
        safety_rat = safety_rat + safety_step   -- we'll increment the safety ratio
        safety_handler()                        -- we need to make sure it's not beyond limits
    else                      -- if the mouse is released
        if safety_rat < safety_threshold then   -- did they get the safety lever up far enough?
            safety_status = safety_dropping     -- then we'll drop it
        else
            safety_status = safety_on           -- otherwise the safety is on
            bolt_home_pos = cock_rat            -- save the bolt position in case it gets moved
            xp_gun_armed = 0                    -- if the safety is on, disable the weapon (duh)
        end
    end
end

function safety_lever_down_handler(phase, duration)
    if phase < released then    -- if the mouse has been clicked or is held down
        safety_rat = safety_rat - safety_step   -- we'll decrement the safety ratio
        safety_handler()                        -- and make sure it wasn't decremented beyond limits
    else                        -- if the mouse is released
        if safety_rat < safety_threshold then   -- did they get the safety lever up far enough?
            safety_status = safety_dropping     -- then we'll drop it
        else
            safety_status = safety_on           -- otherwise the safety is on
            bolt_home_pos = cock_rat            -- save the bolt position in case it gets moved
            xp_gun_armed = 0                    -- safety on, gun unarmed.
       end
    end
end

function assist_lever_toggle_handler(phase, duration)
    if phase == pressed then                    -- we only do this once per click
        if assist_status == assist_on or assist_status == assist_on_ing then      -- it's engaged so we'll disengage it
            assist_status = assist_off_ing
        elseif assist_status == assist_off or assist_status == assist_off_ing then -- it's disengaged so we'll engage it
            assist_status = assist_on_ing
        end
    end
end

function cock_lever_handler(phase, duration)
    if phase == pressed and bolt_phase == bolt_home then    -- the bolt is home and someone doesn't want it to be
        bolt_phase = bolt_moving_fwd                        -- start moving it forward
    end
end

function fire_guns_before_handler(phase, duration)
    if phase == pressed or phase == holding then
        trigger_on = isOn
    else
        trigger_on = isOff
    end
    if xp_engine_running == 0 then xp_gun_armed = 0 end
    if phase == holding and bolt_phase == bolt_home and xp_gun_armed == 1 then
        bolt_phase = bolt_moving_fwd
        gun_fired = 1
    end
end

function fire_guns_after_handler(phase, duration)
end

function startup_engine_before_handler(phase, duration)
end

function startup_engine_after_handler(phase, duration)
    if phase == released then
        if xp_engine_running == 1 then
            update_cock_status ()
        end
    end
end

-- Create custom datarefs

safety_rat = create_dataref("Dr1/spandau/safety_ratio","number",safety_handler)         -- safety lever position ratio
safety_status = create_dataref("Dr1/spandau/safety_status","number")                    -- safety lever position (0:down,1:up,2:dropping)
assist_rat = create_dataref("Dr1/spandau/assist_lever_ratio","number",assist_handler)   -- cocking assist lever position ratio
assist_status = create_dataref("Dr1/spandau/assist_lever_status","number")              -- cocking assist lever status (0:on,1:off,2:on-ing,3:off-ing)
cock_rat = create_dataref("Dr1/spandau/cock_lever_ratio","number",cock_handler)         -- cock lever position ratio 
slide_rat = create_dataref("Dr1/spandau/bolt_slide_ratio","number")                     -- bolt slide position ratio
belt_rat = create_dataref("Dr1/spandau/belt_position_ratio","number")                   -- belt position ratio
trigger_on = create_dataref("Dr1/spandau/trigger_state","number")                       -- is the fire_guns command being sent?
gun_fired = create_dataref("Dr1/spandau/fire_sound", "number")                         -- send fire_sound if 1       

-- Create custom commands
safety_up = create_command("Dr1/guns/safety_lever_up", "Moves the safety lever up", safety_lever_up_handler)
safety_down = create_command("Dr1/guns/safety_lever_down", "Moves the safety lever up", safety_lever_down_handler)
assist_toggle = create_command("Dr1/guns/assist_toggle", "Toggles the cocking assist lever", assist_lever_toggle_handler)
cock_toggle = create_command("Dr1/guns/bolt_lever", "Cycles bolt lever", cock_lever_handler)
fire_guns = wrap_command("sim/weapons/fire_guns", fire_guns_before_handler, fire_guns_after_handler)
start_up = wrap_command("sim/starters/engage_starter_1", startup_engine_before_handler, startup_engine_after_handler)

-- Housekeeping

function flight_start()
    safety_rat = 0              -- initialize the aircraft with the safety off
    safety_status = 0           -- initialize the aircraft with the safety down
    assist_rat = 1              -- initialize the aircraft with the cocking assist disengaged
    assist_status = assist_off  -- initial the aircraft with the cocking assist not moving.
end

function after_physics()
    -- if the safety lever isn't down we'll keep dropping it.
--    if fire_sound == 1 then fire_sound = 0 end  -- reset the fire sound dataref.
    if safety_status == safety_dropping then
        safety_rat = safety_rat - safety_step   -- decrement the safety lever ratio
        safety_handler()                        -- verify it's not out of limits
        if safety_rat == 0 then 
            safety_status = safety_off
            bolt_home_pos = 0                       -- restore bolt home position
            if cock_phase == cock_chambered and xp_rounds_left >= 1 then    -- safety off with round chambered, good to go!
                xp_gun_armed = 1
            end
         end
    end
    if assist_status > assist_off then  -- anything above "on and off" means it's moving
        change_assist_lever()
    end
    if bolt_phase > bolt_home then      -- the bolt is moving
        change_cock_lever()
    end
    check_rounds()
end