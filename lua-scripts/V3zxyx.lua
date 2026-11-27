--// V3zxyx | standalone MM2 script, Delta-friendly
--// Place: 142823291
if getgenv().V3zxyx_Cleanup then pcall(getgenv().V3zxyx_Cleanup) end
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
if game.PlaceId ~= 142823291 then
print("[V3zxyx] Not Murder Mystery 2, running anyway.")
end
LP.Idled:Connect(function()
pcall(function()
VirtualUser:Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
task.wait(1)
VirtualUser:Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
end)
end)
local S = {
AutoFarm = false, Mode = "Nearest", AutoGrab = false, DodgeKnife = false, EndRound = false,
KillAura = false, AuraDist = 18, KillAll = false, SilentAim = false, KillM = false,
AutoShoot = false, ShootBind = false,
Chams = false, GunCham = false, Names = false, AutoEmote = false, Emote = "dab",
WalkSpeed = false, WSValue = 40, JumpPower = false, JPValue = 90,
InfJump = false, InfJumpPower = 70,
Invis = false, AntiFling = false,
CoinTracker = false, Webhook = "", Interval = 60,
}
local roles, Murderer, Sheriff = {}, nil, nil
local highlights = {}
local currentTween, lastCoin, invisChair = nil, nil, nil
local conns = {}
local function track(c) table.insert(conns, c) return c end
--// role polling
task.spawn(function()
while true do
task.wait(0.4)
pcall(function()
local res = RS:FindFirstChild("GetPlayerData", true):InvokeServer()
if type(res) == "table" then roles = res end
end)
Murderer, Sheriff = nil, nil
for _, p in ipairs(Players:GetPlayers()) do
pcall(function()
if p.Backpack:FindFirstChild("Knife") or (p.Character and p.Character:FindFirstChild("Knife")) then Murderer = p.Name end
if p.Backpack:FindFirstChild("Gun") or (p.Character and p.Character:FindFirstChild("Gun")) then Sheriff = p.Name end
end)
end
end
end)
local function isAlive(p)
local r = roles[p.Name]
if not r then return false end
if not r.Killed and not r.Dead then return true end
local c = p.Character
if c and c:FindFirstChild("HumanoidCloned") then return true end
return false
end
local function char()
local c = LP.Character
if not c then return end
return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end
local function mapModel()
for _, m in ipairs(workspace:GetChildren()) do
if m:IsA("Model") and not m.Name:lower():find("lobby") then
if m:FindFirstChild("CoinContainer") or m:FindFirstChild("Spawns") then return m end
end
end
end
local function gunDrop()
local m = mapModel()
return m and m:FindFirstChild("GunDrop") or nil
end
local function equip(name)
local c, _, hum = char()
if not (c and hum) then return end
local t = LP.Backpack:FindFirstChild(name) or c:FindFirstChild(name)
if t and hum:FindFirstChild("Animator") then pcall(function() hum:EquipTool(t) end) end
end
local function trackBagFull()
local r = roles[LP.Name]
if not r then return false end
local coins = tonumber(r.Coins) or 0
if LP:GetAttribute("Elite") ~= nil then return coins >= 50 end
return coins >= 40
end
local function collect(coin)
local c, hrp = char()
if not (c and hrp and coin and coin.Parent) then return end
pcall(function()
firetouchinterest(coin, hrp, 1)
task.wait(0.05)
firetouchinterest(coin, hrp, 0)
end)
end
local function tweenTo(cf, speed, instant)
local c, hrp = char()
if not hrp then return end
if currentTween then pcall(function() currentTween:Cancel() end) end
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.AssemblyAngularVelocity = Vector3.zero
if instant then
hrp.CFrame = cf
return
end
local dist = (hrp.Position - cf.Position).Magnitude
currentTween = TweenService:Create(hrp, TweenInfo.new(math.clamp(dist / speed, 0.15, 4), Enum.EasingStyle.Linear), { CFrame = cf })
currentTween:Play()
end
local function nearestCoin(hrp)
local m = mapModel()
local container = m and m:FindFirstChild("CoinContainer")
if not container then return end
local best, bestD = nil, math.huge
for _, coin in ipairs(container:GetChildren()) do
if coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual") then
local ok, d = pcall(function() return (hrp.Position - coin.CoinVisual.Position).Magnitude end)
if ok and d < bestD then best, bestD = coin, d end
end
end
return best
end
local function randomCoin(hrp)
local m = mapModel()
local container = m and m:FindFirstChild("CoinContainer")
if not container then return end
local list = {}
for _, coin in ipairs(container:GetChildren()) do
if coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual") then table.insert(list, coin) end
end
if #list == 0 then return end
return list[math.random(1, #list)]
end
local function goLobby()
for _, f in ipairs(workspace:GetChildren()) do
if f.Name:lower():find("lobby") then
for _, o in ipairs(f:GetDescendants()) do
if o:IsA("SpawnLocation") then
tweenTo(CFrame.new(o.Position + Vector3.new(0, 5, 0)), 5000, true)
return
end
end
end
end
end
local function shootMurderer()
local c, hrp = char()
if not (c and hrp) then return end
local gun = c:FindFirstChild("Gun") or LP.Backpack:FindFirstChild("Gun")
if not gun then return end
local m = Murderer and Players:FindFirstChild(Murderer)
if not (m and m.Character) then return end
local mhrp = m.Character:FindFirstChild("HumanoidRootPart")
local mhum = m.Character:FindFirstChildOfClass("Humanoid")
if not (mhrp and mhum) then return end
local vel = mhrp.AssemblyLinearVelocity or Vector3.zero
local dir = mhum.MoveDirection or Vector3.zero
local target = mhrp.Position + (vel * 0.5) * (2.8 / 15) + dir * 2.8
local origin = hrp.CFrame
local ra = hrp:FindFirstChild("RootAttachment")
if ra then origin = ra.WorldCFrame end
local ev = c:FindFirstChild("Gun") and c.Gun:FindFirstChild("Shoot")
local ev2 = workspace:FindFirstChild(LP.Name) and workspace[LP.Name]:FindFirstChild("Gun")
local shootEv = ev or (ev2 and ev2:FindFirstChild("Shoot"))
if shootEv then
pcall(function() shootEv:FireServer(origin, CFrame.new(target)) end)
end
end
local function visible(p)
local c, hrp = char()
if not (c and hrp) or not p.Character then return false end
local thrp = p.Character:FindFirstChild("HumanoidRootPart")
if not thrp then return false end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { c }
local hit = workspace:Raycast(hrp.Position, (thrp.Position - hrp.Position).Unit * 60, params)
return (not hit) or (hit.Instance:IsDescendantOf(p.Character))
end
local function fling(target)
local c, hrp = char()
if not (c and hrp) or not target or not target.Character then return end
local thrp = target.Character:FindFirstChild("HumanoidRootPart")
if not thrp then return end
local bv = Instance.new("BodyAngularVelocity")
bv.AngularVelocity = Vector3.new(0, 0, 60000)
bv.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
bv.Parent = thrp
task.delay(0.6, function() if bv then bv:Destroy() end end)
end
--// infinite jump
local function doInfJump()
local c, hrp, hum = char()
if not (hrp and hum) or hum.Health <= 0 then return end
hum:ChangeState(Enum.HumanoidStateType.Jumping)
hrp.AssemblyLinearVelocity = Vector3.new(
hrp.AssemblyLinearVelocity.X,
S.InfJumpPower,
hrp.AssemblyLinearVelocity.Z
)
end
track(UIS.JumpRequest:Connect(function()
if S.InfJump then doInfJump() end
end))
track(UIS.InputBegan:Connect(function(input, gp)
if gp then return end
if S.InfJump and input.KeyCode == Enum.KeyCode.Space then doInfJump() end
end))
--// loops
local loops = {}
loops.farm = task.spawn(function()
while true do
task.wait(0.15)
if not S.AutoFarm then continue end
pcall(function()
local c, hrp, hum = char()
if not (hrp and hum and hum.Health > 0) then return end
if not Murderer then return end
if not isAlive(LP) then return end
if trackBagFull() then
if S.KillM or S.KillAll or S.AutoShoot then return end
hum.Health = 0
return
end
local coin = (S.Mode == "Randomize") and randomCoin(hrp) or nearestCoin(hrp)
if coin and coin ~= lastCoin then
lastCoin = coin
local p = coin.CoinVisual.Position
local far = (hrp.Position - p).Magnitude > 200
if far then tweenTo(CFrame.new(p + Vector3.new(0, 10, 0)), 5000, true) end
tweenTo(CFrame.new(p + Vector3.new(0, 1.5, 0)), 24, false)
end
end)
end
end)
loops.grab = task.spawn(function()
while true do
task.wait(0.1)
if S.AutoGrab then
pcall(function()
local c, hrp = char()
local g = gunDrop()
if hrp and g and Murderer and Murderer ~= LP.Name then g.CFrame = hrp.CFrame end
end)
end
end
end)
loops.dodge = task.spawn(function()
while true do
task.wait(0.08)
if S.DodgeKnife then
pcall(function()
local c, hrp = char()
if not hrp then return end
for _, k in ipairs(workspace:GetChildren()) do
if k.Name == "ThrowingKnife" then
local b = k:FindFirstChild("BladePosition")
if b and (b.Position - hrp.Position).Magnitude <= 15 then
local pos = hrp.Position
hrp.CFrame = CFrame.new(pos.X, pos.Y + 100, pos.Z)
task.wait(0.2)
hrp.CFrame = CFrame.new(pos)
end
end
end
end)
end
end
end)
loops.aura = task.spawn(function()
while true do
task.wait()
if S.KillAura and Murderer == LP.Name then
pcall(function()
local c, hrp = char()
if not hrp then return end
local knife = c:FindFirstChild("Knife") or LP.Backpack:FindFirstChild("Knife")
if not knife then return end
equip("Knife")
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and isAlive(p) and p.Character then
local r = p.Character:FindFirstChild("HumanoidRootPart")
if r and (r.Position - hrp.Position).Magnitude <= S.AuraDist then
local k = c:FindFirstChild("Knife")
if k then pcall(function() k.Events.HandleTouched:FireServer(r) end) end
end
end
end
end)
end
end
end)
loops.killall = task.spawn(function()
while true do
task.wait(0.5)
if S.KillAll and Murderer == LP.Name then
pcall(function()
local c = char()
if not c then return end
equip("Knife")
local k = c:FindFirstChild("Knife")
if not k then return end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and isAlive(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
pcall(function() k.Events.HandleTouched:FireServer(p.Character.HumanoidRootPart) end)
end
end
end)
end
end
end)
loops.shoot = task.spawn(function()
while true do
task.wait()
if S.KillM then
pcall(function()
if trackBagFull() then return end
equip("Gun")
shootMurderer()
end)
elseif S.AutoShoot then
pcall(function()
local m = Murderer and Players:FindFirstChild(Murderer)
if Sheriff == LP.Name and m and visible(m) and not trackBagFull() then
equip("Gun")
shootMurderer()
end
end)
end
end
end)
loops.endround = task.spawn(function()
while true do
task.wait(1)
if S.EndRound and Murderer and Murderer ~= LP.Name and not isAlive(LP) then
local m = Players:FindFirstChild(Murderer)
if m then fling(m) end
end
end
end)
loops.chams = task.spawn(function()
while true do
task.wait(0.5)
if S.Chams or S.Names then
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and p.Character then
if S.Chams and not p.Character:FindFirstChild("V3zxyxHL") then
local h = Instance.new("Highlight")
h.Name = "V3zxyxHL"
h.Parent = p.Character
highlights[p] = h
end
if S.Chams and p.Character:FindFirstChild("V3zxyxHL") then
local h = p.Character.V3zxyxHL
local r = roles[p.Name]
if r and r.Role == "Murderer" then
h.FillColor = Color3.fromRGB(230, 0, 0)
elseif r and (r.Role == "Sheriff" or r.Role == "Hero") then
h.FillColor = Color3.fromRGB(0, 90, 230)
else
h.FillColor = Color3.fromRGB(76, 215, 134)
end
end
if S.Names and p.Character:FindFirstChild("Head") and not p.Character.Head:FindFirstChild("V3zxyxTag") then
local bb = Instance.new("BillboardGui")
bb.Name = "V3zxyxTag"
bb.Adornee = p.Character.Head
bb.Size = UDim2.new(0, 200, 0, 50)
bb.StudsOffset = Vector3.new(0, 2.5, 0)
bb.AlwaysOnTop = true
bb.Parent = p.Character.Head
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1, 1)
tl.BackgroundTransparency = 1
tl.Text = p.Name
tl.TextSize = 18
tl.Font = Enum.Font.SourceSansBold
tl.TextColor3 = Color3.new(1, 1, 1)
tl.TextStrokeTransparency = 0.4
tl.Parent = bb
end
end
end
else
for p, h in pairs(highlights) do
if h then h:Destroy() end
highlights[p] = nil
end
for _, p in ipairs(Players:GetPlayers()) do
if p.Character and p.Character:FindFirstChild("Head") then
local t = p.Character.Head:FindFirstChild("V3zxyxTag")
if t then t:Destroy() end
end
end
end
end
end)
loops.guncham = task.spawn(function()
while true do
task.wait(0.3)
if S.GunCham then
local g = gunDrop()
if g and not g:FindFirstChild("V3zxyxGunHL") then
local h = Instance.new("Highlight")
h.Name = "V3zxyxGunHL"
h.FillColor = Color3.fromRGB(128, 225, 0)
h.FillTransparency = 0.5
h.Parent = g
end
end
end
end)
loops.misc = task.spawn(function()
while true do
task.wait(0.2)
local c, hrp, hum = char()
if hum then
hum.WalkSpeed = S.WalkSpeed and S.WSValue or 16
if not S.InfJump then
hum.JumpPower = S.JumpPower and S.JPValue or 50
end
end
if S.AntiFling then
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and p.Character then
for _, v in ipairs(p.Character:GetDescendants()) do
if v:IsA("BasePart") then v.CanCollide = false end
end
end
end
end
if S.AutoEmote then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
end
end)
--// void / fling recovery
local VOID_Y = workspace.FallenPartsDestroyHeight
local MAX_Y = 5000
local lastCF, outSince = nil, nil
track(RunService.Heartbeat:Connect(function()
local c, hrp, hum = char()
if not (hrp and hum) then outSince = nil return end
local y = hrp.Position.Y
if y > VOID_Y and y < MAX_Y then
if hum.FloorMaterial ~= Enum.Material.Air then lastCF = hrp.CFrame end
outSince = nil
else
outSince = outSince or os.clock()
if os.clock() - outSince > 4 and lastCF then
hrp.CFrame = lastCF + Vector3.new(0, 4, 0)
hrp.AssemblyLinearVelocity = Vector3.zero
outSince = nil
end
end
end))
--// anti-stealer
task.spawn(function()
pcall(function()
local trade = RS:WaitForChild("Trade", 10)
if not trade then return end
local decline = trade:WaitForChild("DeclineTrade", 5)
local update = trade:WaitForChild("UpdateTrade", 5)
if decline then pcall(function() decline:FireServer() end) end
if update then
track(update.OnClientEvent:Connect(function()
if decline and decline.Parent then pcall(function() decline:FireServer() end) end
end))
end
end)
end)
--// coin webhook tracker
local earned, lastCount = {}, {}
task.spawn(function()
local ev = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Gameplay") and RS.Remotes.Gameplay:FindFirstChild("CoinCollected")
if ev then
track(ev.OnClientEvent:Connect(function(bag, cur)
earned[bag] = earned[bag] or 0
lastCount[bag] = lastCount[bag] or 0
local d = cur - lastCount[bag]
if d > 0 then earned[bag] = earned[bag] + d end
lastCount[bag] = cur
end))
end
local req = (syn and syn.request) or (http and http.request) or http_request or request
while true do
task.wait(1)
if S.CoinTracker and S.Webhook ~= "" and req then
for bag, n in pairs(earned) do
if n > 0 then
pcall(function()
req({
Url = S.Webhook,
Method = "POST",
Headers = { ["Content-Type"] = "application/json" },
Body = HttpService:JSONEncode({
username = "Coin Tracker",
embeds = {{ title = "Coins", description = ("Bag: %s
Coins: %d"):format(bag, n) }},
}),
})
end)
end
end
table.clear(earned)
end
end
end)
--// UI
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "V3zxyx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = guiParent
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(290, 330)
main.Position = UDim2.new(0, 20, 0, 80)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 34)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "V3zxyx | mm2"
title.TextSize = 15
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(26, 26)
minBtn.Position = UDim2.new(1, -34, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Parent = main
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
--// collapsed logo
local logoBtn = Instance.new("TextButton")
logoBtn.Name = "V3zxyxLogo"
logoBtn.Size = UDim2.fromOffset(42, 42)
logoBtn.Position = main.Position
logoBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
logoBtn.Text = "V3"
logoBtn.Font = Enum.Font.GothamBold
logoBtn.TextSize = 15
logoBtn.TextColor3 = Color3.fromRGB(90, 220, 150)
logoBtn.AutoButtonColor = false
logoBtn.Visible = false
logoBtn.Parent = gui
Instance.new("UICorner", logoBtn).CornerRadius = UDim.new(1, 0)
local logoStroke = Instance.new("UIStroke")
logoStroke.Color = Color3.fromRGB(60, 140, 90)
logoStroke.Thickness = 1.5
logoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
logoStroke.Parent = logoBtn
local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.fromOffset(7, 7)
logoDot.Position = UDim2.new(1, -11, 1, -11)
logoDot.BackgroundColor3 = Color3.fromRGB(90, 220, 150)
logoDot.Parent = logoBtn
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 26)
tabBar.Position = UDim2.fromOffset(8, 36)
tabBar.BackgroundTransparency = 1
tabBar.ClipsDescendants = true
tabBar.Parent = main
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -76)
scroll.Position = UDim2.fromOffset(8, 68)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll
local tabHolder = Instance.new("UIListLayout")
tabHolder.FillDirection = Enum.FillDirection.Horizontal
tabHolder.Padding = UDim.new(0, 3)
tabHolder.SortOrder = Enum.SortOrder.LayoutOrder
tabHolder.Parent = tabBar
local pages, activePage = {}, nil
local function newPage()
local f = Instance.new("Frame")
f.Size = UDim2.fromScale(1, 1)
f.BackgroundTransparency = 1
f.Visible = false
f.Parent = scroll
local l = Instance.new("UIListLayout")
l.Padding = UDim.new(0, 4)
l.SortOrder = Enum.SortOrder.LayoutOrder
l.Parent = f
table.insert(pages, f)
return f
end
local function newTab(name)
local b = Instance.new("TextButton")
local tw = TextService:GetTextSize(name, 11, Enum.Font.Gotham, Vector2.new(200, 26)).X
b.Size = UDim2.fromOffset(math.ceil(tw) + 14, 26)
b.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
b.Text = name
b.Font = Enum.Font.Gotham
b.TextSize = 11
b.TextColor3 = Color3.fromRGB(200, 200, 205)
b.TextTruncate = Enum.TextTruncate.AtEnd
b.Parent = tabBar
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
local page = newPage()
b.MouseButton1Click:Connect(function()
for _, p in ipairs(pages) do p.Visible = false end
for _, t in ipairs(tabBar:GetChildren()) do
if t:IsA("TextButton") then t.BackgroundColor3 = Color3.fromRGB(28, 28, 34) end
end
page.Visible = true
b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
end)
if not activePage then
activePage = true
page.Visible = true
b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
end
return page
end
local function toggle(page, text, default, cb)
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 30)
row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
row.Parent = page
Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -46, 1, 0)
lbl.Position = UDim2.fromOffset(10, 0)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Gotham
lbl.TextSize = 12
lbl.TextColor3 = Color3.fromRGB(225, 225, 230)
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextTruncate = Enum.TextTruncate.AtEnd
lbl.Text = text
lbl.Parent = row
local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(34, 18)
btn.Position = UDim2.new(1, -42, 0.5, -9)
btn.BackgroundColor3 = default and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(45, 45, 52)
btn.Text = ""
btn.Parent = row
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
local state = default
btn.MouseButton1Click:Connect(function()
state = not state
btn.BackgroundColor3 = state and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(45, 45, 52)
cb(state)
end)
return row
end
local function button(page, text, cb)
local b = Instance.new("TextButton")
b.Size = UDim2.new(1, 0, 0, 30)
b.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
b.Font = Enum.Font.Gotham
b.TextSize = 12
b.TextColor3 = Color3.fromRGB(225, 225, 230)
b.TextTruncate = Enum.TextTruncate.AtEnd
b.Text = text
b.Parent = page
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
b.MouseButton1Click:Connect(function() pcall(cb) end)
return b
end
local function slider(page, text, min, max, default, cb)
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 40)
row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
row.Parent = page
Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -20, 0, 18)
lbl.Position = UDim2.fromOffset(10, 2)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Gotham
lbl.TextSize = 11
lbl.TextColor3 = Color3.fromRGB(200, 200, 205)
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = text .. ": " .. default
lbl.Parent = row
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, -20, 0, 8)
bar.Position = UDim2.fromOffset(10, 26)
bar.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
bar.Parent = row
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale((default - min) / (max - min), 1)
fill.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
fill.Parent = bar
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local dragging = false
local function set(x)
local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
local v = math.floor(min + (max - min) * rel + 0.5)
fill.Size = UDim2.fromScale(rel, 1)
lbl.Text = text .. ": " .. v
cb(v)
end
bar.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
end)
UIS.InputChanged:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
set(i.Position.X)
end
end)
UIS.InputEnded:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
end
--// dragging (window + logo)
local dragging, dragStart, startPos = false, nil, nil
local logoDragging, logoStart, logoOrigin, logoMoved = false, nil, nil, false
title.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
dragging, dragStart, startPos = true, i.Position, main.Position
end
end)
logoBtn.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
logoDragging, logoStart, logoOrigin, logoMoved = true, i.Position, logoBtn.Position, false
end
end)
UIS.InputChanged:Connect(function(i)
if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
if dragging then
local d = i.Position - dragStart
main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
elseif logoDragging then
local d = i.Position - logoStart
if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then logoMoved = true end
logoBtn.Position = UDim2.new(logoOrigin.X.Scale, logoOrigin.X.Offset + d.X, logoOrigin.Y.Scale, logoOrigin.Y.Offset + d.Y)
end
end)
UIS.InputEnded:Connect(function(i)
if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
dragging = false
if logoDragging then
logoDragging = false
if not logoMoved then
logoBtn.Visible = false
main.Position = logoBtn.Position
main.Visible = true
end
end
end)
minBtn.MouseButton1Click:Connect(function()
logoBtn.Position = main.Position
logoBtn.Visible = true
main.Visible = false
end)
--// pages
local pMain = newTab("Main")
local pRole = newTab("Roles")
local pVis = newTab("Visual")
local pPlayer = newTab("Player")
local pMisc = newTab("Misc")
toggle(pMain, "Auto Farm Coins", false, function(v) S.AutoFarm = v end)
button(pMain, "Farm Mode: Nearest", function()
S.Mode = S.Mode == "Nearest" and "Randomize" or "Nearest"
end)
toggle(pMain, "Auto Grab Gun", false, function(v) S.AutoGrab = v end)
toggle(pMain, "Dodge Knife", false, function(v) S.DodgeKnife = v end)
toggle(pMain, "Auto End Round (fling)", false, function(v) S.EndRound = v end)
button(pMain, "Teleport To Lobby", goLobby)
button(pMain, "Teleport To Map", function()
local m = mapModel()
if m and m:FindFirstChild("Spawns") then
local s = m.Spawns:GetChildren()[1]
if s then tweenTo(s.CFrame * CFrame.new(0, 5, 0), 5000, true) end
end
end)
toggle(pRole, "Kill Aura", false, function(v) S.KillAura = v end)
slider(pRole, "Aura Range", 5, 60, 18, function(v) S.AuraDist = v end)
toggle(pRole, "Auto Kill All", false, function(v) S.KillAll = v end)
toggle(pRole, "Silent Aim", false, function(v) S.SilentAim = v end)
toggle(pRole, "Kill Murderer (blatant)", false, function(v) S.KillM = v end)
toggle(pRole, "Auto Shoot Murderer", false, function(v) S.AutoShoot = v end)
button(pRole, "Shoot Murderer Now", function()
equip("Gun")
shootMurderer()
end)
toggle(pVis, "Player Chams", false, function(v) S.Chams = v end)
toggle(pVis, "Gun Cham", false, function(v) S.GunCham = v end)
toggle(pVis, "Name ESP", false, function(v) S.Names = v end)
toggle(pPlayer, "Walk Speed", false, function(v) S.WalkSpeed = v end)
slider(pPlayer, "Speed", 16, 120, 40, function(v) S.WSValue = v end)
toggle(pPlayer, "Jump Power", false, function(v) S.JumpPower = v end)
slider(pPlayer, "Jump", 50, 200, 90, function(v) S.JPValue = v end)
toggle(pPlayer, "Infinite Jump", false, function(v) S.InfJump = v end)
slider(pPlayer, "Inf Jump Height", 30, 200, 70, function(v) S.InfJumpPower = v end)
toggle(pPlayer, "Anti Fling", false, function(v) S.AntiFling = v end)
button(pPlayer, "Invisible (chair)", function()
local c = char()
if not c then return end
if invisChair and invisChair.Parent then
invisChair:Destroy()
return
end
local hrp = c:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local pos = hrp.CFrame
local seat = Instance.new("Seat")
seat.Anchored = false
seat.CanCollide = false
seat.Transparency = 1
seat.Name = "V3zxyxInvis"
seat.Parent = workspace
local w = Instance.new("Weld", seat)
w.Part0 = seat
w.Part1 = hrp
seat.CFrame = pos
invisChair = seat
end)
toggle(pMisc, "Coin Webhook Tracker", false, function(v) S.CoinTracker = v end)
local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(1, 0, 0, 30)
webhookBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
webhookBox.PlaceholderText = "Discord webhook URL"
webhookBox.Text = ""
webhookBox.Font = Enum.Font.Gotham
webhookBox.TextSize = 11
webhookBox.TextColor3 = Color3.new(1, 1, 1)
webhookBox.Parent = pMisc
Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0, 6)
webhookBox.FocusLost:Connect(function() S.Webhook = webhookBox.Text end)
button(pMisc, "Unload Script", function() getgenv().V3zxyx_Cleanup() end)
--// silent aim hook on gun activation
local aimConn
task.spawn(function()
while true do
task.wait(0.3)
local c = LP.Character
local gun = c and c:FindFirstChild("Gun")
if not S.SilentAim or not gun or Sheriff ~= LP.Name then
if aimConn then aimConn:Disconnect() aimConn = nil end
elseif gun and not aimConn then
aimConn = gun.Activated:Connect(function()
local m = Murderer and Players:FindFirstChild(Murderer)
if not (m and m.Character) then return end
local r = m.Character:FindFirstChild("HumanoidRootPart")
local c2, hrp = char()
if not (r and hrp) then return end
local ev = gun:FindFirstChild("Shoot")
if ev then pcall(function() ev:FireServer(hrp.CFrame, r.CFrame) end) end
end)
end
end
end)
getgenv().V3zxyx_Cleanup = function()
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
for _, l in ipairs(loops) do pcall(function() task.cancel(l) end) end
if aimConn then pcall(function() aimConn:Disconnect() end) end
pcall(function() gui:Destroy() end)
for p, h in pairs(highlights) do pcall(function() h:Destroy() end) end
getgenv().V3zxyx_Cleanup = nil
end
print("[V3zxyx] loaded")--// V3zxyx | standalone MM2 script, Delta-friendly
--// Place: 142823291
if getgenv().V3zxyx_Cleanup then pcall(getgenv().V3zxyx_Cleanup) end
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
if game.PlaceId ~= 142823291 then
print("[V3zxyx] Not Murder Mystery 2, running anyway.")
end
LP.Idled:Connect(function()
pcall(function()
VirtualUser:Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
task.wait(1)
VirtualUser:Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
end)
end)
local S = {
AutoFarm = false, Mode = "Nearest", AutoGrab = false, DodgeKnife = false, EndRound = false,
KillAura = false, AuraDist = 18, KillAll = false, SilentAim = false, KillM = false,
AutoShoot = false, ShootBind = false,
Chams = false, GunCham = false, Names = false, AutoEmote = false, Emote = "dab",
WalkSpeed = false, WSValue = 40, JumpPower = false, JPValue = 90,
InfJump = false, InfJumpPower = 70,
Invis = false, AntiFling = false,
CoinTracker = false, Webhook = "", Interval = 60,
}
local roles, Murderer, Sheriff = {}, nil, nil
local highlights = {}
local currentTween, lastCoin, invisChair = nil, nil, nil
local conns = {}
local function track(c) table.insert(conns, c) return c end
--// role polling
task.spawn(function()
while true do
task.wait(0.4)
pcall(function()
local res = RS:FindFirstChild("GetPlayerData", true):InvokeServer()
if type(res) == "table" then roles = res end
end)
Murderer, Sheriff = nil, nil
for _, p in ipairs(Players:GetPlayers()) do
pcall(function()
if p.Backpack:FindFirstChild("Knife") or (p.Character and p.Character:FindFirstChild("Knife")) then Murderer = p.Name end
if p.Backpack:FindFirstChild("Gun") or (p.Character and p.Character:FindFirstChild("Gun")) then Sheriff = p.Name end
end)
end
end
end)
local function isAlive(p)
local r = roles[p.Name]
if not r then return false end
if not r.Killed and not r.Dead then return true end
local c = p.Character
if c and c:FindFirstChild("HumanoidCloned") then return true end
return false
end
local function char()
local c = LP.Character
if not c then return end
return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end
local function mapModel()
for _, m in ipairs(workspace:GetChildren()) do
if m:IsA("Model") and not m.Name:lower():find("lobby") then
if m:FindFirstChild("CoinContainer") or m:FindFirstChild("Spawns") then return m end
end
end
end
local function gunDrop()
local m = mapModel()
return m and m:FindFirstChild("GunDrop") or nil
end
local function equip(name)
local c, _, hum = char()
if not (c and hum) then return end
local t = LP.Backpack:FindFirstChild(name) or c:FindFirstChild(name)
if t and hum:FindFirstChild("Animator") then pcall(function() hum:EquipTool(t) end) end
end
local function trackBagFull()
local r = roles[LP.Name]
if not r then return false end
local coins = tonumber(r.Coins) or 0
if LP:GetAttribute("Elite") ~= nil then return coins >= 50 end
return coins >= 40
end
local function collect(coin)
local c, hrp = char()
if not (c and hrp and coin and coin.Parent) then return end
pcall(function()
firetouchinterest(coin, hrp, 1)
task.wait(0.05)
firetouchinterest(coin, hrp, 0)
end)
end
local function tweenTo(cf, speed, instant)
local c, hrp = char()
if not hrp then return end
if currentTween then pcall(function() currentTween:Cancel() end) end
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.AssemblyAngularVelocity = Vector3.zero
if instant then
hrp.CFrame = cf
return
end
local dist = (hrp.Position - cf.Position).Magnitude
currentTween = TweenService:Create(hrp, TweenInfo.new(math.clamp(dist / speed, 0.15, 4), Enum.EasingStyle.Linear), { CFrame = cf })
currentTween:Play()
end
local function nearestCoin(hrp)
local m = mapModel()
local container = m and m:FindFirstChild("CoinContainer")
if not container then return end
local best, bestD = nil, math.huge
for _, coin in ipairs(container:GetChildren()) do
if coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual") then
local ok, d = pcall(function() return (hrp.Position - coin.CoinVisual.Position).Magnitude end)
if ok and d < bestD then best, bestD = coin, d end
end
end
return best
end
local function randomCoin(hrp)
local m = mapModel()
local container = m and m:FindFirstChild("CoinContainer")
if not container then return end
local list = {}
for _, coin in ipairs(container:GetChildren()) do
if coin.Name == "Coin_Server" and coin:FindFirstChild("CoinVisual") then table.insert(list, coin) end
end
if #list == 0 then return end
return list[math.random(1, #list)]
end
local function goLobby()
for _, f in ipairs(workspace:GetChildren()) do
if f.Name:lower():find("lobby") then
for _, o in ipairs(f:GetDescendants()) do
if o:IsA("SpawnLocation") then
tweenTo(CFrame.new(o.Position + Vector3.new(0, 5, 0)), 5000, true)
return
end
end
end
end
end
local function shootMurderer()
local c, hrp = char()
if not (c and hrp) then return end
local gun = c:FindFirstChild("Gun") or LP.Backpack:FindFirstChild("Gun")
if not gun then return end
local m = Murderer and Players:FindFirstChild(Murderer)
if not (m and m.Character) then return end
local mhrp = m.Character:FindFirstChild("HumanoidRootPart")
local mhum = m.Character:FindFirstChildOfClass("Humanoid")
if not (mhrp and mhum) then return end
local vel = mhrp.AssemblyLinearVelocity or Vector3.zero
local dir = mhum.MoveDirection or Vector3.zero
local target = mhrp.Position + (vel * 0.5) * (2.8 / 15) + dir * 2.8
local origin = hrp.CFrame
local ra = hrp:FindFirstChild("RootAttachment")
if ra then origin = ra.WorldCFrame end
local ev = c:FindFirstChild("Gun") and c.Gun:FindFirstChild("Shoot")
local ev2 = workspace:FindFirstChild(LP.Name) and workspace[LP.Name]:FindFirstChild("Gun")
local shootEv = ev or (ev2 and ev2:FindFirstChild("Shoot"))
if shootEv then
pcall(function() shootEv:FireServer(origin, CFrame.new(target)) end)
end
end
local function visible(p)
local c, hrp = char()
if not (c and hrp) or not p.Character then return false end
local thrp = p.Character:FindFirstChild("HumanoidRootPart")
if not thrp then return false end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { c }
local hit = workspace:Raycast(hrp.Position, (thrp.Position - hrp.Position).Unit * 60, params)
return (not hit) or (hit.Instance:IsDescendantOf(p.Character))
end
local function fling(target)
local c, hrp = char()
if not (c and hrp) or not target or not target.Character then return end
local thrp = target.Character:FindFirstChild("HumanoidRootPart")
if not thrp then return end
local bv = Instance.new("BodyAngularVelocity")
bv.AngularVelocity = Vector3.new(0, 0, 60000)
bv.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
bv.Parent = thrp
task.delay(0.6, function() if bv then bv:Destroy() end end)
end
--// infinite jump
local function doInfJump()
local c, hrp, hum = char()
if not (hrp and hum) or hum.Health <= 0 then return end
hum:ChangeState(Enum.HumanoidStateType.Jumping)
hrp.AssemblyLinearVelocity = Vector3.new(
hrp.AssemblyLinearVelocity.X,
S.InfJumpPower,
hrp.AssemblyLinearVelocity.Z
)
end
track(UIS.JumpRequest:Connect(function()
if S.InfJump then doInfJump() end
end))
track(UIS.InputBegan:Connect(function(input, gp)
if gp then return end
if S.InfJump and input.KeyCode == Enum.KeyCode.Space then doInfJump() end
end))
--// loops
local loops = {}
loops.farm = task.spawn(function()
while true do
task.wait(0.15)
if not S.AutoFarm then continue end
pcall(function()
local c, hrp, hum = char()
if not (hrp and hum and hum.Health > 0) then return end
if not Murderer then return end
if not isAlive(LP) then return end
if trackBagFull() then
if S.KillM or S.KillAll or S.AutoShoot then return end
hum.Health = 0
return
end
local coin = (S.Mode == "Randomize") and randomCoin(hrp) or nearestCoin(hrp)
if coin and coin ~= lastCoin then
lastCoin = coin
local p = coin.CoinVisual.Position
local far = (hrp.Position - p).Magnitude > 200
if far then tweenTo(CFrame.new(p + Vector3.new(0, 10, 0)), 5000, true) end
tweenTo(CFrame.new(p + Vector3.new(0, 1.5, 0)), 24, false)
end
end)
end
end)
loops.grab = task.spawn(function()
while true do
task.wait(0.1)
if S.AutoGrab then
pcall(function()
local c, hrp = char()
local g = gunDrop()
if hrp and g and Murderer and Murderer ~= LP.Name then g.CFrame = hrp.CFrame end
end)
end
end
end)
loops.dodge = task.spawn(function()
while true do
task.wait(0.08)
if S.DodgeKnife then
pcall(function()
local c, hrp = char()
if not hrp then return end
for _, k in ipairs(workspace:GetChildren()) do
if k.Name == "ThrowingKnife" then
local b = k:FindFirstChild("BladePosition")
if b and (b.Position - hrp.Position).Magnitude <= 15 then
local pos = hrp.Position
hrp.CFrame = CFrame.new(pos.X, pos.Y + 100, pos.Z)
task.wait(0.2)
hrp.CFrame = CFrame.new(pos)
end
end
end
end)
end
end
end)
loops.aura = task.spawn(function()
while true do
task.wait()
if S.KillAura and Murderer == LP.Name then
pcall(function()
local c, hrp = char()
if not hrp then return end
local knife = c:FindFirstChild("Knife") or LP.Backpack:FindFirstChild("Knife")
if not knife then return end
equip("Knife")
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and isAlive(p) and p.Character then
local r = p.Character:FindFirstChild("HumanoidRootPart")
if r and (r.Position - hrp.Position).Magnitude <= S.AuraDist then
local k = c:FindFirstChild("Knife")
if k then pcall(function() k.Events.HandleTouched:FireServer(r) end) end
end
end
end
end)
end
end
end)
loops.killall = task.spawn(function()
while true do
task.wait(0.5)
if S.KillAll and Murderer == LP.Name then
pcall(function()
local c = char()
if not c then return end
equip("Knife")
local k = c:FindFirstChild("Knife")
if not k then return end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and isAlive(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
pcall(function() k.Events.HandleTouched:FireServer(p.Character.HumanoidRootPart) end)
end
end
end)
end
end
end)
loops.shoot = task.spawn(function()
while true do
task.wait()
if S.KillM then
pcall(function()
if trackBagFull() then return end
equip("Gun")
shootMurderer()
end)
elseif S.AutoShoot then
pcall(function()
local m = Murderer and Players:FindFirstChild(Murderer)
if Sheriff == LP.Name and m and visible(m) and not trackBagFull() then
equip("Gun")
shootMurderer()
end
end)
end
end
end)
loops.endround = task.spawn(function()
while true do
task.wait(1)
if S.EndRound and Murderer and Murderer ~= LP.Name and not isAlive(LP) then
local m = Players:FindFirstChild(Murderer)
if m then fling(m) end
end
end
end)
loops.chams = task.spawn(function()
while true do
task.wait(0.5)
if S.Chams or S.Names then
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and p.Character then
if S.Chams and not p.Character:FindFirstChild("V3zxyxHL") then
local h = Instance.new("Highlight")
h.Name = "V3zxyxHL"
h.Parent = p.Character
highlights[p] = h
end
if S.Chams and p.Character:FindFirstChild("V3zxyxHL") then
local h = p.Character.V3zxyxHL
local r = roles[p.Name]
if r and r.Role == "Murderer" then
h.FillColor = Color3.fromRGB(230, 0, 0)
elseif r and (r.Role == "Sheriff" or r.Role == "Hero") then
h.FillColor = Color3.fromRGB(0, 90, 230)
else
h.FillColor = Color3.fromRGB(76, 215, 134)
end
end
if S.Names and p.Character:FindFirstChild("Head") and not p.Character.Head:FindFirstChild("V3zxyxTag") then
local bb = Instance.new("BillboardGui")
bb.Name = "V3zxyxTag"
bb.Adornee = p.Character.Head
bb.Size = UDim2.new(0, 200, 0, 50)
bb.StudsOffset = Vector3.new(0, 2.5, 0)
bb.AlwaysOnTop = true
bb.Parent = p.Character.Head
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1, 1)
tl.BackgroundTransparency = 1
tl.Text = p.Name
tl.TextSize = 18
tl.Font = Enum.Font.SourceSansBold
tl.TextColor3 = Color3.new(1, 1, 1)
tl.TextStrokeTransparency = 0.4
tl.Parent = bb
end
end
end
else
for p, h in pairs(highlights) do
if h then h:Destroy() end
highlights[p] = nil
end
for _, p in ipairs(Players:GetPlayers()) do
if p.Character and p.Character:FindFirstChild("Head") then
local t = p.Character.Head:FindFirstChild("V3zxyxTag")
if t then t:Destroy() end
end
end
end
end
end)
loops.guncham = task.spawn(function()
while true do
task.wait(0.3)
if S.GunCham then
local g = gunDrop()
if g and not g:FindFirstChild("V3zxyxGunHL") then
local h = Instance.new("Highlight")
h.Name = "V3zxyxGunHL"
h.FillColor = Color3.fromRGB(128, 225, 0)
h.FillTransparency = 0.5
h.Parent = g
end
end
end
end)
loops.misc = task.spawn(function()
while true do
task.wait(0.2)
local c, hrp, hum = char()
if hum then
hum.WalkSpeed = S.WalkSpeed and S.WSValue or 16
if not S.InfJump then
hum.JumpPower = S.JumpPower and S.JPValue or 50
end
end
if S.AntiFling then
for _, p in ipairs(Players:GetPlayers()) do
if p ~= LP and p.Character then
for _, v in ipairs(p.Character:GetDescendants()) do
if v:IsA("BasePart") then v.CanCollide = false end
end
end
end
end
if S.AutoEmote then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
end
end)
--// void / fling recovery
local VOID_Y = workspace.FallenPartsDestroyHeight
local MAX_Y = 5000
local lastCF, outSince = nil, nil
track(RunService.Heartbeat:Connect(function()
local c, hrp, hum = char()
if not (hrp and hum) then outSince = nil return end
local y = hrp.Position.Y
if y > VOID_Y and y < MAX_Y then
if hum.FloorMaterial ~= Enum.Material.Air then lastCF = hrp.CFrame end
outSince = nil
else
outSince = outSince or os.clock()
if os.clock() - outSince > 4 and lastCF then
hrp.CFrame = lastCF + Vector3.new(0, 4, 0)
hrp.AssemblyLinearVelocity = Vector3.zero
outSince = nil
end
end
end))
--// anti-stealer
task.spawn(function()
pcall(function()
local trade = RS:WaitForChild("Trade", 10)
if not trade then return end
local decline = trade:WaitForChild("DeclineTrade", 5)
local update = trade:WaitForChild("UpdateTrade", 5)
if decline then pcall(function() decline:FireServer() end) end
if update then
track(update.OnClientEvent:Connect(function()
if decline and decline.Parent then pcall(function() decline:FireServer() end) end
end))
end
end)
end)
--// coin webhook tracker
local earned, lastCount = {}, {}
task.spawn(function()
local ev = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Gameplay") and RS.Remotes.Gameplay:FindFirstChild("CoinCollected")
if ev then
track(ev.OnClientEvent:Connect(function(bag, cur)
earned[bag] = earned[bag] or 0
lastCount[bag] = lastCount[bag] or 0
local d = cur - lastCount[bag]
if d > 0 then earned[bag] = earned[bag] + d end
lastCount[bag] = cur
end))
end
local req = (syn and syn.request) or (http and http.request) or http_request or request
while true do
task.wait(1)
if S.CoinTracker and S.Webhook ~= "" and req then
for bag, n in pairs(earned) do
if n > 0 then
pcall(function()
req({
Url = S.Webhook,
Method = "POST",
Headers = { ["Content-Type"] = "application/json" },
Body = HttpService:JSONEncode({
username = "Coin Tracker",
embeds = {{ title = "Coins", description = ("Bag: %s
Coins: %d"):format(bag, n) }},
}),
})
end)
end
end
table.clear(earned)
end
end
end)
--// UI
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "V3zxyx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = guiParent
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(290, 330)
main.Position = UDim2.new(0, 20, 0, 80)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 34)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "V3zxyx | mm2"
title.TextSize = 15
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(26, 26)
minBtn.Position = UDim2.new(1, -34, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Parent = main
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
--// collapsed logo
local logoBtn = Instance.new("TextButton")
logoBtn.Name = "V3zxyxLogo"
logoBtn.Size = UDim2.fromOffset(42, 42)
logoBtn.Position = main.Position
logoBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
logoBtn.Text = "V3"
logoBtn.Font = Enum.Font.GothamBold
logoBtn.TextSize = 15
logoBtn.TextColor3 = Color3.fromRGB(90, 220, 150)
logoBtn.AutoButtonColor = false
logoBtn.Visible = false
logoBtn.Parent = gui
Instance.new("UICorner", logoBtn).CornerRadius = UDim.new(1, 0)
local logoStroke = Instance.new("UIStroke")
logoStroke.Color = Color3.fromRGB(60, 140, 90)
logoStroke.Thickness = 1.5
logoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
logoStroke.Parent = logoBtn
local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.fromOffset(7, 7)
logoDot.Position = UDim2.new(1, -11, 1, -11)
logoDot.BackgroundColor3 = Color3.fromRGB(90, 220, 150)
logoDot.Parent = logoBtn
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 26)
tabBar.Position = UDim2.fromOffset(8, 36)
tabBar.BackgroundTransparency = 1
tabBar.ClipsDescendants = true
tabBar.Parent = main
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -76)
scroll.Position = UDim2.fromOffset(8, 68)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll
local tabHolder = Instance.new("UIListLayout")
tabHolder.FillDirection = Enum.FillDirection.Horizontal
tabHolder.Padding = UDim.new(0, 3)
tabHolder.SortOrder = Enum.SortOrder.LayoutOrder
tabHolder.Parent = tabBar
local pages, activePage = {}, nil
local function newPage()
local f = Instance.new("Frame")
f.Size = UDim2.fromScale(1, 1)
f.BackgroundTransparency = 1
f.Visible = false
f.Parent = scroll
local l = Instance.new("UIListLayout")
l.Padding = UDim.new(0, 4)
l.SortOrder = Enum.SortOrder.LayoutOrder
l.Parent = f
table.insert(pages, f)
return f
end
local function newTab(name)
local b = Instance.new("TextButton")
local tw = TextService:GetTextSize(name, 11, Enum.Font.Gotham, Vector2.new(200, 26)).X
b.Size = UDim2.fromOffset(math.ceil(tw) + 14, 26)
b.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
b.Text = name
b.Font = Enum.Font.Gotham
b.TextSize = 11
b.TextColor3 = Color3.fromRGB(200, 200, 205)
b.TextTruncate = Enum.TextTruncate.AtEnd
b.Parent = tabBar
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
local page = newPage()
b.MouseButton1Click:Connect(function()
for _, p in ipairs(pages) do p.Visible = false end
for _, t in ipairs(tabBar:GetChildren()) do
if t:IsA("TextButton") then t.BackgroundColor3 = Color3.fromRGB(28, 28, 34) end
end
page.Visible = true
b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
end)
if not activePage then
activePage = true
page.Visible = true
b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
end
return page
end
local function toggle(page, text, default, cb)
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 30)
row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
row.Parent = page
Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -46, 1, 0)
lbl.Position = UDim2.fromOffset(10, 0)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Gotham
lbl.TextSize = 12
lbl.TextColor3 = Color3.fromRGB(225, 225, 230)
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextTruncate = Enum.TextTruncate.AtEnd
lbl.Text = text
lbl.Parent = row
local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(34, 18)
btn.Position = UDim2.new(1, -42, 0.5, -9)
btn.BackgroundColor3 = default and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(45, 45, 52)
btn.Text = ""
btn.Parent = row
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
local state = default
btn.MouseButton1Click:Connect(function()
state = not state
btn.BackgroundColor3 = state and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(45, 45, 52)
cb(state)
end)
return row
end
local function button(page, text, cb)
local b = Instance.new("TextButton")
b.Size = UDim2.new(1, 0, 0, 30)
b.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
b.Font = Enum.Font.Gotham
b.TextSize = 12
b.TextColor3 = Color3.fromRGB(225, 225, 230)
b.TextTruncate = Enum.TextTruncate.AtEnd
b.Text = text
b.Parent = page
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
b.MouseButton1Click:Connect(function() pcall(cb) end)
return b
end
local function slider(page, text, min, max, default, cb)
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 40)
row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
row.Parent = page
Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -20, 0, 18)
lbl.Position = UDim2.fromOffset(10, 2)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Gotham
lbl.TextSize = 11
lbl.TextColor3 = Color3.fromRGB(200, 200, 205)
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = text .. ": " .. default
lbl.Parent = row
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, -20, 0, 8)
bar.Position = UDim2.fromOffset(10, 26)
bar.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
bar.Parent = row
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale((default - min) / (max - min), 1)
fill.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
fill.Parent = bar
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local dragging = false
local function set(x)
local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
local v = math.floor(min + (max - min) * rel + 0.5)
fill.Size = UDim2.fromScale(rel, 1)
lbl.Text = text .. ": " .. v
cb(v)
end
bar.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
end)
UIS.InputChanged:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
set(i.Position.X)
end
end)
UIS.InputEnded:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
end
--// dragging (window + logo)
local dragging, dragStart, startPos = false, nil, nil
local logoDragging, logoStart, logoOrigin, logoMoved = false, nil, nil, false
title.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
dragging, dragStart, startPos = true, i.Position, main.Position
end
end)
logoBtn.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
logoDragging, logoStart, logoOrigin, logoMoved = true, i.Position, logoBtn.Position, false
end
end)
UIS.InputChanged:Connect(function(i)
if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
if dragging then
local d = i.Position - dragStart
main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
elseif logoDragging then
local d = i.Position - logoStart
if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then logoMoved = true end
logoBtn.Position = UDim2.new(logoOrigin.X.Scale, logoOrigin.X.Offset + d.X, logoOrigin.Y.Scale, logoOrigin.Y.Offset + d.Y)
end
end)
UIS.InputEnded:Connect(function(i)
if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
dragging = false
if logoDragging then
logoDragging = false
if not logoMoved then
logoBtn.Visible = false
main.Position = logoBtn.Position
main.Visible = true
end
end
end)
minBtn.MouseButton1Click:Connect(function()
logoBtn.Position = main.Position
logoBtn.Visible = true
main.Visible = false
end)
--// pages
local pMain = newTab("Main")
local pRole = newTab("Roles")
local pVis = newTab("Visual")
local pPlayer = newTab("Player")
local pMisc = newTab("Misc")
toggle(pMain, "Auto Farm Coins", false, function(v) S.AutoFarm = v end)
button(pMain, "Farm Mode: Nearest", function()
S.Mode = S.Mode == "Nearest" and "Randomize" or "Nearest"
end)
toggle(pMain, "Auto Grab Gun", false, function(v) S.AutoGrab = v end)
toggle(pMain, "Dodge Knife", false, function(v) S.DodgeKnife = v end)
toggle(pMain, "Auto End Round (fling)", false, function(v) S.EndRound = v end)
button(pMain, "Teleport To Lobby", goLobby)
button(pMain, "Teleport To Map", function()
local m = mapModel()
if m and m:FindFirstChild("Spawns") then
local s = m.Spawns:GetChildren()[1]
if s then tweenTo(s.CFrame * CFrame.new(0, 5, 0), 5000, true) end
end
end)
toggle(pRole, "Kill Aura", false, function(v) S.KillAura = v end)
slider(pRole, "Aura Range", 5, 60, 18, function(v) S.AuraDist = v end)
toggle(pRole, "Auto Kill All", false, function(v) S.KillAll = v end)
toggle(pRole, "Silent Aim", false, function(v) S.SilentAim = v end)
toggle(pRole, "Kill Murderer (blatant)", false, function(v) S.KillM = v end)
toggle(pRole, "Auto Shoot Murderer", false, function(v) S.AutoShoot = v end)
button(pRole, "Shoot Murderer Now", function()
equip("Gun")
shootMurderer()
end)
toggle(pVis, "Player Chams", false, function(v) S.Chams = v end)
toggle(pVis, "Gun Cham", false, function(v) S.GunCham = v end)
toggle(pVis, "Name ESP", false, function(v) S.Names = v end)
toggle(pPlayer, "Walk Speed", false, function(v) S.WalkSpeed = v end)
slider(pPlayer, "Speed", 16, 120, 40, function(v) S.WSValue = v end)
toggle(pPlayer, "Jump Power", false, function(v) S.JumpPower = v end)
slider(pPlayer, "Jump", 50, 200, 90, function(v) S.JPValue = v end)
toggle(pPlayer, "Infinite Jump", false, function(v) S.InfJump = v end)
slider(pPlayer, "Inf Jump Height", 30, 200, 70, function(v) S.InfJumpPower = v end)
toggle(pPlayer, "Anti Fling", false, function(v) S.AntiFling = v end)
button(pPlayer, "Invisible (chair)", function()
local c = char()
if not c then return end
if invisChair and invisChair.Parent then
invisChair:Destroy()
return
end
local hrp = c:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local pos = hrp.CFrame
local seat = Instance.new("Seat")
seat.Anchored = false
seat.CanCollide = false
seat.Transparency = 1
seat.Name = "V3zxyxInvis"
seat.Parent = workspace
local w = Instance.new("Weld", seat)
w.Part0 = seat
w.Part1 = hrp
seat.CFrame = pos
invisChair = seat
end)
toggle(pMisc, "Coin Webhook Tracker", false, function(v) S.CoinTracker = v end)
local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(1, 0, 0, 30)
webhookBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
webhookBox.PlaceholderText = "Discord webhook URL"
webhookBox.Text = ""
webhookBox.Font = Enum.Font.Gotham
webhookBox.TextSize = 11
webhookBox.TextColor3 = Color3.new(1, 1, 1)
webhookBox.Parent = pMisc
Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0, 6)
webhookBox.FocusLost:Connect(function() S.Webhook = webhookBox.Text end)
button(pMisc, "Unload Script", function() getgenv().V3zxyx_Cleanup() end)
--// silent aim hook on gun activation
local aimConn
task.spawn(function()
while true do
task.wait(0.3)
local c = LP.Character
local gun = c and c:FindFirstChild("Gun")
if not S.SilentAim or not gun or Sheriff ~= LP.Name then
if aimConn then aimConn:Disconnect() aimConn = nil end
elseif gun and not aimConn then
aimConn = gun.Activated:Connect(function()
local m = Murderer and Players:FindFirstChild(Murderer)
if not (m and m.Character) then return end
local r = m.Character:FindFirstChild("HumanoidRootPart")
local c2, hrp = char()
if not (r and hrp) then return end
local ev = gun:FindFirstChild("Shoot")
if ev then pcall(function() ev:FireServer(hrp.CFrame, r.CFrame) end) end
end)
end
end
end)
getgenv().V3zxyx_Cleanup = function()
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
for _, l in ipairs(loops) do pcall(function() task.cancel(l) end) end
if aimConn then pcall(function() aimConn:Disconnect() end) end
pcall(function() gui:Destroy() end)
for p, h in pairs(highlights) do pcall(function() h:Destroy() end) end
getgenv().V3zxyx_Cleanup = nil
end
print("[V3zxyx] loaded")