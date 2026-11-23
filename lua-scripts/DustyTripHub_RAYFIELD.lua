--[[
  DUSTY TRIP HUB v2 -- RAYFIELD
  Misma logica de siempre, GUI ambientada en A Dusty Trip.
  Link alternativo si no carga:
  https://raw.githubusercontent.com/jensonhirst/Rayfield/master/source
]]

-- Si el juego crashea al cargar, descomenta esta linea (modo discreto de Rayfield):
-- pcall(function() getgenv().SecureMode = true end)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

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
local SessionId = "TS-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))

-- ============================================================================
-- TEMA DUSTY TRIP (tierra, arena, oxido y texto crema)
-- ============================================================================
local ThemeDusty = {
	TextColor = Color3.fromRGB(248, 242, 215),
	Background = Color3.fromRGB(20, 16, 12),
	Topbar = Color3.fromRGB(44, 33, 21),
	Shadow = Color3.fromRGB(10, 8, 6),

	NotificationBackground = Color3.fromRGB(28, 22, 15),
	NotificationActionsBackground = Color3.fromRGB(212, 82, 20),

	TabBackground = Color3.fromRGB(44, 33, 21),
	TabStroke = Color3.fromRGB(80, 55, 30),
	TabBackgroundSelected = Color3.fromRGB(232, 110, 18),
	TabTextColor = Color3.fromRGB(188, 168, 138),
	SelectedTabTextColor = Color3.fromRGB(14, 11, 9),

	ElementBackground = Color3.fromRGB(28, 22, 15),
	ElementBackgroundHover = Color3.fromRGB(44, 33, 21),
	SecondaryElementBackground = Color3.fromRGB(20, 16, 12),
	ElementStroke = Color3.fromRGB(80, 55, 30),
	SecondaryElementStroke = Color3.fromRGB(60, 42, 24),

	SliderBackground = Color3.fromRGB(90, 55, 25),
	SliderProgress = Color3.fromRGB(232, 110, 18),
	SliderStroke = Color3.fromRGB(255, 185, 80),

	ToggleBackground = Color3.fromRGB(30, 22, 14),
	ToggleEnabled = Color3.fromRGB(232, 110, 18),
	ToggleDisabled = Color3.fromRGB(80, 70, 58),
	ToggleEnabledStroke = Color3.fromRGB(255, 185, 80),
	ToggleDisabledStroke = Color3.fromRGB(110, 95, 78),
	ToggleEnabledOuterStroke = Color3.fromRGB(120, 85, 45),
	ToggleDisabledOuterStroke = Color3.fromRGB(60, 48, 34),

	DropdownSelected = Color3.fromRGB(44, 33, 21),
	DropdownUnselected = Color3.fromRGB(28, 22, 15),

	InputBackground = Color3.fromRGB(28, 22, 15),
	InputStroke = Color3.fromRGB(80, 55, 30),
	PlaceholderColor = Color3.fromRGB(128, 108, 82),
}

local Palette = {
	Accent = Color3.fromRGB(232, 110, 18),
	Gold = Color3.fromRGB(255, 185, 80),
	Cyan = Color3.fromRGB(86, 210, 225),
	Green = Color3.fromRGB(60, 190, 95),
	Red = Color3.fromRGB(218, 46, 40),
}

-- ============================================================================
-- VENTANA RAYFIELD
-- ============================================================================
local Window = Rayfield:CreateWindow({
	Name = "🌵 DUSTY TRIP HUB  |  v2 Rayfield",
	LoadingTitle = "DUSTY TRIP HUB",
	LoadingSubtitle = "Preparando el convoy...",
	Theme = ThemeDusty,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "DustyTripHub",
		FileName = "Config",
	},
	Discord = { Enabled = false },
	KeySystem = false,
})

local TCombate = Window:CreateTab("🎯 Combate")
local TJugador = Window:CreateTab("🏃 Jugador")
local TTP = Window:CreateTab("📍 TP")
local TLoot = Window:CreateTab("🧲 Loot")
local TVeh = Window:CreateTab("🚗 Vehiculo")

-- ============================================================================
-- ESTADO (la misma logica de siempre)
-- ============================================================================
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

local METERS_TO_STUDS = 3.5714
local ESP_MAX_RANGE = 220

