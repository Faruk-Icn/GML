local Math = {}

function Math.Round(Value: number, DecimalPlaces: number?): number
	local Factor = 10 ^ (DecimalPlaces or 0)
	local Scaled = Value * Factor
	if Scaled < 0 then
		return -math.floor(-Scaled + 0.5) / Factor
	end
	return math.floor(Scaled + 0.5) / Factor
end

function Math.Map(Value: number, InputMin: number, InputMax: number, OutputMin: number, OutputMax: number): number
	assert(InputMin ~= InputMax, "Input range must have a non-zero width")
	return OutputMin + (Value - InputMin) / (InputMax - InputMin) * (OutputMax - OutputMin)
end

function Math.Lerp(Start: number, Finish: number, Alpha: number): number
	return Start + (Finish - Start) * Alpha
end

function Math.Clamp01(Value: number): number
	return math.clamp(Value, 0, 1)
end

return Math
