-- DIAGNOSTIC — run on an alt, then open a trade and keep it open 10s
local RS = game:GetService("ReplicatedStorage")
local lp = game:GetService("Players").LocalPlayer
local out = {}
local function add(s) out[#out+1] = s; warn(s) end

add("=== REMOTES ===")
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        local path = d:GetFullName():gsub("ReplicatedStorage%.", "")
        add(d.ClassName .. " | " .. path)
    end
end

add("=== INVENTORY ===")
for _, c in ipairs(lp:GetChildren()) do
    if c:IsA("Folder") or c:IsA("Configuration") then
        local kids = c:GetChildren()
        if #kids > 0 and kids[1]:IsA("StringValue") then
            add("CONTAINER " .. c:GetFullName())
            for i = 1, math.min(3, #kids) do
                add("  child Name=" .. kids[i].Name .. " Value=" .. kids[i].Value)
            end
        end
    end
end

add("=== TRADE GUI (waiting 10s) ===")
task.spawn(function()
    for i = 1, 40 do
        for _, g in ipairs(lp.PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name:lower():find("trade") then
                add("GUI " .. g.Name .. " enabled=" .. tostring(g.Enabled))
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextButton") then add("  BTN " .. d:GetFullName() .. " text=" .. d.Text) end
                end
                break
            end
        end
        task.wait(0.25)
    end
    if writefile then writefile("mm2diag.txt", table.concat(out, "\n")) end
    add("=== DONE ===")
end)
