# Introduction
A heavily modified version of sleitnick's [Knit](https://sleitnick.github.io/Knit/)

Unlike Knit, here you can dynamically create `Pots` (the equivalent of Knit's `Controllers`) in the client even after the initial startup and have the option to terminate said `Pot` with `Aqua.TerminatePot()` or `Aqua.Drought`.

`Hosts` however, cannot be dynamically be created since it has to handle client-server and server-client interactions.

Aqua is paired with my `Class` module, where it grants the ability to make private and protected properties.
Class, as mentioned, can also be used for other purposes like making vanilla classes themselves.

***

## Aqua
Both `Hosts` and `Pots` inherit the capabilities of a `Class` object.

### **Host**

### **Pot**
A `Pot` is a client-sided `Controller` which can be terminated even after `Aqua.Hydrate()` is ran, other than that, `Pots` are similar to Knit's `Controllers`, with the only difference is being a `Class` object instead of a `table` and having some parts being sugarcoated.

### API
| method | params |
| :---: | :--- |
| `Pot:__init()` | N/A |
| `Pot:__start()` | N/A |
| `Pot:__terminate()` | N/A |
| `Pot:__regSched(sched)` | `sched: AquaScheduler` |

### **Host**
A `Host` is basically the same as Knit's `Service`, with no difference (other than being a `Class` object too).

***

## Aqua Scheduler
Aqua Scheduler is an internal property that both `Pots` and `Hosts` possess (known as `_scheduler`).  
This basically sugarcoats `RunService.RenderStepped`, `RunService:BindToRenderStep()`, `RunService.Stepped` and `RunService.Heartbeat` and will automatically clean itself when `self._scheduler:cleanup()` is called.

### API
| method | params |
| :---: | :--- |
| `scheduler:onRenderStepped(fn, overridePriority)` | `fn: (dt: number) -> (), overridePriority: number?` |
| `scheduler:onStepped(fn)` | `fn: (dt: number) -> ()` |
| `scheduler:onHeartbeat(fn)` | `fn: (dt: number) -> ()` |
| `scheduler:cleanup(fn)` | `fn: (dt: number) -> ()` |

<sub>Note: The parameter `overridePriority` is associated with the default `RenderPriorityValue` when making a `Pot`, having either of those given will connect `fn` to `RunService:BindToRenderStep()` instead of `RunService.RenderStepped`</sub>

***

## Class
To use the `Class` module, all you have to do is to require the said module and you're done, the module returns a `function` with the optional parameter `defaultProps` where you can create constants before the module calls `class:__init()`

### **Internal, Private and Protected properties**
Protected properties can be read by all sources, however, said sources other than the class itself, may it be a script, a seperate class object or such, cannot write, override or change the property in detail. To initialize a protected property, simply add in two underscores ( `_` ) before the property's name, ie: `self.__protected`.  

To create a private property on the other hand, simply add in one underscore ( `_` ) instead of two, ie: `self._private`. Private properties can only be accessed by the class itself, with no exceptions and will raise an error if so; unless the external source is an inherited class by calling `class.inherits(otherClass)`.

Internal properties are quite special, because, other than the source class itself, cannot access it; read or write, not even inherited properties. Internal properties are made by adding two underscores ( `_` ) before and after the property's name, ie: `self.__internal__`.

### **Constants**
Every properties can be locked or unlocked, simply do `self:__lockProperty(propName)` or `self:__unlockProperty(propName)`. Locked properties cannot be changed after after it was locked or set as a constant, however, if it's not initialized as a constant, we can call `self:__unlockProperty(propName)` prior it is being written.

To make a constant property, convert all `lowercase` characters to `UPPERCASE` instead (Underscores are ignored).

Constants are basically locked properties but cannot be unlocked in any way.  

### **Strict properties**
Strict properties are properties that must meet a certain condition before being assigned with a new value. For example, if we want property `X` to only accept players, we simply have to call `self:__strictifyProperty(propName, predicate)` and assign a predicate.

An example demonstration is provided below:
```lua
local class = Class()
function class:__init()
    self.X = 2
    self:__strictifyProperty('X', function(value)
        return type(value) == "number" -- we only expect numbers
    end)
    self.X = 10 -- ok
    self.X = "test" -- uh oh error!
end
-- main code
```

### ***Example Class***
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
```
### ***Inheritance***
```lua
local Class = require(path.to.class)

local classObject = Class()
function classObject:__init()
    self._message = "I can only be accessed by myself and my successors"
    self.__secret__ = "fun fact, i have no successors"
end

local class = classObject.new()

local successor = Class()
successor.inherits(classObject)
function successor:__init()
    print(class._message) -- prints
    print(class.__secret__) -- error
end

successor.new()
```