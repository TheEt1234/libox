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

function api.create_thread(sandbox)
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

function api.is_sandbox_dead(id)
    local sandbox = active_sandboxes[id]
    if sandbox == nil then return true end
    if sandbox.thread == nil then return false end -- api.run_sandbox will work just fine
    if coroutine.status(sandbox.thread) == "dead" then return true end
    return false
end

function api.delete_sandbox(id) -- idk if i should deprecate this? but im not gonna use it
    active_sandboxes[id] = nil
end

local function locals(val, f_thread)
    --[[
        Arguments to this are sorta confusing but better what we had before
        f_thread: optional thread if type(val) == "function"
        val: the value you are trying to get locals of, can be function or thread, if thread then f_thread is ignored
    ]]
    local ret = {
        _F = "", -- the function itself, weighed using string.dump
        _L = {}, -- Locals
        _U = {}  -- Upvalues
    }

    local getinfo, getlocal, getupvalue = debug.getinfo, debug.getlocal, debug.getupvalue

    if type(val) == "thread" then
        -- i don't think the thread can have any upvalues
        -- as in like....
        -- yeah....
        -- lets take a look at a closure, function x() local n = {} return function() return n end end
        -- that has n
        -- but yeah yeah
        -- fuck i got lost
        -- lets just check them just in case
        local level = getinfo(val, 1, "u")
        if level ~= nil then
            local index = 1
            while true do
                local k, v = getlocal(val, 1, index)
                if k ~= nil then
                    ret._L[k] = v
                else
                    break
                end
                index = index + 1
            end
            if level.nups > 0 then
                local index = 1
                local f = getinfo(val, 1, "f").func
                while true do
                    local k, v = getupvalue(f, index)
                    if k ~= nil then
                        ret._U[k] = v
                    else
                        break
                    end
                    index = index + 1
                end
            end
        end
    elseif type(val) == "function" then
        local func_info = getinfo(f_thread, val, "Su")
        if not func_info or func_info.what == "C" then
            return {}
        end -- whatever
        local f_size = string.dump(val)
        ret._F = f_size
        local index = 1
        while true do
            local k, v = getlocal(val, index)
            if k ~= nil then
                ret._L[k] = v
            else
                break
            end
            index = index + 1
        end
        if func_info.nups > 0 then
            local index = 1
            while true do
                local k, v = getupvalue(val, index)
                if k ~= nil then
                    ret._U[k] = v
                else
                    break
                end
                index = index + 1
            end
        end
    end
    return ret
end

api.locals = locals


local function get_size(env, seen, thread, recursed)
    local deferred_weigh_locals = {}
    if not recursed then
        deferred_weigh_locals[#deferred_weigh_locals + 1] = thread
    end

    local function internal(x, seen)
        local t = type(x)
        if t == "string" then
            return #x + 25
        elseif t == "number" then
            return 8
        elseif t == "boolean" then
            return 1
        elseif t == "table" and not seen[x] then
            local cost = 8
            seen[x] = true
            for k, v in pairs(x) do
                local k_cost = internal(k, seen)
                local v_cost = internal(v, seen)
                cost = cost + k_cost + v_cost
            end
            return cost
        elseif t == "function" and not seen[x] then
            -- oh the fun!
            seen[x] = true
            deferred_weigh_locals[#deferred_weigh_locals + 1] = x
            return 0 -- deffered
        elseif t == "thread" and not seen[x] then
            seen[x] = true
            deferred_weigh_locals[#deferred_weigh_locals + 1] = x
            return 0 -- deffered
        else
            return 0
        end
    end

    local retv = internal(env, seen)
    if debug.getlocal ~= nil and debug.getupvalue ~= nil then
        for i = 1, #deferred_weigh_locals do
            local v = deferred_weigh_locals[i]
            local their_locals = locals(v, thread)

            local size = get_size(their_locals, seen, thread, true)
            retv = retv + size
        end
    end

    return retv
end

api.get_size = get_size

function api.size_check(env, lim, thread)
    if thread == nil then error("Thread is nil! you can't check the size!") end
    local size = api.get_size(env, {}, thread, false)
    return size < lim
end

function api.run_sandbox(ID, value_passed)
    --[[
        Returns: ok, errmsg_or_value
    ]]
    local sandbox = active_sandboxes[ID]
    if sandbox == nil then
        return false, "Sandbox not found. (Garbage collected?)"
    end

    sandbox.last_ran = os.clock()

    if sandbox.thread == nil then
        local ok, errmsg = api.create_thread(sandbox)
        if ok == false then
            return false, errmsg
        end
    end

    local thread = sandbox.thread
    if coroutine.status(thread) == "dead" then
        return false, "The coroutine is dead, nothing to do."
    end

    local ok, errmsg_or_value

    local pcall_ok = pcall(function()
        debug.sethook(thread, sandbox.in_hook(), "", sandbox.hook_time)
        getmetatable("").__index = sandbox.env.string
        ok, errmsg_or_value = coroutine.resume(thread, value_passed)
    end)

    debug.sethook(thread)
    getmetatable("").__index = string

    local size_check = api.size_check(sandbox.env, sandbox.size_limit, thread)
    if not size_check then return false, "Out of memory!" end

    if not pcall_ok then -- idk how this happens lmao
        return false, "Something very weird happened, most likely timed out."
    end

    if not ok then
        return false, errmsg_or_value
    else
        return true, errmsg_or_value
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

-- export
api.active_sandboxes = active_sandboxes
libox.coroutine = api

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
