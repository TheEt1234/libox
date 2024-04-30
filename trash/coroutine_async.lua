--[[
    The "async" version of the coroutine sandbox
    Called from sync, continues in async, calls callback
]]
--[[
    callback is called with:
        callback(ok, errmsg_or_value)
    Good luck!

]]
function libox.coroutine.run_sandbox_async(ID, callback, values_passed)
    local sandbox = libox.coroutine.active_sandboxes[ID]
    if sandbox == nil then
        return callback(false, "Sandbox not found. (Garbage collected?)")
    end

    sandbox.last_ran = os.clock()

    if sandbox.thread == nil then
        local is_success, errmsg = libox.coroutine.create_thread(sandbox)
        if is_success == false then
            return callback(false, errmsg)
        end
    end

    local thread = sandbox.thread
    if coroutine.status(thread) == "dead" then
        return callback(false, "The coroutine is dead, nothing to do.")
    end

    minetest.handle_async(
        function(sandbox)
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
        end,
        function(ok, errmsg_or_value)
            local size_check = libox.coroutine.size_check(sandbox.env, sandbox.size_limit, thread)
            if size_check ~= true then
                return callback(true, "Out of memory!")
            else
                return callback(ok, errmsg_or_value)
            end
        end,
        sandbox
    )
end
