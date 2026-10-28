local Time = {}

local Units = {
	{ 31536000, "year" },
	{ 2592000, "month" },
	{ 86400, "day" },
	{ 3600, "hour" },
	{ 60, "minute" },
	{ 1, "second" },
}

function Time.FormatTimestamp(Timestamp: number, Format: string?, UseLocalTime: boolean?): string
	assert(type(Timestamp) == "number" and Timestamp > -math.huge and Timestamp < math.huge, "Timestamp must be a finite number")
	local Date = DateTime.fromUnixTimestamp(Timestamp)
	local Pattern = Format or "YYYY-MM-DD HH:mm:ss"
	if UseLocalTime then
		return Date:FormatLocalTime(Pattern, "en-us")
	end
	return Date:FormatUniversalTime(Pattern, "en-us")
end

function Time.FromUTC(Year: number, Month: number, Day: number, Hour: number?, Minute: number?, Second: number?): number
	return DateTime.fromUniversalTime(Year, Month, Day, Hour or 0, Minute or 0, Second or 0).UnixTimestamp
end

function Time.FormatDuration(Seconds: number): string
	assert(type(Seconds) == "number" and Seconds >= 0 and Seconds < math.huge, "Seconds must be a finite non-negative number")
	local Whole = math.floor(Seconds)
	local Hours = math.floor(Whole / 3600)
	local Minutes = math.floor(Whole % 3600 / 60)
	local Remaining = Whole % 60
	if Hours > 0 then
		return string.format("%d:%02d:%02d", Hours, Minutes, Remaining)
	end
	return string.format("%d:%02d", Minutes, Remaining)
end

function Time.Relative(Timestamp: number, Now: number?): string
	assert(type(Timestamp) == "number" and Timestamp > -math.huge and Timestamp < math.huge, "Timestamp must be a finite number")
	assert(Now == nil or (type(Now) == "number" and Now > -math.huge and Now < math.huge), "Now must be a finite number")
	local Difference = (Now or DateTime.now().UnixTimestamp) - Timestamp
	local Absolute = math.abs(Difference)
	if Absolute < 1 then
		return "just now"
	end
	for _, Unit in ipairs(Units) do
		local Duration = Unit[1] :: number
		if Absolute >= Duration then
			local Count = math.floor(Absolute / Duration)
			local Label = Unit[2] :: string
			local Phrase = tostring(Count) .. " " .. Label .. (if Count == 1 then "" else "s")
			return if Difference >= 0 then Phrase .. " ago" else "in " .. Phrase
		end
	end
	return "just now"
end

return Time
