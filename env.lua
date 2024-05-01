local BYTECODE_CHAR = 27


local function wrap(f, obj)
    return function(...)
        return f(obj, ...)
    end
end

function libox.safe.rep(str, n)
    if #str * n > 64000 then
        error("no its not that easy", 2)
    end
    return string.rep(str, n)
end

function libox.safe.PcgRandom(seed, seq)
    if seq and #seq > 1000 then error("Sequence too large, size limit is 1000", 2) end
    local pcg = PcgRandom(seed, sequence)

    -- now make the interface
    local interface = {
        next = wrap(pcg.next, pcg),
        rand_normal_dist = function(min, max, num_trials)
            if num_trials and num_trials > 50 then
                error("too many trials", 2)
            end
            return pcg:rand_normal_dist(min, max, num_trials)
        end
    }
    return interface
end

function libox.safe.pcall(f, ...)
    local ret_values = { pcall(f, ...) }
    if not debug.gethook() then
        error("Code timed out!", 2)
    end
    return unpack(ret_values)
end

function libox.safe.xpcall(f, handler, ...)
    local ret_values = {
        xpcall(f, function(...)
            if not debug.gethook() then
                error("Code timed out!", 2)
                return
            end
            return handler(...)
        end, ...)
    }

    if not debug.gethook() then
        error("Code timed out!", 2)
    end

    return unpack(ret_values)
end

function libox.safe.get_loadstring(env) -- chunkname is ignored
    return function(code, chunkname)
        if chunkname ~= nil then
            error(
                "Adding a chunkname is forbidden, see https://www.lua-users.org/wiki/SandBoxes i dont know if this is actually true but yeah, besides who cares",
                2)
        end
        if type(code) == "string" and #code > 64000 then error("Code too long :/", 2) end
        if code:byte(1) == BYTECODE_CHAR then
            error("dont sneak in bytecode (mod security will prevent you anyway)", 2)
        end
        local f, errmsg = loadstring(code)
        if f == nil then
            return nil, errmsg
        end
        setfenv(f, env)

        if rawget(_G, "jit") then
            jit.off(f, true)
        end

        return f, errmsg
    end
end

-- Wraps os.date to only replace valid formats,
-- ignoring invalid ones that would cause a hard crash.
local TIME_MAX = 32535244800 -- 01/01/3001
-- todo: change on 01/01/3001
-- this is from mooncontroller btw
local function safe_date(str, time)
    if type(time) ~= "number" then
        time = os.time()
    elseif time < 0 or time >= TIME_MAX then
        return nil
    end

    if type(str) ~= "string" then
        return os.date("%c", time)
    end
    if str == "*t" then
        return os.date("*t", time)
    end
    str = string.gsub(str, "%%[aAbBcdHImMpSwxXyY]", function(s)
        return os.date(s, time)
    end)
    return str
end

local function datetable()
    return os.date("*t")
end

function libox.create_basic_environment()
    --[[
        get the safest, least strict lua environment
        don't add setfenv/getfenv here, or that could cause RCE or allow some REALLY nasty crap (like modifying environments of library functions), while that would be *fun* to mess with and exploit, i don't think we should sacrefice some serious security for "it would be fun"
    ]]

    -- INCLUDES: basic lib (minus the coroutine, that thing can't be serialized), string lib, table lib, math, bit, os
    -- is meant to be added on top of
    local env = {
        _VERSION = _VERSION,
        assert = assert,
        error = error,
        collectgarbage = function(arg)
            if arg ~= "count" then error("The only valid mode to collectgarbage is count") end
            return collectgarbage("count")
        end,
        ipairs = ipairs,
        pairs = pairs,
        next = next,
        pcall = libox.safe.pcall,
        xpcall = libox.safe.xpcall,
        select = select,
        unpack = function(t, a, b)
            if not b or b < 2 ^ 30 then
                b = 2 ^ 29 -- whatever lmao
            end
            return unpack(t, a, b)
        end,

        tonumber = tonumber,
        tostring = tostring,
        type = type,

    }
    env.loadstring = libox.safe.get_loadstring(env)
    env._G = env

    env.string = {
        byte = string.byte,
        char = string.char,
        dump = string.dump,
        find = function(s, pattern, init)
            return string.find(s, pattern, init, true)
        end,
        format = string.format,
        len = string.len,
        lower = string.lower,
        rep = libox.safe.rep,
        reverse = string.reverse,
        sub = string.sub,
        upper = string.upper,
        -- minetest helpers
        trim = string.trim, -- WARN: i dont know about this, but probably alright
        split = function(str, delim, include_empty, max_splits, sep_is_pattern)
            if sep_is_pattern == true then
                error("No the seperator won't be a pattern", 2)
            end
            return string.split(str, delim, include_empty, max_splits, false)
        end,
    }

    env.table = {
        insert = table.insert,
        maxn = table.maxn,
        remove = table.remove,
        sort = table.sort,
        -- minetest helpers:
        indexof = table.indexof,
        copy = table.copy,
        insert_all = table.insert_all,
        key_value_swap = table.key_value_swap,
        shuffle = table.shuffle,
        -- luajit helpers
        move = table.move,
        -- deperecated stuff lol, no code should rely on this but whatever, i like foreach
        foreach = table.foreach,
        foreachi = table.foreachi,
    }

    env.math = {}
    for _, v in ipairs({
        "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "cosh", "deg", "exp", "floor",
        "fmod", "frexp", "huge", "ldexp", "log", "log10", "max", "min", "modf", "pi", "pow",
        "rad", "random", "sin", "sinh", "sqrt", "tan", "tanh",

        -- minetest helpers
        "hypot", "sign", "factorial", "round"
    }) do -- todo: get rid of math.random and replace it with a PcgRandom.next ?
        env.math[v] = math[v]
    end

    env.bit = table.copy(bit)

    env.vector = table.copy(vector)
    env.vector.metatable = nil

    env.os = {
        clock = os.clock,
        datetable = datetable,
        difftime = os.difftime,
        time = os.time,
        date = safe_date,
    }

    env.minetest = {
        formspec_escape = libox.sandbox_lib_f(minetest.formspec_escape),
        explode_table_event = libox.sandbox_lib_f(minetest.explode_table_event),
        explode_textlist_event = libox.sandbox_lib_f(minetest.explode_textlist_event),
        explode_scrollbar_event = libox.sandbox_lib_f(minetest.explode_scrollbar_event),
        inventorycube = libox.sandbox_lib_f(minetest.inventorycube),
        urlencode = libox.sandbox_lib_f(minetest.urlencode),
        rgba = libox.sandbox_lib_f(minetest.rgba),
        encode_base64 = libox.sandbox_lib_f(minetest.encode_base64),
        decode_base64 = libox.sandbox_lib_f(minetest.decode_base64),
        get_us_time = libox.sandbox_lib_f(minetest.get_us_time),
    } -- safe minetest functions


    -- extra global environment stuff
    for _, v in ipairs({
        "dump", "dump2"
    }) do
        env[v] = _G[v]
    end

    -- oh yeah who could forget...
    -- some random minetest stuffs
    env.PcgRandom = libox.safe.PcgRandom
    env.PerlinNoise = PerlinNoise

    return env
end