local function notify(title, desc)
	if not State.Running then return end
	if CONFIG.VerboseLog then
		print(string.format("[%s] %s :: %s", CONFIG.LogTag, title, desc))
	end
	pcall(function()
		Rayfield:Notify({ Title = title, Content = desc, Duration = 3 })
	end)
end

-- ============================================================================
-- GUI PARA EL ESP (Rayfield dibuja su menu, nosotros dibujamos los recuadros)
-- ============================================================================
local function getGuiParent()
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h and not h:IsA("ScreenGui") then return h end
	end
	return CG
end

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "DTH_ESP_Rayfield"
ESPGui.ResetOnSpawn = false
ESPGui.DisplayOrder = 100
pcall(function()
	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		syn.protect_gui(ESPGui)
	end
end)
pcall(function() ESPGui.Parent = getGuiParent() end)
if not ESPGui.Parent then ESPGui.Parent = LP:WaitForChild("PlayerGui") end

-- Declarados aqui para que los botones que los usan ya los vean (scope)
local Connections = {}
local ItemESPFolder = Instance.new("Folder")
ItemESPFolder.Name = "DTH_LootESP"
ItemESPFolder.Parent = ESPGui

local ESPContainer = Instance.new("Frame")
ESPContainer.Name = "DTH_ESPContainer"
ESPContainer.Size = UDim2.fromScale(1, 1)
ESPContainer.BackgroundTransparency = 1
ESPContainer.Visible = false
ESPContainer.Parent = ESPGui

local ESPPool = {}
local Theme = Palette

local function createESPItem()
	local h = Instance.new("Frame")
	h.Size = UDim2.fromScale(1, 1)
	h.BackgroundTransparency = 1
	h.Visible = false
	h.Parent = ESPContainer

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(60, 90)
	box.BackgroundColor3 = Palette.Cyan
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
	hpFill.BackgroundColor3 = Palette.Green
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local nameTag = Instance.new("TextLabel")
	nameTag.Size = UDim2.new(1, 0, 0, 14)
	nameTag.Position = UDim2.new(0.5, -50, 0, -18)
	nameTag.AnchorPoint = Vector2.new(0.5, 0)
	nameTag.Font = Enum.Font.GothamBold
	nameTag.TextSize = 9
	nameTag.TextColor3 = Palette.Cyan
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
	hpTag.TextColor3 = Color3.fromRGB(248, 242, 215)
	hpTag.BackgroundTransparency = 0.6
	hpTag.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
	hpTag.Parent = h
	Instance.new("UICorner", hpTag).CornerRadius = UDim.new(0, 5)

	local headDot = Instance.new("Frame")
	headDot.AnchorPoint = Vector2.new(0.5, 0.5)
	headDot.Size = UDim2.fromOffset(8, 8)
	headDot.BackgroundColor3 = Palette.Accent
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
	ringStroke.Color = Palette.Red
	ringStroke.Thickness = 1.4
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

	local ptr = Instance.new("Frame")
	ptr.AnchorPoint = Vector2.new(0.5, 0)
	ptr.Size = UDim2.new(0, 8, 1, -22)
	ptr.BackgroundColor3 = Palette.Gold
	ptr.BorderSizePixel = 0
	ptr.Visible = false
	ptr.Parent = h
	Instance.new("UICorner", ptr).CornerRadius = UDim.new(1, 0)

	return { Holder = h, Box = box, HPBg = hpBg, HPFill = hpFill,
		NameTag = nameTag, HpTag = hpTag, HeadDot = headDot, Ring = ring, Pointer = ptr }
end

-- ============================================================================
-- UTILIDADES DE MOVIMIENTO (igual que antes)
-- ============================================================================
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

