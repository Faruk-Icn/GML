# GML

**Stars appreciated ⭐**

![Starstruck achievement animation](https://githubachievements.com/cdn-cgi/image/width=1200/images/starstruck/1.gif)

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

## Migrate an existing game with AI

Copy and paste this prompt into an AI coding assistant that has access to your Roblox project or Rojo repository:

```text
Migrate the Roblox project I have opened or attached to GML: https://github.com/Faruk-Icn/GML. Read GML's current README and source before editing. If you cannot access my project, ask me for the files or repository instead of guessing its structure.

First inspect my existing scripts, modules, startup order, require paths, remotes, and any Rojo project file. Identify which code runs on the client, which runs on the server, and which modules are shared. Preserve the game's behavior and existing public APIs. Reuse or adapt working systems instead of replacing them just to use a GML utility.

Install GML at ReplicatedStorage.Modules.Library.GML, with its utility ModuleScripts as children. Use one client bootstrap at StarterPlayer.StarterPlayerScripts.GMLClient to load ReplicatedStorage.Modules.Client. Use one server bootstrap at ServerScriptService.GMLServer to load ServerStorage.Modules.Client. The server folder really is named Client in this framework. Update the Rojo mapping if this project uses Rojo; otherwise give me exact Roblox Studio placement steps.

Move or adapt startup modules into the appropriate client or server folder. GML requires all discovered modules, runs every Init in priority order, then every Start in priority order. Set Priority only where existing dependencies require it. Keep dependency-only ModuleScripts out of the auto-loaded folders unless loading them is intentional. Update require paths and remove redundant startup scripts only after their callers and behavior have been accounted for.

Keep existing RemoteEvent and RemoteFunction names, locations, arguments, and responses unless a change is necessary and you explain it. For server handlers that need throttling, create a limiter with GML.RateLimiter.New(...) and bind it with limiter:BindEvent(...) or limiter:BindFunction(...). Use GML.RemoteGuard for argument checks, and keep permission and game-state checks on the server. Do not leave a second unrestricted OnServerEvent listener performing the same protected action. Be careful that BindFunction assigns OnServerInvoke.

GML lives in ReplicatedStorage, so do not put secrets, data-store implementations, or private server logic in GML or its children. Keep those in server-only modules. Do not install the optional webhook tracker unless I request it, and never put webhook URLs in source code. Migrate in small steps, check for circular requires and duplicate lifecycle calls, and run the project's available checks or Roblox Studio tests. Do not add unrelated features or unnecessary code comments.

When finished, give me a short mapping from old locations to new locations, list any behavior or API changes, and report what you tested and what still needs manual Studio testing.
```

## Optional webhook tracker

The [webhook tracker](src/optional/WebhookTracker.luau) is a server-only add-on. It is intentionally absent from `default.project.json`, so installing GML does not start outbound tracking. To enable it, copy the file as a ModuleScript to `ServerStorage.Modules.Client.WebhookTracker` or map that location to `src/optional/WebhookTracker.luau` in your own Rojo project. The server bootstrap will call its `Init` and `Start` lifecycle methods.

Create one new webhook URL and store the **full URL** in your experience's [Roblox secrets store](https://create.roblox.com/docs/cloud-services/secrets) as `GML_WEBHOOK_URL`, scoped to the endpoint's domain. Enable **Allow HTTP Requests**. Configure a local secret separately for Studio playtesting. Never paste the URL into a ModuleScript or commit it to Git. Rotate any webhook URL that has been shared publicly.

Edit `WebhookTracker.Config` before syncing to customize its display name, group ID, polling interval, optional friend counts, and optional providers for country, visits, or a public thumbnail URL. `GroupId = 0` disables group checks. The module sends join, leave, group-join, and verified game-pass events. Its embeds include player names, user IDs, profile links, and session data; the configured endpoint receives that data. It uses one secret endpoint, a bounded send queue, retry delays, and no mention pings. It does not fetch from third-party Roblox proxies or send chat text. Legacy chat counts can be enabled; for a custom or modern chat system, call `WebhookTracker.RecordChat(player)` from your trusted server-side chat code if you need counts. If the endpoint rejects direct HTTP requests, use an HTTPS relay you control and store that relay URL as the secret.

The tracker does **not** assign `MarketplaceService.ProcessReceipt` or grant purchases. In your existing receipt handler, after the product has been granted and recorded, call `WebhookTracker.ProductPurchased(receiptInfo)` before returning `PurchaseGranted`:

```luau
local WebhookTracker = require(game:GetService("ServerStorage").Modules.Client.WebhookTracker)

if Decision == Enum.ProductPurchaseDecision.PurchaseGranted then
	WebhookTracker.ProductPurchased(ReceiptInfo)
end
return Decision
```

`Decision` and `ReceiptInfo` here are the values from your existing handler; keep its grant and duplicate-receipt logic. The notification is queued separately and must never determine whether Roblox considers a purchase granted. Roblox documents `ProcessReceipt` as the [developer-product fulfillment callback](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService). The tracker deduplicates notification calls by `PurchaseId` within one server session, so persistent cross-server deduplication remains the responsibility of the game's purchase system.

The tracker also exposes `SetTotalSpent(player, robux)` and `SetTotalPlaytime(player, seconds)` for games that maintain those totals, plus `:Destroy()` to disconnect its listeners. If no secret is available, the add-on warns and stays inactive. A webhook endpoint can reject or rate-limit requests, so notifications are best-effort and do not replace gameplay data or purchase records.

## License

MIT. See [LICENSE](LICENSE).
