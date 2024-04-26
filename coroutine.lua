-- a new type of sandbox just dropped!

local active_sandboxes = {}
local api = {}
--[[
    Problems we have to solve:
        Storing the coroutine somewhere
            - We CANNOT serialize it without some real shenanigans (would require the mod to be trusted)
        *Some* level of persistance (persistance through yields)
        Proper async support (optional)

    As for storing the coroutines:
       - We can simply store it outside of the node and not worry about persistance thru server reboots
           - We need to also somehow garbage collect un-used sandboxes too


    ## This is duable ##

    *OH YEAH, ANOTHER PROBLEM*
    ***M E M O R Y***
    How do we make absolute sure that the sandbox cannot overfill the memory

    Well crap....

    i has idea
    you know we have theese fancy debuggery hookeys
    yeah what if we could just
    ```lua

        debug.sethook(thread, function()
            ...
            if collectgarbage("count")>critical_treshold then
                error("Sandbox memory reached critical treshold, sorry... aborting")
            end
        end, "", 1)

        ...
        env = nil
        collectgarbage("collect")
    ```
    we can also give the script *some* control over the garbage collector, but making sure to revert everything it did after execution if possible

]]

--[[
    So, we need something that is able to look up sandboxes
    We could use an array, but when we do something like active_sandboxes[50] = nil... well what about the sandbox 51
    and uhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh right what about it
    ok
    i will just use an array i guess?

    yeah that will make garbage collection slightly faster... actually no it won't
    what about generating new IDs? just math.random() until we get one that isn't occupied
    because doing a full table.remove seems stupid

    whatever i just wanted to use a random string
]]

--[[
    Oh yeah about that "garbage collection"
    How am i gonna do it...

    My initial idea was that after a certain time,
    a monster would iterate through alll the sandboxes,
    then select the ones that have been untouched for a long time and just delete them

    Honestly that sounds fine
]]


local critical_memory_treshold = 1024 * 1024 * 1024 * 5 -- 5 gigabytes hardcoded

local function rand_text(n)
    local out = ""
    for _ = 1, n do
        out = out .. string.char(math.random(0x41, 0x5A)) -- [A-Z]
    end
    return out
end

function api.get_default_hook(max_time)
    -- Why seperate from the libox util function?
    -- because of the critical memory treshold
    -- TODO: eventually put this in the default libox hook

    local time = minetest.get_us_time

    local current_time = time()
    return function()
        if time() - current_time > max_time then
            error("Code timed out! Reason: Time limit exceeded, the limit:" .. tostring(max_time / 1000) .. "ms", 2)
            debug.sethook()
        elseif collectgarbage("count") >= critical_memory_treshold then
            error("Lua memory usage reached critical treshold, sorry... aborting", 2)
            debug.sethook()
        end
    end
end

function api.create_sandbox(def)
    local ID = def.ID or rand_text(10)
    active_sandboxes[ID] = {
        is_garbage_collected = def.is_garbage_collected,
        env = def.env,
        hook_function = def.hook_function or api.get_default_hook(def.time_limit),

    }

    return ID
end
