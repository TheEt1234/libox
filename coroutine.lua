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
        ...
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
    we can also give the script *some* control over the garbage collector,
    but making sure to revert everything it did after execution **if possible**

================================================
    So, we need something that is able to look up sandboxes
    We could use an array, but when we do something like active_sandboxes[50] = nil... well what about the sandbox 51
    and uhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh right what about it
    ok
    i will just use an array i guess?

    yeah that will make garbage collection slightly faster... actually no it won't
    what about generating new IDs? just math.random() until we get one that isn't occupied
    because doing a full table.remove seems stupid

    whatever i just wanted to use a random string
==========================================
    Oh yeah about that "garbage collection"
    How am i gonna do it...

    My initial idea was that after a certain time,
    a monster would iterate through alll the sandboxes,
    then select the ones that have been untouched for a long time and just delete them

    Honestly that sounds fine
]]
--[[
    OH CRAP ANOTHER VERY VERY TRICKY PROBLEM
    LOCAL VARIABLES
    yeah
    them....

    They bypass every single way we can weigh the environment
    Unless...

    We can do:
        Some crazy lua shittery (probably requires some debug functions)
        Some crazy native shittery (requires mod to be trusted, and optionally requires to compile on windows too)
            - By native i mean some language that can interface with the Lua C api (i think its not just C? idk)

    I'd much rather prefer to do lua shittery rather than learn C or rust or whatever
    Oh yeah also crazy native shittery might allow for some fun features like automatic yielding
    Honestly im kinda willing to learn C and make this mod optionally rely on the trusted environment
        - That was a lie i am not learning C

    But well, options for lua shittery:
        debug.getlocal (actually looks like the best one?)
    Okay we are using that

]]

local gigabyte = 1024 * 1024 * 1024

api.settings = {
    memory_treshold = 5,
    gc = {
        time_treshold = 10 * 60, -- if a sandbox has been untouched then collect it
        number_of_sandboxes = 60,
        auto = false,
        interval = 60
    }
}

local settings = minetest.settings

local function setting(v, thing)
    local t = type(v)
    local number = function(n) return n end -- noop
    if t == "number" then
        number = tonumber
    end

    if t ~= "boolean" then
        return number(settings:get(thing))
    else
        return settings:get_bool(thing)
    end
end
local function do_the_settings_thing(name, table)
    for k, v in pairs(table) do
        if type(v) == "table" then
            do_the_settings_thing(name .. "." .. k, v)
        else
            table[k] = setting(v, name .. "." .. k) or v
        end
    end
end

do_the_settings_thing("libox", api.settings)

local BYTE_A, BYTE_Z = string.byte("A"), string.byte("Z")
local function rand_text(n)
    local out = ""
    for _ = 1, n do
        out = out .. string.char(math.random(BYTE_A, BYTE_Z)) -- [A-Z]
    end
    return out
end


local real_mem_treshold = gigabyte * api.settings.memory_treshold
function api.get_default_hook(max_time)
    -- Why seperate from the libox util function?
    -- because of the critical memory treshold
    -- TODO: eventually put this in the default libox hook
    -- oh yeah also this is function hell i know

    return function()
        local time = minetest.get_us_time

        local current_time = time()
        return function()
            if time() - current_time > max_time then
                debug.sethook()
                error("Code timed out! Reason: Time limit exceeded, the limit:" .. tostring(max_time / 1000) .. "ms", 2)
                -- If theese 2 lines of code were swapped, total chaos would happen, i have no idea why it makes so much of a difference and why the hook is literally unstoppable
            elseif collectgarbage("count") >= real_mem_treshold then
                debug.sethook()
                collectgarbage("collect")
                error("Lua memory usage reached critical treshold, sorry... aborting", 2)
            end
        end
    end
end

