--[[
    fokker_dr1_control.lua
    by Jeffory J. Beckers
    20 June 2020
    Creative Commons CC BY-SA-NC

    Adds additional control for Jemma Studios Fokker Dr.1 "Dreidecker" Triplane
    made famous by Manfred "The Red Baron" von Richthofen and his Flying Circus.
]]

-- constants/properties
defineProperty("magneto_full_charge", 1)
defineProperty("magneto_cranks_to_full_charge", 6)
defineProperty("secs_to_full_magneto_charge", 3)
defineProperty("starter_spin_time", 2.0)
defineProperty("fuel_valve_turn_time", 0.25)  -- time it takes the fuel valve to turn in seconds.
defineProperty("mag_switch_turn_time", 0.25)  -- time it takes the fuel valve to turn in seconds.
defineProperty("oil_pulse_interval", 2.0)  -- time between oil pulses
defineProperty("oil_pulse_decay", 0.08)  -- time it takes oil to drain after pulse.

tot_degrees = 360 * get(magneto_cranks_to_full_charge)

fuel_ON = 4     -- setting for the fuel valve open
fuel_OFF = 0    -- setting for the fuel valve closed
isOn = 1        -- um... I mean, what's to explain?
isOff = 0       -- see isOn
isOpen = 1      -- you're getting the idea by now.
not_moving = 0
moving_up = 1
moving_down = -1
fuel_valve_moving = not_moving --0:not moving, 1: moving up, -1: moving_down
mag_switch_moving = not_moving --same

oil_consumption_per_hour = 6 -- liters
oil_consumption_per_second = oil_consumption_per_hour / 3600
oil_is_pulsing = isOff
oil_pulse_moving = not_moving

sparks = sasl.al.loadSample ("sounds/continuousspark.wav")
sasl.al.setSamplePosition ( sparks , -0.13689, 0.07209, 1)
sasl.al.setSampleGain ( sparks , 50)

crank = {}
for i = 1, 13, 1 do
    crank[i] = sasl.al.loadSample ("sounds/crank"..i..".wav")
    sasl.al.setSamplePosition ( crank[i] , -0.13689, 0.07209, 1)
    sasl.al.setSampleGain ( crank[i] , 25)    
end

pull_prop = sasl.al.loadSample ("sounds/fokker_dr1 STARTER_RECIP_inn.wav")
sasl.al.setSampleGain ( pull_prop , 25)

engine_stop = sasl.al.loadSample ("sounds/engine_stop.wav")
sasl.al.setSampleGain ( engine_stop , 25)

-- look up our datarefs
xp_mix = globalPropertyfae("sim/cockpit2/engine/actuators/mixture_ratio", 1)
yoke_roll = globalPropertyf("sim/cockpit2/controls/yoke_roll_ratio")
yoke_hdg = globalPropertyf("sim/cockpit2/controls/yoke_heading_ratio")
yoke_pitch = globalPropertyf("sim/cockpit2/controls/yoke_pitch_ratio")
ground_speed = globalPropertyf("sim/flightmodel2/position/groundspeed")
parking_brake = globalPropertyf("sim/cockpit2/controls/parking_brake_ratio")
xp_vulkan = globalPropertyf ("sim/private/stats/gfx/vulkan/descriptors/max_sets")
running = globalPropertyi("sim/operation/prefs/startup_running")         -- 0: cold and dark, 1: engines_running
fuel_valve = globalPropertyi("sim/cockpit2/fuel/fuel_tank_selector")       -- 0: none, 1: left, 2: center, 3: right, 4: all
fuel_supply = globalPropertyiae("sim/cockpit2/fuel/fuel_tank_pump_on", 1)    -- 0: off, 1: on
xp_battery = globalPropertyiae("sim/cockpit2/electrical/battery_on", 1)  -- 0: off, 1: on
open_canopy = globalPropertyi("sim/cockpit2/switches/canopy_open")         -- 0: closed, 1: open
open_can_rat = globalPropertyf("sim/flightmodel2/misc/canopy_open_ratio")  -- 0: closed, 1: open
left_brakes = globalPropertyf("sim/cockpit2/controls/left_brake_ratio")
right_brakes = globalPropertyf("sim/cockpit2/controls/right_brake_ratio")
xp_engine_running = globalPropertyiae("sim/flightmodel/engine/ENGN_running", 1)
xp_engine_rpm = globalPropertyfae("sim/cockpit2/engine/indicators/engine_speed_rpm", 1)
xp_radio = {}
xp_radio[1] = globalPropertyi("sim/cockpit2/radios/actuators/com1_power")
xp_radio[2] = globalPropertyi("sim/cockpit2/radios/actuators/com2_power")
xp_radio[3] = globalPropertyi("sim/cockpit2/radios/actuators/nav1_power")
xp_radio[4] = globalPropertyi("sim/cockpit2/radios/actuators/nav2_power")