-- ============================================================================
-- ESP DE ENEMIGOS (igual que antes)
-- ============================================================================
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
		local accent = isTarget and Palette.Red
			or (dist < 45 and Palette.Accent)
			or (dist < 120 and Palette.Gold)
			or Palette.Cyan
		it.Box.BackgroundColor3 = accent
		it.NameTag.Text = "HOSTILE: " .. e.Name:upper()
		it.NameTag.TextColor3 = accent
		local pct = math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100 + 0.5)
		it.HpTag.Text = "[" .. math.floor(dist) .. "m] HP " .. pct .. "%"
		it.HpTag.TextColor3 = isTarget and Palette.Red or Color3.fromRGB(188, 168, 138)
		it.HPFill.Size = UDim2.fromScale(1, math.clamp(pct / 100, 0, 1))
		it.HPFill.BackgroundColor3 = pct > 55 and Palette.Green
			or (pct > 20 and Palette.Gold or Palette.Red)

		local head = e:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local pt, on = Cam:WorldToViewportPoint(head.Position)
			it.HeadDot.Visible = on and pt.Z > 0
			if it.HeadDot.Visible then
				it.HeadDot.Position = UDim2.fromOffset(pt.X, pt.Y)
				it.HeadDot.BackgroundColor3 = isTarget and Palette.Red or Palette.Accent
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
-- TP POR METROS (igual que antes)
-- ============================================================================
local function startMeterFlyTP(meters)
	local hrp = getHRP()
	if not hrp or typeof(meters) ~= "number" then return end
	local origin = getSpawnOrigin()
	if not origin then
		notify("TP Fly", "Spawn no detectado, ponte en spawn")
		return
	end
	State.TPActiveMeters = meters
	State.TPOriginZ = origin.Z
	State.TPActive = true
	clearMotion(hrp)
	notify("TP Fly", "Rumbo a " .. meters .. "m desde spawn")
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
		notify("TP Fly", "Frenado exacto en " .. State.TPActiveMeters .. "m desde spawn")
		return
	end
	hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z + (targetZ > hrp.Position.Z and 1 or -1) * step)
end

-- ============================================================================
-- SILENT AIM HOOK (igual que antes)
-- ============================================================================
local silentAimInstalled = false
local hookReady = false
local hookingActive = false
local oldNamecall = nil

