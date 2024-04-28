libox = {
    safe = {}
}
-- reason for being called main instead of just having this in init.lua: it gets executed both in the async and in the non async environment


local MP = minetest.get_modpath("libox")
dofile(MP .. "/env.lua")
dofile(MP .. "/utils.lua")
dofile(MP .. "/normal.lua")
--dofile(MP .. "/coroutine.lua") -- now defined in init.lua
