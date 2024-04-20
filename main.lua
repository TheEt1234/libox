libox = {}
-- reason for being called main instead of just having this in init.lua: it gets executed both in the async and in the non async environment


local MP = minetest.get_modpath("libox")
dofile(MP .. "/utils.lua")
dofile(MP .. "/normal.lua")