local dr1_mix_v  -- value of Dr1/cockpit/mixture_ratio
local dr1_ail_left_v = 0 -- value of Dr1/cockpit/vr_ail_left
local dr1_ail_right_v = 0 -- value of Dr1/cockpit/vr_ail_right
local dr1_rudder_v = 0 -- value of Dr1/cockpit/vr_ail_right
local dr1_elev_v = 0 -- value of Dr1/cockpit/vr_elevator

function get_fokker_mix_handler ()
    return dr1_mix_v
end

function set_fokker_mix_handler (f)
    --[[Since the VR display for our 'backward' mixture handle show the red/green axis
    reversed from proper operation (green should be full on, red should be off) we need
    a custom dataref that shows the correct axis in VR but reversed to the actual xp mix]]
    dr1_mix_v = f
    set(xp_mix, 1-dr1_mix_v)
end

function get_yoke_roll_left_handler()
    return dr1_ail_left_v
end

function set_yoke_roll_left_handler (f)
    -- Deals with manipulation of the left aileron in VR
    -- Value of the yoke_roll dataref must be inverted from our manip for proper function
    dr1_ail_left_v = f
    set(yoke_roll, -dr1_ail_left_v)
end

function get_yoke_roll_right_handler()
    return dr1_ail_right_v
end

function set_yoke_roll_right_handler (f)
    -- Deals with manipulation of the left aileron in VR
    dr1_ail_right_v = f
    set(yoke_roll, -dr1_ail_right_v)
end

function get_yoke_heading_handler()
    return dr1_rudder_v
end

function set_yoke_heading_handler (f)
    dr1_rudder_v = f
    set(yoke_hdg, -dr1_rudder_v)
end

function get_yoke_pitch_handler ()
    return dr1_elev_v
end

function set_yoke_pitch_handler (f)
    dr1_elev_v = f
    set(yoke_pitch, -dr1_elev_v)
end


function chock_handler(phase)
    if phase == 0 then
        if get(ground_speed) < 0.07 then
            set(chock_toggle, 1-get(chock_toggle))   -- toggle the chocks.
            set(parking_brake, get(chock_toggle))
        end
    end
    return 1
end

function xp_park_handler(phase)
    chock_handler (phase)
    return 0
end

function schnirpsknopf_handler(phase)
    -- Handles changes to the Schnirpsknopf (blip switch)
    if phase == SASL_COMMAND_END then      -- they let go of the schnirpsknopf
         set(fuel_supply, isOn)    -- we turn on the fuel supply
    else                    -- they either just pressed or are holding the blip switch
        set(fuel_supply, isOff)     -- we turn off the fuel supply
    end 
end

function move_mag_switch()
    local move_step = 1 / get (mag_switch_turn_time) * timer_lib.SIM_PERIOD
    set(dr1_mag_switch, get(dr1_mag_switch) + (mag_switch_moving * move_step))

    if get(dr1_mag_switch) >= 1 then
        set (dr1_mag_switch, 1)
        if get(dr1_magneto_charge) >= get(magneto_full_charge) then
            set (xp_battery, isOn)
        end
        mag_switch_moving = not_moving
    end
    if get(dr1_mag_switch) <= 0 then
        set (dr1_mag_switch, 0)
        set (xp_battery, isOff)
        mag_switch_moving = not_moving
    end

end

function dr1_mag_switch_on_handler (phase)
    if phase == SASL_COMMAND_BEGIN then
        mag_switch_moving = moving_up
    end
end

function dr1_mag_switch_off_handler (phase)
    if phase == SASL_COMMAND_BEGIN then
        mag_switch_moving = moving_down
    end
end

function dr1_mag_switch_toggle_handler (phase)
    if phase == SASL_COMMAND_BEGIN then
        if not (mag_switch_moving == not_moving) then
            mag_switch_moving = mag_switch_moving * -1 --if it's already moving when we hit this command, swap the motion.
        elseif get(dr1_mag_switch) == isOn then
            mag_switch_moving = moving_down
        else
            mag_switch_moving = moving_up
        end
    end
