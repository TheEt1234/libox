# Libox
# DO NOT CONSIDER THIS PROJECT SECURE CURRENTLY

A minetest lua sandboxing library

Offers mainly some very useful sandbox utilities and the "normal" sandbox

- "Normal" sandbox 
    - the usual luacontroller style sandbox, no ability to yield

Everything in libox is avaliable in the async environment as well, hoewer it hasn't been tested

It also offers the "coroutine" sandbox
## "Coroutine" sandbox
- An example of a (VERY INSECURE, also i think its the like... ONLY example?) coroutine sandbox can be found at https://github.com/loosewheel/lwcomputers 
- it is a sandbox that can use coroutine.yield(), allowing it to restore its state the next execution
- The coroutine is impossible to serialize, so we store it outside of nodes and don't let other mods handle the storage of sandboxes
- Hoewer mods can still index a sandbox by its ID (usually a short random string)
- the environment gets measured for size (EVERYTHING, even local variables, and upvalues, and upvalue's upvalues) each time after it executes, if it exceeds that it halts
- requires debug.getlocal and debug.getupvalue, thus libox needs to be trusted for this to be secure (i could go the "screw it i will just ban the word local" but i am not that type of person....)
- Cannot work in extremely complex environments (completely fails to measure `_G`, or `minetest` (they return `stack overflow`) but it serializes `minetest.registered_nodes`, taking it ~10 miliseconds, returning the size of ~2 megabytes, with mods nothing but mtg, for context digiline_sanitize returned only `21 902` bytes )

## Planned
- Improvements to the coroutine sandbox, and a proof of concept mod using them

- Tests
    - when i feel like it, don't consider this project usable until i get tests working
    (whenever it be manual or whatever)


License:
    Code:
        - LGPLv3