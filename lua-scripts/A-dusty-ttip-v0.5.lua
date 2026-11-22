-- ============================================================================
-- DUSTY TRIP HUB [v1 - GUI PROPIO, MINIMALISTA]
-- Mismas funciones que el script anterior: aim, ESP, TP spawn, veh, loot...
-- Copia y pega en la consola de Roblox.
-- ============================================================================

local CONFIG = {
	LogTag = "DUSTY-TRIP-HUB",
	VerboseLog = true,
	EnemyCacheInterval = 0.35,
}

local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local CG = game:GetService("CoreGui")
local Plrs = game:GetService("Players")

local LP = Plrs.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()
local SessionId = "TS-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))

local Caps = {
	gethui = typeof(gethui) == "function",
	syn = syn ~= nil and typeof(syn.protect_gui) == "function",
	getrawmetatable = typeof(getrawmetatable) == "function",
	hookmetamethod = typeof(hookmetamethod) == "function",
	checkcaller = typeof(checkcaller) == "function",
	setreadonly = typeof(setreadonly) == "function",
	getnamecallmethod = typeof(getnamecallmethod) == "function",
}

local function resolveParentGui()
	local candidates = {}
	pcall(function()
		if Caps.gethui then
			local h = gethui()
			if h then table.insert(candidates, h) end
		end
	end)
	pcall(function()
		if Caps.syn then
			local g = Instance.new("ScreenGui")
			syn.protect_gui(g)
			g.Parent = CG
			table.insert(candidates, g)
		end
	end)
	table.insert(candidates, CG)
	table.insert(candidates, LP:WaitForChild("PlayerGui"))
	for _, c in ipairs(candidates) do
		local ok, p = pcall(function()
			local probe = Instance.new("ScreenGui")
			probe.Parent = c
			if probe.Parent ~= c then error("rechazado") end
			probe:Destroy()
			return c
		end)
		if ok and p then return p end
	end
	return LP:WaitForChild("PlayerGui")
end

local ParentGui = resolveParentGui()
if ParentGui:FindFirstChild("NexusHubPropio") then ParentGui.NexusHubPropio:Destroy() end
local SG = Instance.new("ScreenGui")
SG.Name = "NexusHubPropio"
SG.ResetOnSpawn = false
SG.DisplayOrder = 2147483647
local parentOK = pcall(function() SG.Parent = ParentGui end)
if not parentOK or SG.Parent ~= ParentGui then
	ParentGui = LP:WaitForChild("PlayerGui")
	SG.Parent = ParentGui
end

-- Paleta Dusty Trip (tierra/rojo + textos crema)
local Theme = {
	BgMain = Color3.fromRGB(20, 16, 12),
	Surface = Color3.fromRGB(28, 22, 15),
	SurfaceAlt = Color3.fromRGB(44, 33, 21),
	Border = Color3.fromRGB(80, 55, 30),
	Accent = Color3.fromRGB(232, 110, 18),
	AccentRust = Color3.fromRGB(212, 82, 20),
	AccentGold = Color3.fromRGB(255, 185, 80),
	CyanSignal = Color3.fromRGB(86, 210, 225),
	ActiveBg = Color3.fromRGB(20, 57, 27),
	ActiveBorder = Color3.fromRGB(58, 175, 75),
	ActivePill = Color3.fromRGB(60, 190, 95),
	InactivePill = Color3.fromRGB(30, 22, 14),
	Danger = Color3.fromRGB(218, 46, 40),
	TextMain = Color3.fromRGB(248, 242, 215),
	TextMuted = Color3.fromRGB(188, 168, 138),
	TextPlaceholder = Color3.fromRGB(128, 108, 82),
	DarkInk = Color3.fromRGB(14, 11, 9),
}

local METERS_TO_STUDS = 3.5714
local ESP_MAX_RANGE = 220

-- Estado
local State = {
	Running = true,
	SilentAim = false, Aimbot = false, AimSmooth = 12, AimPart = "Head",
	ShowFOV = true, FOVRadius = 135, Triggerbot = false, KillAura = false,
	Hitbox = false, HitboxScale = 2, Wallbang = false, NoRecoil = false,
	InfAmmo = false, GodMode = false,
	Speed = false, SpeedVal = 35, Jump = false, JumpVal = 100,
	Fly = false, FlyVal = 55, FlyBoostMult = 2.2,
	InfJump = false, InfStamina = false, Noclip = false,
	TPActive = false, TPActiveMeters = 0, TPOriginZ = 0, TPRate = 280,
	SpawnOrigin = nil, SpawnCaptured = false,
	ESPItems = false, ESPEnemies = false,
}

-- Utilidades de movimiento
local function getHRP()
	return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") or nil
end
local function getHum()
	return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") or nil
end
local function clearMotion(p)
	if p and p:IsA("BasePart") then
		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
	end
end
local function getSeatedVehicleModel(hum)
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("BasePart") then
		local mdl = seat:FindFirstAncestorOfClass("Model")
		if mdl and mdl ~= LP.Character then return mdl end
	end
	return nil
end
local function moveVehicleIfSeated(hum, c)
	local veh = getSeatedVehicleModel(hum)
	if not veh then return false end
	pcall(function()
		for _, p in ipairs(veh:GetDescendants()) do
			if p:IsA("BasePart") then clearMotion(p) end
		end
		veh:PivotTo(c + Vector3.new(0, 2, 0))
	end)
	return true
end
local function findSafeGroundY(x, z, startY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(x, startY or 600, z), Vector3.new(0, -1200, 0), params)
	return hit and (hit.Position.Y + 4) or nil
end

-- Captura del spawn (reusable)
local function captureSpawnOrigin(hrp)
	if hrp and hrp:IsA("BasePart") then
		State.SpawnOrigin = hrp.Position
		State.SpawnCaptured = true
		return true
	end
	return false
end
local function getSpawnOrigin()
	if State.SpawnCaptured and State.SpawnOrigin then return State.SpawnOrigin end
	return getHRP() and getHRP().Position or nil
end

-- Cache de enemigos
local CachedEnemies = {}
local CachedFOVTarget = nil
local function refreshEnemyCache()
	local list = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Health > 0 and obj.Parent
			and obj.Parent:IsA("Model") and obj.Parent ~= LP.Character
			and not Plrs:GetPlayerFromCharacter(obj.Parent) then
			local root = obj.Parent:FindFirstChild("HumanoidRootPart") or obj.RootPart or obj.Parent.PrimaryPart
			if root and root:IsA("BasePart") then table.insert(list, obj.Parent) end
		end
	end
	CachedEnemies = list
end
local function getEnemies()
	if #CachedEnemies == 0 then refreshEnemyCache() end
	return CachedEnemies
end

-- Pool de ESP
local ESPContainer = Instance.new("Frame")
ESPContainer.Name = "DTH_ESPContainer"
ESPContainer.Size = UDim2.fromScale(1, 1)
ESPContainer.BackgroundTransparency = 1
ESPContainer.Visible = false
ESPContainer.Parent = SG

local ESPPool = {}

local function createESPItem()
	local h = Instance.new("Frame")
	h.Size = UDim2.fromScale(1, 1)
	h.BackgroundTransparency = 1
	h.Visible = false
	h.Parent = ESPContainer

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(60, 90)
	box.BackgroundColor3 = Theme.CyanSignal
	box.BackgroundTransparency = 0.90
	box.BorderSizePixel = 0
	box.Parent = h
	Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBG"
	hpBg.Size = UDim2.new(0, 86, 0, 12)
	hpBg.Position = UDim2.new(0.5, -43, 1, 4)
	hpBg.AnchorPoint = Vector2.new(0.5, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(8, 6, 4)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = h
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.AnchorPoint = Vector2.new(0, 1)
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Theme.ActivePill
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local nameTag = Instance.new("TextLabel")
	nameTag.Size = UDim2.new(1, 0, 0, 14)
	nameTag.Position = UDim2.new(0.5, -50, 0, -18)
	nameTag.AnchorPoint = Vector2.new(0.5, 0)
	nameTag.Font = Enum.Font.GothamBold
	nameTag.TextSize = 9
	nameTag.TextColor3 = Theme.CyanSignal
	nameTag.BackgroundTransparency = 1
	nameTag.TextXAlignment = Enum.TextXAlignment.Center
	nameTag.TextTruncate = Enum.TextTruncate.AtEnd
	nameTag.Parent = h

	local hpTag = Instance.new("TextLabel")
	hpTag.Size = UDim2.new(0, 90, 0, 11)
	hpTag.Position = UDim2.new(0.5, -45, 1, 8)
	hpTag.AnchorPoint = Vector2.new(0.5, 0)
	hpTag.Font = Enum.Font.Gotham
	hpTag.TextSize = 8
	hpTag.TextColor3 = Theme.TextMain
	hpTag.BackgroundTransparency = 0.6
	hpTag.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
	hpTag.Parent = h
	Instance.new("UICorner", hpTag).CornerRadius = UDim.new(0, 5)

	local headDot = Instance.new("Frame")
	headDot.AnchorPoint = Vector2.new(0.5, 0.5)
	headDot.Size = UDim2.fromOffset(8, 8)
	headDot.BackgroundColor3 = Theme.Accent
	headDot.BorderSizePixel = 0
	headDot.Visible = false
	headDot.Parent = h
	Instance.new("UICorner", headDot).CornerRadius = UDim.new(1, 0)

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(28, 28)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = h
	local ringStroke = Instance.new("UIStroke", ring)
	ringStroke.Color = Theme.Danger
	ringStroke.Thickness = 1.4
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

	local ptr = Instance.new("Frame")
	ptr.AnchorPoint = Vector2.new(0.5, 0)
	ptr.Size = UDim2.new(0, 8, 1, -22)
	ptr.BackgroundColor3 = Theme.AccentGold
	ptr.BorderSizePixel = 0
	ptr.Visible = false
	ptr.Parent = h
	Instance.new("UICorner", ptr).CornerRadius = UDim.new(1, 0)

	return { Holder = h, Box = box, HPBg = hpBg, HPFill = hpFill,
		NameTag = nameTag, HpTag = hpTag, HeadDot = headDot, Ring = ring, Pointer = ptr }
end

local function getProjectedEnemyBox(model, root)
	if not Cam then return nil end
	local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
	if not ok or typeof(size) ~= "Vector3" or size.Magnitude < 0.1 then
		cf = root.CFrame
		size = Vector3.new(4, 6, 3)
	end
	local half = size * 0.5
	local mnX, mnY = math.huge, math.huge
	local mxX, mxY = -math.huge, -math.huge
	local anyVisible = false
	for _, d in ipairs({
		cf * Vector3.new(-half.X, -half.Y, -half.Z), cf * Vector3.new(-half.X, -half.Y,  half.Z),
		cf * Vector3.new(-half.X,  half.Y, -half.Z), cf * Vector3.new(-half.X,  half.Y,  half.Z),
		cf * Vector3.new( half.X, -half.Y, -half.Z), cf * Vector3.new( half.X, -half.Y,  half.Z),
		cf * Vector3.new( half.X,  half.Y, -half.Z), cf * Vector3.new( half.X,  half.Y,  half.Z),
	}) do
		local pt, on = Cam:WorldToViewportPoint(d)
		if pt.Z > 0 then
			if on then anyVisible = true end
			mnX = math.min(mnX, pt.X); mxX = math.max(mxX, pt.X)
			mnY = math.min(mnY, pt.Y); mxY = math.max(mxY, pt.Y)
		end
	end
	if not anyVisible or mxX <= mnX or mxY <= mnY then return nil end
	return mnX, mnY, mxX, mxY
end

local function updateAdvancedESP()
	if not State.Running or not State.ESPEnemies then
		ESPContainer.Visible = false
		for _, it in ipairs(ESPPool) do it.Holder.Visible = false end
		return
	end
	local hrp = getHRP()
	if not hrp then
		ESPContainer.Visible = false
		return
	end
	ESPContainer.Visible = true
	local enemies = getEnemies()
	for i = #ESPPool + 1, #enemies do ESPPool[i] = createESPItem() end

	for i, it in ipairs(ESPPool) do
		local e = enemies[i]
		local hum = e and e:FindFirstChildOfClass("Humanoid")
		local root = e and ((e:FindFirstChild("HumanoidRootPart")) or (hum and hum.RootPart) or e.PrimaryPart)
		if not e or not e.Parent or not hum or hum.Health <= 0 or not root then
			it.Holder.Visible = false
			continue
		end
		local dist = (root.Position - hrp.Position).Magnitude
		if dist > ESP_MAX_RANGE then
			it.Holder.Visible = false
			continue
		end
		local mnX, mnY, mxX, mxY = getProjectedEnemyBox(e, root)
		if not mnX then
			it.Holder.Visible = false
			continue
		end
		it.Holder.Visible = true
		local w = math.max(14, mxX - mnX)
		local h = math.max(14, mxY - mnY)
		it.Box.Size = UDim2.fromOffset(w, h)
		it.Box.Position = UDim2.fromOffset(mnX, mnY)

		local isTarget = CachedFOVTarget and CachedFOVTarget.Parent
			and (CachedFOVTarget:FindFirstAncestorOfClass("Model") == e) or false
		local accent = isTarget and Theme.Danger
			or (dist < 45 and Theme.Accent)
			or (dist < 120 and Theme.AccentGold)
			or Theme.CyanSignal
		it.Box.BackgroundColor3 = accent
		it.NameTag.Text = "HOSTILE: " .. e.Name:upper()
		it.NameTag.TextColor3 = accent
		local pct = math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100 + 0.5)
		it.HpTag.Text = "[" .. math.floor(dist) .. "m] HP " .. pct .. "%"
		it.HpTag.TextColor3 = isTarget and Theme.Danger or Theme.TextMuted
		it.HPFill.Size = UDim2.fromScale(1, math.clamp(pct / 100, 0, 1))
		it.HPFill.BackgroundColor3 = pct > 55 and Theme.ActivePill
			or (pct > 20 and Theme.AccentGold or Theme.Danger)

		local head = e:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local pt, on = Cam:WorldToViewportPoint(head.Position)
			it.HeadDot.Visible = on and pt.Z > 0
			if it.HeadDot.Visible then
				it.HeadDot.Position = UDim2.fromOffset(pt.X, pt.Y)
				it.HeadDot.BackgroundColor3 = isTarget and Theme.Danger or Theme.Accent
				it.Ring.Visible = isTarget
				if it.Ring.Visible then it.Ring.Position = UDim2.fromOffset(pt.X, pt.Y) end
			end
		else
			it.HeadDot.Visible = false
		end

		it.Pointer.Position = UDim2.fromOffset(mnX + w * 0.5, mxY + 4)
		it.Pointer.Visible = true
	end
