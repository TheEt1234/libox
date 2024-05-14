libox = {
    safe = {},
    supply_additional_environment = function(...) return ... end, -- for other mods
}


local MP = minetest.get_modpath("libox")
dofile(MP .. "/env.lua")
dofile(MP .. "/utils.lua")
dofile(MP .. "/normal.lua")
libox.pat = loadfile(MP .. "/pat.lua")()
