--[[
    fokker_control.lua
    by Jeffory J. Beckers
    20 June 2020
    Creative Commons CC BY-SA-NC

    Adds additional control for Jemma Studios Fokker Dr.1 "Dreidecker" Triplane
    made famous by Manfred "The Red Baron" von Richthofen and his Flying Circus.
]]
-- constants

-- look up our datarefs
xp_mix = find_dataref("sim/cockpit2/engine/actuators/mixture_ratio[0]")
yoke_roll = find_dataref("sim/cockpit2/controls/yoke_roll_ratio")
yoke_hdg = find_dataref("sim/cockpit2/controls/yoke_heading_ratio")
ground_speed = find_dataref("sim/flightmodel2/position/groundspeed")
parking_brake = find_dataref("sim/cockpit2/controls/parking_brake_ratio")
xp_vulkan = find_dataref ("sim/private/stats/gfx/vulkan/descriptors/max_sets")

function fokker_mix_handler ()
    --[[Since the VR display for our 'backward' mixture handle show the red/green axis
    reversed from proper operation (green should be full on, red should be off) we need
    a custom dataref that shows the correct axis in VR but reversed to the actual xp mix]]
    xp_mix = 1-dr1_mix
end

function yoke_roll_left_handler ()
    -- Deals with manipulation of the left aileron in VR
    -- Value of the yoke_roll dataref must be inverted from our manip for proper function
    yoke_roll = -dr1_ail_left
end

function yoke_roll_right_handler ()
    -- Deals with manipulation of the left aileron in VR
    
    yoke_roll = -dr1_ail_right
end

function yoke_heading_handler ()
    yoke_hdg = -dr1_rudder
end

function chock_handler(phase, duration)
    if phase == 0 then
        if ground_speed < 0.07 then
            chock_toggle = 1-chock_toggle   -- toggle the chocks.
            parking_brake = chock_toggle
        end
    end
end

function xp_park_handler(phase, duration)
    chock_handler (phase, duration)
end

dr1_mix = create_dataref("Dr1/cockpit/mixture_ratio", "number", fokker_mix_handler) 
dr1_ail_left = create_dataref("Dr1/cockpit/vr_ail_left", "number", yoke_roll_left_handler)
dr1_ail_right = create_dataref("Dr1/cockpit/vr_ail_right", "number", yoke_roll_right_handler)
dr1_rudder = create_dataref("Dr1/cockpit/vr_rudder", "number", yoke_heading_handler)
chock_toggle = create_dataref("Dr1/cockpit/wheelchocks", "number")
dr1_starter = create_dataref("Dr1/cockpit/show_start_button", "number")

chock_cmd = create_command("Dr1/cockpit/chock_toggle", "Toggles wheel chock boards.", chock_handler)
xp_park_brake = replace_command("sim/flight_controls/brakes_toggle_max", xp_park_handler)
xp_park = replace_command("sim/flight_controls/brakes_toggle_regular", xp_park_handler)

function flight_start()
    chock_toggle = 1
    parking_brake = 1
    if xp_vulkan > 1 then
        dr1_starter = 0
    else
        dr1_starter = 1
    end
end

function after_physics()
    -- we need to invert the xp_mix for dr1_mix or the lever won't animate if someone
    -- uses a quadrant.
    dr1_mix = 1-xp_mix
end