end

-- ============================================================================
-- TP POR METROS (contando desde SPAWN)
-- ============================================================================
local function startMeterFlyTP(meters)
	local hrp = getHRP()
	if not hrp or typeof(meters) ~= "number" then return end
	local origin = getSpawnOrigin()
	if not origin then
		notify("TP Fly", "Spawn no detectado, pon te en spawn", Theme.Danger)
		return
	end
	State.TPActiveMeters = meters
	State.TPOriginZ = origin.Z
	State.TPActive = true
	clearMotion(hrp)
	notify("TP Fly", "Rumbo a " .. meters .. "m desde spawn", Theme.Accent)
end

local function stepMeterFlyTP(dt)
	if not State.TPActive then return end
	local hrp = getHRP()
	if not hrp then State.TPActive = false return end
	clearMotion(hrp)
	local targetZ = State.TPOriginZ - State.TPActiveMeters * METERS_TO_STUDS
	local dist = math.abs(targetZ - hrp.Position.Z)
	local step = State.TPRate * dt
	if dist <= step then
		hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, targetZ)
		State.TPActive = false
		notify("TP Fly", "Frenado exacto en " .. State.TPActiveMeters .. "m desde spawn", Theme.ActiveBorder)
		return
	end
	hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z + (targetZ > hrp.Position.Z and 1 or -1) * step)
end

-- ============================================================================
-- SILENT AIM HOOK
-- ============================================================================
local silentAimInstalled = false
local hookReady = false
local hookingActive = false
local oldNamecall = nil

local function installSilentAimHook()
	if silentAimInstalled and hookReady then return end
	silentAimInstalled = true
	pcall(function()
		local rawMT = getrawmetatable and getrawmetatable(game)
		if not rawMT or not hookmetamethod or not checkcaller then return end
		if isreadonly and isreadonly(rawMT) then pcall(setreadonly, rawMT, false) end

		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if hookingActive or not State.Running or not State.SilentAim or checkcaller() then
				return oldNamecall(self, ...)
			end
			local t = CachedFOVTarget
			if t and t.Parent and self == workspace then
				local m = getnamecallmethod()
				if m == "Raycast" or m == "raycast" then
					local a = { ... }
					if typeof(a[1]) == "Vector3" then
						hookingActive = true
						local d = t.Position - a[1]
						a[2] = d.Unit * math.clamp(d.Magnitude + 15, 10, 600)
						hookingActive = false
						return oldNamecall(self, table.unpack(a))
					end
				end
			end
			return oldNamecall(self, ...)
		end)
		hookReady = true
	end)
end

-- ============================================================================
-- HERRAMIENTAS + LOOT + VEHICULO
-- ============================================================================
local OriginalHeads = setmetatable({}, { __mode = "k" })

local function syncHitboxes(on)
	for _, e in ipairs(getEnemies()) do
		local head = e:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			if on and not OriginalHeads[head] then
				OriginalHeads[head] = { Size = head.Size, Transparency = head.Transparency }
				head.Size = Vector3.new(6, 6, 6) * State.HitboxScale
				head.Transparency = 0.35
			elseif not on and OriginalHeads[head] then
				head.Size = OriginalHeads[head].Size
				head.Transparency = OriginalHeads[head].Transparency
			end
		end
	end
end

local function applyCharacterMods(char)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		if State.Speed then hum.WalkSpeed = State.SpeedVal end
		if State.Jump then
			hum.UseJumpPower = true
			hum.JumpPower = State.JumpVal
		end
	end
	if State.Noclip then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end

local function bringItems(keywords)
	local hrp = getHRP()
	if not hrp then return end
	local mine = LP.Character
	local total = 0
	for _, item in ipairs(workspace:GetDescendants()) do
		local isMine = mine and item:IsDescendantOf(mine)
		if isMine then continue end
		local n = item.Name:lower()
		for _, kw in ipairs(keywords) do
			if n:find(kw, 1, true) then
				if item:IsA("BasePart") and not item.Anchored then
					item.CFrame = hrp.CFrame + Vector3.new(0, 2, -3)
					total += 1
				elseif item:IsA("Model") and item.PrimaryPart and not item.PrimaryPart.Anchored then
					item:PivotTo(hrp.CFrame + Vector3.new(0, 2, -3))
					total += 1
				end
				break
			end
		end
	end
	notify("Loot", "Trajiste: " .. total, Theme.AccentGold)
end

-- ============================================================================
-- NOTIFICACIONES
-- ============================================================================
local function notify(title, desc, accent)
	if not State.Running then return end
	if CONFIG.VerboseLog then
		print(string.format("[%s] %s :: %s", CONFIG.LogTag, title, desc))
	end
	task.spawn(function()
		local c = Instance.new("Frame")
		c.Size = UDim2.new(0.22, 0, 0, 44)
		c.BackgroundColor3 = Theme.Surface
		c.Parent = SG
		c:AnchorPoint = Vector2.new(1, 0)
		c.Position = UDim2.new(1, -18, 0, 12)
		Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -8, 1, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 9
		t.TextColor3 = Theme.TextMain
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.Parent = c
		t.Text = "  " .. title .. "\n  " .. desc
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 4, 1, -10)
		bar.Position = UDim2.new(0, 8, 0, 5)
		bar.BackgroundColor3 = accent or Theme.Accent
		bar.Parent = c
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		TS:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(1, -260, 0, 12) }):Play()
		task.wait(2.1)
		local tw = TS:Create(c, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, -18, 0, 12) })
		tw:Play()
		tw.Completed:Wait()
		if c.Parent then c:Destroy() end
	end)
end

-- ============================================================================
-- GUI
-- ============================================================================
local Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.fromOffset(420, 420)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Theme.BgMain
Main.ClipsDescendants = true
Main.Parent = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Theme.Surface
titleBar.Parent = Main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleL = Instance.new("TextLabel")
titleL.Text = "🌵 DUSTY TRIP HUB"
titleL.Font = Enum.Font.GothamBold
titleL.TextSize = 12
titleL.TextColor3 = Theme.TextMain
titleL.BackgroundTransparency = 1
titleL.TextXAlignment = Enum.TextXAlignment.Left
titleL.Size = UDim2.new(1, -60, 0, 48)
titleL.Position = UDim2.new(0, 14, 0, 0)
titleL.Parent = titleBar

local closeB = Instance.new("TextButton")
closeB.Size = UDim2.fromOffset(28, 28)
closeB.Position = UDim2.new(1, -32, 0.5, -14)
closeB.BackgroundColor3 = Theme.Danger
closeB.Text = "✕"
closeB.Font = Enum.Font.GothamBold
closeB.TextSize = 12
closeB.Parent = titleBar
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 8)

local miniB = Instance.new("TextButton")
miniB.Size = UDim2.fromOffset(28, 28)
miniB.Position = UDim2.new(1, -64, 0.5, -14)
miniB.BackgroundColor3 = Theme.SurfaceAlt
miniB.Text = "—"
miniB.Font = Enum.Font.GothamBold
miniB.TextSize = 12
miniB.Parent = titleBar
Instance.new("UICorner", miniB).CornerRadius = UDim.new(0, 8)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -4, 1, -58)
Scroll.Position = UDim2.new(2, 0, 54, 0)
Scroll.BackgroundTransparency = 1
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Theme.Accent
Scroll.Parent = Main

local pages, tabBtns = {}, {}
local function addTab(name, icon)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.19, 0, 0, 26)
	btn.BackgroundColor3 = Theme.Surface
	btn.Text = icon .. " " .. name
	btn.TextColor3 = Theme.TextMuted
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 9
	btn.AutoButtonColor = false
	btn.Parent = Scroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
	pages[name] = Instance.new("Frame")
	pages[name].Size = UDim2.new(1, 0, 1, 0)
	pages[name].BackgroundTransparency = 1
	pages[name].Visible = false
	pages[name].Parent = Scroll
	tabBtns[name] = btn
	btn.MouseButton1Click:Connect(function()
		for n, p in pairs(pages) do
			p.Visible = (n == name)
		end
	end)
	return pages[name]
end
local pCombate = addTab("Combate", "🎯")
local pTP = addTab("TP", "📍")
local pLoot = addTab("Loot", "🧲")
local pVeh = addTab("Veh", "🚗")
pCombate.Visible = true
tabBtns["Combate"].BackgroundColor3 = Theme.Accent
tabBtns["Combate"].TextColor3 = Theme.DarkInk

-- FOV circle (se muestra sobre todo el juego)
local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "DTH_FOVFrame"
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.fromOffset(270, 270)
FOVFrame.BackgroundColor3 = Theme.Accent
FOVFrame.BackgroundTransparency = 0.94
FOVFrame.Visible = false
FOVFrame.Parent = SG
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Theme.Accent
fovStroke.Thickness = 1.6
fovStroke.Parent = FOVFrame

-- Helpers de GUI
local function sec(parent, text)
	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, 0, 0, 14)
	s.BackgroundTransparency = 1
	s.Text = string.upper(text)
	s.Font = Enum.Font.GothamBold
	s.TextSize = 8
	s.TextColor3 = Theme.AccentGold
	s.Parent = parent
	return s
