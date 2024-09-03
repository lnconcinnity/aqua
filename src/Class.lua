local PRIVATE_MARKER = newproxy() -- only the class and inherited class can access it
local PROTECTED_MARKER = newproxy() -- only the class and inherited can read and write; will only be read-only for other sources
local INHERITED_MARKER = newproxy()
local INHERITS_MARKER = newproxy()
local STRICTIFIY_VALUE_MARKER = newproxy()
local INTERNAL_MARKER = newproxy()
local PUBLIC_MARKER = newproxy()
local LOCKED_MARKER = newproxy() -- cant change after runtime fr
local SPECIAL_HANDLER_MARKER = newproxy()

local EXPLICIT_PRIVATE_PREFIX = "_"
local EXPLICIT_PROTECTED_PREFIX = "__"

local READ_PRIVATE_NO_ACCESS = "Attempted to read private \"%s\""
local READ_INTERNAL_FAILED = "Cannot read internal property \"%s\""
local WRITE_PRIVATE_NO_ACCESS = "Attempted to write private \"%s\" with the value \"%s\""
local WRITE_PROTECTED_NO_ACCESS = "Attempted to write protected \"%s\" with the value \"%s\""
local WRITE_INTERNAL_FAILED = "Cannot write internal property \"%s\""
local CANNOT_WRITE_CONSTANT = "Attempted to overwrite constant \"%s\""
local CANNOT_WRITE_LOCKED = "Attempt to overwrite locked property \"%s\""

local CLONE_IGNORE_PROPERTIES = {'new'}
local AUTOLOCK_PROPERTIES = {'__wrapSignal', '__lockProperty', '__unlockProperty', '__strictifyProperty__', '__canStrictifyProperties__', '__canMakeConstants__', '__propChangedSignals__', '__wrapCoroutine', '__wrapTask', '__registerCHandler__'}

local function hasFunction(class, method)
	for _, fn in pairs(class) do
		if type(fn) == "function" and fn == method then
			return true
		end
	end
	return false
end

local function canAccessViaInheritance(class, methodOrClass)
	for inherited in pairs(class[INHERITED_MARKER]) do
		if (type(methodOrClass) == "table" and inherited == methodOrClass) or hasFunction(inherited, methodOrClass) then
			return true
		end
	end
	return false
end


local function isWithinClassScope(class, self, includeInherited)
	local level = 3--skip pcall, debug.info and __index or __newindex
	local within = false
	local calledWithinFunction = false
	while true do
		level += 1
		local _, method = pcall(debug.info, level, 'f')
		local _, methodName = pcall(debug.info, level, 'n')
		if not method then break end

		if hasFunction(class, method) or class[methodName] == method or rawget(self, SPECIAL_HANDLER_MARKER)[method] ~= nil then
			calledWithinFunction = true
		end

		local result = calledWithinFunction or (if includeInherited then canAccessViaInheritance(class, method) else false)
		if result then
			within = true
			break
		end
	end
	return within
end

local function isSpecialKey(key)
	return type(key) == "userdata"
end

local function isAConstant(str: string)
	if isSpecialKey(str) then return false end
	str = str:gsub('_', '') -- remove underscores
	local compare = str:gsub('(%l)', '')
	return #compare == #str
end

