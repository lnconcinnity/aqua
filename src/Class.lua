local PRIVATE_MARKER = newproxy() -- only the class and inherited class can access it
local PROTECTED_MARKER = newproxy() -- only the class and inherited can read and write; will only be read-only for other sources
local INHERITED_MARKER = newproxy()
local INHERITS_MARKER = newproxy()

local EXPLICIT_PRIVATE_PREFIX = "_"
local EXPLICIT_PROTECTED_PREFIX = "__"

local READ_PRIVATE_NO_ACCESS = "Attempted to read private \"%s\""
local WRITE_PRIVATE_NO_ACCESS = "Attempted to write private \"%s\" with the value \"%s\""
local WRITE_PROTECTED_NO_ACCESS = "Attempted to write protected \"%s\" with the value \"%s\""

local EMPTY_STRING = ''

local function canAccessViaInheritance(class)
	for inherited in pairs(class[INHERITED_MARKER]) do
		if inherited[INHERITS_MARKER][class] then
			return true
		end
	end
	return false
end

local function isWithinClassScope(class)
	local level = 1--skip  __index
	local within = false
	local calledWithinFunction = false
	while true do
		level += 1
		local method = debug.info(level, 'f')
		local _, fnName = pcall(debug.info, method, 'n') -- anonymous and c-functions will return nil and prolly error?
		if fnName == EMPTY_STRING then
			break
		end
		
		if class[fnName] ~= nil then
			calledWithinFunction = true
		end
		local result = (class[fnName] == method or calledWithinFunction) or canAccessViaInheritance(class)
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

local function isAccessingProtected(key)
	return not isSpecialKey(key) and key:sub(1, 2) == EXPLICIT_PROTECTED_PREFIX
end

local function isAccessingPrivate(key)
	return not isSpecialKey(key) and key:sub(1, 2) ~= EXPLICIT_PROTECTED_PREFIX and key:sub(1, 1) == EXPLICIT_PRIVATE_PREFIX
end

local function Class(defaultProps: {}?)
	local meta = {}
	local class = {}
	class[INHERITS_MARKER] = {}
	class[INHERITED_MARKER] = {}
	
	function meta:__index(key)
		local inScope = isWithinClassScope(class)
		if isAccessingPrivate(key) and not inScope then
			error(string.format(READ_PRIVATE_NO_ACCESS, key), 2)
		end

		local public = rawget(self, key)
		local protected = rawget(self, PROTECTED_MARKER)
		if inScope then
			-- we can access private variables
			local privates = rawget(self, PRIVATE_MARKER)
			return privates[key] or protected[key] or public or class[key]
		end
		return protected[key] or public or class[key]
	end

	function meta:__newindex(key, value)
		local accessingPrivate, accessingProtected = isAccessingPrivate(key), isAccessingProtected(key)
		if (accessingPrivate or accessingProtected) and not isWithinClassScope(class) then
			error(string.format(
				if accessingPrivate then WRITE_PRIVATE_NO_ACCESS else WRITE_PROTECTED_NO_ACCESS,
				tostring(key), tostring(value)), 2)
		elseif accessingPrivate then
			rawget(self, PRIVATE_MARKER)[key] = value
		elseif accessingProtected then
			rawget(self, PROTECTED_MARKER)[key] = value
		else
			if key == PROTECTED_MARKER or key == PRIVATE_MARKER then
				error("Cannot override internal properties", 3)
			end
			rawset(self, key, value)
		end
	end

	function class.new(...)
		local source = if type(defaultProps) == "table" then table.clone(defaultProps) else {}
		source[PRIVATE_MARKER] = {}
		source[PROTECTED_MARKER] = {}
		local self = setmetatable(source, meta)
		if self.__init then
			self:__init(...)
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

	return class
end

return Class