function api.create_sandbox(def)
    local ID = def.ID or rand_text(10)
    active_sandboxes[ID] = {
        code = def.code,
        is_garbage_collected = def.is_garbage_collected or true,
        env = def.env or {},
        in_hook = def.in_hook or api.get_default_hook(def.time_limit or 3000),
        --error_handler = def.error_handler or libox.traceback,
        last_ran = os.clock(),                         -- for gc
        hook_time = def.hook_time or 10,
        size_limit = def.size_limit or 1024 * 1024 * 5 -- 5 megabytes... yeah huge i know
    }
    return ID
end

local function create_thread(sandbox)
    if sandbox.code:byte(1) == 27 then
        return false, "Bytecode was not allowed."
    end

    local f, msg = loadstring(sandbox.code)
    if not f then
        return false, msg
    end
    setfenv(f, sandbox.env)

    if rawget(_G, "jit") then
        jit.off(f, true) -- turn jit off for that function and yes this is needed or the user can repeat until false, sorry
    end

    sandbox.thread = coroutine.create(f)
    return true
end


function api.delete_sandbox(id)
    active_sandboxes[id] = nil
end

--[[
local function locals(thread)
    local vars = {
        upvals = {},
        locals = {}
    }
    local index = 1
    local level = 1

    local does_that_level_actually_exist = debug.getinfo(thread, level, "f")

    if not does_that_level_actually_exist then
        return {}
    end

    local f = does_that_level_actually_exist.func -- dont call this (duh)

    while true do
        local k, v = debug.getlocal(thread, level, index)
        if k ~= nil then
            vars.locals[k] = v
        else
            break
        end
        index = index + 1
    end

    local index = 0
    while true do
        local k, v = debug.getupvalue(f, index)
        if k ~= nil then
            vars.upvals[k] = v
        else
            break
        end
        index = index + 1
    end

    return vars
end
--]]


-- env_or_nil is not supposed to be provided when type(thread) == "function"
local function locals(thread, f, env_or_nil)
    local thing = {
        _G = env_or_nil,
        _L = {},     -- Locals
        _U = {}      -- Upvalues
    }
    if f == nil then -- thread and env_or_nil are real
        local level_actually_exists = debug.getinfo(thread, 1, "u")
        if level_actually_exists then
            local index = 1
            while true do
                local k, v = debug.getlocal(thread, 1, index)
                if k ~= nil then
                    thing._L[k] = v
                else
                    break
                end
                index = index + 1
            end
            if level_actually_exists.nups > 0 then
                local index = 1
                local f = debug.getinfo(thread, 1, "f").func
                while true do
                    local k, v = debug.getupvalue(f, index)
                    if k ~= nil then
                        thing._U[k] = v
                    else
                        break
                    end
                    index = index + 1
                end
            end
        end
    elseif f ~= nil then -- our main focus is f now
        --[[
            Too lazy to not repeat myself
            So in this scenario "thread" is the function, "thing" is nothing...
            We wont bother with the function environment, too silly of an idea, afterall it can only be stored from outside, or stored publically/privately on inside somewhere
        ]]
        -- for less confusion
        local func_info = debug.getinfo(thread, f, "Su")
        if not func_info or func_info.what == "C" then return 25 end -- whatever

        local f_size = string.dump(f)
        thing.env_or_nil = f_size
        local index = 1
        while true do
            local k, v = debug.getlocal(f, index)
            if k ~= nil then
                thing._L[k] = v
            else
                break
            end
            index = index + 1
        end
        if func_info.nups > 0 then
            local index = 1
            while true do
                local k, v = debug.getupvalue(f, index)
                if k ~= nil then
                    thing._U[k] = v
                else
                    break
                end
                index = index + 1
            end
        end
    end
    return thing
end



