--[[
	main.lua
	by Jemma Studios
	for the Fokker Dr1
]]

--------------------------------------------------------------------------------
-- Fokker Dr1 settings.

--[[The assist lever of the right Spandau LMG machine gun is in an ackward position
and cannot be seen from the pilot's standard view.  So this option let's the pilot
arm both assist levers by actuating the left Spandau assist lever.  For "study level"
nerds, set this to 2 and you'll need to set up a custom camera, or move the camera
to see the right side of the receiver of the right gun to actuate the assist lever]]
local dr1_settings = {}
dr1_settings["Number_of_assist_levers_to_use_in_the_cockpit"] = 1
dr1_settings["Number_of_rounds_to_continously_fire_before_barrels_start_to_heat"] = 10
dr1_settings["Number_of_rounds_to_continously_fire_before_barrels_deform"] = 60
dr1_settings["How_many_seconds_does_it_take_to_fully_cool_a_barrel"] = 10

dr1_settings["Minimum_airspeed_in_which_Alberts_moustache_begins_to_uncurl"] = 10
dr1_settings["Airspeed_at_which_Alberts_moustache_is_fully_uncurled"] = 70
dr1_settings["Constant_used_to_determine_how_Alberts_mustache_wiggles_with_engines_running"] = 0.2
dr1_settings["Constant_used_to_determine_how_Alberts_mustache_wiggles_with_engines_at_idle"] = 0.02

--------------------------------------------------------------------------------

sasl.setLogLevel ( LOG_DEBUG )
--sasl.setLogLevel ( LOG_INFO )
sasl.options.setAircraftPanelRendering ( false )
sasl.options.set3DRendering ( false )
sasl.options.setInteractivity ( false )

timer_lib = {}
debug_lib = {}
function debug_lib.on_debug(tString)
	if getLogLevel() == LOG_DEBUG then print ("DEBUG MODE! "..tString) end
end
dr1_config = {}

dr1_config_path = sasl.getAircraftPath ()
dr1_config_path = dr1_config_path.. "/fokker_dr1_config.ini"

dr1_config = sasl.readConfig ( dr1_config_path , "ini" )

for i, v in pairs (dr1_config) do
	dr1_settings[i] = v
end
if dr1_settings["Number_of_assist_levers_to_use_in_the_cockpit"] ~= 2 then dr1_settings["Number_of_assist_levers_to_use_in_the_cockpit"] = 1 end
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

components = {
	timer_library {},
	fokker_dr1_guns {	num_assist_levers = dr1_settings["Number_of_assist_levers_to_use_in_the_cockpit"],
						barrel_rounds_min = dr1_settings["Number_of_rounds_to_continously_fire_before_barrels_start_to_heat"],
						barrel_rounds_max = dr1_settings["Number_of_rounds_to_continously_fire_before_barrels_deform"],
						barrel_cool_time = dr1_settings["How_many_seconds_does_it_take_to_fully_cool_a_barrel"]
						},
	fokker_dr1_albert {	airspeed_min = dr1_settings["Minimum_airspeed_in_which_Alberts_moustache_begins_to_uncurl"],
						airspeed_max = dr1_settings["Airspeed_at_which_Alberts_moustache_is_fully_uncurled"],
						stache_wiggle = dr1_settings["Constant_used_to_determine_how_Alberts_mustache_wiggles_with_engines_running"],
						stache_wiggle_floor = dr1_settings["Constant_used_to_determine_how_Alberts_mustache_wiggles_with_engines_at_idle"]
						}
}

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

