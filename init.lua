local ie = minetest.request_insecure_environment()
if ie == nil and (debug.getlocal == nil or debug.getupvalue == nil) then
    minetest.log("warning", [[
===== ATTENTION (this is mainly for servers)=======
Libox is not included in trusted mods,
this means that libox cannot measure local variables and upvalues inside coroutine sandboxes
(it needs debug.getlocal and debug.getupvalue to do it)

LIBOX WILL EXPOSE AND USE debug.getlocal AND debug.getupvalue
also MAKE SURE TO TRUST ALL MODS IF YOU MAKE LIBOX A TRUSTED MOD
(but also this is very hard to abuse unless your mods store the insecure environment somewhere)

If you don't use coroutine sandboxes, feel free to ignore this warning
Libox can also reuse debug.getlocal and getupvalue if it is already avaliable in the environment
========== ATTENTION END ==========
        ]])
elseif debug.getlocal == nil or debug.getupvalue == nil then
    debug.getlocal = ie.debug.getlocal
    debug.getupvalue = ie.debug.getupvalue
end

ie = nil

local MP = minetest.get_modpath(minetest.get_current_modname())
dofile(MP .. "/main.lua")
-- Files that are executed sync only
dofile(MP .. "/coroutine.lua")
dofile(MP .. "/coroutine.test.lua")

minetest.register_async_dofile(MP .. "/main.lua")
