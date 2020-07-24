--[[
    fokker_init.lua
    by Jeffory J. Beckers
    12 June 2020
    Creative Commons CC BY-SA-NC

    Initializes everything needed for the Jemma Studios Fokker Dr.1 "Dreidecker" Triplane
    made famous by Manfred "The Red Baron" von Richthofen and his Flying Circus.
]]

-- Assign constants
fuel_ON = 4     -- setting for the fuel valve open
fuel_OFF = 0    -- setting for the fuel valve closed
isOn = 1        -- um... I mean, what's to explain?
isOff = 0       -- see isOn
isOpen = 1      -- you're getting the idea by now.

-- Assign the datarefs we need
xp_mix = find_dataref("sim/cockpit2/engine/actuators/mixture_ratio[0]")
running = find_dataref("sim/operation/prefs/startup_running")         -- 0: cold and dark, 1: engines_running
fuel_valve = find_dataref("sim/cockpit2/fuel/fuel_tank_selector")       -- 0: none, 1: left, 2: center, 3: right, 4: all
fuel_supply = find_dataref("sim/cockpit2/fuel/fuel_tank_pump_on[0]")    -- 0: off, 1: on
magneto_switch = find_dataref("sim/cockpit2/electrical/battery_on[0]")  -- 0: off, 1: on
open_canopy = find_dataref("sim/cockpit2/switches/canopy_open")         -- 0: closed, 1: open
open_can_rat = find_dataref("sim/flightmodel2/misc/canopy_open_ratio")  -- 0: closed, 1: open
left_brakes = find_dataref("sim/cockpit2/controls/left_brake_ratio")
right_brakes = find_dataref("sim/cockpit2/controls/right_brake_ratio")
-- Create functions used by create_commands

function schnirpsknopf_handler(phase, duration)
    -- Handles changes to the Schnirpsknopf (blip switch)
    if phase == 2 then      -- they let go of the schnirpsknopf
         fuel_supply = isOn    -- we turn on the fuel supply
    else                    -- they either just pressed or are holding the blip switch
        fuel_supply = isOff     -- we turn off the fuel supply
    end 
end

-- Create custom datarefs

-- Create custom commands

schnirpsknopf_cmd = create_command("Dr1/command/schnirpsknopf", "Actuates the Schnirpsknopf (blip switch).", schnirpsknopf_handler)

-- Housekeeping

function before_physics()
    left_brakes = 0
    right_brakes = 0
end

function flight_start()
    open_canopy = isOpen        -- let's open the canopy that isn't there.
    open_can_rat = isOpen       -- gotta do both to avoid a delayed opening.
    if running == 0 then        -- if they started cold and dark,
        fuel_valve = fuel_OFF   -- we need to close the fuel valve
        magneto_switch = isOff  -- turn the magneto on.
        xp_mix = isOff          -- we'll push the mixture lean for something else to do on startup
    else
        fuel_valve = fuel_ON    -- otherwise we'll make sure it's on.
    end
end