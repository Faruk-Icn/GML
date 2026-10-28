local Number = {}

local Suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local Multipliers = {}

for Index, Suffix in ipairs(Suffixes) do
	Multipliers[Suffix] = 1000 ^ (Index - 1)
end

function Number.Abbreviate(Value: number, DecimalPlaces: number?): string
	assert(type(Value) == "number" and Value > -math.huge and Value < math.huge, "Value must be a finite number")
	local Places = math.clamp(math.floor(DecimalPlaces or 1), 0, 6)
	local Absolute = math.abs(Value)
	local Index = 1
	while Absolute >= 1000 and Index < #Suffixes do
		Absolute /= 1000
		Index += 1
	end
	local Rounded = tonumber(string.format("%." .. Places .. "f", Absolute)) :: number
	if Rounded >= 1000 and Index < #Suffixes then
		Absolute = Rounded / 1000
		Index += 1
	end
	local Sign = if Value < 0 then "-" else ""
	return Sign .. string.format("%." .. Places .. "f", Absolute) .. Suffixes[Index]
end

function Number.ParseAbbreviated(Text: string): number?
	if type(Text) ~= "string" then
		return nil
	end
	local Numeric, Suffix = string.match(Text, "^%s*([+-]?%d*%.?%d+)%s*([%a]*)%s*$")
	if not Numeric then
		return nil
	end
	local Multiplier = Multipliers[Suffix]
	if not Multiplier then
		return nil
	end
	return tonumber(Numeric) * Multiplier
end

function Number.Commas(Value: number, DecimalPlaces: number?): string
	assert(type(Value) == "number" and Value > -math.huge and Value < math.huge, "Value must be a finite number")
	local Places = math.clamp(math.floor(DecimalPlaces or 0), 0, 6)
	local Formatted = string.format("%." .. Places .. "f", math.abs(Value))
	local Integer, Fraction = string.match(Formatted, "^(%d+)(.*)$")
	local Result = (Integer :: string):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(Result, 1, 1) == "," then
		Result = string.sub(Result, 2)
	end
	return (if Value < 0 then "-" else "") .. Result .. (Fraction :: string)
end

return Number