end

local function makeBtn(text, bg, parent, cb, sizeH)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, sizeH or 34)
	b.BackgroundColor3 = bg or Theme.SurfaceAlt
	b.Text = text
	b.TextColor3 = Theme.TextMain
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(math.clamp(base.R * 255 + 20, 0, 255),
				math.clamp(base.G * 255 + 18, 0, 255), math.clamp(base.B * 255 + 14, 0, 255))
		}):Play()
	end)
	b.MouseLeave:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function makeTgl(text, parent, cb, initial)
	local active = initial or false
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = active and Theme.ActiveBg or Theme.Surface
	b.Text = "   " .. text
	b.TextColor3 = active and Theme.TextMain or Theme.TextMuted
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local sk = Instance.new("UIStroke", b)
	sk.Color = active and Theme.ActiveBorder or Theme.Border
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.new(0, 44, 0, 20)
	pill.Position = UDim2.new(1, -52, 0.5, -10)
	pill.BackgroundColor3 = active and Theme.ActivePill or Theme.InactivePill
	pill.Text = active and "ON" or "OFF"
	pill.TextColor3 = active and Theme.DarkInk or Theme.TextMuted
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 8
	pill.Parent = b
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)
	b.MouseButton1Click:Connect(function()
		active = not active
		pill.Text = active and "ON" or "OFF"
		TS:Create(b, TweenInfo.new(0.16), {
			BackgroundColor3 = active and Theme.ActiveBg or Theme.Surface,
			TextColor3 = active and Theme.TextMain or Theme.TextMuted,
		}):Play()
		TS:Create(pill, TweenInfo.new(0.16), {
			BackgroundColor3 = active and Theme.ActivePill or Theme.InactivePill,
			TextColor3 = active and Theme.DarkInk or Theme.TextMuted,
		}):Play()
		sk.Color = active and Theme.ActiveBorder or Theme.Border
		notify("Dusty Trip Hub", text .. (active and " activado" or " desactivado"),
			active and Theme.ActiveBorder or Theme.Danger)
		cb(active)
	end)
	return b
end

local function makeSld(label, minV, maxV, defV, parent, cb)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 42)
	card.BackgroundColor3 = Theme.Surface
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local top = Instance.new("TextLabel")
	top.Size = UDim2.new(1, -18, 0, 14)
	top.Position = UDim2.new(0, 9, 0, 4)
	top.BackgroundTransparency = 1
	top.Text = label .. ": " .. defV
	top.TextColor3 = Theme.TextMain
	top.Font = Enum.Font.GothamMedium
	top.TextSize = 9
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.Parent = card
	local hitZone = Instance.new("TextButton")
	hitZone.Size = UDim2.new(1, -12, 0, 22)
	hitZone.Position = UDim2.new(0, 6, 0, 17)
	hitZone.BackgroundTransparency = 1
	hitZone.AutoButtonColor = false
	hitZone.Parent = card
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -6, 0, 7)
	bar.Position = UDim2.new(0, 3, 0.5, -3.5)
	bar.BackgroundColor3 = Theme.InactivePill
	bar.Parent = hitZone
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp((defV - minV) / (maxV - minV), 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Theme.Accent
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local sliding = false
	local function applyInput(input)
		local r = math.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor(minV + (maxV - minV) * r + 0.5)
		fill.Size = UDim2.new(r, 0, 1, 0)
		top.Text = label .. ": " .. val
		cb(val)
	end
	hitZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			applyInput(input)
		end
	end)
	hitZone.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			sliding = false
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyInput(input)
		end
	end)
	return card
end