end

local curr_mag_lever_angle
local frames = 5
function dr1_crank_mag_lever_handler (phase)
    if phase == SASL_COMMAND_BEGIN then
        curr_mag_lever_angle = get (dr1_mag_lever_angle)
    end
    if phase < SASL_COMMAND_END then
--        if not isSamplePlaying(crank) then sasl.al.playSample(crank) end
        local mag_step = 1 / get(secs_to_full_magneto_charge) * timer_lib.SIM_PERIOD
        set (dr1_magneto_charge, get(dr1_magneto_charge) + mag_step)
        if get(dr1_magneto_charge) >= get (magneto_full_charge) then
            if not isSamplePlaying(sparks) then sasl.al.playSample(sparks) end
            if get(dr1_mag_switch) == isOn then
                set (xp_battery, isOn)
            end
        end
        if math.abs(curr_mag_lever_angle - get(dr1_mag_lever_angle)) < mag_step*tot_degrees and frames >= 4 then
                curr_crank = math.random (13)
                sasl.al.playSample(crank[curr_crank])
                frames = 0
        end
        frames = frames + 1
        set (dr1_mag_lever_angle, (tot_degrees * get(dr1_magneto_charge) / get (magneto_full_charge)) % 360)
    end
    if phase == SASL_COMMAND_END then
        sasl.al.stopSample(crank[curr_crank])
    end
end

function engine_startup_status (phase)
    --[[ 
    X-Plane does not allow the starter command to function if the battery is off.
    However, I want the pilot to be able to attempt to spin the prop using the default
    starter animations even if the magneto switch is off and/or the magneto has not
    been charged, because afterall, that prop could be pulled at anytime.
    So every time the starter is pulled, this will adjust either the battery or fuel to
    allow the starter to move the prop at all times, but won't let it start unless fuel is
    on, mag switch is on, and magneto is charged.
    ]]

    if phase == SASL_COMMAND_BEGIN then
        if get(dr1_fuel_valve) == isOff then
            -- the fuel supply is off so we can safely turn the battery on temporarily
            set (xp_battery, isOn)
        elseif get(dr1_fuel_valve) == isOn and (get(dr1_mag_switch) == isOff or get(dr1_magneto_charge) < get(magneto_full_charge)) then
            set (fuel_valve, fuel_OFF)
            set (xp_battery, isOn)
        end
    end
    if phase == SASL_COMMAND_END then
        -- we'll return everything where it belongs.
        if get(dr1_mag_switch) == isOff or get(dr1_magneto_charge) < get(magneto_full_charge) then
            set (xp_battery, isOff)
        end
        if get(dr1_fuel_valve) == isOn then
            set (fuel_valve, fuel_ON)
        end
    end
end

local starter_time = 0.0
function xp_engine_starter_handler (phase)
    if phase == SASL_COMMAND_BEGIN then
        engine_startup_status(phase)
        if get(xp_engine_running) == isOff then
            sasl.al.playSample ( pull_prop , true )
        end
        starter_time = timer_lib.RUN_TIME_SEC
        return 1
    elseif phase == SASL_COMMAND_CONTINUE then
        if timer_lib.RUN_TIME_SEC - starter_time > get(starter_spin_time) then
            sasl.al.stopSample ( pull_prop )
            return 0
        else
            return 1
        end
    else
        engine_startup_status(phase)
        sasl.al.stopSample ( pull_prop )
        return 0
    end
end

function move_fuel_valve()
    local move_step = 1 / get (fuel_valve_turn_time) * timer_lib.SIM_PERIOD
    set(dr1_fuel_valve, get(dr1_fuel_valve) + (fuel_valve_moving * move_step))
    if get(dr1_fuel_valve) >= isOn then
        set(dr1_fuel_valve, isOn)
        set(fuel_valve, fuel_ON)
        fuel_valve_moving = not_moving
    elseif get(dr1_fuel_valve) <= isOff then
        set(dr1_fuel_valve, isOff)
        set(fuel_valve, fuel_OFF)
        fuel_valve_moving = not_moving
    end
end

function dr1_fuel_selector_on_handler(phase)
    if phase == SASL_COMMAND_BEGIN then
        fuel_valve_moving = moving_up
    end
end

