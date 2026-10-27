# GML

GML is an open source Luau framework for loading Roblox modules through `Init` and `Start` hooks. It also includes number, timestamp, duration, math, table, signal, remote, cleanup, state, pooling, timer, attribute, random, and tween utilities.

## Layout

| Roblox location | Purpose |
| --- | --- |
| `ReplicatedStorage.Modules.Library.GML` | Main ModuleScript and its utility ModuleScript children |
| `ReplicatedStorage.Modules.Client` | Client modules loaded by the client script |
| `ServerStorage.Modules.Client` | Server modules loaded by the server script |
| `StarterPlayer.StarterPlayerScripts.GMLClient` | The single client bootstrap script |
| `ServerScriptService.GMLServer` | The single server bootstrap script |

The server folder is named `Client` to match the requested path. Its contents run only on the server because they live in `ServerStorage`.

## Install

Clone this repository and sync `default.project.json` with [Rojo](https://rojo.space/). The project file creates the folders and places the two bootstrap scripts automatically. You can also copy the files into Roblox Studio by hand using the layout above. When copying by hand, make `src/GML/init.luau` the source of the `GML` ModuleScript and put the other files in `src/GML` beneath it as ModuleScript children.

Place your client ModuleScripts under `ReplicatedStorage.Modules.Client` and your server ModuleScripts under `ServerStorage.Modules.Client`. Both bootstrap scripts search descendants, so nested folders are supported. Each bootstrap runs once per client or server session.

## Lifecycle modules

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GML = require(ReplicatedStorage.Modules.Library.GML)

local Coins = { Priority = 10 }

function Coins:Init()
	self.Amount = 0
	self.Changed = GML.Signal.New()
end

function Coins:Start()
	self.Amount += 1000
	self.Changed:Fire(self.Amount)
	print(GML.Number.Abbreviate(self.Amount))
end

return Coins
```

Put this ModuleScript in either module folder. Lower `Priority` values run first; the default is `100`. GML requires all modules, calls every `Init` in priority order, then calls every `Start` in priority order. Equal priorities are ordered by full Roblox path. Errors are written with `warn` and stored in `Loader.Errors`; other modules continue loading. Loading the same ModuleScript again with the same loader skips it.

To use a loader manually:

```luau
local GML = require(game:GetService("ReplicatedStorage").Modules.Library.GML)
local Loader = GML.New("Extra")
Loader:LoadModules(workspace.ExtraModules, { IncludeDescendants = true, Debug = true })

local Coins = Loader:GetModuleByName("Coins")
local Exact = Loader:GetModule(workspace.ExtraModules.Coins:GetFullName())
print(Loader.IsLoaded, #Loader.Errors, Coins, Exact)
```

`GetModuleByName` returns the first matching name. Use `GetModule` with a full path when names repeat.

## Utilities

All utility modules are children of `GML` and are available directly from the main module.

```luau
local GML = require(game:GetService("ReplicatedStorage").Modules.Library.GML)

print(GML.Number.Abbreviate(1250000))
print(GML.Number.Abbreviate(1250000, 2))
print(GML.Number.ParseAbbreviated("1.25M"))
print(GML.Number.Commas(1250000))

local Timestamp = GML.Time.FromUTC(2026, 10, 27, 12, 30)
print(GML.Time.FormatTimestamp(Timestamp))
print(GML.Time.FormatTimestamp(Timestamp, "YYYY-MM-DD", true))
print(GML.Time.Relative(Timestamp))
print(GML.Time.FormatDuration(3672))

print(GML.Math.Round(3.14159, 2))
print(GML.Math.Map(50, 0, 100, 0, 1))
print(GML.Math.Lerp(0, 10, 0.25))
print(GML.Math.Clamp01(1.5))

local Copy = GML.Table.DeepCopy({ Stats = { Coins = 10 } })
local Combined = GML.Table.Merge(Copy, { Stats = { Level = 2 } })
print(GML.Table.Count(Combined.Stats))

local Changed = GML.Signal.New()
local Connection = Changed:Connect(function(Value)
	print(Value)
end)
Changed:Once(function(Value)
	print("First change:", Value)
end)
Changed:Fire(10)
Connection:Disconnect()
Changed:Destroy()
```

### Rate limiting

`GML.RateLimiter` can bind directly to a `RemoteEvent`, `UnreliableRemoteEvent`, or `RemoteFunction` on the server. It gives each player an independent token bucket, checks the limit before calling your handler, and clears that player's bucket when they leave. Create your remotes under `ReplicatedStorage.Remotes`, then bind them from a server ModuleScript or Script.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GML = require(ReplicatedStorage.Modules.Library.GML)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PurchaseLimit = GML.RateLimiter.New(5, 10)
local PurchaseBinding = PurchaseLimit:BindEvent(Remotes:WaitForChild("Purchase"), function(Player, ItemId)
	print(Player.Name, ItemId)
end, function(Player, RetryAfter)
	warn(Player.Name, "can retry in", RetryAfter, "seconds")
end)

local QuoteLimit = GML.RateLimiter.New(2, 5)
local QuoteBinding = QuoteLimit:BindFunction(Remotes:WaitForChild("GetQuote"), function(Player, ItemId)
	return { ItemId = ItemId, Price = 100 }
end)
```

`BindEvent(remote, handler, rejected?)` drops calls over the limit and optionally calls `rejected(player, retryAfter)`. Other `OnServerEvent` listeners on that remote still run, so put the protected action inside the bound handler. `BindFunction(remote, handler)` returns `nil, retryAfter` to the invoking client when blocked. It assigns `OnServerInvoke`, replacing any handler previously assigned outside GML; do not assign another handler while the binding is active. Both methods return a binding with `:Disconnect()` to remove the remote handler and player cleanup listener. Use a separate limiter instance for each remote if each action should have its own budget.

`New(capacity, windowSeconds)` requires a positive integer capacity and a positive window in seconds. The bucket permits an initial burst up to capacity and refills evenly over the window. The lower-level `Allow(key, cost)` method returns `allowed`, `retryAfter`, and the remaining token balance. `Remaining(key)`, `Reset(key)`, and `ResetAll()` are also available. Keys can be strings or numbers; omit the key for one shared bucket. A custom clock function can be passed as the third `New` argument for deterministic tests. Validate remote arguments and permissions inside each handler.

### More modules

| Module | Main API | Use |
| --- | --- | --- |
| `RemoteGuard` | `String`, `Number`, `Boolean`, `Instance`, `Optional`, `Check`, `Wrap` | Validate remote arguments and apply a permission callback before a handler |
| `Cleanup` | `New`, `Add`, `Remove`, `Clean`, `Destroy` | Collect connections, instances, tasks, functions, and objects with cleanup methods |
| `StateMachine` | `New`, `CanTransition`, `Transition`, `Changed`, `Destroy` | Allow only configured state changes |
| `ObjectPool` | `New`, `Acquire`, `Release`, `Destroy` | Reuse objects and cap how many idle objects are kept |
| `Timer` | `New`, `Start`, `Remaining`, `Stop`, `Destroy` | Run one-shot or repeating cancellable delays |
| `AttributeObserver` | `New`, `Watch`, `Destroy` | Receive new and previous attribute values |
| `WeightedRandom` | `New`, `Add`, `Roll`, `Clear` | Select an entry according to its weight |
| `Tween` | `New`, `Play`, `Cancel`, `CancelAll`, `Destroy` | Play one managed tween per target and cancel it cleanly |

```luau
local GML = require(game:GetService("ReplicatedStorage").Modules.Library.GML)

local GuardedHandler = GML.RemoteGuard.Wrap({ GML.RemoteGuard.String(1, 32) }, function(Player, ItemId)
	print(Player.Name, ItemId)
end, function(Player, ItemId)
	return Player.UserId > 0
end)
local PurchaseRemote = game:GetService("ReplicatedStorage").Remotes.Purchase
local PurchaseBinding = GML.RateLimiter.New(5, 10):BindEvent(PurchaseRemote, GuardedHandler)

local Bag = GML.Cleanup.New()
Bag:Add(workspace.ChildAdded:Connect(function(Child)
	print(Child.Name)
end))

local Flow = GML.StateMachine.New("Lobby", {
	Lobby = { "Playing" },
	Playing = { "Lobby" },
})
Flow:Transition("Playing")

local Pool = GML.ObjectPool.New(function()
	return Instance.new("Part")
end, function(Part)
	Part.Parent = nil
end, 20)
local Part = Pool:Acquire()
Pool:Release(Part)

local Countdown = GML.Timer.New(5, function()
	print("Done")
end)
Countdown:Start()

local Observer = GML.AttributeObserver.New(workspace)
Observer:Watch("Round", function(Current, Previous)
	print(Current, Previous)
end, true)

local Loot = GML.WeightedRandom.New()
Loot:Add("Common", 80):Add("Rare", 20)
print(Loot:Roll())
```

For a LocalScript next to a `Frame`:

```luau
local GML = require(game:GetService("ReplicatedStorage").Modules.Library.GML)
local Tweens = GML.Tween.New()
Tweens:Play(script.Parent:WaitForChild("Frame"), TweenInfo.new(0.25), { BackgroundTransparency = 0 })
```

`RemoteGuard.Wrap` returns `nil, "Invalid arguments"` when input fails validation and `nil, "Not allowed"` when its optional permission callback returns false. Pass the wrapped handler to `RateLimiter:BindEvent` or `:BindFunction` to combine the checks. `ObjectPool.New` accepts create, reset, maximum idle count, and dispose callbacks in that order. Call `Destroy` on cleanup, observer, timer, tween, pool, and state machine objects when their owner is finished with them.

`Number.Abbreviate` uses `K`, `M`, `B`, `T`, `Qa`, `Qi`, `Sx`, `Sp`, `Oc`, `No`, and `Dc`. `Number.ParseAbbreviated` accepts these exact suffixes and returns `nil` for invalid input. Decimal places for `Abbreviate` and `Commas` are limited to 0–6. `Time.FormatTimestamp` accepts Roblox `DateTime` format patterns and uses UTC unless the third argument is `true`. `Time.Relative` uses approximate 30-day months and 365-day years. `Signal:Wait()` yields until the next fire and returns its arguments; destroying the signal resumes waiters with no values.

## License

MIT. See [LICENSE](LICENSE).