-- ============================================================================
-- COMBATE
-- ============================================================================
local function buildCombate()
	local parent = pCombate
	sec(parent, "Puntería y FOV")
	makeTgl("👻 Silente Aim (En FOV)", parent, function(s)
		State.SilentAim = s
		if s then refreshEnemyCache() installSilentAimHook() end
	end)
	makeTgl("🎯 Aimbot Suave", parent, function(s)
		State.Aimbot = s
		if s then refreshEnemyCache() end
	end)
	makeSld("Suavizado Aimbot", 1, 30, State.AimSmooth, parent, function(v) State.AimSmooth = v end)
	makeSld("Radio FOV (px)", 35, 340, State.FOVRadius, parent, function(v) State.FOVRadius = v end)

	sec(parent, "Parte objetivo")
	makeBtn("🧠 Head", Theme.SurfaceAlt, parent, function()
		State.AimPart = "Head"
		notify("Parte Objetivo", "Apuntando a: Head", Theme.Accent)
	end)
	makeBtn("🦺 Torso", Theme.SurfaceAlt, parent, function()
		State.AimPart = "Torso"
		notify("Parte Objetivo", "Apuntando a: Torso", Theme.Accent)
	end)
	makeBtn("⚙️ HumanoidRootPart", Theme.SurfaceAlt, parent, function()
		State.AimPart = "HumanoidRootPart"
		notify("Parte Objetivo", "Apuntando a: HumanoidRootPart", Theme.Accent)
	end)

	sec(parent, "Armas, Enemigos & Supervivencia")
	makeTgl("🔫 Triggerbot (En mira)", parent, function(s) State.Triggerbot = s end)
	makeTgl("🗡️ Kill Aura (35m)", parent, function(s) State.KillAura = s end)
	makeTgl("💥 Hitbox Extendido", parent, function(s) State.Hitbox = s syncHitboxes(s) end)
	makeSld("Multiplicador Hitbox", 1, 5, State.HitboxScale, parent, function(v)
		State.HitboxScale = v
		if State.Hitbox then syncHitboxes(true) end
	end)
	makeTgl("🧱 Wallbang", parent, function(s) State.Wallbang = s end)
	makeTgl("🎯 No Recoil", parent, function(s) State.NoRecoil = s end)
	makeTgl("♾️ Munición Infinita", parent, function(s) State.InfAmmo = s end)
	makeTgl("🛡️ God Mode", parent, function(s) State.GodMode = s end)

	sec(parent, "ESP enemigos")
	makeTgl("👾 ESP enemigos (HUD)", parent, function(s)
		State.ESPEnemies = s
		if s then refreshEnemyCache() end
	end)

	-- Stats
	local statsH = Instance.new("TextLabel")
	statsH.Text = "── STATS (mapa real) ──"
	statsH.Font = Enum.Font.GothamBold
	statsH.TextSize = 9
	statsH.TextColor3 = Theme.AccentGold
	statsH.BackgroundTransparency = 1
	statsH.Size = UDim2.new(1, 0, 0, 16)
	statsH.Parent = parent
	local statsB = Instance.new("TextLabel")
	statsB.Font = Enum.Font.Gotham
	statsB.TextSize = 8
	statsB.TextColor3 = Theme.TextMuted
	statsB.TextXAlignment = Enum.TextXAlignment.Left
	statsB.Size = UDim2.new(1, -4, 0, 72)
	statsB.BackgroundColor3 = Theme.Surface
	statsB.BackgroundTransparency = 0.14
	statsB.Parent = parent
	Instance.new("UICorner", statsB).CornerRadius = UDim.new(0, 7)

	local function dashScan()
		local vehicles, weapons, otherModels, pickups, total = {}, {}, {}, {}, 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("MeshPart") then
				local seat = obj:FindFirstChildWhichIsA("VehicleSeat", true)
				if seat then table.insert(vehicles, obj.Name)
				else
					table.insert(otherModels, obj.Name)
					local n = obj.Name:lower()
					for _, kw in ipairs({"cap","chapa","coin","scrap","bottle","gun","ammo","rifle","pistol","shotgun","bullet","c4","gold","engine","motor","nut","bolt","wrench","jack","tire","sponge","food","water"}) do
						if n:find(kw, 1, true) then table.insert(pickups, obj.Name); break end
					end
				end
				total += 1
			end
		end
		return vehicles, weapons, otherModels, pickups, total
	end

	local function dashUpdate()
		if not State.Running then return end
		local veh, wp, other, pickups, total = dashScan()
		local names = {}
		for _, n in ipairs(veh) do table.insert(names, n) end
		statsB.Text = table.concat({
			"[ DUSTY TRIP — STATS ]",
			string.format(" players: %d | cars: %d %s", #Plrs:GetPlayers(), #veh, table.concat(names, ", ")),
			string.format(" modelos: %d | pickups: %d %s", #other, #pickups, table.concat(pickups, ", ")),
			string.format(" enemigos: %d | objetos: %d", #getEnemies(), total),
		}, "\n")
	end

	makeBtn("📄 Dump: modelos reales", Theme.SurfaceAlt, parent, function()
		local count = 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("MeshPart") then
				count += 1
				print(string.format("[%s] REAL_MODEL name=%q class=%s pos=%.0f,%.0f,%.0f",
					CONFIG.LogTag, obj.Name, obj.ClassName, obj.Position.X, obj.Position.Y, obj.Position.Z))
			end
		end
		notify("Scan", "Dumped " .. count .. " modelos reales", Theme.AccentGold)
	end)

	task.spawn(function()
		while State.Running and task.wait(1) do
			dashUpdate()
		end
	end)
end

-- ============================================================================
-- PLAYER
-- ============================================================================
local function buildPlayer()
	local parent = pCombate
	sec(parent, "Movimiento")
	makeTgl("⚡ Velocidad personalizada", parent, function(s)
		State.Speed = s
		local hum = getHum()
		if hum then hum.WalkSpeed = s and State.SpeedVal or 16 end
	end)
	makeSld("Velocidad", 16, 120, State.SpeedVal, parent, function(v)
		State.SpeedVal = v
		local hum = getHum()
		if State.Speed and hum then hum.WalkSpeed = v end
	end)
	makeTgl("🦘 Potencia de salto", parent, function(s)
		State.Jump = s
		local hum = getHum()
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = s and State.JumpVal or 50
		end
	end)
	makeSld("Salto", 50, 300, State.JumpVal, parent, function(v)
		State.JumpVal = v
		local hum = getHum()
		if State.Jump and hum then hum.JumpPower = v end
	end)
	makeTgl("✈️ Vuelo CFrame", parent, function(s)
		State.Fly = s
		clearMotion(getHRP())
	end)
	makeSld("Velocidad de vuelo", 10, 220, State.FlyVal, parent, function(v) State.FlyVal = v end)
	makeTgl("♾️ Salto infinito", parent, function(s) State.InfJump = s end)
	makeTgl("💨 Stamina infinita", parent, function(s) State.InfStamina = s end)
	makeTgl("👻 Noclip", parent, function(s)
		State.Noclip = s
		if not s and LP.Character then
			for _, part in ipairs(LP.Character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
	end)
end

-- ============================================================================
-- TP POR METROS
-- ============================================================================
local meterBox = Instance.new("TextBox")
meterBox.Size = UDim2.new(1, 0, 0, 32)
meterBox.BackgroundColor3 = Theme.Surface
meterBox.PlaceholderText = "Ingresar metros (ej. 1500)..."
meterBox.PlaceholderColor3 = Theme.TextPlaceholder
meterBox.TextColor3 = Theme.TextMain
meterBox.Font = Enum.Font.Gotham
meterBox.TextSize = 10
meterBox.Parent = pTP
Instance.new("UICorner", meterBox).CornerRadius = UDim.new(0, 7)

makeBtn("✈️ Iniciar TP a Metro Exacto", Theme.AccentRust, pTP, function()
	local m = tonumber(meterBox.Text)
	if m then startMeterFlyTP(m) else notify("TP", "Ingresa un número válido", Theme.Danger) end
end)
makeBtn("📍 Marcar Spawn (origen 0m)", Theme.ActiveBg, pTP, function()
	if captureSpawnOrigin(getHRP()) then
		local o = getSpawnOrigin()
		notify("TP Fly", "Spawn marcado en Z " .. math.floor(o.Z) .. " (0m)", Theme.ActiveBorder)
	else
		notify("TP Fly", "No hay personaje", Theme.Danger)
	end
end)
makeBtn("🛑 Frenar TP", Color3.fromRGB(76, 30, 26), pTP, function()
	local hrp = getHRP()
	if State.TPActive then
		State.TPActive = false
		clearMotion(hrp)
		local origin = getSpawnOrigin()
		local z = hrp and hrp.Position.Z or 0
		local cur = origin and math.floor((origin.Z - z) / METERS_TO_STUDS + 0.5) or 0
		notify("TP Fly", "Detenido en " .. math.max(0, cur) .. "m desde spawn", Theme.AccentGold)
	end
end)
makeBtn("500m", Theme.SurfaceAlt, pTP, function() startMeterFlyTP(500) end)
makeBtn("1Km", Theme.SurfaceAlt, pTP, function() startMeterFlyTP(1000) end)
makeBtn("5Km", Theme.SurfaceAlt, pTP, function() startMeterFlyTP(5000) end)

-- ============================================================================
-- LOOT
-- ============================================================================
local function buildLoot()
	local parent = pLoot
	sec(parent, "Atraer objetos")
	makeBtn("🪙 Traer Chapas / Dinero", Color3.fromRGB(72, 54, 18), parent, function() bringItems({"cap","chapa","coin","scrap","bottle"}) end)
	makeBtn("🔫 Traer Armas / Munición", Color3.fromRGB(78, 28, 24), parent, function() bringItems({"gun","ammo","rifle","pistol","shotgun","bullet"}) end)
	makeBtn("🥫 Traer Comida / Agua", Color3.fromRGB(34, 52, 62), parent, function() bringItems({"food","water","burger","can","drink","sponge"}) end)
	makeBtn("💎 Traer Tuercas / Motores", Color3.fromRGB(92, 50, 22), parent, function() bringItems({"engine","motor","nut","bolt","wrench","jack","tire","c4","gold"}) end)
	makeTgl("👁️ ESP Items con Nombres", parent, function(s) State.ESPItems = s end)
end

local function buildVeh()
	local parent = pVeh
	sec(parent, "Mecánica y Combustible")
	makeBtn("⛽ Combustible al 100%", Theme.ActiveBg, parent, function()
		local n = 0
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("NumberValue") then
				local nl = v.Name:lower()
				if nl:find("fuel") or nl:find("gas") or nl:find("nafta") then
					v.Value = 100
					n += 1
				end
			end
		end
		notify("Vehículo", "Tanques llenados: " .. n, Theme.ActiveBorder)
	end)
	makeBtn("🛠️ Reparar auto actual", Color3.fromRGB(84, 52, 22), parent, function()
		local hum = getHum()
		local seat = hum and hum.SeatPart
		if seat and seat.Parent then
			for _, p in ipairs(seat.Parent:GetDescendants()) do
				if p:IsA("BasePart") then pcall(function() p.Broken = false end) end
			end
			notify("Vehículo", "Vehículo reparado", Theme.Accent)
		else
			notify("Vehículo", "Súbete a un vehículo primero", Theme.AccentGold)
		end
	end)
end

-- ============================================================================
-- ESP DE LOOT
-- ============================================================================
local ItemESPFolder = Instance.new("Folder")
ItemESPFolder.Name = "DTH_LootESP"
ItemESPFolder.Parent = SG

local function refreshItemESP()
	ItemESPFolder:ClearAllChildren()
	if not State.ESPItems or not State.Running then return end
	local hrp = getHRP()
	if not hrp then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		local n = obj.Name:lower()
		local col = nil
		if n:find("cap") or n:find("chapa") or n:find("coin") or n:find("scrap") then
			col = Theme.AccentGold
		elseif n:find("gun") or n:find("ammo") or n:find("rifle") or n:find("pistol") or n:find("shotgun") then
			col = Color3.fromRGB(255, 82, 68)
		elseif n:find("gas") or n:find("fuel") or n:find("oil") or n:find("canister") then
			col = Theme.ActiveBorder
		elseif n:find("engine") or n:find("motor") or n:find("nut") or n:find("bolt") or n:find("wrench") or n:find("jack") then
			col = Theme.Accent
		end
		if col then
			local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position)
			local dist = pos and (pos - hrp.Position).Magnitude
			if dist and dist <= 220 then
				local hl = Instance.new("Highlight")
				hl.Adornee = obj
				hl.FillColor = col
				hl.OutlineColor = Theme.TextMain
				hl.FillTransparency = 0.55
				hl.Parent = ItemESPFolder
				local anchor = obj:IsA("BasePart") and obj or obj.PrimaryPart
				if anchor then
					local bb = Instance.new("BillboardGui")
					bb.Adornee = anchor
					bb.Size = UDim2.new(0, 130, 0, 24)
					bb.StudsOffset = Vector3.new(0, 2.2, 0)
					bb.AlwaysOnTop = true
					bb.MaxDistance = 220
					bb.Parent = ItemESPFolder
					local tx = Instance.new("TextLabel")
					tx.Size = UDim2.new(1, 0, 1, 0)
					tx.BackgroundTransparency = 1
					tx.Text = obj.Name .. " [" .. math.floor(dist) .. "m]"
					tx.TextColor3 = col
					tx.Font = Enum.Font.GothamBold
					tx.TextSize = 9
					tx.Parent = bb
				end
			end
		end
	end
end

-- ============================================================================
-- BUCLES PRINCIPALES
-- ============================================================================
local Connections = {}
local function trackConn(c) table.insert(Connections, c) return c end

trackConn(RS.Stepped:Connect(function()
	if not State.Running then return end
	if State.Noclip and LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
	if State.InfStamina then
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Stamina = 100 end
	end
end))

trackConn(RS.RenderStepped:Connect(function(dt)
	if not State.Running then return end
	Cam = workspace.CurrentCamera

	if State.SilentAim or State.Aimbot then
		CachedFOVTarget = nil
		for _, e in ipairs(getEnemies()) do
			local hum = e:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local part = e:FindFirstChild("Head") or e:FindFirstChild("HumanoidRootPart")
				if part and State.SilentAim then
					local sp, on = Cam:WorldToViewportPoint(part.Position)
					local center = Vector2.new(Cam.ViewportSize.X * 0.5, Cam.ViewportSize.Y * 0.5)
					if sp.Z > 0 and on and (Vector2.new(sp.X, sp.Y) - center).Magnitude <= State.FOVRadius then
						CachedFOVTarget = part
						break
					end
				end
			end
		end
	end

	if State.ShowFOV then
		local vp = Cam.ViewportSize
		FOVFrame.Size = UDim2.fromOffset(State.FOVRadius * 2, State.FOVRadius * 2)
		FOVFrame.Position = UDim2.fromOffset(vp.X * 0.5, vp.Y * 0.5)
		FOVFrame.Visible = true
	else
		FOVFrame.Visible = false
	end
	pcall(updateAdvancedESP)
	pcall(stepMeterFlyTP, dt)

	local char = LP.Character
	if not char or not Cam then return end

	if State.Speed then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = State.SpeedVal end
	end
	if State.Fly then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			clearMotion(hrp)
			local dir = Vector3.zero
			if UIS.KeyboardEnabled then
				if UIS:IsKeyDown(Enum.KeyCode.W) then dir += Cam.CFrame.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= Cam.CFrame.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= Cam.CFrame.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.D) then dir += Cam.CFrame.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
				if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
			end
			if dir.Magnitude > 0 then
				dir = dir.Unit
				local spd = State.FlyVal * (UIS.KeyboardEnabled and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) and State.FlyBoostMult or 1)
				hrp.CFrame = hrp.CFrame + dir * spd * dt
			end
		end
	end
	if State.Aimbot and CachedFOVTarget and CachedFOVTarget.Parent then
		local c = Cam.CFrame
		local desired = CFrame.new(c.Position, CachedFOVTarget.Position)
		local alpha = 1 - math.exp(-State.AimSmooth * dt)
		Cam.CFrame = c:Lerp(desired, math.clamp(alpha, 0, 1))
	end
end))

trackConn(RS.Heartbeat:Connect(function()
	if not State.Running or not State.GodMode then return end
	local hum = getHum()
	if hum then
		hum.Health = hum.MaxHealth
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	end
end))

trackConn(LP.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	if State.Running then applyCharacterMods(char) end
	captureSpawnOrigin(char:FindFirstChild("HumanoidRootPart"))
end))
captureSpawnOrigin(getHRP())

task.spawn(function()
	while State.Running and task.wait(CONFIG.EnemyCacheInterval) do
		if State.SilentAim or State.Aimbot or State.KillAura or State.Hitbox or State.ESPEnemies then
			refreshEnemyCache()
		end
	end
end)

task.spawn(function()
	while State.Running and task.wait(0.18) do
		pcall(function()
			if State.KillAura then
				local hrp = getHRP()
				if hrp then
					for _, e in ipairs(CachedEnemies) do
						local root = e:FindFirstChild("HumanoidRootPart") or e:FindFirstChild("Torso")
						if root and (root.Position - hrp.Position).Magnitude <= 35 then
							local hum = e:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 then
								hum.Health = 0
								hum:BreakJoints()
							end
						end
					end
				end
			end
			if State.Hitbox then syncHitboxes(true) end

			local char = LP.Character
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then
					if State.Wallbang then
						for _, p in ipairs(tool:GetDescendants()) do
							if p:IsA("BasePart") then
								p.CanCollide = false
								p.Massless = true
							end
						end
					end
					if State.NoRecoil then
						for _, v in ipairs(tool:GetDescendants()) do
							if v:IsA("NumberValue") then
								local nl = v.Name:lower()
								if nl:find("recoil") or nl:find("kick") then v.Value = 0 end
							end
						end
					end
					if State.InfAmmo then
						for _, v in ipairs(tool:GetDescendants()) do
							if v:IsA("NumberValue") then
								local nl = v.Name:lower()
								if nl:find("ammo") or nl:find("bullet") or nl:find("balas") then v.Value = 999 end
							end
						end
					end
				end
				if State.Triggerbot then
					local vp = Cam.ViewportSize
					local ray = Cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
					local hit = workspace:Raycast(ray.Origin, ray.Direction * 350,
						{ FilterDescendantsInstances = { LP.Character }, FilterType = Enum.RaycastFilterType.Exclude })
					if hit and hit.Instance then
						local mdl = hit.Instance:FindFirstAncestorOfClass("Model")
						if mdl and mdl:FindFirstChildOfClass("Humanoid") and tool then
							tool:Activate()
						end
					end
				end
			end
		end)
	end
end)

task.spawn(function()
	while State.Running and task.wait(2.5) do
		refreshItemESP()
	end
end)

-- ============================================================================
-- KILL SWITCH
-- ============================================================================
closeB.MouseButton1Click:Connect(function()
	print(string.format("[%s] KILL SWITCH ejecutado", CONFIG.LogTag))
	State.Running = false
	State.TPActive = false
	State.SilentAim = false
	State.Aimbot = false
	State.Triggerbot = false
	State.KillAura = false
	State.Hitbox = false
	State.Wallbang = false
	State.NoRecoil = false
	State.InfAmmo = false
	State.GodMode = false
	State.ESPEnemies = false
	State.ESPItems = false
	State.Speed = false
	State.Jump = false
	State.Fly = false
	State.InfJump = false
	State.InfStamina = false
	State.Noclip = false
	ItemESPFolder:ClearAllChildren()
	ESPContainer.Visible = false
	syncHitboxes(false)
	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	SG:Destroy()
end)

-- ============================================================================
-- INICIO
-- ============================================================================
buildCombate()
buildPlayer()
buildLoot()
buildVeh()

miniB.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)