function dr1_fuel_selector_off_handler(phase)
    if phase == SASL_COMMAND_BEGIN then
        fuel_valve_moving = moving_down
    end
end

function xp_fuel_selector_all_handler(phase)
    if phase == SASL_COMMAND_BEGIN then
        fuel_valve_moving = moving_up
    end
    return 0
end

function xp_fuel_selector_none_handler(phase)
    if phase == SASL_COMMAND_BEGIN then
        fuel_valve_moving = moving_down
    end
    return 0
end

function move_oil()
    local move_step = 1 / get (oil_pulse_decay) * timer_lib.SIM_PERIOD
    set(oil_level_ratio, get(oil_level_ratio) + (oil_pulse_moving * move_step))
    if get(oil_level_ratio) >= (get(oil_level)/10) then
        oil_pulse_moving = moving_down
    end
    if get(oil_level_ratio) <= 0 then
        set(oil_level_ratio, 0)
        oil_pulse_moving = not_moving
    end
end

function pulse_oil()
    oil_pulse_moving = moving_up
end

function update_oil ()
    local oil_step = oil_consumption_per_second * timer_lib.SIM_PERIOD
    if get(xp_engine_running) == isOn then
        if oil_is_pulsing == isOff then
            timer_lib.run_at_interval(pulse_oil, get(oil_pulse_interval))
            oil_is_pulsing = isOn
        end
        set(oil_level, get(oil_level) - oil_step)
    else
        oil_is_pulsing = isOff
        timer_lib.stop_timer(pulse_oil)
    end
    if get(oil_level) <= 0 then
        set(fuel_valve, fuel_OFF)
        oil_is_pulsing = isOff
        timer_lib.stop_timer(pulse_oil)        
    end
end

local was_running = false
function check_rpm()
    if get(xp_engine_rpm) > 300 then 
        was_running = true
        sasl.al.stopSample ( engine_stop )
    end
    if get (xp_engine_rpm) < 280 and was_running == true then
        if not sasl.al.isSamplePlaying ( engine_stop ) then
            sasl.al.playSample ( engine_stop )
        end
    end
    if get(xp_engine_rpm) < 30 then was_running = false end
end

dr1_mix = createFunctionalPropertyf ("Dr1/cockpit/mixture_ratio", get_fokker_mix_handler, set_fokker_mix_handler) -- fokker_mix_handler
dr1_ail_left = createFunctionalPropertyf("Dr1/cockpit/vr_ail_left", get_yoke_roll_left_handler, set_yoke_roll_left_handler) -- yoke_roll_left_handler
dr1_ail_right = createFunctionalPropertyf("Dr1/cockpit/vr_ail_right", get_yoke_roll_right_handler, set_yoke_roll_right_handler) -- yoke_roll_right_handler
dr1_rudder = createFunctionalPropertyf("Dr1/cockpit/vr_rudder", get_yoke_heading_handler, set_yoke_heading_handler) -- yoke_heading_handler
dr1_elevator = createFunctionalPropertyf("Dr1/cockpit/vr_elevator", get_yoke_pitch_handler, set_yoke_pitch_handler) -- yoke_pitch_handler
chock_toggle = createGlobalPropertyi("Dr1/cockpit/wheelchocks", 1)
dr1_starter = createGlobalPropertyi ("Dr1/cockpit/show_start_button", 0)
dr1_mag_switch = createGlobalPropertyf ("Dr1/electrical/mag_switch_pos", 0.0)
dr1_mag_lever_angle = createGlobalPropertyf ("Dr1/electrical/mag_lever_angle", 0.0)
dr1_magneto_charge = createGlobalPropertyf ("Dr1/electrical/magneto_charge", 0.0)
dr1_fuel_valve = createGlobalPropertyf ("Dr1/control/fuel_valve_ratio", 0.0)
oil_level = createGlobalPropertyf ("Dr1/engines/oil_level_liters", 10.0)
oil_level_ratio = createGlobalPropertyf ("Dr1/engines/oil_pulse_ratio", 0)

chock_cmd = sasl.createCommand("Dr1/cockpit/chock_toggle", "Toggles wheel chock boards.")  -- chock_handler
sasl.registerCommandHandler ( chock_cmd , 0, chock_handler )

