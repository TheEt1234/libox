libox.test.describe("Normal sandbox (tests the environment)", function(it)
    it("Doesn't do bytecode", function(assert) -- mod security prevents it anyway kek
        assert(not libox.normal_sandbox({
            code = string.dump(assert),
            env = {},
            in_hook = function() end,
        }))
    end)
    it("Limits time", function(assert)
        assert(not libox.normal_sandbox({
            code = "repeat until false ",
            env = {},
            max_time = 1000
        }))
    end)
    it("Handles pcall correctly", function(assert)
        assert(not libox.normal_sandbox({
            code = "pcall(function() repeat until false end)",
            env = libox.create_basic_environment(),
            max_time = 1000
        }))
    end)
    it("Handles xpcall correctly", function(assert)
        assert(not libox.normal_sandbox({
            code = "xpcall(function() error('yeh') end,function() repeat until false end)",
            env = libox.create_basic_environment(),
            max_time = 1000
        }))
    end)
    it("Isn't vurnable to severe trollery", function(assert, good, bad, custom)
        local t1 = minetest.get_us_time()
        local ok, errmsg = libox.normal_sandbox({
            code = [[
                local x = "."
                repeat
                    x = x .. x
                until false
            ]],
            env = {},
            max_time = 10000, -- 10 milis for this
        })                    -- normal luac sandbox would kill itself
        local t2 = minetest.get_us_time()
        if ok then
            bad()
        else
            custom("took " .. (t2 - t1) .. "us, sandbox was given 10 000 us")
        end
    end)
    it("Can loadstring", function(assert)
        assert(libox.normal_sandbox({
            code = [[
                assert(
                    loadstring(
                        "return 'hi'"
                    )
                )
                ]],
            env = libox.create_basic_environment(),
            max_time = 1000,
        }))
    end)
    it("Can loadstring securely", function(assert)
        assert(not libox.normal_sandbox({
            code = [[
                loadstring('assert(debug)')() -- we don't use minetest as an example because libox.create_basic_environment already does some magic
            ]],
            env = libox.create_basic_environment(),
            max_time = 1000,
        }))
    end)
    it("Can handle shenanigans", function(assert, good, bad, custom)
        --[[
            This attempts to abuse libox.traceback to create a gigantic errmsg and force several executions of debug.getinfo
        ]]
        local code = [[
            pcall(loadstring(code)())
        ]]
        local env = libox.create_basic_environment()
        env.code = code

        local t1 = minetest.get_us_time()
        local ok, _ = libox.normal_sandbox({
            code = code,
            env = env,
            max_time = 10000
        })
        local t2 = minetest.get_us_time()
        if ok then
            bad()
        else
            custom("took: " .. (t2 - t1) .. "us, sandbox was given 10 000 us")
        end
    end)
    it("Can't abuse string.rep", function(assert, good, bad, custom)
        assert(not libox.normal_sandbox({
            code = "string.rep('a',9999999)",
            env = libox.create_basic_environment(),
            max_time = 10000,
        }))
    end)
    it("Can handle some basic shenanigans", function(assert)
        assert(not libox.normal_sandbox({
            code = [[
                local str = string.rep(":",64000)
                str = str .. str
                minetest.urlencode(str)
            ]],
            max_time = 10000,
            env = libox.create_basic_environment()
        }))
    end)
end)
