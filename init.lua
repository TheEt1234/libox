local MP = minetest.get_modpath(minetest.get_current_modname())


dofile(MP .. "/main.lua")
minetest.register_async_dofile(MP .. "/main.lua")
