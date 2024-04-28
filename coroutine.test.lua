--[[
    THEESE TESTS CAN BE ACTIVATED USING WORLDEDIT
    do //lua libox.coroutine.test.run_tests()

    This does not test async anymore, that will be super tricky
    async in general is just... super tricky, more and more it feels like just a complicated way to call functions lmao

    Also libox coroutines ware TTD'ed somewhat (test driven developed)
]]
libox.coroutine.test = {}
libox.coroutine.test.tests = {} -- its hard to name things okay

local function it(name, func)
    libox.coroutine.test.tests[#libox.coroutine.test.tests + 1] = { f = func, n = name }
end

function libox.coroutine.test.run_tests()
    for _, v in pairs(libox.coroutine.test.tests) do
        local result = v.f()
        if result == true then
            minetest.log(v.n .. " : Success")
        else
            minetest.log(v.n .. " : Failure")
        end
    end
end

function libox.coroutine.test.run_test(test)
    for _, v in pairs(libox.coroutine.test.tests) do
        if v.n == test then
            local result = v.f()
            if result == true then
                minetest.log(v.n .. " : Success")
            else
                minetest.log(v.n .. " : Failure")
            end
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
        Probably needs debug.getlocal as well?
        or needs debug.getupvalue

        Honestly i hope it doesnt need upvalues

        NOPE, IT NEEEEDS UPVALUES
        ARGH! i hate lua for doing questionable shit
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
    minetest.debug(dump(v))
    return (v.is_err) and (v.is_special == true) and
        (v.errmsg == "Out of memory!")
end)
