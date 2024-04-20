local BYTECODE_CHAR = 27
function libox.get_default_hook(max_time)
    local time = minetest.get_us_time

    local current_time = time()
    return function()
        if time() - current_time > max_time then
            error("Code timed out! Reason: Time limit exceeded, the limit:" .. tostring(max_time / 1000) .. "ms", 2)
        end
    end
end

function libox.traceback(...) -- directly taken from the async_controller mod
    local MP = minetest.get_modpath("libox")
    local args = { ... }
    local errmsg = tostring(args[1])
    local string_meta = getmetatable("")
    string_meta.__index = string -- Leave string sandbox permanently

    local traceback = "Traceback: " .. "\n"
    local level = 1
    while true do
        local info = debug.getinfo(level, "nlS")
        if not info then break end
        local name = info.name
        local text
        if name ~= nil then
            text = "In function " .. name
        else
            text = "In " .. info.what
        end
        if info.source == "=(load)" then
            traceback = traceback .. text .. " at line " .. info.currentline .. "\n"
        end
        level = level + 1
    end

    local base = MP:sub(1, #errmsg - #MP)
    return errmsg:gsub(base, "<libox>", 1) .. "\n" .. traceback
end

function libox.sandbox_lib_f(f, ...)
    --[[
        Sandbox external functions, should not be done for functions that can execute arbitrary code/functions!
    ]]
    local args = { ... }
    return function(...)
        local string_meta = getmetatable("")
        local sandbox = string_meta.__index

        string_meta.__index = string
        local retvalue = { f(unpack(args), ...) }
        string_meta.__index = sandbox

        if not debug.gethook() then
            error("Code timed out! (Reason: external function erased the debug hook)", 2)
        end
        return unpack(retvalue)
    end
end

libox.safe = {}

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
                error(...)
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

function libox.safe.loadstring(code, chunkname) -- chunkname is ignored
    if chunkname ~= nil then error("Adding a chunkname is forbidden, see https://www.lua-users.org/wiki/SandBoxes", 2) end
    if type(code) == "string" and #code > 64000 then error("Code too long :/", 2) end
    if code:byte(1) == BYTECODE_CHAR then
        error("dont sneak in bytecode", 2)
    end
    local f, errmsg = loadstring(code)
    if f == nil then
        return nil, errmsg
    end
    if getfenv(2) == _G then
        error("Report this as a bug plz, this is bad", 2)
    end
    setfenv(f, getfenv(2))

    if rawget(_G, "jit") then
        jit.off(f, true)
    end

    return f, errmsg
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
        loadstring = libox.safe.loadstring,
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
        rep = function(string, n, sep)
            if #string * n > 64000 then
                error("no its not that easy", 2)
            end
            if #string * n * #sep > 64000 then
                error("no its not that easy", 2)
            end
            return string.rep(string, n, sep)
        end,
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
        -- deperecated stuff lol
        move = table.move,
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
    }) do
        env.math[v] = math[v]
    end

    env.bit = table.copy(bit)

    env.os = {
        clock = os.clock,
        datetable = datetable,
        difftime = os.difftime,
        time = os.time,
        date = safe_date,
    }

    env.minetest = {
        formspec_escape = minetest.formspec_escape,
        explode_table_event = minetest.explode_table_event,
        explode_textlist_event = minetest.explode_textlist_event,
        explode_scrollbar_event = minetest.explode_scrollbar_event,
        inventorycube = minetest.inventorycube,
        urlencode = minetest.urlencode,
        rgba = minetest.rgba,
        encode_base64 = minetest.encode_base64,
        decode_base64 = minetest.decode_base64,
        get_us_time = minetest.get_us_time,
    } -- safe minetest functions

    env.vector = table.copy(vector)
    env.vector.metatable = nil

    -- extra global environment stuff
    for _, v in ipairs({
        "dump", "dump2"
    }) do
        env[v] = _G[v]
    end
    return env
end

function libox.digiline_sanitize(input, allow_functions, wrap)
    --[[
		Parameters:
			1) t: the table that you are going to send (doesnt need to be a table tho)
			2) allow_functions: true/false, explains itself
			3) wrap: function, the function that wraps around the functions in this table, by default it's libox.sandbox_wrap
			Also, errors may be forcefully corrected, to copy use table.copy
	]]

    local wrap = wrap --or libox.sandbox_wrap

    local function internal(msg, back_references)
        local t = type(msg)
        if t == "string" then
            return true, #msg + 25
        elseif t == "number" then
            if msg ~= msg then
                return false, 0
            end
            return true, 8
        elseif t == "boolean" then
            return true, 1
        elseif t == "table" then
            back_references = back_references or {}
            local bref = back_references[msg]
            if bref then
                return true, 0
            end
            -- Construct a new table by cleaning all the keys and values and adding
            -- up their costs, plus 8 bytes as a rough estimate of table overhead.
            local cost = 8
            back_references[msg] = true
            for k, v in pairs(msg) do
                local k_cost, v_cost
                allowed_k, k_cost = internal(k, back_references)
                allowed_v, v_cost = internal(v, back_references)
                if allowed_k == false or allowed_v == false then
                    msg[k] = nil -- forcefully correct the error
                end

                if type(allowed_v) ~= "boolean" and allowed_v ~= nil then
                    msg[k] = allowed_v
                elseif type(allowed_k) ~= "boolean" and allowed_k ~= nil then
                    -- this one is... tricky
                    -- and honestly who the hell does that, kill the key
                    msg[k] = nil
                end
                -- If we only counted the cost of a table element when we actually
                -- used it, we would be vulnerable to the following attack:
                -- 1. Construct a huge table (too large to pass the cost limit).
                -- 2. Insert it somewhere in a table, with a function as a key.
                -- 3. Insert it somewhere in another table, with a number as a key.
                -- 4. The first occurrence doesn’t pay the cost because functions
                --    are stripped and therefore the element is dropped.
                -- 5. The second occurrence doesn’t pay the cost because it’s in
                --    back_references.
                -- By counting the costs regardless of whether the objects will be
                -- included, we avoid this attack; it may overestimate the cost of
                -- some messages, but only those that won’t be delivered intact
                -- anyway because they contain illegal object types.
                cost = cost + k_cost + v_cost
            end
            return true, cost
        elseif t == "function" and allow_functions == true then
            local success, bytecode = pcall(function()
                return string.dump(msg)
            end)
            local cost = #bytecode + 25
            if not success then return false, 0 end -- that function cannot be serialized or cannot be transmitted between environments

            setfenv(msg, {})
            -- any/all environment functions will have to be passed by arguments, sorry
            if wrap ~= nil then
                -- we have a problem here...
                -- we cannot really modify the message.... besides just saying "is it allowed" or not
                -- to solve this, i uhh did this
                if msg == input then
                    input = wrap(msg) -- change the t to be the wrapping
                    return true, cost
                else
                    local wrapping = wrap(msg)
                    return wrapping, cost -- introduce special case
                end
            end

            return true, cost
        else
            return false, 0
        end
    end

    local allowed, cost = internal(input)
    if not allowed then
        return nil, 0
    else
        return input, cost
    end
end

if rawget(_G, "jit") then
    -- unsure if this is required for fastness but whatever
    jit.on(libox.digiline_sanitize, true)
end
