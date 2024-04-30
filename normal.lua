local BYTECODE_CHAR = 27


function libox.normal_sandbox(def)
    local code = def.code
    local env = def.env
    local error_handler = def.error_handler or libox.traceback
    local in_hook = def.in_hook or libox.get_default_hook(def.max_time)

    if code:byte(1) == BYTECODE_CHAR then
        return false, "Bytecode is not allowed."
        -- mod security prevents it anyway
    end

    local f, msg = loadstring(code)
    if not f then return nil, msg end
    setfenv(f, env)

    if rawget(_G, "jit") then
        jit.off(f, true) -- turn jit off for that function and yes this is needed or the user can repeat until false, sorry
    end


    debug.sethook(in_hook, "", def.hook_time)
    getmetatable("").__index = env.string
    local ok, ret = xpcall(f, error_handler)
    debug.sethook()

    getmetatable("").__index = string
    if not ok then
        return false, ret
    else
        return true, ret
    end
end
