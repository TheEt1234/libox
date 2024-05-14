# Libox

A minetest sandboxing library, offering a basic environment, utilities, normal sandbox and a "coroutine" sandbox

Everything is avaliable in the async environment except the coroutine sandbox (due to minetest limitations)

See [api.md](https://github.com/TheEt1234/libox/blob/master/api.md) for documentation and definitions

See [env_docs.md](https://github.com/TheEt1234/libox/blob/master/env_docs.md) for documentation of the sandbox environment

# Optional dependancies
dbg - not actually used for debugging, just used to provide `dbg.shorten_path`, if unavaliable it will fallback to the copied implementation

# License
Code (unless mentioned somewhere differently) - LGPLv3  
Inspiration: [Luacontrollers](https://github.com/minetest-mods/mesecons/tree/master/mesecons_luacontroller)  
libox.traceback's shortened paths: [The minetest dbg mod's shorten_path.lua](https://github.com/appgurueu/dbg/blob/master/src/shorten_path.lua) - MIT licensed  
pat.lua: [source](https://notabug.org/pgimeno/patlua/src/master/pat.lua) [the mesecon issue](https://github.com/minetest-mods/mesecons/issues/456) - MIT licensed  
`github/workflows/luacheck.yml` - from mt-mods, [original source here ](https://github.com/mt-mods/mt-mods/blob/master/snippets/luacheck.yml) - MIT licensed