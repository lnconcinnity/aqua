local function makeRegisterNet(class)
    assert(getmetatable(class) == nil, "Cannot append with makeRegisterNet() to a class object")
    function class:__registerNet(networkObject)
        class._networkObject = networkObject
    end
end

local function makeRegisterScheduler(class)
    assert(getmetatable(class) == nil, "Cannot append with makeRegisterScheduler() to a class object")
    function class:__registerNet(_scheduler)
        class._scheduler = _scheduler
    end
end

local function makeCleanInternal(class)
    function class:__cleanInternal()
        if self._scheduler then
            self._scheduler:cleanup()
            self._scheduler = nil
        end
    end
end

return {
    regNet = makeRegisterNet,
    regSched = makeRegisterScheduler,
    cleanInternal = makeCleanInternal,
}