local function isAccessingInternal(key)
	return not isSpecialKey(key) and key:sub(1, 2) == EXPLICIT_PROTECTED_PREFIX and key:sub(#key - #EXPLICIT_PROTECTED_PREFIX+1) == EXPLICIT_PROTECTED_PREFIX
end

local function isAccessingProtected(key)
	return not isSpecialKey(key) and key:sub(1, 2) == EXPLICIT_PROTECTED_PREFIX and key:sub(#key - #EXPLICIT_PROTECTED_PREFIX) ~= EXPLICIT_PROTECTED_PREFIX
end

local function isAccessingPrivate(key)
	return not isSpecialKey(key) and key:sub(1, 2) ~= EXPLICIT_PROTECTED_PREFIX and key:sub(#key - #EXPLICIT_PROTECTED_PREFIX) ~= EXPLICIT_PROTECTED_PREFIX and key:sub(1, 1) == EXPLICIT_PRIVATE_PREFIX
end

local function initSelf(class, defaultProps)
	local markers, realProps = {
		[PRIVATE_MARKER] = {},
		[PROTECTED_MARKER] = {},
		[LOCKED_MARKER] = {},
		[INTERNAL_MARKER] = {},
		[STRICTIFIY_VALUE_MARKER] = {},
		[PUBLIC_MARKER] = {},
		[SPECIAL_HANDLER_MARKER] = setmetatable({}, {__mode = 'k'}),
	}, {}

	local function insert(source)
		for key, value in pairs(source) do
			if isSpecialKey(key) then
				markers[key] = value
			else
				if CLONE_IGNORE_PROPERTIES[key] then continue end
				realProps[key] = value
			end
		end
	end

	insert(class)
	if defaultProps then
		insert(defaultProps)
	end

	return markers, realProps
end

local function pasteSelf(self, props)
	for key, value in pairs(props) do
		self[key] = value
	end
end

local function Class(defaultProps: {}?)
	local meta = {}
	local class = {}
	class[INHERITS_MARKER] = {}
	class[INHERITED_MARKER] = {}

	function meta:__index(key)
		local canAccessPrivate, canAccessInternal = isWithinClassScope(class, self, true), isWithinClassScope(class, self, false)
		if isAccessingInternal(key) and not canAccessInternal then
			error(string.format(READ_INTERNAL_FAILED, key), 2)
		elseif isAccessingPrivate(key) and not canAccessPrivate then
			error(string.format(READ_PRIVATE_NO_ACCESS, key), 2)
		end

		local public = rawget(self, PUBLIC_MARKER)
		local protected = rawget(self, PROTECTED_MARKER)
		local result = protected[key] or public[key]
		if canAccessPrivate or canAccessInternal then
			local foundInternal = rawget(self, INTERNAL_MARKER)[key]
			if foundInternal ~= nil then return foundInternal end
			local foundPrivate = rawget(self, PRIVATE_MARKER)[key]
			if foundPrivate ~= nil then return foundPrivate end
		end
		return result
	end

	function meta:__newindex(key, value)
		local accessingPrivate, accessingProtected, accessingLocked, accessingInternal = isAccessingPrivate(key), isAccessingProtected(key), rawget(self, LOCKED_MARKER)[key:sub(2)] ~= nil, isAccessingInternal(key)
		if accessingLocked then
			error(string.format(
				if isAConstant(key) then CANNOT_WRITE_CONSTANT else CANNOT_WRITE_LOCKED,
				key), 2)
		elseif accessingInternal and not isWithinClassScope(class, self, false) then
			error(string.format(WRITE_INTERNAL_FAILED, key), 2)
		elseif (accessingPrivate or accessingProtected) and not isWithinClassScope(class, self, true) then
			error(string.format(
				if accessingPrivate then WRITE_PRIVATE_NO_ACCESS else WRITE_PROTECTED_NO_ACCESS,
				tostring(key), tostring(value)), 2)
		else
			local internal, private, protected, public = rawget(self, INTERNAL_MARKER),
			rawget(self, PRIVATE_MARKER),
			rawget(self, PROTECTED_MARKER),
			rawget(self, PUBLIC_MARKER)
	
			local oldValue = internal[key] or private[key] or protected[key] or public[key]
			if oldValue == value then
				return
			end

			local predicate = rawget(self, STRICTIFIY_VALUE_MARKER)[key]
			if predicate ~= nil then
				local ok, err = predicate(value)
				if not ok then
					error(err or "Failed to set strict property", 2)
				end
			end

			if isAConstant(key) and not rawget(self, INTERNAL_MARKER).__canMakeConstants__ then
				error("Cannot initialize constant '" .. key .. "' after initialization", 2)
			end

			if accessingInternal then
				internal[key] = value
			elseif accessingPrivate then
				private[key] = value
			elseif accessingProtected then
				protected[key] = value
			else
				if key == PROTECTED_MARKER or key == PRIVATE_MARKER then
					error("Cannot override internal properties", 2)
				end
				public[key] = value
			end

			local sigContainer = rawget(self, '__propChangedSignals__')
			if sigContainer then
				local foundChangedSignal = sigContainer[key] :: BindableEvent | nil
				if foundChangedSignal then
					foundChangedSignal:Fire(value, oldValue)
				end
			end
		end
	end

	function class.new(...)
		local markers, realProps = initSelf(class, defaultProps)
		local self = setmetatable(markers, meta)
		self.__canMakeConstants__ = true
		self.__canStrictifyProperties__ = true
		self.__propChangedSignals__ = {}

		pasteSelf(self, realProps)
		if self.__init then
			self:__init(...)
		end

		-- now check the constants
		for key, value in pairs(self) do
			if isAConstant(key) and type(value) ~= "function" then
				self[LOCKED_MARKER][key] = true
				if type(value) == "table" then
					table.freeze(value)
				end
			end
		end

		self.__canMakeConstants__ = false
		self.__canStrictifyProperties__ = false
		
		for _, key in next, AUTOLOCK_PROPERTIES do
			self:__lockProperty(key)
		end

		return self
	end

	function class.inherits(otherClass)
		assert(otherClass[INHERITED_MARKER] ~= nil, "Cannot inherit from an unrelated class or table")
		class[INHERITS_MARKER][otherClass] = true
		otherClass[INHERITED_MARKER][class] = true
	end

	function class.extend()
		local subClass = Class()
		setmetatable(subClass, {__index = class})
		return subClass
	end

	function class:OnPropertyChanged(propName: string, handler: (...any) -> ()): RBXScriptConnection
		local signal = self.__propSignals__[propName]
		if not signal then
			signal = Instance.new("BindableEvent")
			signal.Name = propName
			self.__propSignals__[propName] = signal
		end
		local conn = self:__wrapSignal(signal.Event, handler)
		return conn
	end
	
	function class:__strictifyProperty__(propName: string, predicate: (value: any) -> boolean)
		assert(self.__canStrictifyProperties__ == true, "Cannot strictify properties after initialization")
		self[STRICTIFIY_VALUE_MARKER][propName] = predicate
	end

	function class:__registerSpecialHandler__(handler)
		self[SPECIAL_HANDLER_MARKER][handler] = true
		return handler
	end
	
	function class:__wrapSignal(signal, handler)
		return signal:Connect(self:__registerSpecialHandler__(handler))
	end
	
	function class:__wrapCoroutine(coroutine, handler)
		return coroutine(self:__registerSpecialHandler__(handler))
	end
	
	function class:__wrapTask(task, handler)
		return task(self:__registerSpecialHandler__(handler))
	end

	function class:__lockProperty(propName: string)
		self[LOCKED_MARKER][propName] = true
	end

	function class:__unlockProperty(propName: string)
		assert(not isAConstant(propName), "Cannot unlock a constant!")
		self[LOCKED_MARKER][propName] = nil
	end

	return class
end

return Class