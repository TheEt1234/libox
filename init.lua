local ie = minetest.request_insecure_environment()
if ie == nil and (debug.getlocal == nil or debug.getupvalue == nil) then
    minetest.log("warning", [[
=== ATTENTION ===
Libox is not included in trusted mods,
this means that libox cannot measure local variables and upvalues inside coroutine sandboxes
(it needs debug.getlocal and debug.getupvalue to do it)

LIBOX WILL EXPOSE AND USE debug.getlocal AND debug.getupvalue
MAKE SURE TO TRUST ALL MODS IF YOU MAKE LIBOX A TRUSTED MOD
(realistically this is very hard to abuse)

If you don't use coroutine sandboxes, feel free to ignore this warning
Libox can also reuse debug.getlocal and getupvalue if it is already avaliable in the environment
=== ATTENTION END ===
        ]])
elseif debug.getlocal == nil or debug.getupvalue == nil then
    debug.getlocal = ie.debug.getlocal
    debug.getupvalue = ie.debug.getupvalue
end

ie = nil

--[[
    Problem: we need to somehow get debug.getlocal from the normal environment
    to the async environment

    All functions are serialized, and as you may know, serializing C functions isn't possible

    Ya know... there are not many options... BUT we can try!

    Worst case is we will have a seperate API for async coroutines that must be called from not-async (so lame)

    Okay so, it IS impossible (practically, i dont want to get into C code)
]]
-- Well then...
-- I guess i have no sane_input choice but to make 2 different files for the coroutine sandbox

local MP = minetest.get_modpath(minetest.get_current_modname())
dofile(MP .. "/main.lua")
-- Files that are executed sync only
dofile(MP .. "/coroutine.lua")
dofile(MP .. "/coroutine_async.lua") -- called from sync, does async stuffs
dofile(MP .. "/coroutine.test.lua")
minetest.register_async_dofile(MP .. "/main.lua")
