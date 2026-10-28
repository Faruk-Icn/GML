local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Tracker = {}

Tracker.Config = {
	SecretName = "GMLK_WEBHOOK_URL",
	LegacySecretName = "GML_WEBHOOK_URL",
	WebhookName = "Game Tracker",
	WebhookAvatarUrl = "",
	GroupId = 0,
	GroupCheckInterval = 60,
	TrackFriends = false,
	TrackLegacyChatCount = false,
	CountryProvider = nil,
	VisitCountProvider = nil,
	ThumbnailProvider = nil,
	MinSendInterval = 2,
	MaxQueue = 100,
	Debug = false,
}

local Sessions = {}
local GroupStatus = {}
local Connections = {}
local ChatConnections = {}
local SeenReceipts = {}
local TrackingPlayers = {}
local Queue = {}
local WebhookUrl = nil
local Started = false
local Draining = false
local LastSend = 0

local function SafeText(Value: any, Limit: number): string
	local Result = tostring(Value == nil and "Unknown" or Value)
	Result = Result:gsub("\\", "\\\\")
	Result = Result:gsub("%*", "\\*"):gsub("_", "\\_"):gsub("`", "\\`"):gsub("~", "\\~")
	return string.sub(Result, 1, Limit)
end

local function Field(Name: string, Value: any, Inline: boolean?)
	return { name = Name, value = SafeText(Value, 1024), inline = Inline == true }
end

local function Session(Player: Player)
	local Data = Sessions[Player.UserId]
	if not Data then
		Data = { JoinedAt = os.time(), SessionSpent = 0, TotalSpent = 0, TotalPlaytime = 0, ChatCount = 0 }
		Sessions[Player.UserId] = Data
	end
	return Data
end

local function CountFriends(Player: Player): number
	if not Tracker.Config.TrackFriends then
		return 0
	end
	local Count = 0
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player then
			local Success, IsFriend = pcall(Player.IsFriendsWith, Player, Other.UserId)
			if Success and IsFriend then
				Count += 1
			end
		end
	end
	return Count
end

local function BaseFields(Player: Player)
	local Fields = {
		Field("Game", game.Name, true),
		Field("Username", Player.Name, true),
		Field("Display name", Player.DisplayName, true),
		Field("User ID", Player.UserId, true),
		Field("Account age", tostring(Player.AccountAge) .. " days", true),
		Field("Membership", Player.MembershipType == Enum.MembershipType.Premium and "Premium" or "None", true),
		Field("Profile", string.format("https://www.roblox.com/users/%d/profile", Player.UserId)),
	}
	if Tracker.Config.GroupId > 0 then
		table.insert(Fields, Field("Group member", GroupStatus[Player.UserId] == true and "Yes" or "No", true))
	end
	if Tracker.Config.TrackFriends then
		table.insert(Fields, Field("Friends in server", Player:GetAttribute("TrackerFriendsInServer") or 0, true))
	end
	if type(Tracker.Config.CountryProvider) == "function" then
		local Success, Country, Flag = pcall(Tracker.Config.CountryProvider, Player)
		if Success then
			table.insert(Fields, Field("Country", tostring(Flag or "🌍") .. " " .. tostring(Country or "Unknown"), true))
		end
	end
	if type(Tracker.Config.VisitCountProvider) == "function" then
		local Success, Visits = pcall(Tracker.Config.VisitCountProvider)
		if Success then
			table.insert(Fields, Field("Total visits", Visits, true))
		end
	end
	return Fields
end

local function Embed(Title: string, Color: number, Player: Player, Fields)
	local Data = {
		title = Title,
		color = Color,
		author = { name = SafeText(Player.DisplayName .. " (@" .. Player.Name .. ")", 256) },
		fields = Fields,
		timestamp = DateTime.now():ToIsoDate(),
		footer = { text = "GMLK Webhook Tracker" },
	}
	if type(Tracker.Config.ThumbnailProvider) == "function" then
		local Success, Url = pcall(Tracker.Config.ThumbnailProvider, Player)
		if Success and type(Url) == "string" and string.match(Url, "^https://") then
			Data.thumbnail = { url = Url }
		end
	end
	return Data
end

