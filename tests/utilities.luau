local Number = require("../src/GMLK/Number")
local Time = require("../src/GMLK/Time")
local RemoteGuard = require("../src/GMLK/RemoteGuard")

assert(Number.Abbreviate(1250000, 2) == "1.25M")
assert(Number.Abbreviate(-1500, 1) == "-1.5K")
assert(Number.ParseAbbreviated("1.25M") == 1250000)
assert(Number.ParseAbbreviated("not a number") == nil)
assert(Number.Commas(1234567) == "1,234,567")
assert(not pcall(Number.Abbreviate, math.huge))

assert(Time.FormatDuration(3672) == "1:01:12")
assert(Time.Relative(100, 160) == "1 minute ago")
assert(Time.Relative(160, 100) == "in 1 minute")
assert(not pcall(Time.FormatDuration, -1))

local Handler = RemoteGuard.Wrap({ RemoteGuard.Number(1, 1) }, function(_, Amount)
	return Amount + 1
end)

assert(Handler({}, 1) == 2)
local Invalid, Reason = Handler({}, 2)
assert(Invalid == nil and Reason == "Invalid arguments")

print("Utility checks passed")
