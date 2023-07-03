# Aqua
A heavily modified version of sleitnick's [Knit](https://sleitnick.github.io/Knit/)

Unlike Knit, here you can dynamically create `Pots` (the equivalent of Knit's `Controllers`) in the client even after the initial startup and have the option to terminate said `Pot` with `Aqua.TerminatePot()` or `Aqua.Drought`.

`Hosts` however, cannot be dynamically be created since it has to handle client-server and server-client interactions.

Aqua is paired with my `Class` module, where it grants private and protected properties.
Class, as mentioned, can also be used for other purposes like making vanilla classes themselves.

To use the `Class` module, all you have to do is to require the said module and you're done, the module returns a `function` with the optional parameter `defaultProps` where you can create constants before the module calls `class:__init()`

To make a protected property, simply add in two underscores ( `_` ) before the 
property's name, protected properties can be read by all sources however every other sources, may it be a script, a seperate class object or such cannot write, override or change the property in detail.
To make a private property, simply add in one underscore instead of two. To make a constant property, convert all lowercase characters to uppercase instead.

Example Class
```lua
local Class = require(path.to.class)

local classObject = Class({
    CONSTANT_MESSAGE = "Bye"
    publicMessage = "Hi"
    _privateMessage = "Secret",
    __protectedMessage = "Hello?"
})

function classObject:init()
    print(self.CONSTANT_MESSAGE, self.publicMessage, self._privateMessage, self.__protectedMessage)
    -- Bye, Hi, Secret, Hello?
end

function classObject:setProtected(msg)
    self.__protectedMessage = msg
end

function classObject:changeConstant(msg)
    self.CONSTANT_MESSAGE = msg -- errors
end

local class = classObject.new()

print(class.__protectedMessage) -- "Hello?"
class.__protectedMessage = "Hi!" -- errors
-- class:setProtected("Hi!") -- success
print(class.__protectedMessage)

print(class._privateMessage) -- errors

class:changeConstant("Never mind!") -- error
print(class.CONSTANT_MESSAGE)