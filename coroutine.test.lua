--[[
    THEESE TESTS CAN BE ACTIVATED USING WORLDEDIT
    do //lua libox.coroutine.test.run_tests()

    This does not test async anymore, that will be super tricky
    async in general is just... super tricky, more and more it feels like just a complicated way to call functions lmao

    Also libox coroutines ware TTD'ed somewhat (test driven developed)

    ~~Maybe i should discover what this mtt thing is~~
]]
libox.coroutine.test = {}
libox.coroutine.test.tests = {} -- its hard to name things okay

local function it(name, func)
    libox.coroutine.test.tests[#libox.coroutine.test.tests + 1] = { f = func, n = name }
end

local function run_test_internal(v)
    local result = v.f()

    if type(result) ~= "boolean" and result ~= nil then
        minetest.log(v.n .. " : " .. result)
    elseif result == true then
        minetest.log(v.n .. " : Success")
    else
        minetest.log(v.n .. " : Failure")
    end
end

function libox.coroutine.test.run_tests()
    for _, v in pairs(libox.coroutine.test.tests) do
        run_test_internal(v)
    end
end

function libox.coroutine.test.run_test(test)
    for _, v in pairs(libox.coroutine.test.tests) do
        if v.n == test then
            run_test_internal(v)
            break
        end
    end
end

it("Can yield", function()
    local sandbox = libox.coroutine.create_sandbox({
        code = [[
local count = 0
repeat
    count = count+1
    coroutine.yield(count)
until false
]],
        env = {
            coroutine = {
                yield = coroutine.yield
            }
        },
    })

    local values = {
        libox.coroutine.run_sandbox(sandbox).ret_values, -- 1
        libox.coroutine.run_sandbox(sandbox).ret_values, -- 2
        libox.coroutine.run_sandbox(sandbox).ret_values, -- 3
        libox.coroutine.run_sandbox(sandbox).ret_values, -- 4
    }

    local succ = (values[1] == 1) and (values[2] == 2)
        and (values[3] == 3) and (values[4] == 4)

    if not succ then
        minetest.debug(dump(values))
    end

    libox.coroutine.delete_sandbox(sandbox)
    return succ
end)

it("Limits time", function()
    local sandbox = libox.coroutine.create_sandbox({
        code = "repeat until false",
        env = {},
    })
    local v = libox.coroutine.run_sandbox(sandbox)
    return v.is_err
end)

it("Limits environment size", function()
    local sandbox = libox.coroutine.create_sandbox({
        code = "a = string.rep('a',1000); coroutine.yield()",
        env = {
            string = {
                rep = string.rep,
                -- Never let the user get arbitrary string.rep, or the user can create terabytes of strings... we are giving it to the user here for testing
            },
        },
        size_limit = 1000

    })
    local v = libox.coroutine.run_sandbox(sandbox)
    return (v.is_err) and (v.is_special == true) and
        (v.errmsg == "Out of memory!")
end)

it("Limits circular references", function()
    local env = {}
    env._G = env
    env.f = function()
        --local a = env._G
        return env._G
    end
    local sandbox = libox.coroutine.create_sandbox({
        code = [[
            local e = _G -- Hehe i am an unsuspecting user and i am sure this won't be a mistake
            coroutine.yield()
        ]],
        -- When having _G as the environment, it simply stack overflows? this is like... bad... yeah
        env = env,
        size_limit = 1000,
        time_limit = 1000000 -- 1 million microseconds, can you imagine that (that's definitely not 1 second)

    })

    libox.coroutine.run_sandbox(sandbox)
    return true -- if it doesnt stack overflow it does thing propertly
end)

it("Limits local variables", function()
    --[[
        IMPORTANT: This fails when there is no access to debug.getlocal
    ]]

    local sandbox = libox.coroutine.create_sandbox({
        code = "local a = string.rep('a',1000); coroutine.yield(); coroutine.yield()",
        env = {
            string = {
                rep = string.rep,
                -- Never let the user get arbitrary string.rep, we are giving it to the user here for testing
            },
            coroutine = {
                yield = coroutine.yield
            },
        },
        size_limit = 1000,
        time_limit = 1000000 -- 1 million microseconds, can you imagine that (that's definitely not 1 second)

    })
    local v = libox.coroutine.run_sandbox(sandbox)
    return (v.is_err) and (v.is_special == true) and
        (v.errmsg == "Out of memory!")
end)

it("Really limits local variables...", function()
    --[[
        IMPORTANT: This fails when there is no access to debug.getlocal
    ]]

    local sandbox = libox.coroutine.create_sandbox({
        code = [[
        function evil()
            local a = string.rep('a',1000)
            coroutine.yield();
        end
        evil();
        coroutine.yield();
        coroutine.yield()
        ]],
        env = {
            string = {
                rep = string.rep,
                -- Never let the user get arbitrary string.rep, we are giving it to the user here for testing
            },
            coroutine = {
                yield = coroutine.yield
            },
        },
        size_limit = 1000,
        time_limit = 1000000 -- 1 million microseconds, can you imagine that (that's definitely not 1 second)

    })
    local v = libox.coroutine.run_sandbox(sandbox)
    return (v.is_err) and (v.is_special == true) and
        (v.errmsg == "Out of memory!")
end)

it("Limits upvalues", function()
    --[[
        this fails when we cant look up upvalues
    ]]
    local sandbox = libox.coroutine.create_sandbox({
        code = [[
            function get_evil()
                local evil = string.rep('a', 60000000)
                return function()
                    return evil
                end
            end
            local evil = get_evil()
            coroutine.yield()
        ]],
        env = {
            string = {
                rep = string.rep,
                -- Never let the user get arbitrary string.rep, we are giving it to the user here for testing
            },
            coroutine = {
                yield = coroutine.yield
            },
        },
        size_limit = 1000,
        time_limit = 1000000 -- 1 million microseconds, can you imagine that (that's definitely not 1 second)

    })
    local v = libox.coroutine.run_sandbox(sandbox)
    return (v.is_err) and (v.is_special == true) and
        (v.errmsg == "Out of memory!")
end)

it("Time to weigh _G (warn: unstable? theres a lot of crap in _G for sure)", function()
    local env = libox.create_basic_environment()
    libox.coroutine.get_size(env, {}, coroutine.create(function() end))
    -- JIT it up a little

    local sandbox = libox.coroutine.create_sandbox({
        code = [[
            local e = _G -- Hehe i am an unsuspecting user not aware of this sandboxing software's implementation and i am sure this won't be a problem
            coroutine.yield()
        ]],
        -- yeah
        env = _G,
        size_limit = 1000,
        time_limit = 1000000 -- 1 million microseconds, can you imagine that (that's definitely not 1 second)

    })

    local t1 = minetest.get_us_time()
    libox.coroutine.run_sandbox(sandbox)
    local sandboxd = libox.coroutine.active_sandboxes[sandbox]
    return "time:" ..
        (minetest.get_us_time() - t1) / 1000 .. "ms" ..
        " size:" .. libox.coroutine.get_size(sandboxd.env, {}, sandboxd.thread)
        ..
        " digiline sanitize thinks:" ..
        ({ libox.digiline_sanitize(env, true) })[2] .. " lua gc thinks: " .. collectgarbage("count") * 1024
end)
