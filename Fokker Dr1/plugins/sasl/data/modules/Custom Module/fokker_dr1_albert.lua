--[[
    fokker_dr1_albert.lua

    This script animates Albert's mustache in the Jemma Studios Fokker Dr.1
]]

--[[
    Alfred's moustache will begin to uncurl when airspeed gets above the airspeed_min
    below, and will fully uncurl 
]]
defineProperty("airspeed_min", 10) -- can be overridden in main.lua as required.
defineProperty("airspeed_max", 70) -- can be overridden in main.lua as required.
defineProperty("stache_wiggle", 0.2) -- can be overridden in main.lua as required.
defineProperty("stache_wiggle_floor", 0.02) -- can be overridden in main.lua as required.
local airspeed_step = (get(airspeed_max) - get(airspeed_min)) / 12 -- there are twelve sections of moustache.

xp_prop_speed = globalPropertyiae("sim/cockpit2/engine/indicators/prop_speed_rpm", 1)     -- 0:not running; 1:it's running

moustache_rat = createGlobalPropertyfa ("Dr1/alfred/moustache_ratio", {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0})

function random(min, max)
    min = min * 100
    max = max * 100
    return (min + math.random()  * (max - min)) / 100;
end

air_speed = globalPropertyf("sim/flightmodel2/position/true_airspeed")


function update_moustache()
    local sw = get(stache_wiggle)
    local swf = get(stache_wiggle_floor)
    if get(air_speed) < get(airspeed_min) then
        for i = 1, 12, 1
        do
            if get(xp_prop_speed) >= 400 or get(air_speed) > get(airspeed_min) then
                if get(air_speed) <= get (airspeed_min) then
                    prop_range = get(xp_prop_speed) - 600
                    swr = swf + (prop_range * (sw-swf)) / 600
                    r = random (-swr, swr)
                else
                    r = random (-sw, sw)
                end
            else 
                r = 0
            end
            set(moustache_rat, r, i)
        end
    end
    if get(air_speed) >= get(airspeed_min) then
        local range = get(air_speed) - get(airspeed_min)
        local result = range / get(airspeed_step)
        local quotient = math.floor(range / get(airspeed_step))
        local remainder = result - quotient    -- the remainder
        for i = 1, quotient, 1
        do
            r = random (1-sw, 1+sw)
            set(moustache_rat, r, i)
        end
        if quotient < 12 then
            r = remainder + random (1-sw, 1+sw)
            set (moustache_rat, r, quotient + 1)
        end
        if quotient > 1 and quotient < 11 then
            for i = quotient + 2, 12, 1
            do
                r = random (-sw, sw)
                set (moustache_rat, r, i)
            end
        end
    end
end

function update ()
    update_moustache()
    updateAll (components)
end