local function Send(Body: string)
	for Attempt = 1, 3 do
		if LastSend > 0 then
			local Delay = math.max(2, Tracker.Config.MinSendInterval) - (os.clock() - LastSend)
			if Delay > 0 then
				task.wait(Delay)
			end
		end
		LastSend = os.clock()
		local Success, Response = pcall(HttpService.RequestAsync, HttpService, {
			Url = WebhookUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = Body,
		})
		if Success and Response.Success then
			if Tracker.Config.Debug then
				print("[GMLK.WebhookTracker] Event sent")
			end
			return true
		end
		local Status = if Success and type(Response) == "table" then tonumber(Response.StatusCode) or 0 else 0
		if Status ~= 0 and Status ~= 429 and Status < 500 then
			warn("[GMLK.WebhookTracker] Request failed with status " .. tostring(Status))
			return false
		end
		if Attempt < 3 then
			task.wait(2 ^ Attempt)
		end
	end
	warn("[GMLK.WebhookTracker] Request failed after retries")
	return false
end

local function Drain()
	while #Queue > 0 do
		local Body = table.remove(Queue, 1)
		local Success = pcall(Send, Body)
		if not Success then
			warn("[GMLK.WebhookTracker] Could not send event")
		end
	end
	Draining = false
end

local function Enqueue(EmbedData): boolean
	if not WebhookUrl then
		return false
	end
	if #Queue >= math.max(1, Tracker.Config.MaxQueue) then
		warn("[GMLK.WebhookTracker] Queue full; event dropped")
		return false
	end
	local Payload = {
		username = Tracker.Config.WebhookName,
		allowed_mentions = { parse = {} },
		embeds = { EmbedData },
	}
	if Tracker.Config.WebhookAvatarUrl ~= "" then
		Payload.avatar_url = Tracker.Config.WebhookAvatarUrl
	end
	local Success, Body = pcall(HttpService.JSONEncode, HttpService, Payload)
	if not Success then
		warn("[GMLK.WebhookTracker] Could not encode event")
		return false
	end
	table.insert(Queue, Body)
	if not Draining then
		Draining = true
		task.spawn(Drain)
	end
	return true
end

local function CheckGroup(Player: Player, Announce: boolean)
	local GroupId = Tracker.Config.GroupId
	if GroupId <= 0 or Player.Parent ~= Players then
		return
	end
	local Success, InGroup = pcall(Player.IsInGroup, Player, GroupId)
	if not Success or Player.Parent ~= Players then
		return
	end
	local Previous = GroupStatus[Player.UserId]
	GroupStatus[Player.UserId] = InGroup
	Player:SetAttribute("TrackerInGroup", InGroup)
	if Announce and Previous == false and InGroup then
		Tracker.GroupJoined(Player)
	end
end

local function RefreshFriends()
	if not Tracker.Config.TrackFriends then
		return
	end
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			Player:SetAttribute("TrackerFriendsInServer", CountFriends(Player))
		end)
	end
end

function Tracker:Init()
	if WebhookUrl then
		return
	end
	local Success, Secret = pcall(HttpService.GetSecret, HttpService, self.Config.SecretName)
	if not Success then
		Success, Secret = pcall(HttpService.GetSecret, HttpService, self.Config.LegacySecretName)
	end
	if Success then
		WebhookUrl = Secret
	else
		warn("[GMLK.WebhookTracker] Secret unavailable; tracker disabled")
	end
end

function Tracker:Start()
	if Started or not WebhookUrl then
		return
	end
	Started = true
	table.insert(Connections, Players.PlayerAdded:Connect(function(Player)
		task.spawn(Tracker.PlayerAdded, Player)
	end))
	table.insert(Connections, Players.PlayerRemoving:Connect(function(Player)
		Tracker.PlayerLeft(Player)
		TrackingPlayers[Player] = nil
		GroupStatus[Player.UserId] = nil
		local Connection = ChatConnections[Player]
		if Connection then
			Connection:Disconnect()
			ChatConnections[Player] = nil
		end
		task.defer(RefreshFriends)
	end))
	table.insert(Connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, PassId, WasPurchased)
		if WasPurchased and Player:IsA("Player") then
			task.spawn(Tracker.GamepassPurchased, Player, PassId)
		end
	end))
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Tracker.PlayerAdded, Player)
	end
	if self.Config.GroupId > 0 then
		task.spawn(function()
			while Started do
				task.wait(math.max(10, Tracker.Config.GroupCheckInterval))
				if Started then
					for _, Player in ipairs(Players:GetPlayers()) do
						task.spawn(CheckGroup, Player, true)
					end
				end
			end
		end)
	end
	game:BindToClose(function()
		local Deadline = os.clock() + 5
		while Draining and os.clock() < Deadline do
			task.wait(0.1)
		end
	end)
end

