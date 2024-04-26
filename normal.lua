local BYTECODE_CHAR = 27


function libox.normal_sandbox(def)
    local code = def.code
    local allow_bytecode = def.allow_bytecode
    local env = def.env
    local error_handler = def.error_handler or libox.traceback
    local in_hook = def.in_hook or libox.get_default_hook(def.max_time)

    if not allow_bytecode and code:byte(1) == BYTECODE_CHAR then
        return false, "Bytecode was not allowed."
        -- bytecode can write to ARBITRARY memory locations i think, or something, idk
        -- ok so update: minetest, when using mod security does not allow bytecode
        -- (this also means the deserialization of functions)
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
