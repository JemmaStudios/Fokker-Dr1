--[[ timer_library.lua
    Jeffory J. Beckers
    Jemma Studios
    MIT License
    25 October 2020
    ver 1.0.0

    Looking-For-A-Handout-Ware https://paypal.me/JemmaStudios

    Sets up xLua style function timer for SASL 3.  Makes life a little simpler when converting a project from xLua to SASL

    LIBARY SETUP.
    Drop this script in the "plugins\sasl\data\modules\Custom Module" folder
    add it as a component in "plugins\sasl\data\modules\main.lua"
    add the line "timer_lib = {}" anywhere in your main.lua script

    USAGE:
    After completing the setup above, the following functions can be called from any other subcomponent in your project.

    (If the following function documentation looks familiar it's because I plagarized from JGregory's xLua post)
    You can create a timer out of any function. Timer functions take no arguments. 

    timer_lib.run_at_interval(func, interval)
    Runs func every interval seconds, starting interval seconds from the call.

    timer_lib.run_after_time(func, delay)
    Runs func once after delay seconds, then timer stops.

    timer_lib.run_timer(func, delay, interval)
    Runs func after delay seconds, then every interval seconds after that.

    timer_lib.stop_timer(func)
    This ensures that func does not run again until you re­schedule it; any scheduled runs from previous calls are canceled.

    timer_lib.is_timer_scheduled(func)
    This returns true if the timer function will run at any time in the future. It returns false if the timer isn’t 
    scheduled or if func has never been used as a timer.

    BONUS feature!
    timer_lib.SIM_PERIOD
    contains the duration of the current frame in seconds (so it is always a fraction). Use this to normalize rates, 
    e.g. to add 3 units of fuel per second in a per­frame callback you’d do fuel = fuel + 3 * SIM_PERIOD
    ]]

local timers = {} -- timers table.  each element is {p_function_pointer, f_current_time_step, f_interval, f_delay_to_start, i_only_do_once}

local xp_frame_rate_period = globalPropertyf("sim/operation/misc/frame_rate_period") -- how many seconds per frame?
local xp_total_running_time = globalPropertyf ("sim/time/total_running_time_sec") -- how many seconds have we been loaded up.
local xp_total_flight_time = globalPropertyf ("sim/time/total_flight_time_sec") -- how many seconds have we been loaded up.
timer_lib.SIM_PERIOD = get(xp_frame_rate_period)
timer_lib.RUN_TIME_SEC = get(xp_total_running_time)
timer_lib.FLIGHT_TIME_SEC = get(xp_total_flight_time)

function timer_lib.run_at_interval(s_function, f_interval)
    -- Sets up a timer to run function s_function at f_interval seconds (can be fractions of a second)
    local tTimer = {s_function, f_interval, f_interval, 0, 0}
    table.insert(timers, tTimer)
end

function timer_lib.run_timer(s_function, f_delay, f_interval)
    -- Sets up a timer to run function s_function at f_interval seconds after an f_interval delay in seconds (all seconds can be fractions)
    local tTimer = {s_function, f_interval, f_interval, f_delay, 0}
    table.insert(timers, tTimer)
end

function timer_lib.run_after_time(s_function, f_delay)
    -- Sets up a timer to run function s_function, just once, after f_delay seconds (seconds can be in fractions.)
    local tTimer = {s_function, 0, 0, f_delay, 1}
    table.insert(timers, tTimer)
end

function timer_lib.stop_timer(s_function)
    -- removes s_function from the timer table if it existed
    for i, v in ipairs(timers) do
        if v[1] == s_function then
            table.remove(timers, i)
        end
    end
end

function timer_lib.is_timer_scheduled(s_function)
    -- returns true if s_function is in the timers table
    for i, v in ipairs(timers) do
        if v[1] == s_function then
            return true
        end
    end
    return false
end

function run_timers()
    for i, v in ipairs(timers) do
        if v[4] <= 0 then
            if v[2] >= v[3] then
                v[1]()
                timers[i][2] = 0
            end
            timers[i][2] = v[2] + get(xp_frame_rate_period)
            if v[5] == 1 then
                table.remove(timers, i)
            end

        end
        v[4] = v[4] - get(xp_frame_rate_period)
    end
end

function update()
    timer_lib.SIM_PERIOD = get(xp_frame_rate_period)
    timer_lib.RUN_TIME_SEC = get(xp_total_running_time)
    timer_lib.FLIGHT_TIME_SEC = get(xp_total_flight_time)
    run_timers()
    updateAll(components)
end