xp_park_brake = sasl.findCommand ("sim/flight_controls/brakes_toggle_max") -- xp_park_handler
sasl.registerCommandHandler ( xp_park_brake , 1, xp_park_handler)
xp_park = sasl.findCommand ("sim/flight_controls/brakes_toggle_regular")
sasl.registerCommandHandler ( xp_park, 1, xp_park_handler)
xp_starter = sasl.findCommand ("sim/starters/engage_starter_1")
sasl.registerCommandHandler ( xp_starter, 1, xp_engine_starter_handler)
xp_fuel_selector_all = sasl.findCommand("sim/fuel/fuel_selector_all")
sasl.registerCommandHandler ( xp_fuel_selector_all, 1, xp_fuel_selector_all_handler)
xp_fuel_selector_none = sasl.findCommand("sim/fuel/fuel_selector_none")
sasl.registerCommandHandler ( xp_fuel_selector_none, 1, xp_fuel_selector_none_handler)
schnirpsknopf_cmd = sasl.createCommand("Dr1/command/schnirpsknopf", "Actuates the Schnirpsknopf (blip switch)." ) 
sasl.registerCommandHandler ( schnirpsknopf_cmd , 0, schnirpsknopf_handler )
dr1_mag_switch_on_cmd = sasl.createCommand("Dr1/electrical/mag_switch_on", "Turns on the Dr1 magneto switch")
sasl.registerCommandHandler( dr1_mag_switch_on_cmd, 0, dr1_mag_switch_on_handler )
dr1_mag_switch_off_cmd = sasl.createCommand("Dr1/electrical/mag_switch_off", "Turns off the Dr1 magneto switch")
sasl.registerCommandHandler( dr1_mag_switch_off_cmd, 0, dr1_mag_switch_off_handler )
dr1_mag_switch_toggle_cmd = sasl.createCommand("Dr1/electrical/mag_switch_toggle", "Toggles the Dr1 magneto switch")
sasl.registerCommandHandler( dr1_mag_switch_toggle_cmd, 0, dr1_mag_switch_toggle_handler )
dr1_mag_lever_crank_cmd = sasl.createCommand("Dr1/electrical/crank_mag_lever", "Cranks the magneto lever")
sasl.registerCommandHandler( dr1_mag_lever_crank_cmd, 0, dr1_crank_mag_lever_handler)
dr1_fuel_selector_on_cmd = sasl.createCommand("Dr1/command/fuel_valve_on", "Turns the fuel valve on")
sasl.registerCommandHandler( dr1_fuel_selector_on_cmd, 0, dr1_fuel_selector_on_handler)
dr1_fuel_selector_off_cmd = sasl.createCommand("Dr1/command/fuel_valve_off", "Turns the fuel valve off")
sasl.registerCommandHandler( dr1_fuel_selector_off_cmd, 0, dr1_fuel_selector_off_handler)

-- on reload and/or startup
set(chock_toggle, 1)
set(parking_brake, 1)

if get(xp_vulkan) > 1 then
    set(dr1_starter, 0)
else
    set(dr1_starter, 1)
end

for i = 1, 4, 1
do
    set(xp_radio[i], 0)         -- turn off com1, com2, nav1, nav2
end
set(open_canopy, isOpen)        -- let's open the canopy that isn't there.
set(open_can_rat, isOpen)       -- gotta do both to avoid a delayed opening.
if get(running) == isOff or get(xp_engine_running) == isOff then        -- if they started cold and dark,
    debug_lib.on_debug("Cold and Dark")
    set(xp_battery, isOff)
    set(dr1_magneto_charge, 0)
    set(fuel_valve, fuel_OFF)   -- we need to close the fuel valve
    set(dr1_fuel_valve, isOff)
    set(dr1_mag_switch, isOff)  -- turn the magneto off.
    set(xp_mix, isOff)          -- we'll push the mixture lean for something else to do on startup
else
    set(dr1_magneto_charge, get(magneto_full_charge))
    set(dr1_mag_switch, isOn)
    set(fuel_valve, fuel_ON)    -- otherwise we'll make sure it's on.
    set(dr1_fuel_valve, isOn)
end

function update ()
    check_rpm()
    update_oil()
    if not (oil_pulse_moving == not_moving) then
        move_oil()
    end
    if not (fuel_valve_moving == not_moving) then
        move_fuel_valve()
    end
    if not (mag_switch_moving == not_moving) then
        move_mag_switch()
    end
    set(dr1_mix, 1-get(xp_mix))
    if get(left_brakes) > 0 then set(left_brakes, 0) end
    if get(right_brakes) > 0 then set(right_brakes, 0) end
    updateAll (components)
end
