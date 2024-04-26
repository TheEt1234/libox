# Libox
# DO NOT CONSIDER THIS PROJECT SECURE CURRENTLY

A minetest lua sandboxing library

Offers mainly some very useful sandbox utilities and the "normal" sandbox

- "Normal" sandbox 
    - the usual luacontroller style sandbox, no ability to yield

Everything in libox is avaliable in the async environment as well, hoewer it hasn't been tested



## Planned
- "Coroutine" sandbox
    - a sandbox that can yield(), allowing it to restore its state the next execution
    - runs every [n] globalsteps (is not run when the "parent node" is unloaded)
    - data is stored *outside* of the node, as it is impossible to serialize a coroutine unless i did some native (aka C) shenanigans, that would require being a trusted mod though
    - the environment gets measured for size each time after it executes, if it exceeds that it halts 
    - low priority
- Tests
    - when i feel like it, don't consider this project usable until i get tests working
    (whenever it be manual or whatever)


License:
    Code:
        - LGPLv3