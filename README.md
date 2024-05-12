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
Traceback's shortened paths: [The minetest debug mod's shorten_path.lua](https://github.com/appgurueu/dbg/blob/master/src/shorten_path.lua) - MIT licensed