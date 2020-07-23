--[[
    fokker_control.lua
    by Jeffory J. Beckers
    20 June 2020
    Creative Commons CC BY-SA-NC

    Adds additional control for Jemma Studios Fokker Dr.1 "Dreidecker" Triplane
    made famous by Manfred "The Red Baron" von Richthofen and his Flying Circus.
]]


xp_mix = find_dataref("sim/cockpit2/engine/actuators/mixture_ratio[0]") 

function fokker_mix ()
    --[[Since the VR display for our 'backward' mixture handle show the red/green axis
    reversed from proper operation (green should be full on, red should be off) we need
    a custom dataref that shows the correct axis in VR but reversed to the actual xp mix]]
    xp_mix = 1-dr1_mix
end

dr1_mix = create_dataref("Dr1/cockpit/mixture_ratio", "number", fokker_mix) 

function after_physics()
    -- we need to invert the xp_mix for dr1_mix or the lever won't animate if someone
    -- uses a quadrant.
    dr1_mix = 1-xp_mix
end