function Tracker.PlayerAdded(Player: Player)
	if TrackingPlayers[Player] then
		return
	end
	TrackingPlayers[Player] = true
	Session(Player)
	CheckGroup(Player, false)
	if Player.Parent ~= Players then
		TrackingPlayers[Player] = nil
		Sessions[Player.UserId] = nil
		return
	end
	if Tracker.Config.TrackLegacyChatCount and TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
		ChatConnections[Player] = Player.Chatted:Connect(function()
			Tracker.RecordChat(Player)
		end)
	end
	if Tracker.Config.TrackFriends then
		Player:SetAttribute("TrackerFriendsInServer", CountFriends(Player))
	end
	RefreshFriends()
	local Fields = BaseFields(Player)
	table.insert(Fields, Field("Players in server", #Players:GetPlayers(), true))
	Enqueue(Embed("Player joined", 5763719, Player, Fields))
end

function Tracker.PlayerLeft(Player: Player)
	local Data = Session(Player)
	local Fields = BaseFields(Player)
	local Seconds = math.max(0, os.time() - Data.JoinedAt)
	table.insert(Fields, Field("Session seconds", Seconds, true))
	table.insert(Fields, Field("Total seconds", Data.TotalPlaytime + Seconds, true))
	table.insert(Fields, Field("Session Robux", Data.SessionSpent, true))
	table.insert(Fields, Field("Total Robux", Data.TotalSpent, true))
	table.insert(Fields, Field("Chat messages", Data.ChatCount, true))
	table.insert(Fields, Field("Last milestone", Player:GetAttribute("TrackerLastFunnel") or "None"))
	Enqueue(Embed("Player left", 15548997, Player, Fields))
	Sessions[Player.UserId] = nil
end

function Tracker.GroupJoined(Player: Player)
	local Fields = BaseFields(Player)
	table.insert(Fields, Field("Last milestone", Player:GetAttribute("TrackerLastFunnel") or "None"))
	Enqueue(Embed("Player joined group", 5763719, Player, Fields))
end

function Tracker.RecordChat(Player: Player)
	local Data = Session(Player)
	Data.ChatCount += 1
end

function Tracker.SetTotalSpent(Player: Player, Robux: number)
	assert(type(Robux) == "number" and Robux >= 0 and Robux < math.huge, "Robux must be a non-negative finite number")
	Session(Player).TotalSpent = math.max(0, Robux)
end

function Tracker.SetTotalPlaytime(Player: Player, Seconds: number)
	assert(type(Seconds) == "number" and Seconds >= 0 and Seconds < math.huge, "Seconds must be a non-negative finite number")
	Session(Player).TotalPlaytime = math.max(0, Seconds)
end

function Tracker.ProductPurchased(ReceiptInfo)
	local PurchaseId = ReceiptInfo.PurchaseId
	if not PurchaseId or SeenReceipts[PurchaseId] then
		return
	end
	SeenReceipts[PurchaseId] = true
	task.spawn(function()
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			return
		end
		local Success, Info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, ReceiptInfo.ProductId, Enum.InfoType.Product)
		local Name = if Success and Info then Info.Name else "Unknown product"
		local Spent = math.max(0, tonumber(ReceiptInfo.CurrencySpent) or 0)
		local Data = Session(Player)
		Data.SessionSpent += Spent
		Data.TotalSpent += Spent
		local Fields = BaseFields(Player)
		table.insert(Fields, Field("Product", Name, true))
		table.insert(Fields, Field("Product ID", ReceiptInfo.ProductId, true))
		table.insert(Fields, Field("Robux", Spent, true))
		Enqueue(Embed("Developer product purchased", 16763904, Player, Fields))
	end)
end

function Tracker.GamepassPurchased(Player: Player, PassId: number)
	local OwnsSuccessfully, Owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, PassId)
	if not OwnsSuccessfully or not Owns then
		return
	end
	local Success, Info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, PassId, Enum.InfoType.GamePass)
	local Name = if Success and Info then Info.Name else "Unknown game pass"
	local Spent = if Success and Info then math.max(0, tonumber(Info.PriceInRobux) or 0) else 0
	local Data = Session(Player)
	Data.SessionSpent += Spent
	Data.TotalSpent += Spent
	local Fields = BaseFields(Player)
	table.insert(Fields, Field("Game pass", Name, true))
	table.insert(Fields, Field("Pass ID", PassId, true))
	table.insert(Fields, Field("Listed Robux", Spent, true))
	Enqueue(Embed("Game pass purchased", 10181046, Player, Fields))
end

function Tracker:Destroy()
	Started = false
	for _, Connection in ipairs(Connections) do
		Connection:Disconnect()
	end
	table.clear(Connections)
	for Player, Connection in pairs(ChatConnections) do
		Connection:Disconnect()
		ChatConnections[Player] = nil
	end
end

return Tracker