print(string.format("[%s] DUSTY TRIP HUB GUI-PRIO v1 listo", CONFIG.LogTag))
notify("DUSTY TRIP HUB", "v1 GUI propio listo", Theme.Accent)-- ============================================================================
-- DUSTY TRIP HUB [v1 - GUI PROPIO, MINIMALISTA]
-- Mismas funciones que el script anterior: aim, ESP, TP spawn, veh, loot...
-- Copia y pega en la consola de Roblox.
-- ============================================================================

local CONFIG = {
	LogTag = "DUSTY-TRIP-HUB",
	VerboseLog = true,
	EnemyCacheInterval = 0.35,
}

local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local CG = game:GetService("CoreGui")
local Plrs = game:GetService("Players")

local LP = Plrs.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()
local SessionId = "TS-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))

local Caps = {
	gethui = typeof(gethui) == "function",
	syn = syn ~= nil and typeof(syn.protect_gui) == "function",
	getrawmetatable = typeof(getrawmetatable) == "function",
	hookmetamethod = typeof(hookmetamethod) == "function",
	checkcaller = typeof(checkcaller) == "function",
	setreadonly = typeof(setreadonly) == "function",
	getnamecallmethod = typeof(getnamecallmethod) == "function",
}

local function resolveParentGui()
	local candidates = {}
	pcall(function()
		if Caps.gethui then
			local h = gethui()
			if h then table.insert(candidates, h) end
		end
	end)
	pcall(function()
		if Caps.syn then
			local g = Instance.new("ScreenGui")
			syn.protect_gui(g)
			g.Parent = CG
			table.insert(candidates, g)
		end
	end)
	table.insert(candidates, CG)
	table.insert(candidates, LP:WaitForChild("PlayerGui"))
	for _, c in ipairs(candidates) do
		local ok, p = pcall(function()
			local probe = Instance.new("ScreenGui")
			probe.Parent = c
			if probe.Parent ~= c then error("rechazado") end
			probe:Destroy()
			return c
		end)
		if ok and p then return p end
	end
	return LP:WaitForChild("PlayerGui")
end

local ParentGui = resolveParentGui()
if ParentGui:FindFirstChild("NexusHubPropio") then ParentGui.NexusHubPropio:Destroy() end
local SG = Instance.new("ScreenGui")
SG.Name = "NexusHubPropio"
SG.ResetOnSpawn = false
SG.DisplayOrder = 2147483647
local parentOK = pcall(function() SG.Parent = ParentGui end)
if not parentOK or SG.Parent ~= ParentGui then
	ParentGui = LP:WaitForChild("PlayerGui")
	SG.Parent = ParentGui
end

-- Paleta Dusty Trip (tierra/rojo + textos crema)
local Theme = {
	BgMain = Color3.fromRGB(20, 16, 12),
	Surface = Color3.fromRGB(28, 22, 15),
	SurfaceAlt = Color3.fromRGB(44, 33, 21),
	Border = Color3.fromRGB(80, 55, 30),
	Accent = Color3.fromRGB(232, 110, 18),
	AccentRust = Color3.fromRGB(212, 82, 20),
	AccentGold = Color3.fromRGB(255, 185, 80),
	CyanSignal = Color3.fromRGB(86, 210, 225),
	ActiveBg = Color3.fromRGB(20, 57, 27),
	ActiveBorder = Color3.fromRGB(58, 175, 75),
	ActivePill = Color3.fromRGB(60, 190, 95),
	InactivePill = Color3.fromRGB(30, 22, 14),
	Danger = Color3.fromRGB(218, 46, 40),
	TextMain = Color3.fromRGB(248, 242, 215),
	TextMuted = Color3.fromRGB(188, 168, 138),
	TextPlaceholder = Color3.fromRGB(128, 108, 82),
	DarkInk = Color3.fromRGB(14, 11, 9),
}

local METERS_TO_STUDS = 3.5714
local ESP_MAX_RANGE = 220

-- Estado
local State = {
	Running = true,
	SilentAim = false, Aimbot = false, AimSmooth = 12, AimPart = "Head",
	ShowFOV = true, FOVRadius = 135, Triggerbot = false, KillAura = false,
	Hitbox = false, HitboxScale = 2, Wallbang = false, NoRecoil = false,
	InfAmmo = false, GodMode = false,
	Speed = false, SpeedVal = 35, Jump = false, JumpVal = 100,
	Fly = false, FlyVal = 55, FlyBoostMult = 2.2,
	InfJump = false, InfStamina = false, Noclip = false,
	TPActive = false, TPActiveMeters = 0, TPOriginZ = 0, TPRate = 280,
	SpawnOrigin = nil, SpawnCaptured = false,
	ESPItems = false, ESPEnemies = false,
}

-- Utilidades de movimiento
local function getHRP()
	return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") or nil
end
local function getHum()
	return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") or nil
end
local function clearMotion(p)
	if p and p:IsA("BasePart") then
		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
	end
end
local function getSeatedVehicleModel(hum)
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("BasePart") then
		local mdl = seat:FindFirstAncestorOfClass("Model")
		if mdl and mdl ~= LP.Character then return mdl end
	end
	return nil
end
local function moveVehicleIfSeated(hum, c)
	local veh = getSeatedVehicleModel(hum)
	if not veh then return false end
	pcall(function()
		for _, p in ipairs(veh:GetDescendants()) do
			if p:IsA("BasePart") then clearMotion(p) end
		end
		veh:PivotTo(c + Vector3.new(0, 2, 0))
	end)
	return true
end
local function findSafeGroundY(x, z, startY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(x, startY or 600, z), Vector3.new(0, -1200, 0), params)
	return hit and (hit.Position.Y + 4) or nil
end

-- Captura del spawn (reusable)
local function captureSpawnOrigin(hrp)
	if hrp and hrp:IsA("BasePart") then
		State.SpawnOrigin = hrp.Position
		State.SpawnCaptured = true
		return true
	end
	return false
end
local function getSpawnOrigin()
	if State.SpawnCaptured and State.SpawnOrigin then return State.SpawnOrigin end
	return getHRP() and getHRP().Position or nil
end

-- Cache de enemigos
local CachedEnemies = {}
local CachedFOVTarget = nil
local function refreshEnemyCache()
	local list = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Health > 0 and obj.Parent
			and obj.Parent:IsA("Model") and obj.Parent ~= LP.Character
			and not Plrs:GetPlayerFromCharacter(obj.Parent) then
			local root = obj.Parent:FindFirstChild("HumanoidRootPart") or obj.RootPart or obj.Parent.PrimaryPart
			if root and root:IsA("BasePart") then table.insert(list, obj.Parent) end
		end
	end
	CachedEnemies = list
end
local function getEnemies()
	if #CachedEnemies == 0 then refreshEnemyCache() end
	return CachedEnemies
end

-- Pool de ESP
local ESPContainer = Instance.new("Frame")
ESPContainer.Name = "DTH_ESPContainer"
ESPContainer.Size = UDim2.fromScale(1, 1)
ESPContainer.BackgroundTransparency = 1
ESPContainer.Visible = false
ESPContainer.Parent = SG

local ESPPool = {}

local function createESPItem()
	local h = Instance.new("Frame")
	h.Size = UDim2.fromScale(1, 1)
	h.BackgroundTransparency = 1
	h.Visible = false
	h.Parent = ESPContainer

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(60, 90)
	box.BackgroundColor3 = Theme.CyanSignal
	box.BackgroundTransparency = 0.90
	box.BorderSizePixel = 0
	box.Parent = h
	Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBG"
	hpBg.Size = UDim2.new(0, 86, 0, 12)
	hpBg.Position = UDim2.new(0.5, -43, 1, 4)
	hpBg.AnchorPoint = Vector2.new(0.5, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(8, 6, 4)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = h
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.AnchorPoint = Vector2.new(0, 1)
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Theme.ActivePill
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local nameTag = Instance.new("TextLabel")
	nameTag.Size = UDim2.new(1, 0, 0, 14)
	nameTag.Position = UDim2.new(0.5, -50, 0, -18)
	nameTag.AnchorPoint = Vector2.new(0.5, 0)
	nameTag.Font = Enum.Font.GothamBold
	nameTag.TextSize = 9
	nameTag.TextColor3 = Theme.CyanSignal
	nameTag.BackgroundTransparency = 1
	nameTag.TextXAlignment = Enum.TextXAlignment.Center
	nameTag.TextTruncate = Enum.TextTruncate.AtEnd
	nameTag.Parent = h

	local hpTag = Instance.new("TextLabel")
	hpTag.Size = UDim2.new(0, 90, 0, 11)
	hpTag.Position = UDim2.new(0.5, -45, 1, 8)
	hpTag.AnchorPoint = Vector2.new(0.5, 0)
	hpTag.Font = Enum.Font.Gotham
	hpTag.TextSize = 8
	hpTag.TextColor3 = Theme.TextMain
	hpTag.BackgroundTransparency = 0.6
	hpTag.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
	hpTag.Parent = h
	Instance.new("UICorner", hpTag).CornerRadius = UDim.new(0, 5)

	local headDot = Instance.new("Frame")
	headDot.AnchorPoint = Vector2.new(0.5, 0.5)
	headDot.Size = UDim2.fromOffset(8, 8)
	headDot.BackgroundColor3 = Theme.Accent
	headDot.BorderSizePixel = 0
	headDot.Visible = false
	headDot.Parent = h
	Instance.new("UICorner", headDot).CornerRadius = UDim.new(1, 0)

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(28, 28)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = h
	local ringStroke = Instance.new("UIStroke", ring)
	ringStroke.Color = Theme.Danger
	ringStroke.Thickness = 1.4
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

	local ptr = Instance.new("Frame")
	ptr.AnchorPoint = Vector2.new(0.5, 0)
	ptr.Size = UDim2.new(0, 8, 1, -22)
	ptr.BackgroundColor3 = Theme.AccentGold
	ptr.BorderSizePixel = 0
	ptr.Visible = false
	ptr.Parent = h
	Instance.new("UICorner", ptr).CornerRadius = UDim.new(1, 0)

	return { Holder = h, Box = box, HPBg = hpBg, HPFill = hpFill,
		NameTag = nameTag, HpTag = hpTag, HeadDot = headDot, Ring = ring, Pointer = ptr }
end

local function getProjectedEnemyBox(model, root)
	if not Cam then return nil end
	local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
	if not ok or typeof(size) ~= "Vector3" or size.Magnitude < 0.1 then
		cf = root.CFrame
		size = Vector3.new(4, 6, 3)
	end
	local half = size * 0.5
	local mnX, mnY = math.huge, math.huge
	local mxX, mxY = -math.huge, -math.huge
	local anyVisible = false
	for _, d in ipairs({
		cf * Vector3.new(-half.X, -half.Y, -half.Z), cf * Vector3.new(-half.X, -half.Y,  half.Z),
		cf * Vector3.new(-half.X,  half.Y, -half.Z), cf * Vector3.new(-half.X,  half.Y,  half.Z),
		cf * Vector3.new( half.X, -half.Y, -half.Z), cf * Vector3.new( half.X, -half.Y,  half.Z),
		cf * Vector3.new( half.X,  half.Y, -half.Z), cf * Vector3.new( half.X,  half.Y,  half.Z),
	}) do
		local pt, on = Cam:WorldToViewportPoint(d)
		if pt.Z > 0 then
			if on then anyVisible = true end
			mnX = math.min(mnX, pt.X); mxX = math.max(mxX, pt.X)
			mnY = math.min(mnY, pt.Y); mxY = math.max(mxY, pt.Y)
		end
	end
	if not anyVisible or mxX <= mnX or mxY <= mnY then return nil end
	return mnX, mnY, mxX, mxY
end

local function updateAdvancedESP()
	if not State.Running or not State.ESPEnemies then
		ESPContainer.Visible = false
		for _, it in ipairs(ESPPool) do it.Holder.Visible = false end
		return
	end
	local hrp = getHRP()
	if not hrp then
		ESPContainer.Visible = false
		return
	end
	ESPContainer.Visible = true
	local enemies = getEnemies()
	for i = #ESPPool + 1, #enemies do ESPPool[i] = createESPItem() end

	for i, it in ipairs(ESPPool) do
		local e = enemies[i]
		local hum = e and e:FindFirstChildOfClass("Humanoid")
		local root = e and ((e:FindFirstChild("HumanoidRootPart")) or (hum and hum.RootPart) or e.PrimaryPart)
		if not e or not e.Parent or not hum or hum.Health <= 0 or not root then
			it.Holder.Visible = false
			continue
		end
		local dist = (root.Position - hrp.Position).Magnitude
		if dist > ESP_MAX_RANGE then
			it.Holder.Visible = false
			continue
		end
		local mnX, mnY, mxX, mxY = getProjectedEnemyBox(e, root)
		if not mnX then
			it.Holder.Visible = false
			continue
		end
		it.Holder.Visible = true
		local w = math.max(14, mxX - mnX)
		local h = math.max(14, mxY - mnY)
		it.Box.Size = UDim2.fromOffset(w, h)
		it.Box.Position = UDim2.fromOffset(mnX, mnY)

		local isTarget = CachedFOVTarget and CachedFOVTarget.Parent
			and (CachedFOVTarget:FindFirstAncestorOfClass("Model") == e) or false
		local accent = isTarget and Theme.Danger
			or (dist < 45 and Theme.Accent)
			or (dist < 120 and Theme.AccentGold)
			or Theme.CyanSignal
		it.Box.BackgroundColor3 = accent
		it.NameTag.Text = "HOSTILE: " .. e.Name:upper()
		it.NameTag.TextColor3 = accent
		local pct = math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100 + 0.5)
		it.HpTag.Text = "[" .. math.floor(dist) .. "m] HP " .. pct .. "%"
		it.HpTag.TextColor3 = isTarget and Theme.Danger or Theme.TextMuted
		it.HPFill.Size = UDim2.fromScale(1, math.clamp(pct / 100, 0, 1))
		it.HPFill.BackgroundColor3 = pct > 55 and Theme.ActivePill
			or (pct > 20 and Theme.AccentGold or Theme.Danger)

		local head = e:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local pt, on = Cam:WorldToViewportPoint(head.Position)
			it.HeadDot.Visible = on and pt.Z > 0
			if it.HeadDot.Visible then
				it.HeadDot.Position = UDim2.fromOffset(pt.X, pt.Y)
				it.HeadDot.BackgroundColor3 = isTarget and Theme.Danger or Theme.Accent
				it.Ring.Visible = isTarget
				if it.Ring.Visible then it.Ring.Position = UDim2.fromOffset(pt.X, pt.Y) end
			end
		else
			it.HeadDot.Visible = false
		end

		it.Pointer.Position = UDim2.fromOffset(mnX + w * 0.5, mxY + 4)
		it.Pointer.Visible = true
	end
