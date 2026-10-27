local RemoteGuard = {}

function RemoteGuard.String(MinLength: number?, MaxLength: number?): (any) -> boolean
	local Minimum = MinLength or 0
	local Maximum = MaxLength or math.huge
	assert(Minimum >= 0 and Maximum >= Minimum, "Invalid string length range")
	return function(Value)
		return type(Value) == "string" and #Value >= Minimum and #Value <= Maximum
	end
end

function RemoteGuard.Number(Minimum: number?, Maximum: number?): (any) -> boolean
	local Low = Minimum or -math.huge
	local High = Maximum or math.huge
	assert(Low <= High, "Invalid number range")
	return function(Value)
		return type(Value) == "number" and Value == Value and Value > -math.huge and Value < math.huge and Value >= Low and Value <= High
	end
end

function RemoteGuard.Boolean(): (any) -> boolean
	return function(Value)
		return type(Value) == "boolean"
	end
end

function RemoteGuard.Instance(ClassName: string?, Ancestor: Instance?): (any) -> boolean
	return function(Value)
		return typeof(Value) == "Instance"
			and (ClassName == nil or Value:IsA(ClassName))
			and (Ancestor == nil or Value:IsDescendantOf(Ancestor))
	end
end

function RemoteGuard.Optional(Validator: (any) -> boolean): (any) -> boolean
	assert(type(Validator) == "function", "Validator must be a function")
	return function(Value)
		return Value == nil or Validator(Value)
	end
end

function RemoteGuard.Check(Validators: { (any) -> boolean }, ...): boolean
	assert(type(Validators) == "table", "Validators must be a table")
	local Arguments = table.pack(...)
	if Arguments.n ~= #Validators then
		return false
	end
	for Index, Validator in ipairs(Validators) do
		if type(Validator) ~= "function" then
			return false
		end
		local Success, Valid = pcall(Validator, Arguments[Index])
		if not Success or Valid ~= true then
			return false
		end
	end
	return true
end

function RemoteGuard.Wrap(Validators: { (any) -> boolean }, Handler: (Player, ...any) -> ...any, Authorize: ((Player, ...any) -> boolean)?)
	assert(type(Handler) == "function", "Handler must be a function")
	assert(Authorize == nil or type(Authorize) == "function", "Authorize must be a function")
	return function(Player: Player, ...)
		if not RemoteGuard.Check(Validators, ...) then
			return nil, "Invalid arguments"
		end
		if Authorize and not Authorize(Player, ...) then
			return nil, "Not allowed"
		end
		return Handler(Player, ...)
	end
end

return RemoteGuard