function api.get_size(thread, thing, is_function) -- Get the size of a thread using it's environment
    if debug.getlocal and debug.getupvalue and type(thread) == "thread" and not is_function then
        thing = locals(thread, nil, thing)
    elseif debug.getlocal and debug.getupvalue and type(thread) == "thread" and is_function then
        thing = locals(thread, thing, nil)
    end
    local function internal(thing, seen)
        local t = type(thing)
        if t == "string" then
            return #thing + 25
        elseif t == "number" then
            return 8
        elseif t == "boolean" then
            return 1
        elseif t == "table" then
            seen = seen or {}
            local bref = seen[thing]
            if bref then
                return 0
            end
            local cost = 8
            seen[thing] = true
            for k, v in pairs(thing) do
                local k_cost = internal(k, seen)
                local v_cost = internal(v, seen)
                cost = cost + k_cost + v_cost
            end
            return cost
        elseif t == "function" then
            -- oh the fun
            return api.get_size(thread, thing, true)
        elseif t == "thread" then
            return api.get_size(thing, nil, false) -- we dont know the environment, who cares anyway
        else
            return 0
        end
    end

    return internal(thing, {
        [thread] = true,
    })
end

function api.size_check(env, lim, thread)
    local size = api.get_size(thread, env)
    if size > lim then
        return {
            is_err = true,
            errmsg = "Out of memory!",
            is_special = true
        }
    else
        return true
    end
end

function api.run_sandbox(ID, values_passed)
    --[[
        Returns: {
            is_err = bool,
            is_special = bool,
            ret_values = table<anything, very unsafe to call from>,
            errmsg = string
        }
    ]]
    local sandbox = active_sandboxes[ID]
    if sandbox == nil then
        return {
            is_err = true,
            is_special = true,
            errmsg = "Sandbox not found. (Garbage collected?)"
        }
    end

    sandbox.last_ran = os.clock()

    if sandbox.thread == nil then
        local is_success, errmsg = create_thread(sandbox)
        if is_success == false then
            return {
                is_err = true,
                is_special = true,
                errmsg = errmsg,
            }
        end
    end

    local thread = sandbox.thread
    if coroutine.status(thread) == "dead" then
        return {
            is_err = true,
            errmsg = "The coroutine is dead, nothing to do.",
            is_special = true
        }
    end

    -- the hazmat suit

    local ok, errmsg_or_value
    pcall(function()
        debug.sethook(thread, sandbox.in_hook(), "", sandbox.hook_time)
        getmetatable("").__index = sandbox.env.string

        -- THE CODE THAT CALLS
        ok, errmsg_or_value = coroutine.resume(thread, values_passed)
    end)
    debug.sethook(thread)
    getmetatable("").__index = string

    local size_check = api.size_check(sandbox.env, sandbox.size_limit, thread)
    if size_check ~= true then return size_check end

    if ok == nil then
        return {
            is_err = true,
            is_special = true,
            errmsg = "Something very weird happened, most likely timed out."
        }
    end

    if ok == false then
        return {
            is_err = true,
            is_special = false,
            errmsg = errmsg_or_value,
            ret_values = errmsg_or_value,
        }
    else
        return {
            is_err = false,
            ret_values = errmsg_or_value,
            is_special = false
        }
    end
end

function api.garbage_collect()
    local number_of_sandboxes = 0
    local to_be_collected = {}
    local current_time = os.clock()
    for k, v in pairs(active_sandboxes) do
        if not v.is_garbage_collected then return end
        number_of_sandboxes = number_of_sandboxes + 1

        local difftime = current_time - v.last_ran
        if difftime > api.settings.gc.time_treshold then
            to_be_collected[#to_be_collected + 1] = k
        end
    end

    if number_of_sandboxes < api.settings.gc.number_of_sandboxes then return false, 0 end
    for i = 1, #to_be_collected do
        active_sandboxes[to_be_collected[i]] = nil
    end

    local size = collectgarbage("collect")
    return #to_be_collected, size
end

api.active_sandboxes = active_sandboxes
libox.coroutine = api

--[[
    TODOs:
        - Auto GC
        - Tests
        - An actual mod using this
        - Actual getsize function, not just clean_and_weigh

]]

local function start_timer()
    minetest.after(api.settings.gc.interval, function()
        api.garbage_collect()
        start_timer()
    end)
end
if api.settings.gc.auto and minetest.after then
    -- if minetest.after doesn't exist then that means we are on async environment
    -- we don't collect garbage there then, i mean like... yeah
    start_timer()
end