end

-- ============================================================================
-- TP POR METROS (contando desde SPAWN)
-- ============================================================================
local function startMeterFlyTP(meters)
	local hrp = getHRP()
	if not hrp or typeof(meters) ~= "number" then return end
	local origin = getSpawnOrigin()
	if not origin then
		notify("TP Fly", "Spawn no detectado, pon te en spawn", Theme.Danger)
		return
	end
	State.TPActiveMeters = meters
	State.TPOriginZ = origin.Z
	State.TPActive = true
	clearMotion(hrp)
	notify("TP Fly", "Rumbo a " .. meters .. "m desde spawn", Theme.Accent)
end

local function stepMeterFlyTP(dt)
	if not State.TPActive then return end
	local hrp = getHRP()
	if not hrp then State.TPActive = false return end
	clearMotion(hrp)
	local targetZ = State.TPOriginZ - State.TPActiveMeters * METERS_TO_STUDS
	local dist = math.abs(targetZ - hrp.Position.Z)
	local step = State.TPRate * dt
	if dist <= step then
		hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, targetZ)
		State.TPActive = false
		notify("TP Fly", "Frenado exacto en " .. State.TPActiveMeters .. "m desde spawn", Theme.ActiveBorder)
		return
	end
	hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z + (targetZ > hrp.Position.Z and 1 or -1) * step)
end

-- ============================================================================
-- SILENT AIM HOOK
-- ============================================================================
local silentAimInstalled = false
local hookReady = false
local hookingActive = false
local oldNamecall = nil

local function installSilentAimHook()
	if silentAimInstalled and hookReady then return end
	silentAimInstalled = true
	pcall(function()
		local rawMT = getrawmetatable and getrawmetatable(game)
		if not rawMT or not hookmetamethod or not checkcaller then return end
		if isreadonly and isreadonly(rawMT) then pcall(setreadonly, rawMT, false) end

		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if hookingActive or not State.Running or not State.SilentAim or checkcaller() then
				return oldNamecall(self, ...)
			end
			local t = CachedFOVTarget
			if t and t.Parent and self == workspace then
				local m = getnamecallmethod()
				if m == "Raycast" or m == "raycast" then
					local a = { ... }
					if typeof(a[1]) == "Vector3" then
						hookingActive = true
						local d = t.Position - a[1]
						a[2] = d.Unit * math.clamp(d.Magnitude + 15, 10, 600)
						hookingActive = false
						return oldNamecall(self, table.unpack(a))
					end
				end
			end
			return oldNamecall(self, ...)
		end)
		hookReady = true
	end)
end

-- ============================================================================
-- HERRAMIENTAS + LOOT + VEHICULO
-- ============================================================================
local OriginalHeads = setmetatable({}, { __mode = "k" })

local function syncHitboxes(on)
	for _, e in ipairs(getEnemies()) do
		local head = e:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			if on and not OriginalHeads[head] then
				OriginalHeads[head] = { Size = head.Size, Transparency = head.Transparency }
				head.Size = Vector3.new(6, 6, 6) * State.HitboxScale
				head.Transparency = 0.35
			elseif not on and OriginalHeads[head] then
				head.Size = OriginalHeads[head].Size
				head.Transparency = OriginalHeads[head].Transparency
			end
		end
	end
end

local function applyCharacterMods(char)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		if State.Speed then hum.WalkSpeed = State.SpeedVal end
		if State.Jump then
			hum.UseJumpPower = true
			hum.JumpPower = State.JumpVal
		end
	end
	if State.Noclip then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end

local function bringItems(keywords)
	local hrp = getHRP()
	if not hrp then return end
	local mine = LP.Character
	local total = 0
	for _, item in ipairs(workspace:GetDescendants()) do
		local isMine = mine and item:IsDescendantOf(mine)
		if isMine then continue end
		local n = item.Name:lower()
		for _, kw in ipairs(keywords) do
			if n:find(kw, 1, true) then
				if item:IsA("BasePart") and not item.Anchored then
					item.CFrame = hrp.CFrame + Vector3.new(0, 2, -3)
					total += 1
				elseif item:IsA("Model") and item.PrimaryPart and not item.PrimaryPart.Anchored then
					item:PivotTo(hrp.CFrame + Vector3.new(0, 2, -3))
					total += 1
				end
				break
			end
		end
	end
	notify("Loot", "Trajiste: " .. total, Theme.AccentGold)
end

-- ============================================================================
-- NOTIFICACIONES
-- ============================================================================
local function notify(title, desc, accent)
	if not State.Running then return end
	if CONFIG.VerboseLog then
		print(string.format("[%s] %s :: %s", CONFIG.LogTag, title, desc))
	end
	task.spawn(function()
		local c = Instance.new("Frame")
		c.Size = UDim2.new(0.22, 0, 0, 44)
		c.BackgroundColor3 = Theme.Surface
		c.Parent = SG
		c:AnchorPoint = Vector2.new(1, 0)
		c.Position = UDim2.new(1, -18, 0, 12)
		Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -8, 1, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 9
		t.TextColor3 = Theme.TextMain
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.Parent = c
		t.Text = "  " .. title .. "\n  " .. desc
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 4, 1, -10)
		bar.Position = UDim2.new(0, 8, 0, 5)
		bar.BackgroundColor3 = accent or Theme.Accent
		bar.Parent = c
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		TS:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(1, -260, 0, 12) }):Play()
		task.wait(2.1)
		local tw = TS:Create(c, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, -18, 0, 12) })
		tw:Play()
		tw.Completed:Wait()
		if c.Parent then c:Destroy() end
	end)
end

-- ============================================================================
-- GUI
-- ============================================================================
local Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.fromOffset(420, 420)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Theme.BgMain
Main.ClipsDescendants = true
Main.Parent = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Theme.Surface
titleBar.Parent = Main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleL = Instance.new("TextLabel")
titleL.Text = "🌵 DUSTY TRIP HUB"
titleL.Font = Enum.Font.GothamBold
titleL.TextSize = 12
titleL.TextColor3 = Theme.TextMain
titleL.BackgroundTransparency = 1
titleL.TextXAlignment = Enum.TextXAlignment.Left
titleL.Size = UDim2.new(1, -60, 0, 48)
titleL.Position = UDim2.new(0, 14, 0, 0)
titleL.Parent = titleBar

local closeB = Instance.new("TextButton")
closeB.Size = UDim2.fromOffset(28, 28)
closeB.Position = UDim2.new(1, -32, 0.5, -14)
closeB.BackgroundColor3 = Theme.Danger
closeB.Text = "✕"
closeB.Font = Enum.Font.GothamBold
closeB.TextSize = 12
closeB.Parent = titleBar
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 8)

local miniB = Instance.new("TextButton")
miniB.Size = UDim2.fromOffset(28, 28)
miniB.Position = UDim2.new(1, -64, 0.5, -14)
miniB.BackgroundColor3 = Theme.SurfaceAlt
miniB.Text = "—"
miniB.Font = Enum.Font.GothamBold
miniB.TextSize = 12
miniB.Parent = titleBar
Instance.new("UICorner", miniB).CornerRadius = UDim.new(0, 8)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -4, 1, -58)
Scroll.Position = UDim2.new(2, 0, 54, 0)
Scroll.BackgroundTransparency = 1
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Theme.Accent
Scroll.Parent = Main

local pages, tabBtns = {}, {}
local function addTab(name, icon)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.19, 0, 0, 26)
	btn.BackgroundColor3 = Theme.Surface
	btn.Text = icon .. " " .. name
	btn.TextColor3 = Theme.TextMuted
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 9
	btn.AutoButtonColor = false
	btn.Parent = Scroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
	pages[name] = Instance.new("Frame")
	pages[name].Size = UDim2.new(1, 0, 1, 0)
	pages[name].BackgroundTransparency = 1
	pages[name].Visible = false
	pages[name].Parent = Scroll
	tabBtns[name] = btn
	btn.MouseButton1Click:Connect(function()
		for n, p in pairs(pages) do
			p.Visible = (n == name)
		end
	end)
	return pages[name]
end
local pCombate = addTab("Combate", "🎯")
local pTP = addTab("TP", "📍")
local pLoot = addTab("Loot", "🧲")
local pVeh = addTab("Veh", "🚗")
pCombate.Visible = true
tabBtns["Combate"].BackgroundColor3 = Theme.Accent
tabBtns["Combate"].TextColor3 = Theme.DarkInk

-- FOV circle (se muestra sobre todo el juego)
local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "DTH_FOVFrame"
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.fromOffset(270, 270)
FOVFrame.BackgroundColor3 = Theme.Accent
FOVFrame.BackgroundTransparency = 0.94
FOVFrame.Visible = false
FOVFrame.Parent = SG
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Theme.Accent
fovStroke.Thickness = 1.6
fovStroke.Parent = FOVFrame

-- Helpers de GUI
local function sec(parent, text)
	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, 0, 0, 14)
	s.BackgroundTransparency = 1
	s.Text = string.upper(text)
	s.Font = Enum.Font.GothamBold
	s.TextSize = 8
	s.TextColor3 = Theme.AccentGold
	s.Parent = parent
	return s
