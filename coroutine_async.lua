local active_sandboxes = libox.coroutine.active_sandboxes

local function create_thread(sandbox)
    if sandbox.code:byte(1) == 27 then
        return false, "Bytecode was not allowed."
    end

    local f, msg = loadstring(sandbox.code)
    if not f then return nil, msg end
    setfenv(f, sandbox.env)

    if rawget(_G, "jit") then
        jit.off(f, true) -- turn jit off for that function and yes this is needed or the user can repeat until false, sorry
    end

    sandbox.thread = coroutine.create(f)
end

local function run_sandbox_async(ID, values_passed, async_callback)
    --[[
        Returns: {
            is_err = bool,
            is_special = bool,
            ret_values = table<anything, very unsafe to call from>,
            errmsg = string
        }
        or returns "In async"
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
        local is_error, errmsg = create_thread(sandbox)
        if is_error then
            return {
                is_err = true,
                is_special = false,
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
    minetest.handle_async(function(sandbox, values_passed)
        local ok, errmsg_or_value
        pcall(function()
            debug.sethook(sandbox.thread, sandbox.in_hook(), "", sandbox.hook_time)
            getmetatable("").__index = sandbox.env.string

            -- THE CODE THAT CALLS
            ok, errmsg_or_value = coroutine.resume(thread, values_passed)
        end)
        debug.sethook(thread)
        getmetatable("").__index = string
        return ok, errmsg_or_value
    end, function(ok, errmsg_or_value)
        local size_check = api.size_check(sandbox.env, sandbox.size_limit, thread)
        if size_check ~= true then return size_check end
        async_callback(ok, errmsg_or_value) -- deal with it
    end, sandbox, values_passed)
    return "In async"
end

libox.coroutine.run_sandbox_async = run_sandbox_async