local function installSilentAimHook()
	if silentAimInstalled and hookReady then return end
	silentAimInstalled = true
	pcall(function()
		local rawMT = typeof(getrawmetatable) == "function" and getrawmetatable(game)
		if not rawMT or typeof(hookmetamethod) ~= "function" or typeof(checkcaller) ~= "function" then return end
		if typeof(isreadonly) == "function" and isreadonly(rawMT) then pcall(setreadonly, rawMT, false) end

		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if hookingActive or not State.Running or not State.SilentAim or checkcaller() then
				return oldNamecall(self, ...)
			end
			local t = CachedFOVTarget
			if t and t.Parent and self == workspace then
				local m = typeof(getnamecallmethod) == "function" and getnamecallmethod() or ""
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
-- HITBOX / PERSONAJE / LOOT (igual que antes)
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
	notify("Loot", "Trajiste: " .. total)
end

-- ============================================================================
-- PESTAÑA: COMBATE
-- ============================================================================
local SCombate = TCombate:CreateSection("Punteria y FOV")

TCombate:CreateToggle({
	Name = "Silent Aim (en FOV)",
	CurrentValue = false,
	Flag = "SilentAim",
	Callback = function(v)
		State.SilentAim = v
		if v then refreshEnemyCache() installSilentAimHook() end
	end,
})

TCombate:CreateToggle({
	Name = "Aimbot suave",
	CurrentValue = false,
	Flag = "Aimbot",
	Callback = function(v)
		State.Aimbot = v
		if v then refreshEnemyCache() end
	end,
})

TCombate:CreateSlider({
	Name = "Suavizado del aimbot",
	Range = {1, 30}, Increment = 1, Suffix = "", CurrentValue = State.AimSmooth,
	Flag = "AimSmooth",
	Callback = function(v) State.AimSmooth = v end,
})

TCombate:CreateSlider({
	Name = "Radio del FOV",
	Range = {35, 340}, Increment = 5, Suffix = "px", CurrentValue = State.FOVRadius,
	Flag = "FOVRadius",
	Callback = function(v) State.FOVRadius = v end,
})

TCombate:CreateToggle({
	Name = "Mostrar circulo de FOV",
	CurrentValue = true,
	Flag = "ShowFOV",
	Callback = function(v) State.ShowFOV = v end,
})

local SParte = TCombate:CreateSection("Parte objetivo")
TCombate:CreateDropdown({
	Name = "Parte del cuerpo",
	Options = {"Head", "Torso", "HumanoidRootPart"},
	CurrentOption = {"Head"},
	MultipleOptions = false,
	Flag = "AimPart",
	Callback = function(opt) State.AimPart = opt[1] or "Head" end,
})

local SArmas = TCombate:CreateSection("Armas, enemigos y supervivencia")
TCombate:CreateToggle({ Name = "Triggerbot (en mira)", CurrentValue = false, Flag = "Triggerbot", Callback = function(v) State.Triggerbot = v end })
TCombate:CreateToggle({ Name = "Kill Aura (35m)", CurrentValue = false, Flag = "KillAura", Callback = function(v) State.KillAura = v end })
TCombate:CreateToggle({ Name = "Hitbox extendido", CurrentValue = false, Flag = "Hitbox", Callback = function(v) State.Hitbox = v syncHitboxes(v) end })
TCombate:CreateSlider({ Name = "Multiplicador hitbox", Range = {1, 5}, Increment = 1, Suffix = "x", CurrentValue = State.HitboxScale, Flag = "HitboxScale", Callback = function(v) State.HitboxScale = v if State.Hitbox then syncHitboxes(true) end end })
TCombate:CreateToggle({ Name = "Wallbang", CurrentValue = false, Flag = "Wallbang", Callback = function(v) State.Wallbang = v end })
TCombate:CreateToggle({ Name = "No Recoil", CurrentValue = false, Flag = "NoRecoil", Callback = function(v) State.NoRecoil = v end })
TCombate:CreateToggle({ Name = "Municion infinita", CurrentValue = false, Flag = "InfAmmo", Callback = function(v) State.InfAmmo = v end })
TCombate:CreateToggle({ Name = "God Mode", CurrentValue = false, Flag = "GodMode", Callback = function(v) State.GodMode = v end })

local SEsp = TCombate:CreateSection("ESP de enemigos")
TCombate:CreateToggle({ Name = "ESP enemigos (HUD)", CurrentValue = false, Flag = "ESPEnemies", Callback = function(v) State.ESPEnemies = v if v then refreshEnemyCache() end end })

-- Stats del mapa (mismo escaneo de antes)
local statsLabel = TCombate:CreateParagraph({
	Title = "Stats del mapa real",
	Content = "Escaneando el desierto...",
})

local function dashScan()
	local vehicles, otherModels, pickups, total = {}, {}, {}, 0
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
	return vehicles, otherModels, pickups, total
end

TCombate:CreateButton({
	Name = "Volcar modelos reales a la consola",
	Callback = function()
		local count = 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("MeshPart") then
				count += 1
				print(string.format("[%s] REAL_MODEL name=%q class=%s", CONFIG.LogTag, obj.Name, obj.ClassName))
			end
		end
		notify("Scan", "Volcados " .. count .. " modelos reales")
	end,
})

-- ============================================================================
-- PESTAÑA: JUGADOR
-- ============================================================================
local SMov = TJugador:CreateSection("Movimiento")

TJugador:CreateToggle({
	Name = "Velocidad personalizada",
	CurrentValue = false, Flag = "Speed",
	Callback = function(v)
		State.Speed = v
		local hum = getHum()
		if hum then hum.WalkSpeed = v and State.SpeedVal or 16 end
	end,
})
TJugador:CreateSlider({ Name = "Velocidad", Range = {16, 120}, Increment = 1, Suffix = "", CurrentValue = State.SpeedVal, Flag = "SpeedVal", Callback = function(v) State.SpeedVal = v local hum = getHum() if State.Speed and hum then hum.WalkSpeed = v end end })
TJugador:CreateToggle({
	Name = "Potencia de salto",
	CurrentValue = false, Flag = "Jump",
	Callback = function(v)
		State.Jump = v
		local hum = getHum()
		if hum then hum.UseJumpPower = true hum.JumpPower = v and State.JumpVal or 50 end
	end,
})
TJugador:CreateSlider({ Name = "Salto", Range = {50, 300}, Increment = 5, Suffix = "", CurrentValue = State.JumpVal, Flag = "JumpVal", Callback = function(v) State.JumpVal = v if State.Jump then local hum = getHum() if hum then hum.JumpPower = v end end end })
TJugador:CreateToggle({ Name = "Vuelo con CFrame", CurrentValue = false, Flag = "Fly", Callback = function(v) State.Fly = v clearMotion(getHRP()) end })
TJugador:CreateSlider({ Name = "Velocidad de vuelo", Range = {10, 220}, Increment = 5, Suffix = "", CurrentValue = State.FlyVal, Flag = "FlyVal", Callback = function(v) State.FlyVal = v end })
TJugador:CreateToggle({ Name = "Salto infinito", CurrentValue = false, Flag = "InfJump", Callback = function(v) State.InfJump = v end })
TJugador:CreateToggle({ Name = "Stamina infinita", CurrentValue = false, Flag = "InfStamina", Callback = function(v) State.InfStamina = v end })
TJugador:CreateToggle({
	Name = "Noclip", CurrentValue = false, Flag = "Noclip",
	Callback = function(v)
		State.Noclip = v
		if not v and LP.Character then
			for _, part in ipairs(LP.Character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
	end,
})

-- ============================================================================
-- PESTAÑA: TP
-- ============================================================================
local STP = TTP:CreateSection("Teletransporte por metros desde el spawn")
TTP:CreateInput({
	Name = "Metros (ej. 1500)",
	PlaceholderText = "1500",
	RemoveTextAfterFocusLost = false,
	Callback = function(txt) State._metersInput = txt end,
})
TTP:CreateButton({ Name = "Ir a metro exacto", Callback = function() local m = tonumber(State._metersInput) if m then startMeterFlyTP(m) else notify("TP", "Ingresa un numero valido") end end })
TTP:CreateButton({ Name = "Marcar spawn (origen 0m)", Callback = function() if captureSpawnOrigin(getHRP()) then local o = getSpawnOrigin() notify("TP Fly", "Spawn marcado en Z " .. math.floor(o.Z) .. " (0m)") else notify("TP Fly", "No hay personaje") end end })
TTP:CreateButton({ Name = "Frenar TP", Callback = function()
	local hrp = getHRP()
	if State.TPActive then
		State.TPActive = false
		clearMotion(hrp)
		local origin = getSpawnOrigin()
		local z = hrp and hrp.Position.Z or 0
		local cur = origin and math.floor((origin.Z - z) / METERS_TO_STUDS + 0.5) or 0
		notify("TP Fly", "Detenido en " .. math.max(0, cur) .. "m desde spawn")
	end
end })
TTP:CreateButton({ Name = "500m", Callback = function() startMeterFlyTP(500) end })
TTP:CreateButton({ Name = "1 Km", Callback = function() startMeterFlyTP(1000) end })
TTP:CreateButton({ Name = "5 Km", Callback = function() startMeterFlyTP(5000) end })

-- ============================================================================
-- PESTAÑA: LOOT
-- ============================================================================
local SLoot = TLoot:CreateSection("Atraer objetos")
TLoot:CreateButton({ Name = "Traer chapas / dinero", Callback = function() bringItems({"cap","chapa","coin","scrap","bottle"}) end })
TLoot:CreateButton({ Name = "Traer armas / municion", Callback = function() bringItems({"gun","ammo","rifle","pistol","shotgun","bullet"}) end })
TLoot:CreateButton({ Name = "Traer comida / agua", Callback = function() bringItems({"food","water","burger","can","drink","sponge"}) end })
TLoot:CreateButton({ Name = "Traer tuercas / motores", Callback = function() bringItems({"engine","motor","nut","bolt","wrench","jack","tire","c4","gold"}) end })
TLoot:CreateToggle({ Name = "ESP de items con nombres", CurrentValue = false, Flag = "ESPItems", Callback = function(v) State.ESPItems = v if not v then ItemESPFolder:ClearAllChildren() end end })

local function refreshItemESP()
	ItemESPFolder:ClearAllChildren()
	if not State.ESPItems or not State.Running then return end
	local hrp = getHRP()
	if not hrp then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		local n = obj.Name:lower()
		local col = nil
		if n:find("cap") or n:find("chapa") or n:find("coin") or n:find("scrap") then
			col = Palette.Gold
		elseif n:find("gun") or n:find("ammo") or n:find("rifle") or n:find("pistol") or n:find("shotgun") then
			col = Color3.fromRGB(255, 82, 68)
		elseif n:find("gas") or n:find("fuel") or n:find("oil") or n:find("canister") then
			col = Color3.fromRGB(58, 175, 75)
		elseif n:find("engine") or n:find("motor") or n:find("nut") or n:find("bolt") or n:find("wrench") or n:find("jack") then
			col = Palette.Accent
		end
		if col then
			local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position)
			local dist = pos and (pos - hrp.Position).Magnitude
			if dist and dist <= 220 then
				local hl = Instance.new("Highlight")
				hl.Adornee = obj
				hl.FillColor = col
				hl.OutlineColor = Color3.fromRGB(248, 242, 215)
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
-- PESTAÑA: VEHICULO
-- ============================================================================
local SVeh = TVeh:CreateSection("Mecanica y combustible")
TVeh:CreateButton({
	Name = "Combustible al 100%",
	Callback = function()
		local n = 0
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("NumberValue") then
				local nl = v.Name:lower()
				if nl:find("fuel") or nl:find("gas") or nl:find("nafta") then v.Value = 100 n += 1 end
			end
		end
		notify("Vehiculo", "Tanques llenados: " .. n)
	end,
})
TVeh:CreateButton({
	Name = "Reparar auto actual",
	Callback = function()
		local hum = getHum()
		local seat = hum and hum.SeatPart
		if seat and seat.Parent then
			for _, p in ipairs(seat.Parent:GetDescendants()) do
				if p:IsA("BasePart") then pcall(function() p.Broken = false end) end
			end
			notify("Vehiculo", "Vehiculo reparado")
		else
			notify("Vehiculo", "Subete a un vehiculo primero")
		end
	end,
})

-- ============================================================================
-- APAGAR TODO
-- ============================================================================
local SSalir = TCombate:CreateSection("Cerrar")
TCombate:CreateButton({
	Name = "Apagar todo y salir",
	Callback = function()
		notify("Dusty Trip Hub", "Apagando todo...")
		State.Running = false
		State.TPActive = false
		for _, k in ipairs({"SilentAim","Aimbot","Triggerbot","KillAura","Hitbox","Wallbang","NoRecoil","InfAmmo","GodMode","ESPEnemies","ESPItems","Speed","Jump","Fly","InfJump","InfStamina","Noclip"}) do
			State[k] = false
		end
		ItemESPFolder:ClearAllChildren()
		ESPContainer.Visible = false
		syncHitboxes(false)
		for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
		ESPGui:Destroy()
		Rayfield:Destroy()
	end,
})

-- ============================================================================
-- BUCLES PRINCIPALES (la misma logica de siempre)
-- ============================================================================
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
		local size = State.FOVRadius * 2
		ESPContainer.Size = UDim2.fromOffset(vp.X, vp.Y)
		if not ESPContainer:FindFirstChild("FOVCircle") then
			local circle = Instance.new("Frame")
			circle.Name = "FOVCircle"
			circle.AnchorPoint = Vector2.new(0.5, 0.5)
			circle.BackgroundColor3 = Palette.Accent
			circle.BackgroundTransparency = 0.94
			circle.BorderSizePixel = 0
			circle.Parent = ESPContainer
			local stroke = Instance.new("UIStroke")
			stroke.Color = Palette.Accent
			stroke.Thickness = 1.6
			stroke.Parent = circle
		end
		local circle = ESPContainer:FindFirstChild("FOVCircle")
		circle.Size = UDim2.fromOffset(size, size)
		circle.Position = UDim2.fromOffset(vp.X * 0.5, vp.Y * 0.5)
		circle.Visible = true
	else
		local circle = ESPContainer:FindFirstChild("FOVCircle")
		if circle then circle.Visible = false end
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
							if hum and hum.Health > 0 then hum.Health = 0 hum:BreakJoints() end
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
							if p:IsA("BasePart") then p.CanCollide = false p.Massless = true end
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
						if mdl and mdl:FindFirstChildOfClass("Humanoid") and tool then tool:Activate() end
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

task.spawn(function()
	while State.Running and task.wait(1) do
		local veh, other, pickups, total = dashScan()
		pcall(function()
			statsLabel:Set({
				Title = "Stats del mapa real",
				Content = string.format("jugadores: %d | autos: %d | modelos: %d | pickups: %d | objetos: %d",
					#Plrs:GetPlayers(), #veh, #other, #pickups, total),
			})
		end)
	end
end)

-- ============================================================================
-- INICIO
-- ============================================================================
Rayfield:LoadConfiguration()
print(string.format("[%s] DUSTY TRIP HUB v2 (Rayfield) listo | sesion %s", CONFIG.LogTag, SessionId))
notify("DUSTY TRIP HUB", "v2 Rayfield listo. Revisa la pestaña Guia.")