end

local function makeBtn(text, bg, parent, cb, sizeH)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, sizeH or 34)
	b.BackgroundColor3 = bg or Theme.SurfaceAlt
	b.Text = text
	b.TextColor3 = Theme.TextMain
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(math.clamp(base.R * 255 + 20, 0, 255),
				math.clamp(base.G * 255 + 18, 0, 255), math.clamp(base.B * 255 + 14, 0, 255))
		}):Play()
	end)
	b.MouseLeave:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function makeTgl(text, parent, cb, initial)
	local active = initial or false
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = active and Theme.ActiveBg or Theme.Surface
	b.Text = "   " .. text
	b.TextColor3 = active and Theme.TextMain or Theme.TextMuted
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local sk = Instance.new("UIStroke", b)
	sk.Color = active and Theme.ActiveBorder or Theme.Border
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.new(0, 44, 0, 20)
	pill.Position = UDim2.new(1, -52, 0.5, -10)
	pill.BackgroundColor3 = active and Theme.ActivePill or Theme.InactivePill
	pill.Text = active and "ON" or "OFF"
	pill.TextColor3 = active and Theme.DarkInk or Theme.TextMuted
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 8
	pill.Parent = b
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)
	b.MouseButton1Click:Connect(function()
		active = not active
		pill.Text = active and "ON" or "OFF"
		TS:Create(b, TweenInfo.new(0.16), {
			BackgroundColor3 = active and Theme.ActiveBg or Theme.Surface,
			TextColor3 = active and Theme.TextMain or Theme.TextMuted,
		}):Play()
		TS:Create(pill, TweenInfo.new(0.16), {
			BackgroundColor3 = active and Theme.ActivePill or Theme.InactivePill,
			TextColor3 = active and Theme.DarkInk or Theme.TextMuted,
		}):Play()
		sk.Color = active and Theme.ActiveBorder or Theme.Border
		notify("Dusty Trip Hub", text .. (active and " activado" or " desactivado"),
			active and Theme.ActiveBorder or Theme.Danger)
		cb(active)
	end)
	return b
end

local function makeSld(label, minV, maxV, defV, parent, cb)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 42)
	card.BackgroundColor3 = Theme.Surface
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local top = Instance.new("TextLabel")
	top.Size = UDim2.new(1, -18, 0, 14)
	top.Position = UDim2.new(0, 9, 0, 4)
	top.BackgroundTransparency = 1
	top.Text = label .. ": " .. defV
	top.TextColor3 = Theme.TextMain
	top.Font = Enum.Font.GothamMedium
	top.TextSize = 9
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.Parent = card
	local hitZone = Instance.new("TextButton")
	hitZone.Size = UDim2.new(1, -12, 0, 22)
	hitZone.Position = UDim2.new(0, 6, 0, 17)
	hitZone.BackgroundTransparency = 1
	hitZone.AutoButtonColor = false
	hitZone.Parent = card
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -6, 0, 7)
	bar.Position = UDim2.new(0, 3, 0.5, -3.5)
	bar.BackgroundColor3 = Theme.InactivePill
	bar.Parent = hitZone
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp((defV - minV) / (maxV - minV), 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Theme.Accent
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local sliding = false
	local function applyInput(input)
		local r = math.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor(minV + (maxV - minV) * r + 0.5)
		fill.Size = UDim2.new(r, 0, 1, 0)
		top.Text = label .. ": " .. val
		cb(val)
	end
	hitZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			applyInput(input)
		end
	end)
	hitZone.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			sliding = false
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyInput(input)
		end
	end)
	return card
end

