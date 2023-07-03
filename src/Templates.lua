local function makeRegisterNet(class)
    assert(getmetatable(class) == nil, "Cannot append with makeRegisterNet() to a class object")
    function class:__registerNet(networkObject)
        class._networkObject = networkObject
    end
end

local function makeRegisterScheulder(class)
    assert(getmetatable(class) == nil, "Cannot append with makeRegisterScheulder() to a class object")
    function class:__registerNet(scheulder)
        class._scheulder = scheulder
    end
end

return {
    regNet = makeRegisterNet,
    regSched = makeRegisterScheulder
}