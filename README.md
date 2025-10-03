# Libox

A minetest sandboxing library, offering a basic environment, utilities, normal sandbox and a "coroutine" sandbox

Everything is avaliable in the async environment except the coroutine sandbox (due to minetest limitations)

See [api.md](https://github.com/TheEt1234/libox/blob/master/api.md) for documentation and definitions

See [env_docs.md](https://github.com/TheEt1234/libox/blob/master/env_docs.md) for documentation of the sandbox environment

# UPDATE: This may not be the best aproach to sandboxing
There is theoretically a WAY better to sandbox, that as of this writing (2025-10-03) has not been tried yet:

A library could parse lua code and automatically insert `coroutine.yield()` statements into it, and sandboxed code should be ran exclusively in another thread if possible.

This has a lot of benefits:
- no need for debug hooks if implemented correctly
    - Can JIT compile sandboxed code
    - Can get rid of the messy code around debug hooks
    - Code coverage can easier co-exist with this mod
- Has the same effect as autohook, without the incredibly messy stuff

# Notice!

Libox (optionally) requires insecure environment to weigh local variables and upvalues in the coroutine sandbox. **Without this someone can overfill your memory with local variables/upvalues**\
***the libox mod will expose debug.getlocal and debug.getupvalue to all mods***

Also if you are using coroutine sandboxes, please use luaJIT (default) instead of PUC lua, as there are a lot of differences between them

For auto-yielding coroutine sandboxes, please read about autohooks in `autohook/README.md`. This allows players to write code as if its running normally without needing to scatter `yield()` in their code.

# Security

- *Somewhat* fixes mesecons issue #516 by limiting based on time not instructions
- ***May introduce new bugs, only time can test that***
- Some of the responsibility is also on the mods that use libox as well (such as not doing something dumb like calling functions straight from the environment), the purpose of libox should be to also handle some of the more common stuff

# Optional dependancies
dbg - not actually used for debugging, just used to provide `dbg.shorten_path`, if unavaliable it will fallback to the copied implementation

# Credits - see License.md for the actual licenses

Code (unless mentioned somewhere differently) - LGPLv3

`libox.shorten_path` - [The minetest dbg mod's shorten_path.lua](https://github.com/appgurueu/dbg/blob/master/src/shorten_path.lua) - MIT licensed

`pat.lua`: [source](https://notabug.org/pgimeno/patlua/src/master/pat.lua) [and the mesecons issue](https://github.com/minetest-mods/mesecons/issues/456) - MIT licensed

`github/workflows/luacheck.yml` - from mt-mods, [original source here ](https://github.com/mt-mods/mt-mods/blob/master/snippets/luacheck.yml) - MIT licensed

`os.date` in the environment - from mooncontroller [original repo here](https://github.com/mt-mods/mooncontroller)

Inspiration: [Luacontrollers](https://github.com/minetest-mods/mesecons/tree/master/mesecons_luacontroller)