-- ============================================================================
-- COMBATE
-- ============================================================================
local function buildCombate()
	local parent = pCombate
	sec(parent, "Puntería y FOV")
	makeTgl("👻 Silente Aim (En FOV)", parent, function(s)
		State.SilentAim = s
		if s then refreshEnemyCache() installSilentAimHook() end
	end)
	makeTgl("🎯 Aimbot Suave", parent, function(s)
		State.Aimbot = s
		if s then refreshEnemyCache() end
	end)
	makeSld("Suavizado Aimbot", 1, 30, State.AimSmooth, parent, function(v) State.AimSmooth = v end)
	makeSld("Radio FOV (px)", 35, 340, State.FOVRadius, parent, function(v) State.FOVRadius = v end)

	sec(parent, "Parte objetivo")
	makeBtn("🧠 Head", Theme.SurfaceAlt, parent, function()
		State.AimPart = "Head"
		notify("Parte Objetivo", "Apuntando a: Head", Theme.Accent)
	end)
	makeBtn("🦺 Torso", Theme.SurfaceAlt, parent, function()
		State.AimPart = "Torso"
		notify("Parte Objetivo", "Apuntando a: Torso", Theme.Accent)
	end)
	makeBtn("⚙️ HumanoidRootPart", Theme.SurfaceAlt, parent, function()
		State.AimPart = "HumanoidRootPart"
		notify("Parte Objetivo", "Apuntando a: HumanoidRootPart", Theme.Accent)
	end)

	sec(parent, "Armas, Enemigos & Supervivencia")
	makeTgl("🔫 Triggerbot (En mira)", parent, function(s) State.Triggerbot = s end)
	makeTgl("🗡️ Kill Aura (35m)", parent, function(s) State.KillAura = s end)
	makeTgl("💥 Hitbox Extendido", parent, function(s) State.Hitbox = s syncHitboxes(s) end)
	makeSld("Multiplicador Hitbox", 1, 5, State.HitboxScale, parent, function(v)
		State.HitboxScale = v
		if State.Hitbox then syncHitboxes(true) end
	end)
	makeTgl("🧱 Wallbang", parent, function(s) State.Wallbang = s end)
	makeTgl("🎯 No Recoil", parent, function(s) State.NoRecoil = s end)
	makeTgl("♾️ Munición Infinita", parent, function(s) State.InfAmmo = s end)
	makeTgl("🛡️ God Mode", parent, function(s) State.GodMode = s end)

	sec(parent, "ESP enemigos")
	makeTgl("👾 ESP enemigos (HUD)", parent, function(s)
		State.ESPEnemies = s
		if s then refreshEnemyCache() end
	end)

	-- Stats
	local statsH = Instance.new("TextLabel")
	statsH.Text = "── STATS (mapa real) ──"
	statsH.Font = Enum.Font.GothamBold
	statsH.TextSize = 9
	statsH.TextColor3 = Theme.AccentGold
	statsH.BackgroundTransparency = 1
	statsH.Size = UDim2.new(1, 0, 0, 16)
	statsH.Parent = parent
	local statsB = Instance.new("TextLabel")
	statsB.Font = Enum.Font.Gotham
	statsB.TextSize = 8
	statsB.TextColor3 = Theme.TextMuted
	statsB.TextXAlignment = Enum.TextXAlignment.Left
	statsB.Size = UDim2.new(1, -4, 0, 72)
	statsB.BackgroundColor3 = Theme.Surface
	statsB.BackgroundTransparency = 0.14
	statsB.Parent = parent
	Instance.new("UICorner", statsB).CornerRadius = UDim.new(0, 7)

	local function dashScan()
		local vehicles, weapons, otherModels, pickups, total = {}, {}, {}, {}, 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("MeshPart") then
				local seat = obj:FindFirstChildWhichIsA("VehicleSeat", true)
				if seat then table.insert(vehicles, obj.Name)
				else
					table.insert(otherModels, obj.Name)
					local n = obj.Name:lower()
					for _, kw in ipairs({"cap","chapa","coin","scrap","bottle","gun","ammo","rifle","pistol","shotgun","bullet","c4","gold","engine","motor","nut","bolt","wrench","jack","tire","sponge","food","water"}) do
						if n:find(kw, 1, true) then table.insert(pickups, obj.Name); break end
					end
				end
				total += 1
			end
		end
		return vehicles, weapons, otherModels, pickups, total
	end

	local function dashUpdate()
		if not State.Running then return end
		local veh, wp, other, pickups, total = dashScan()
		local names = {}
		for _, n in ipairs(veh) do table.insert(names, n) end
		statsB.Text = table.concat({
			"[ DUSTY TRIP — STATS ]",
			string.format(" players: %d | cars: %d %s", #Plrs:GetPlayers(), #veh, table.concat(names, ", ")),
			string.format(" modelos: %d | pickups: %d %s", #other, #pickups, table.concat(pickups, ", ")),
			string.format(" enemigos: %d | objetos: %d", #getEnemies(), total),
		}, "\n")
	end

	makeBtn("📄 Dump: modelos reales", Theme.SurfaceAlt, parent, function()
		local count = 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("MeshPart") then
				count += 1
				print(string.format("[%s] REAL_MODEL name=%q class=%s pos=%.0f,%.0f,%.0f",
					CONFIG.LogTag, obj.Name, obj.ClassName, obj.Position.X, obj.Position.Y, obj.Position.Z))
			end
		end
		notify("Scan", "Dumped " .. count .. " modelos reales", Theme.AccentGold)
	end)

	task.spawn(function()
		while State.Running and task.wait(1) do
			dashUpdate()
		end
	end)
end

-- ============================================================================
-- PLAYER
-- ============================================================================
local function buildPlayer()
	local parent = pCombate
	sec(parent, "Movimiento")
	makeTgl("⚡ Velocidad personalizada", parent, function(s)
		State.Speed = s
		local hum = getHum()
		if hum then hum.WalkSpeed = s and State.SpeedVal or 16 end
	end)
	makeSld("Velocidad", 16, 120, State.SpeedVal, parent, function(v)
		State.SpeedVal = v
		local hum = getHum()
		if State.Speed and hum then hum.WalkSpeed = v end
	end)
	makeTgl("🦘 Potencia de salto", parent, function(s)
		State.Jump = s
		local hum = getHum()
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = s and State.JumpVal or 50
		end
	end)
	makeSld("Salto", 50, 300, State.JumpVal, parent, function(v)
		State.JumpVal = v
		local hum = getHum()
		if State.Jump and hum then hum.JumpPower = v end
	end)
	makeTgl("✈️ Vuelo CFrame", parent, function(s)
		State.Fly = s
		clearMotion(getHRP())
	end)
	makeSld("Velocidad de vuelo", 10, 220, State.FlyVal, parent, function(v) State.FlyVal = v end)
	makeTgl("♾️ Salto infinito", parent, function(s) State.InfJump = s end)
	makeTgl("💨 Stamina infinita", parent, function(s) State.InfStamina = s end)
	makeTgl("👻 Noclip", parent, function(s)
		State.Noclip = s
		if not s and LP.Character then
			for _, part in ipairs(LP.Character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
	end)
end

-- ============================================================================
-- TP POR METROS
-- ============================================================================
local meterBox = Instance.new("TextBox")
meterBox.Size = UDim2.new(1, 0, 0, 32)
meterBox.BackgroundColor3 = Theme.Surface
meterBox.PlaceholderText = "Ingresar metros (ej. 1500)..."
meterBox.PlaceholderColor3 = Theme.TextPlaceholder
meterBox.TextColor3 = Theme.TextMain
meterBox.Font = Enum.Font.Gotham
meterBox.TextSize = 10
meterBox.Parent = pTP
Instance.new("UICorner", meterBox).CornerRadius = UDim.new(0, 7)

makeBtn("✈️ Iniciar TP a Metro Exacto", Theme.AccentRust, pTP, function()
	local m = tonumber(meterBox.Text)
	if m then startMeterFlyTP(m) else notify("TP", "Ingresa un número válido", Theme.Danger) end
end)
makeBtn("📍 Marcar Spawn (origen 0m)", Theme.ActiveBg, pTP, function()
	if captureSpawnOrigin(getHRP()) then
		local o = getSpawnOrigin()
		notify("TP Fly", "Spawn marcado en Z " .. math.floor(o.Z) .. " (0m)", Theme.ActiveBorder)
	else
		notify("TP Fly", "No hay personaje", Theme.Danger)
	end
end)
makeBtn("🛑 Frenar TP", Color3.fromRGB(76, 30, 26), pTP, function()
	local hrp = getHRP()
	if State.TPActive then
		State.TPActive = false
		clearMotion(hrp)
		local origin = getSpawnOrigin()
		local z = hrp and hrp.Position.Z or 0
		local cur = origin and math.floor((origin.Z - z) / METERS_TO_STUDS + 0.5) or 0
		notify("TP Fly", "Detenido en " .. math.max(0, cur) .. "m desde spawn", Theme.AccentGold)
	end
end)
makeBtn("500m", Theme.SurfaceAlt, pTP, function() startMeterFlyTP(500) end)
makeBtn("1Km", Theme.SurfaceAlt, pTP, function() startMeterFlyTP(1000) end)
makeBtn("5Km", Theme.SurfaceAlt, pTP, function() startMeterFlyTP(5000) end)

-- ============================================================================
-- LOOT
-- ============================================================================
local function buildLoot()
	local parent = pLoot
	sec(parent, "Atraer objetos")
	makeBtn("🪙 Traer Chapas / Dinero", Color3.fromRGB(72, 54, 18), parent, function() bringItems({"cap","chapa","coin","scrap","bottle"}) end)
	makeBtn("🔫 Traer Armas / Munición", Color3.fromRGB(78, 28, 24), parent, function() bringItems({"gun","ammo","rifle","pistol","shotgun","bullet"}) end)
	makeBtn("🥫 Traer Comida / Agua", Color3.fromRGB(34, 52, 62), parent, function() bringItems({"food","water","burger","can","drink","sponge"}) end)
	makeBtn("💎 Traer Tuercas / Motores", Color3.fromRGB(92, 50, 22), parent, function() bringItems({"engine","motor","nut","bolt","wrench","jack","tire","c4","gold"}) end)
	makeTgl("👁️ ESP Items con Nombres", parent, function(s) State.ESPItems = s end)
end

local function buildVeh()
	local parent = pVeh
	sec(parent, "Mecánica y Combustible")
	makeBtn("⛽ Combustible al 100%", Theme.ActiveBg, parent, function()
		local n = 0
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("NumberValue") then
				local nl = v.Name:lower()
				if nl:find("fuel") or nl:find("gas") or nl:find("nafta") then
					v.Value = 100
					n += 1
				end
			end
		end
		notify("Vehículo", "Tanques llenados: " .. n, Theme.ActiveBorder)
	end)
	makeBtn("🛠️ Reparar auto actual", Color3.fromRGB(84, 52, 22), parent, function()
		local hum = getHum()
		local seat = hum and hum.SeatPart
		if seat and seat.Parent then
			for _, p in ipairs(seat.Parent:GetDescendants()) do
				if p:IsA("BasePart") then pcall(function() p.Broken = false end) end
			end
			notify("Vehículo", "Vehículo reparado", Theme.Accent)
		else
			notify("Vehículo", "Súbete a un vehículo primero", Theme.AccentGold)
		end
	end)
end

-- ============================================================================
-- ESP DE LOOT
-- ============================================================================
local ItemESPFolder = Instance.new("Folder")
ItemESPFolder.Name = "DTH_LootESP"
ItemESPFolder.Parent = SG

local function refreshItemESP()
	ItemESPFolder:ClearAllChildren()
	if not State.ESPItems or not State.Running then return end
	local hrp = getHRP()
	if not hrp then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		local n = obj.Name:lower()
		local col = nil
		if n:find("cap") or n:find("chapa") or n:find("coin") or n:find("scrap") then
			col = Theme.AccentGold
		elseif n:find("gun") or n:find("ammo") or n:find("rifle") or n:find("pistol") or n:find("shotgun") then
			col = Color3.fromRGB(255, 82, 68)
		elseif n:find("gas") or n:find("fuel") or n:find("oil") or n:find("canister") then
			col = Theme.ActiveBorder
		elseif n:find("engine") or n:find("motor") or n:find("nut") or n:find("bolt") or n:find("wrench") or n:find("jack") then
			col = Theme.Accent
		end
		if col then
			local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position)
			local dist = pos and (pos - hrp.Position).Magnitude
			if dist and dist <= 220 then
				local hl = Instance.new("Highlight")
				hl.Adornee = obj
				hl.FillColor = col
				hl.OutlineColor = Theme.TextMain
				hl.FillTransparency = 0.55
				hl.Parent = ItemESPFolder
				local anchor = obj:IsA("BasePart") and obj or obj.PrimaryPart
				if anchor then
					local bb = Instance.new("BillboardGui")
					bb.Adornee = anchor
					bb.Size = UDim2.new(0, 130, 0, 24)
					bb.StudsOffset = Vector3.new(0, 2.2, 0)
					bb.AlwaysOnTop = true
					bb.MaxDistance = 220
					bb.Parent = ItemESPFolder
					local tx = Instance.new("TextLabel")
					tx.Size = UDim2.new(1, 0, 1, 0)
					tx.BackgroundTransparency = 1
					tx.Text = obj.Name .. " [" .. math.floor(dist) .. "m]"
					tx.TextColor3 = col
					tx.Font = Enum.Font.GothamBold
					tx.TextSize = 9
					tx.Parent = bb
				end
			end
		end
	end
end

-- ============================================================================
-- BUCLES PRINCIPALES
-- ============================================================================
local Connections = {}
local function trackConn(c) table.insert(Connections, c) return c end

trackConn(RS.Stepped:Connect(function()
	if not State.Running then return end
	if State.Noclip and LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
	if State.InfStamina then
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Stamina = 100 end
	end
end))

trackConn(RS.RenderStepped:Connect(function(dt)
	if not State.Running then return end
	Cam = workspace.CurrentCamera

	if State.SilentAim or State.Aimbot then
		CachedFOVTarget = nil
		for _, e in ipairs(getEnemies()) do
			local hum = e:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local part = e:FindFirstChild("Head") or e:FindFirstChild("HumanoidRootPart")
				if part and State.SilentAim then
					local sp, on = Cam:WorldToViewportPoint(part.Position)
					local center = Vector2.new(Cam.ViewportSize.X * 0.5, Cam.ViewportSize.Y * 0.5)
					if sp.Z > 0 and on and (Vector2.new(sp.X, sp.Y) - center).Magnitude <= State.FOVRadius then
						CachedFOVTarget = part
						break
					end
				end
			end
		end
	end

	if State.ShowFOV then
		local vp = Cam.ViewportSize
		FOVFrame.Size = UDim2.fromOffset(State.FOVRadius * 2, State.FOVRadius * 2)
		FOVFrame.Position = UDim2.fromOffset(vp.X * 0.5, vp.Y * 0.5)
		FOVFrame.Visible = true
	else
		FOVFrame.Visible = false
	end
	pcall(updateAdvancedESP)
	pcall(stepMeterFlyTP, dt)

	local char = LP.Character
	if not char or not Cam then return end

	if State.Speed then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = State.SpeedVal end
	end
	if State.Fly then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			clearMotion(hrp)
			local dir = Vector3.zero
			if UIS.KeyboardEnabled then
				if UIS:IsKeyDown(Enum.KeyCode.W) then dir += Cam.CFrame.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= Cam.CFrame.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= Cam.CFrame.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.D) then dir += Cam.CFrame.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
				if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
			end
			if dir.Magnitude > 0 then
				dir = dir.Unit
				local spd = State.FlyVal * (UIS.KeyboardEnabled and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) and State.FlyBoostMult or 1)
				hrp.CFrame = hrp.CFrame + dir * spd * dt
			end
		end
	end
	if State.Aimbot and CachedFOVTarget and CachedFOVTarget.Parent then
		local c = Cam.CFrame
		local desired = CFrame.new(c.Position, CachedFOVTarget.Position)
		local alpha = 1 - math.exp(-State.AimSmooth * dt)
		Cam.CFrame = c:Lerp(desired, math.clamp(alpha, 0, 1))
	end
end))

trackConn(RS.Heartbeat:Connect(function()
	if not State.Running or not State.GodMode then return end
	local hum = getHum()
	if hum then
		hum.Health = hum.MaxHealth
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	end
end))

trackConn(LP.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	if State.Running then applyCharacterMods(char) end
	captureSpawnOrigin(char:FindFirstChild("HumanoidRootPart"))
end))
captureSpawnOrigin(getHRP())

task.spawn(function()
	while State.Running and task.wait(CONFIG.EnemyCacheInterval) do
		if State.SilentAim or State.Aimbot or State.KillAura or State.Hitbox or State.ESPEnemies then
			refreshEnemyCache()
		end
	end
end)

task.spawn(function()
	while State.Running and task.wait(0.18) do
		pcall(function()
			if State.KillAura then
				local hrp = getHRP()
				if hrp then
					for _, e in ipairs(CachedEnemies) do
						local root = e:FindFirstChild("HumanoidRootPart") or e:FindFirstChild("Torso")
						if root and (root.Position - hrp.Position).Magnitude <= 35 then
							local hum = e:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 then
								hum.Health = 0
								hum:BreakJoints()
							end
						end
					end
				end
			end
			if State.Hitbox then syncHitboxes(true) end

			local char = LP.Character
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then
					if State.Wallbang then
						for _, p in ipairs(tool:GetDescendants()) do
							if p:IsA("BasePart") then
								p.CanCollide = false
								p.Massless = true
							end
						end
					end
					if State.NoRecoil then
						for _, v in ipairs(tool:GetDescendants()) do
							if v:IsA("NumberValue") then
								local nl = v.Name:lower()
								if nl:find("recoil") or nl:find("kick") then v.Value = 0 end
							end
						end
					end
					if State.InfAmmo then
						for _, v in ipairs(tool:GetDescendants()) do
							if v:IsA("NumberValue") then
								local nl = v.Name:lower()
								if nl:find("ammo") or nl:find("bullet") or nl:find("balas") then v.Value = 999 end
							end
						end
					end
				end
				if State.Triggerbot then
					local vp = Cam.ViewportSize
					local ray = Cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
					local hit = workspace:Raycast(ray.Origin, ray.Direction * 350,
						{ FilterDescendantsInstances = { LP.Character }, FilterType = Enum.RaycastFilterType.Exclude })
					if hit and hit.Instance then
						local mdl = hit.Instance:FindFirstAncestorOfClass("Model")
						if mdl and mdl:FindFirstChildOfClass("Humanoid") and tool then
							tool:Activate()
						end
					end
				end
			end
		end)
	end
end)

task.spawn(function()
	while State.Running and task.wait(2.5) do
		refreshItemESP()
	end
end)

-- ============================================================================
-- KILL SWITCH
-- ============================================================================
closeB.MouseButton1Click:Connect(function()
	print(string.format("[%s] KILL SWITCH ejecutado", CONFIG.LogTag))
	State.Running = false
	State.TPActive = false
	State.SilentAim = false
	State.Aimbot = false
	State.Triggerbot = false
	State.KillAura = false
	State.Hitbox = false
	State.Wallbang = false
	State.NoRecoil = false
	State.InfAmmo = false
	State.GodMode = false
	State.ESPEnemies = false
	State.ESPItems = false
	State.Speed = false
	State.Jump = false
	State.Fly = false
	State.InfJump = false
	State.InfStamina = false
	State.Noclip = false
	ItemESPFolder:ClearAllChildren()
	ESPContainer.Visible = false
	syncHitboxes(false)
	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	SG:Destroy()
end)

-- ============================================================================
-- INICIO
-- ============================================================================
buildCombate()
buildPlayer()
buildLoot()
buildVeh()

miniB.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)

print(string.format("[%s] DUSTY TRIP HUB GUI-PRIO v1 listo", CONFIG.LogTag))
notify("DUSTY TRIP HUB", "v1 GUI propio listo", Theme.Accent)