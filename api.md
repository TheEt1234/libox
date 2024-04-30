# Api docs

## Disclaimers
- Currently i cannot guarrantee safety of this library, tests are extremely insufficent
- ***DO NOT EVER CALL FUNCTIONS FROM THE ENVIRONMENT (once the environment is defined) AND DO NOT CALL ANY FUNCTIONS RETURNED BY THE SANDBOX*** that will just bypass the debug hook and allow someone to `repeat until false` and *stop* the server that way
- anything coming out of the sandbox should *not* be called, and be checked for every single detail (like you are writing a digiline device)

## Definitions
- microsecond: milisecond * 1000
- hook: a lua function that runs every `n` instructions
- environment: The values that the sandboxed code can work with
- string sandbox: when the `__index` field of a string's metatable gets replaced with the sandboxes `string` (basically, a thing to prevent the sandbox from using unsafe string functions through `"":unsafe_function()`) 

## Utilities
`libox.get_default_hook(max_time)` - Get the hook function that will terminate the program in `max_time` microseconds

`libox.traceback(...) -- directly taken from the async_controller mod` - a function that gives a more useful traceback (by simplifying paths and more:tm:)

`libox.digiline_sanitize(input, allow_functions, wrap)` - use this instead of your own clean_and_weigh_digiline_message implementation, `wrap` is a function that accepts a function and returns another one, this gets called on user functions

`libox.sandbox_lib_f(f, ...)` - use this if you want to escape the string sandbox (do this if you are not 100% sure that your code is free of `"":this_stuff()`) **don't use this on functions that run user functions**

## Environment
`libox.create_basic_environment()` - get a basic secure environment already set up for you

`libox.safe.*` - safe functions/classes, used in libox.create_basic_environment, used internally, you shouldn't modify this table

## "Normal" sandbox

`libox.normal_sandbox(def)`
- A sandbox that executes lua code securely based on parameters in `def` (table)

`def.code` - the code...

`def.env` - The environment of the function

`def.error_handler` - A function inside the `xpcall`, by default `libox.traceback`

`def.in_hook` - The hook function, by default `libox.get_default_hook(def.max_time)`

`def.max_time` - Maximum allowed execution time, in microseconds, only used if `def.in_hook` was not defined

`def.hook_time` - The hook function will execute every `def.hook_time` instructions

## "Coroutine" sandbox
- Optionally requires trusted environment for weighing local variables and upvalues
    - without it someone can overfill your memory, but libox has protections against that somewhat

### What is it?
A sandbox that allows the user to **yield** => temporarily stop execution; then be able to resume from that point


### garbage collection
`libox.coroutine.settings`
- memory_treshold: in gigabytes, if lua's memory reaches above this limit, the hook will error, the user is meant to configure this to their needs
- gc settings:
    - time_treshold: if a sandbox has been untouched for this long, collect it, in seconds
    - number_of_sandboxes: the garbage collection will trigger if the number of stored sandboxes is above this limit
    - auto: if true, garbage collection will automatically activate, i don't think this is nessesary if you have trusted the libox mod 
    - interval: in seconds, when to trigger the garbage collection

All of theese are configurable by the user

`libox.coroutine.garbage_collect()` - trigger the garbage collection

### the docs
- When libox is a trusted mod, it exposes `debug.getlocal` and `debug.getupvalue`

`libox.coroutine.active_sandboxes` - A table containing all the active sandboxes, where the key is the sandbox's id, and the value is the sandbox definition and thread

`libox.coroutine.create_sandbox(def)`
- returns an ID to the sandbox (can be used in libox.coroutine.* functions or just be able to see the sandbox yourself with `libox.coroutine.active_sandboxes[id]`)

- `def.ID` - A custom id, by default random text
- `def.code` - the code
- `def.is_garbage_collected` - if this sandbox should be garbage collected, by default true
- `def.env` - the environment, by default a blank table
- `def.in_hook` - the function that runs in the hook, by default `libox.coroutine.get_default_hook(def.time_limit or 3000)`
- `def.time_limit` - used if debug.in_hook is not avaliable, by default 3000
- `last_ran` - not set by you, but is the last time the sandbox was ran, used for garbage collection
- `def.hook_time` - The hook function will execute every `def.hook_time` instructions, by default 10
- `def.size_limit` - in *bytes*, the size limit of the sandbox, if trusted then upvalues and local variables are counted in too, by default 5 *megabytes*, aka `1024*1024*5` bytes

`libox.coroutine.delete_sandbox(id)` - delete a sandbox by its id, equivilent to `libox.coroutine.active_sandboxes[id] = nil`

`libox.coroutine.run_sandbox(ID, value_passed)`
- `value_passed` - the value passed to the coroutine.resume function, so that in the sandbox it could: `local vals = coroutine.yield("blabla")`
- Returns ok, errmsg

`libox.coroutine.size_check(env, lim, thread)`
- `env` - environment of the thread
- `lim` - the limit
- `thread` - the thread
- returns if its size (computed using `get_size`) is less than the lim
- used internally

`libox.coroutine.get_size(env, seen, thread, recursed)` 
- get the size in bytes of a thread, used by size_check
- normal usage: `libox.coroutine.get_size(env, {}, thread, false)`


# Async
- everything else other than the coroutine sandbox is avaliable in both sync and async environments
- coroutine sandbox is not avaliable in async because 
1) I cannot import the debug.getlocal and debug.getupvalue functions into the async environment
2) I cannot import a coroutine in the async environment

# Todos
- proper testing
 - Verify performance
 - Verify security
- proper examples
- Maybe automatic yielding? depends on how possible that is
- Rewrite README.md