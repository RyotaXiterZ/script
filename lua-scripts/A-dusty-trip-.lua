-- ============================================================================
-- DUSTY TRIP HUB [v13.0.0 APEX - BUILD CORREGIDA]
-- ============================================================================
-- Uso en entorno controlado de tu propio juego. Cada accion queda trazada
-- en la consola con el tag [DUSTY-TRIP-HUB] y un ID de sesion unico, para
-- que puedas correlacionarla con los eventos de tu servidor/anti-cheat.
-- ============================================================================

local CONFIG = {
	LogTag = "DUSTY-TRIP-HUB",
	VerboseLog = true,       -- imprime cada toggle en la consola
	EnemyCacheInterval = 0.35,
	ItemEspInterval = 3,
	NotifyDuration = 2.1,
}

-- ============================================================================
-- SERVICIOS
-- ============================================================================
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local CG = game:GetService("CoreGui")
local Plrs = game:GetService("Players")

local LP = Plrs.LocalPlayer
local Cam = workspace.CurrentCamera
local Mouse = LP:GetMouse()

local SessionId = "TS-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))

-- ============================================================================
-- CAPACIDADES DEL EJECUTOR + PARENT GUI CON SONDEO REAL
-- ============================================================================
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

	for _, candidate in ipairs(candidates) do
		local ok = pcall(function()
			local probe = Instance.new("ScreenGui")
			probe.Parent = candidate
			if probe.Parent ~= candidate then error("parent rechazado") end
			probe:Destroy()
		end)
		if ok then return candidate end
	end

	return LP:WaitForChild("PlayerGui")
end

local ParentGui = resolveParentGui()

if ParentGui:FindFirstChild("NexusHubApex") then
	ParentGui.NexusHubApex:Destroy()
end

local SG = Instance.new("ScreenGui")
SG.Name = "NexusHubApex"
SG.ResetOnSpawn = false
SG.DisplayOrder = 2147483647
SG.IgnoreGuiInset = true

-- FIX: si el parent elegido rechaza el ScreenGui, caer a PlayerGui.
local parentOK = pcall(function() SG.Parent = ParentGui end)
if not parentOK or SG.Parent ~= ParentGui then
	ParentGui = LP:WaitForChild("PlayerGui")
	SG.Parent = ParentGui
end

-- ============================================================================
-- PALETA
-- ============================================================================
-- ============================================================================
-- PALETA DUSTY TRIP (tema característico: suelo rojizo/tierra, textos crema)
-- ============================================================================
local Theme = {
	BgMain = Color3.fromRGB(20, 16, 12),
	GradTop = Color3.fromRGB(33, 26, 20),
	GradBot = Color3.fromRGB(13, 10, 8),
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

-- ============================================================================
-- ESTADO GLOBAL
-- ============================================================================
local METERS_TO_STUDS = 3.5714
local ESP_MAX_RANGE = 200

local State = {
	Running = true,

	TPActive = false,
	TPTargetMeters = 0,
	TPTargetZ = 0,
	TPStartX = 0,
	TPSpeed = 280,
	TPLastStreamZ = nil,

	-- Origen de la medicion: se captura al spawnear o se marca a mano.
	SpawnOrigin = nil,
	SpawnCaptured = false,

	ESPItems = false,
	ESPEnemies = false,

	Speed = false,
	SpeedVal = 35,
	Jump = false,
	JumpVal = 100,
	Fly = false,
	FlyVal = 55,
	FlyBoostMult = 2.2,
	InfJump = false,
	InfStamina = false,
	Noclip = false,

	SilentAim = false,
	Aimbot = false,
	AimSmooth = 12,
	AimPart = "Head",
	ShowFOV = true,
	FOVRadius = 135,
	Triggerbot = false,
	KillAura = false,
	Hitbox = false,
	HitboxScale = 2,
	Wallbang = false,
	NoRecoil = false,
	InfAmmo = false,
	GodMode = false,
}

-- ActiveMods ahora se CALCULA, no se incrementa a mano (evita desincronizacion)
local MOD_FLAGS = {
	"SilentAim", "Aimbot", "ShowFOV", "Triggerbot", "KillAura", "Hitbox",
	"Wallbang", "NoRecoil", "InfAmmo", "GodMode", "ESPEnemies", "ESPItems",
	"Speed", "Jump", "Fly", "InfJump", "InfStamina", "Noclip", "TPActive",
}

local function countActiveMods()
	local n = 0
	for _, key in ipairs(MOD_FLAGS) do
		if State[key] then n += 1 end
	end
	return n
end

State.ActiveMods = countActiveMods()
State.LastPos = nil

local CachedEnemies = {}
local CachedFOVTarget = nil
local Connections = {}

local function track(conn)
	table.insert(Connections, conn)
	return conn
end

local OriginalHeads = setmetatable({}, { __mode = "k" })

local espFolder = Instance.new("Folder")
espFolder.Name = "NexusESP_Items"
espFolder.Parent = SG

local advEspContainer = Instance.new("Frame")
advEspContainer.Name = "NexusESP_AdvancedOverlay"
advEspContainer.Size = UDim2.fromScale(1, 1)
advEspContainer.BackgroundTransparency = 1
advEspContainer.Visible = false
advEspContainer.Parent = SG

local advEspPool = {}

-- ============================================================================
-- FOV CIRCLE
-- ============================================================================
local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "NexusFOVCircle"
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.fromOffset(State.FOVRadius * 2, State.FOVRadius * 2)
FOVFrame.BackgroundColor3 = Theme.Accent
FOVFrame.BackgroundTransparency = 0.94
FOVFrame.Visible = false
FOVFrame.Parent = SG

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = FOVFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Theme.Accent
fovStroke.Thickness = 1.6
fovStroke.Transparency = 0.2
fovStroke.Parent = FOVFrame

-- ============================================================================
-- NOTIFICACIONES + LOG DE PRUEBAS
-- ============================================================================
local NotifHolder = Instance.new("Frame")
NotifHolder.Size = UDim2.new(0, 260, 1, -24)
NotifHolder.Position = UDim2.new(1, -272, 0, 12)
NotifHolder.BackgroundTransparency = 1
NotifHolder.Parent = SG

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifLayout.Padding = UDim.new(0, 7)
NotifLayout.Parent = NotifHolder

local notifSeq = 0
local function notify(title, desc, accentColor)
	if not State.Running then return end
	notifSeq += 1

	if CONFIG.VerboseLog then
		print(string.format("[%s][%s] #%d %s :: %s",
			CONFIG.LogTag, SessionId, notifSeq, tostring(title), tostring(desc)))
	end

	task.spawn(function()
		local vp = Cam and Cam.ViewportSize or Vector2.new(1280, 720)
		local cardW = math.clamp(vp.X - 24, 180, 255)

		local card = Instance.new("Frame")
		card.LayoutOrder = notifSeq
		card.Size = UDim2.fromOffset(cardW, 48)
		card.Position = UDim2.new(1, 80, 0, 0)
		card.BackgroundColor3 = Theme.Surface
		card.BackgroundTransparency = 0.04
		card.Parent = NotifHolder

		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		local sk = Instance.new("UIStroke", card)
		sk.Color = accentColor or Theme.Accent
		sk.Thickness = 1.2

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 4, 1, -14)
		bar.Position = UDim2.new(0, 8, 0, 7)
		bar.BackgroundColor3 = sk.Color
		bar.Parent = card
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, -22, 1, 0)
		txt.Position = UDim2.new(0, 18, 0, 0)
		txt.BackgroundTransparency = 1
		txt.RichText = true
		txt.Text = "<font size='10'><b>" .. tostring(title) .. "</b></font>\n<font size='8' color='#D8C9B8'>" .. tostring(desc) .. "</font>"
		txt.TextColor3 = Theme.TextMain
		txt.Font = Enum.Font.Gotham
		txt.TextSize = 10
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.TextTruncate = Enum.TextTruncate.AtEnd
		txt.Parent = card

		TS:Create(card, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()

		task.wait(CONFIG.NotifyDuration)
		if not card.Parent then return end

		local hideTween = TS:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 80, 0, 0),
			BackgroundTransparency = 1,
		})
		hideTween:Play()
		hideTween.Completed:Wait()
		if card.Parent then card:Destroy() end
	end)
end

-- ============================================================================
-- GUI PRINCIPAL
-- ============================================================================
local Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.fromOffset(490, 430)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.BackgroundColor3 = Theme.BgMain
Main.ClipsDescendants = true
Main.Parent = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local uiScale = Instance.new("UIScale")
uiScale.Scale = 1
uiScale.Parent = Main

local function updateResponsiveLayout()
	if not Cam then return end
	local vp = Cam.ViewportSize
	local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
	local baseW, baseH = 490, 430

	local scaleW = (vp.X - (isMobile and 20 or 32)) / baseW
	local scaleH = (vp.Y - (isMobile and 28 or 36)) / baseH
	local targetScale = math.clamp(math.min(scaleW, scaleH, isMobile and 0.92 or 1), 0.55, 1.05)

	uiScale.Scale = targetScale
	Main.Size = UDim2.fromOffset(baseW, baseH)

	local maxHalfX = math.max(40, (vp.X * 0.5) - ((baseW * targetScale) * 0.5))
	local maxHalfY = math.max(40, (vp.Y * 0.5) - ((baseH * targetScale) * 0.5))
	local curX = math.clamp(Main.Position.X.Offset, -maxHalfX, maxHalfX)
	local curY = math.clamp(Main.Position.Y.Offset, -maxHalfY, maxHalfY)
	Main.Position = UDim2.new(0.5, curX, 0.5, curY)
end

updateResponsiveLayout()
if Cam then
	track(Cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout))
end

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.GradTop),
	ColorSequenceKeypoint.new(1, Theme.GradBot),
})
mainGrad.Rotation = 135
mainGrad.Parent = Main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Theme.Accent
mainStroke.Thickness = 1.6
mainStroke.Transparency = 0.15
mainStroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 46)
TopBar.BackgroundColor3 = Theme.Surface
TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 14)

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 14)
topFix.Position = UDim2.new(0, 0, 1, -14)
topFix.BackgroundColor3 = Theme.Surface
topFix.BorderSizePixel = 0
topFix.Parent = TopBar

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, -24, 0, 1)
topLine.Position = UDim2.new(0, 12, 1, -1)
topLine.BackgroundColor3 = Theme.AccentRust
topLine.BackgroundTransparency = 0.45
topLine.BorderSizePixel = 0
topLine.Parent = TopBar

-- ============================================================================
-- LOGOTIPO DUSTY TRIP + ANIMACIONES (estilo Rayfield: card, glow, rolled-in)
-- ============================================================================
local Banner = Instance.new("TextLabel")
Banner.Text = "🌵 DUSTY TRIP — CONTROLLED HUB [v13.0 APEX]"
Banner.Font = Enum.Font.GothamBold
Banner.TextSize = 14
Banner.TextColor3 = Theme.AccentGold
Banner.BackgroundTransparency = 0.3
Banner.Size = UDim2.new(1, 0, 0, 26)
Banner.Position = UDim2.new(0, 16, 0, 24)
Banner.Parent = TopBar
Instance.new("UICorner", Banner).CornerRadius = UDim.new(0, 7)
local bannerStroke = Instance.new("UIStroke", Banner)
bannerStroke.Color = Theme.AccentRust
bannerStroke.Thickness = 1

local function addPulseGlow(obj, color, seconds)
	task.spawn(function()
		while obj and obj.Parent do
			TS:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.55,
			}):Play()
			TS:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 0.9,
			}):Play()
			wait(seconds * 0.5)
		end
	end)
end

local DustEmitter = Instance.new("ParticleEmitter")
DustEmitter.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.TextPlaceholder)})
DustEmitter.Texture = "rbxassetid://13711444658"
DustEmitter.Rate = 14
DustEmitter.Lifetime = NumberRange.new(1.4, 2.8)
DustEmitter.Acceleration = Vector3.new(0, 4, 0)
DustEmitter.VelocityInheritedFromParent = 0.3
DustEmitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(1, 1),
})
DustEmitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 2.6),
})
DustEmitter.ZOffset = 1
DustEmitter.LightEmission = 0.2
DustEmitter.Speed = NumberRange.new(4, 8)
DustEmitter.Parent = Main

-- Intro: rolar el hub desde arriba con glow en el telemetría (Rayfield-style)
local function entryAnimation()
	TS:Create(Main, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 18),
	}):Play()
	addPulseGlow(TelemetryPill, Theme.Accent, 2.2)
end
task.spawn(function()
	wait(1.6)
	entryAnimation()
end)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -188, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.RichText = true
TitleLabel.Text = "🌵 DUSTY TRIP HUB <font color='#FF7A1A'><b>APEX v13.0</b></font>"
TitleLabel.TextColor3 = Theme.TextMain
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local TelemetryPill = Instance.new("TextLabel")
TelemetryPill.Size = UDim2.new(0, 98, 0, 26)
TelemetryPill.Position = UDim2.new(1, -168, 0.5, -13)
TelemetryPill.BackgroundColor3 = Theme.SurfaceAlt
TelemetryPill.Text = "0 ACTIVE | 60 FPS"
TelemetryPill.TextColor3 = Theme.AccentGold
TelemetryPill.Font = Enum.Font.GothamBold
TelemetryPill.TextSize = 8
TelemetryPill.Parent = TopBar
Instance.new("UICorner", TelemetryPill).CornerRadius = UDim.new(0, 7)
Instance.new("UIStroke", TelemetryPill).Color = Theme.Border

local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0, 28, 0, 28)
MiniBtn.Position = UDim2.new(1, -64, 0.5, -14)
MiniBtn.BackgroundColor3 = Theme.SurfaceAlt
MiniBtn.Text = "—"
MiniBtn.TextColor3 = Theme.TextMain
MiniBtn.Font = Enum.Font.GothamBold
MiniBtn.TextSize = 12
MiniBtn.Parent = TopBar
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -14)
CloseBtn.BackgroundColor3 = Theme.Danger
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

local FloatPill = Instance.new("TextButton")
FloatPill.Size = UDim2.fromOffset(54, 54)
FloatPill.Position = UDim2.new(0.03, 0, 0.22, 0)
FloatPill.BackgroundColor3 = Theme.Surface
FloatPill.Text = "🌵"
FloatPill.TextSize = 24
FloatPill.Visible = false
FloatPill.Parent = SG
Instance.new("UICorner", FloatPill).CornerRadius = UDim.new(1, 0)
local floatSk = Instance.new("UIStroke", FloatPill)
floatSk.Color = Theme.Accent
floatSk.Thickness = 2

local function enableDrag(handle, target)
	local dragging = false
	local startInput, startPos

	track(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startInput = input.Position
			startPos = target.Position
		end
	end))

	track(handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	track(UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			local scaleFactor = (target == Main) and uiScale.Scale or 1
			target.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + (delta.X / scaleFactor),
				startPos.Y.Scale,
				startPos.Y.Offset + (delta.Y / scaleFactor)
			)
		end
	end))
end

enableDrag(TopBar, Main)
enableDrag(FloatPill, FloatPill)

local function setWindowVisible(vis)
	Main.Visible = vis
	FloatPill.Visible = not vis
end

track(MiniBtn.MouseButton1Click:Connect(function() setWindowVisible(false) end))
track(FloatPill.MouseButton1Click:Connect(function() setWindowVisible(true) end))
track(UIS.InputBegan:Connect(function(input, gp)
	if not gp and State.Running and input.KeyCode == Enum.KeyCode.RightShift then
		setWindowVisible(not Main.Visible)
	end
end))

-- ============================================================================
-- PESTAÑAS, BUSCADOR Y COMPONENTES
-- ============================================================================
local TabDock = Instance.new("Frame")
TabDock.Size = UDim2.new(1, -24, 0, 34)
TabDock.Position = UDim2.new(0, 12, 0, 54)
TabDock.BackgroundColor3 = Theme.Surface
TabDock.Parent = Main
Instance.new("UICorner", TabDock).CornerRadius = UDim.new(0, 9)
Instance.new("UIStroke", TabDock).Color = Theme.Border

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabList.VerticalAlignment = Enum.VerticalAlignment.Center
TabList.Padding = UDim.new(0, 5)
TabList.Parent = TabDock

local SearchInput = Instance.new("TextBox")
SearchInput.Size = UDim2.new(1, -24, 0, 30)
SearchInput.Position = UDim2.new(0, 12, 0, 94)
SearchInput.BackgroundColor3 = Theme.Surface
SearchInput.PlaceholderText = "🔍 Buscar en esta pestaña..."
SearchInput.PlaceholderColor3 = Theme.TextPlaceholder
SearchInput.Text = ""
SearchInput.TextColor3 = Theme.TextMain
SearchInput.Font = Enum.Font.Gotham
SearchInput.TextSize = 10
SearchInput.Parent = Main
Instance.new("UICorner", SearchInput).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", SearchInput).Color = Theme.Border

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -24, 1, -138)
ContentArea.Position = UDim2.new(0, 12, 0, 130)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Main

local pages, tabBtns = {}, {}
local currentTab = "Combate"

local function filterTabItems()
	local q = SearchInput.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
	local pg = pages[currentTab]
	if not pg then return end
	for _, child in ipairs(pg:GetChildren()) do
		if child:IsA("GuiObject") then
			if q == "" then
				child.Visible = true
			else
				local tag = child:GetAttribute("FilterTag") or ""
				child.Visible = tag:find(q, 1, true) ~= nil
			end
		end
	end
end

track(SearchInput:GetPropertyChangedSignal("Text"):Connect(filterTabItems))

local function addTab(name, icon)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.19, 0, 0, 26)
	btn.BackgroundColor3 = Theme.Surface
	btn.Text = icon .. " " .. name
	btn.TextColor3 = Theme.TextMuted
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 9
	btn.AutoButtonColor = false
	btn.Parent = TabDock
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Accent
	scroll.ElasticBehavior = Enum.ElasticBehavior.Always
	scroll.Visible = false
	scroll.Parent = ContentArea

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll

	pages[name] = scroll
	tabBtns[name] = btn

	track(btn.MouseButton1Click:Connect(function()
		currentTab = name
		for n, p in pairs(pages) do
			local active = (n == name)
			p.Visible = active
			TS:Create(tabBtns[n], TweenInfo.new(0.16), {
				BackgroundColor3 = active and Theme.Accent or Theme.Surface,
				TextColor3 = active and Theme.DarkInk or Theme.TextMuted,
			}):Play()
		end
		filterTabItems()
	end))

	return scroll
end

local pCbt = addTab("Combate", "🎯")
local pPlr = addTab("Player", "🏃")
local pTP = addTab("TP", "📍")
local pLoot = addTab("Loot", "🧲")
local pVeh = addTab("Veh", "🚗")

pages["Combate"].Visible = true
tabBtns["Combate"].BackgroundColor3 = Theme.Accent
tabBtns["Combate"].TextColor3 = Theme.DarkInk

local function makeSection(titleText, parent)
	local sec = Instance.new("TextLabel")
	sec:SetAttribute("FilterTag", titleText:lower())
	sec.Size = UDim2.new(1, 0, 0, 18)
	sec.BackgroundTransparency = 1
	sec.Text = string.upper(titleText)
	sec.TextColor3 = Theme.AccentGold
	sec.Font = Enum.Font.GothamBold
	sec.TextSize = 8
	sec.TextXAlignment = Enum.TextXAlignment.Left
	sec.Parent = parent
	return sec
end

local function makeBtn(text, bg, parent, cb)
	local b = Instance.new("TextButton")
	b:SetAttribute("FilterTag", text:lower())
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = bg or Theme.SurfaceAlt
	b.Text = text
	b.TextColor3 = Theme.TextMain
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local sk = Instance.new("UIStroke", b)
	sk.Color = Theme.Border

	local base = b.BackgroundColor3
	track(b.MouseEnter:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(
				math.clamp(base.R * 255 + 20, 0, 255),
				math.clamp(base.G * 255 + 18, 0, 255),
				math.clamp(base.B * 255 + 14, 0, 255)
			),
		}):Play()
	end))
	track(b.MouseLeave:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end))
	track(b.MouseButton1Click:Connect(cb))
	return b
end

local function makeTgl(text, parent, cb, initialState)
	local active = initialState or false
	local b = Instance.new("TextButton")
	b:SetAttribute("FilterTag", text:lower())
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = active and Theme.ActiveBg or Theme.Surface
	b.Text = "   " .. text
	b.TextColor3 = active and Theme.TextMain or Theme.TextMuted
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextTruncate = Enum.TextTruncate.AtEnd
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

	-- (quitado el incremento manual de ActiveMods; ahora se calcula)

	track(b.MouseButton1Click:Connect(function()
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
	end))

	return b
end

local function makeSld(label, minV, maxV, defV, parent, cb)
	local card = Instance.new("Frame")
	card:SetAttribute("FilterTag", label:lower())
	card.Size = UDim2.new(1, 0, 0, 42)
	card.BackgroundColor3 = Theme.Surface
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", card).Color = Theme.Border

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
	hitZone.Text = ""
	hitZone.AutoButtonColor = false
	hitZone.Parent = card

	local trackBar = Instance.new("Frame")
	trackBar.Size = UDim2.new(1, -6, 0, 7)
	trackBar.Position = UDim2.new(0, 3, 0.5, -3.5)
	trackBar.BackgroundColor3 = Theme.InactivePill
	trackBar.Parent = hitZone
	Instance.new("UICorner", trackBar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp((defV - minV) / (maxV - minV), 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Theme.Accent
	fill.Parent = trackBar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local sliding = false
	local function applyInput(input)
		local r = math.clamp((input.Position.X - trackBar.AbsolutePosition.X)
			/ math.max(trackBar.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor(minV + (maxV - minV) * r + 0.5)
		fill.Size = UDim2.new(r, 0, 1, 0)
		top.Text = label .. ": " .. val
		cb(val)
	end

	track(hitZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			applyInput(input)
		end
	end))
	track(hitZone.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end))
	-- FIX: tambien soltar al soltar fuera del hitZone
	track(UIS.InputEnded:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			sliding = false
		end
	end))
	track(UIS.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			applyInput(input)
		end
	end))

	return card
end

local function makeTargetPartSubTab(parent)
	local expanded = false

	local container = Instance.new("Frame")
	container:SetAttribute("FilterTag", "parte objetivo head torso humanoidrootpart aim")
	container.Size = UDim2.new(1, 0, 0, 34)
	container.BackgroundColor3 = Theme.Surface
	container.ClipsDescendants = true
	container.Parent = parent
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
	local sk = Instance.new("UIStroke", container)
	sk.Color = Theme.AccentRust
	sk.Thickness = 1.1
	sk.Transparency = 0.25

	local headerBtn = Instance.new("TextButton")
	headerBtn.Size = UDim2.new(1, 0, 0, 34)
	headerBtn.BackgroundColor3 = Theme.SurfaceAlt
	headerBtn.Text = "   🎯 Parte Objetivo"
	headerBtn.TextColor3 = Theme.TextMain
	headerBtn.Font = Enum.Font.GothamBold
	headerBtn.TextSize = 10
	headerBtn.TextXAlignment = Enum.TextXAlignment.Left
	headerBtn.AutoButtonColor = false
	headerBtn.Parent = container
	Instance.new("UICorner", headerBtn).CornerRadius = UDim.new(0, 8)

	local statusBadge = Instance.new("TextLabel")
	statusBadge.Size = UDim2.new(0, 126, 0, 20)
	statusBadge.Position = UDim2.new(1, -134, 0.5, -10)
	statusBadge.BackgroundColor3 = Theme.Accent
	statusBadge.Text = State.AimPart .. "  ▾"
	statusBadge.TextColor3 = Theme.DarkInk
	statusBadge.Font = Enum.Font.GothamBold
	statusBadge.TextSize = 8
	statusBadge.Parent = headerBtn
	Instance.new("UICorner", statusBadge).CornerRadius = UDim.new(0, 5)

	local drawer = Instance.new("Frame")
	drawer.Size = UDim2.new(1, -12, 0, 68)
	drawer.Position = UDim2.new(0, 6, 0, 38)
	drawer.BackgroundTransparency = 1
	drawer.Parent = container

	local drawerLayout = Instance.new("UIListLayout")
	drawerLayout.Padding = UDim.new(0, 4)
	drawerLayout.Parent = drawer

	local optionButtons = {}
	local partsList = {
		{ id = "Head", label = "🧠 Head (Cabeza)" },
		{ id = "Torso", label = "🦺 Torso (Pecho)" },
		{ id = "HumanoidRootPart", label = "⚙️ HumanoidRootPart (Centro)" },
	}

	local function refreshOptionVisuals()
		for _, opt in ipairs(partsList) do
			local btn = optionButtons[opt.id]
			if btn then
				local isSel = (State.AimPart == opt.id)
				TS:Create(btn, TweenInfo.new(0.14), {
					BackgroundColor3 = isSel and Theme.Accent or Theme.SurfaceAlt,
					TextColor3 = isSel and Theme.DarkInk or Theme.TextMain,
				}):Play()
			end
		end
		statusBadge.Text = State.AimPart .. (expanded and "  ▴" or "  ▾")
	end

	for _, opt in ipairs(partsList) do
		local pill = Instance.new("TextButton")
		pill.Size = UDim2.new(1, 0, 0, 20)
		pill.BackgroundColor3 = (State.AimPart == opt.id) and Theme.Accent or Theme.SurfaceAlt
		pill.Text = opt.label
		pill.TextColor3 = (State.AimPart == opt.id) and Theme.DarkInk or Theme.TextMain
		pill.Font = Enum.Font.GothamBold
		pill.TextSize = 8
		pill.AutoButtonColor = false
		pill.Parent = drawer
		Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)
		optionButtons[opt.id] = pill

		track(pill.MouseButton1Click:Connect(function()
			State.AimPart = opt.id
			refreshOptionVisuals()
			notify("Parte Objetivo", "Apuntando a: " .. opt.id, Theme.Accent)
		end))
	end

	track(headerBtn.MouseButton1Click:Connect(function()
		expanded = not expanded
		local targetH = expanded and 112 or 34
		TS:Create(container, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, targetH),
		}):Play()
		statusBadge.Text = State.AimPart .. (expanded and "  ▴" or "  ▾")
	end))

	return container
end

-- ============================================================================
-- UTILIDADES, CACHE, ESP Y SILENT AIM
-- ============================================================================
local function getHRP()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- Captura el punto de spawn: se toma al aparecer el Character (o al respawnear)
-- y se puede re-marcar a mano desde la pestaña TP si el script se ejecuta lejos.
local function captureSpawnOrigin(hrp)
	if not hrp or not hrp:IsA("BasePart") then return false end
	State.SpawnOrigin = hrp.Position
	State.SpawnCaptured = true
	return true
end

local function markSpawnHere()
	local hrp = getHRP()
	if not hrp then return false end
	State.SpawnOrigin = hrp.Position
	State.SpawnCaptured = true
	return true
end

local function getSpawnOrigin()
	if State.SpawnCaptured and State.SpawnOrigin then
		return State.SpawnOrigin
	end
	local hrp = getHRP()
	return hrp and hrp.Position or nil
end

local function getHum()
	local c = LP.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function clearMotion(part)
	if part and part:IsA("BasePart") then
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function getSeatedVehicleModel(hum)
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("BasePart") then
		local mdl = seat:FindFirstAncestorOfClass("Model")
		if mdl and mdl ~= LP.Character then
			return mdl
		end
	end
	return nil
end

local function moveVehicleIfSeated(hum, targetCF)
	local veh = getSeatedVehicleModel(hum)
	if not veh then return false end
	pcall(function()
		for _, p in ipairs(veh:GetDescendants()) do
			if p:IsA("BasePart") then clearMotion(p) end
		end
		veh:PivotTo(targetCF + Vector3.new(0, 2, 0))
	end)
	return true
end

local function findSafeGroundY(x, z, startY, ignoreList)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = ignoreList or {}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(x, startY or 600, z), Vector3.new(0, -1200, 0), params)
	return hit and (hit.Position.Y + 4) or nil
end

local function refreshEnemyCache()
	local list = {}
	local myChar = LP.Character
	local ok, desc = pcall(function() return workspace:GetDescendants() end)
	if not ok then
		CachedEnemies = list
		return
	end

	for _, obj in ipairs(desc) do
		if obj:IsA("Humanoid") and obj.Health > 0 and obj.Parent
			and obj.Parent:IsA("Model") and obj.Parent ~= myChar then
			if not Plrs:GetPlayerFromCharacter(obj.Parent) then
				local root = obj.Parent:FindFirstChild("HumanoidRootPart")
					or obj.RootPart or obj.Parent.PrimaryPart
				if root and root:IsA("BasePart") then
					table.insert(list, obj.Parent)
				end
			end
		end
	end
	CachedEnemies = list
end

local function getEnemies()
	if #CachedEnemies == 0 then
		refreshEnemyCache()
	end
	return CachedEnemies
end

local function hideAllAdvESP()
	advEspContainer.Visible = false
	for _, item in ipairs(advEspPool) do
		item.Holder.Visible = false
	end
end

local CORNER_LEN = 11
local CORNER_THICK = 2

local function makeBracket(parent)
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = parent

	local h = Instance.new("Frame")
	h.BackgroundColor3 = Theme.CyanSignal
	h.BorderSizePixel = 0
	h.Parent = root

	local v = Instance.new("Frame")
	v.BackgroundColor3 = Theme.CyanSignal
	v.BorderSizePixel = 0
	v.Parent = root

	return { Root = root, H = h, V = v }
end

local function getOffScreenArrow(worldPos)
	local vp = Cam.ViewportSize
	local pt = Cam:WorldToViewportPoint(worldPos)
	local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local d = Vector2.new(pt.X, pt.Y) - center
	if pt.Z <= 0 then d = -d end
	if d.Magnitude < 1 then d = Vector2.new(0, -1) end

	local halfW, halfH = center.X - 14, center.Y - 14
	local scale = math.huge
	if math.abs(d.X) > 0.001 then scale = math.min(scale, halfW / math.abs(d.X)) end
	if math.abs(d.Y) > 0.001 then scale = math.min(scale, halfH / math.abs(d.Y)) end

	return center + d.Unit * scale, math.deg(math.atan2(d.Y, d.X)) + 90
end

local function createAdvESPItem()
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Size = UDim2.fromScale(1, 1)
	holder.Position = UDim2.fromScale(0, 0)
	holder.Parent = advEspContainer

	local box = Instance.new("Frame")
	box.Name = "BoxFill"
	box.BackgroundColor3 = Theme.CyanSignal
	box.BackgroundTransparency = 0.95
	box.BorderSizePixel = 0
	box.Parent = holder

	local brackets = {
		makeBracket(holder), -- 1 TL
		makeBracket(holder), -- 2 TR
		makeBracket(holder), -- 3 BL
		makeBracket(holder), -- 4 BR
	}

	local headDot = Instance.new("Frame")
	headDot.AnchorPoint = Vector2.new(0.5, 0.5)
	headDot.Size = UDim2.fromOffset(6, 6)
	headDot.BackgroundColor3 = Theme.Accent
	headDot.BorderSizePixel = 0
	headDot.Parent = holder
	Instance.new("UICorner", headDot).CornerRadius = UDim.new(1, 0)

	local targetRing = Instance.new("Frame")
	targetRing.AnchorPoint = Vector2.new(0.5, 0.5)
	targetRing.Size = UDim2.fromOffset(24, 24)
	targetRing.BackgroundTransparency = 1
	targetRing.BorderSizePixel = 0
	targetRing.Visible = false
	targetRing.Parent = holder
	Instance.new("UICorner", targetRing).CornerRadius = UDim.new(1, 0)
	local ringStroke = Instance.new("UIStroke", targetRing)
	ringStroke.Color = Theme.Danger
	ringStroke.Thickness = 1.5

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBG"
	hpBg.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
	hpBg.BackgroundTransparency = 0.15
	hpBg.BorderSizePixel = 0
	hpBg.Parent = holder

	local hpFill = Instance.new("Frame")
	hpFill.AnchorPoint = Vector2.new(0, 1)
	hpFill.Position = UDim2.fromScale(0, 1)
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Theme.ActivePill
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	local nameTag = Instance.new("TextLabel")
	nameTag.Font = Enum.Font.Code
	nameTag.TextSize = 9
	nameTag.TextColor3 = Theme.CyanSignal
	nameTag.BackgroundColor3 = Color3.fromRGB(6, 8, 10)
	nameTag.BackgroundTransparency = 0.35
	nameTag.TextXAlignment = Enum.TextXAlignment.Left
	nameTag.TextTruncate = Enum.TextTruncate.AtEnd
	nameTag.Parent = holder
	Instance.new("UIPadding", nameTag).PaddingLeft = UDim.new(0, 4)

	local infoTag = Instance.new("TextLabel")
	infoTag.Font = Enum.Font.Code
	infoTag.TextSize = 8
	infoTag.TextColor3 = Theme.TextMuted
	infoTag.BackgroundColor3 = Color3.fromRGB(6, 8, 10)
	infoTag.BackgroundTransparency = 0.35
	infoTag.TextXAlignment = Enum.TextXAlignment.Left
	infoTag.Parent = holder
	Instance.new("UIPadding", infoTag).PaddingLeft = UDim.new(0, 4)

	local pointer = Instance.new("Frame")
	pointer.Name = "FootPointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.BackgroundColor3 = Theme.AccentGold
	pointer.BorderSizePixel = 0
	pointer.Parent = holder
	Instance.new("UICorner", pointer).CornerRadius = UDim.new(1, 0)

	local offArrow = Instance.new("TextLabel")
	offArrow.Text = "▲"
	offArrow.Font = Enum.Font.GothamBold
	offArrow.TextSize = 16
	offArrow.TextColor3 = Theme.AccentGold
	offArrow.BackgroundTransparency = 1
	offArrow.Visible = false
	offArrow.Parent = holder

	return {
		Holder = holder, Box = box, Brackets = brackets,
		HeadDot = headDot, TargetRing = targetRing,
		HPBg = hpBg, HPFill = hpFill,
		NameTag = nameTag, InfoTag = infoTag,
		Pointer = pointer, OffArrow = offArrow,
	}
end

local function getProjectedEnemyBox(model, root)
	if not Cam then return nil end
	local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
	if not ok or typeof(size) ~= "Vector3" or size.Magnitude < 0.1 then
		cf = root.CFrame
		size = Vector3.new(4, 6, 3)
	end

	local half = size * 0.5
	local corners = {
		cf * Vector3.new(-half.X, -half.Y, -half.Z),
		cf * Vector3.new(-half.X, -half.Y,  half.Z),
		cf * Vector3.new(-half.X,  half.Y, -half.Z),
		cf * Vector3.new(-half.X,  half.Y,  half.Z),
		cf * Vector3.new( half.X, -half.Y, -half.Z),
		cf * Vector3.new( half.X, -half.Y,  half.Z),
		cf * Vector3.new( half.X,  half.Y, -half.Z),
		cf * Vector3.new( half.X,  half.Y,  half.Z),
	}

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyVisible = false

	for _, cornerPos in ipairs(corners) do
		local pt, onScreen = Cam:WorldToViewportPoint(cornerPos)
		if pt.Z > 0 then
			if onScreen then anyVisible = true end
			minX = math.min(minX, pt.X)
			maxX = math.max(maxX, pt.X)
			minY = math.min(minY, pt.Y)
			maxY = math.max(maxY, pt.Y)
		end
	end

	if not anyVisible or maxX <= minX or maxY <= minY then
		return nil
	end
	return minX, minY, maxX, maxY
end

local function updateAdvancedESP()
	if not State.Running or not State.ESPEnemies or not Cam then
		hideAllAdvESP()
		return
	end

	local hrp = getHRP()
	if not hrp then
		hideAllAdvESP()
		return
	end

	advEspContainer.Visible = true
	local enemies = getEnemies()

	for i = #advEspPool + 1, #enemies do
		advEspPool[i] = createAdvESPItem()
	end

	local playerFeetWorld = hrp.Position - Vector3.new(0, 2.8, 0)
	local playerFeetScreen = Cam:WorldToViewportPoint(playerFeetWorld)
	local playerFeet2D = Vector2.new(playerFeetScreen.X, playerFeetScreen.Y)

	for i, item in ipairs(advEspPool) do
		local enemy = enemies[i]
		local hum = enemy and enemy:FindFirstChildOfClass("Humanoid")
		local root = enemy and (enemy:FindFirstChild("HumanoidRootPart")
			or (hum and hum.RootPart) or enemy.PrimaryPart)

		if not enemy or not enemy.Parent or not hum or hum.Health <= 0
			or not root or not root:IsA("BasePart") then
			item.Holder.Visible = false
			continue
		end

		local dist = (root.Position - hrp.Position).Magnitude
		if dist > ESP_MAX_RANGE then
			item.Holder.Visible = false
			continue
		end

		local minX, minY, maxX, maxY = getProjectedEnemyBox(enemy, root)
		if not minX then
			local aPos, aRot = getOffScreenArrow(root.Position)
			item.Holder.Visible = true
			item.Box.Visible = false
			for _, b in ipairs(item.Brackets) do b.Root.Visible = false end
			item.HeadDot.Visible = false
			item.TargetRing.Visible = false
			item.HPBg.Visible = false
			item.NameTag.Visible = false
			item.InfoTag.Visible = false
			item.Pointer.Visible = false
			item.OffArrow.Visible = true
			item.OffArrow.Position = UDim2.fromOffset(aPos.X - 9, aPos.Y - 11)
			item.OffArrow.Rotation = aRot
			continue
		end

		item.Holder.Visible = true
		item.Box.Visible = true
		for _, b in ipairs(item.Brackets) do b.Root.Visible = true end
		item.HPBg.Visible = true
		item.NameTag.Visible = true
		item.InfoTag.Visible = true
		item.Pointer.Visible = true
		item.OffArrow.Visible = false

		local w = math.max(12, maxX - minX)
		local h = math.max(12, maxY - minY)

		local isTarget = false
		if CachedFOVTarget and CachedFOVTarget.Parent then
			isTarget = (CachedFOVTarget:FindFirstAncestorOfClass("Model") == enemy)
		end

		local accent = isTarget and Theme.Danger
			or (dist < 45 and Theme.Accent)
			or (dist < 120 and Theme.AccentGold)
			or Theme.CyanSignal

		item.Box.Position = UDim2.fromOffset(minX, minY)
		item.Box.Size = UDim2.fromOffset(w, h)
		item.Box.BackgroundColor3 = accent

		local L = math.min(CORNER_LEN, math.max(5, math.min(w, h) * 0.28))
		local T = CORNER_THICK

		local bTL = item.Brackets[1]
		bTL.Root.Position = UDim2.fromOffset(minX, minY)
		bTL.H.Position = UDim2.fromOffset(0, 0)
		bTL.V.Position = UDim2.fromOffset(0, 0)

		local bTR = item.Brackets[2]
		bTR.Root.Position = UDim2.fromOffset(maxX, minY)
		bTR.H.Position = UDim2.fromOffset(-L, 0)
		bTR.V.Position = UDim2.fromOffset(-T, 0)

		local bBL = item.Brackets[3]
		bBL.Root.Position = UDim2.fromOffset(minX, maxY)
		bBL.H.Position = UDim2.fromOffset(0, -T)
		bBL.V.Position = UDim2.fromOffset(0, -L)

		local bBR = item.Brackets[4]
		bBR.Root.Position = UDim2.fromOffset(maxX, maxY)
		bBR.H.Position = UDim2.fromOffset(-L, -T)
		bBR.V.Position = UDim2.fromOffset(-T, -L)

		for _, b in ipairs(item.Brackets) do
			b.H.Size = UDim2.fromOffset(L, T)
			b.V.Size = UDim2.fromOffset(T, L)
			b.H.BackgroundColor3 = accent
			b.V.BackgroundColor3 = accent
		end

		local head = enemy:FindFirstChild("Head")
		local headPt = head and head:IsA("BasePart")
			and Cam:WorldToViewportPoint(head.Position) or nil
		local vpSize = Cam.ViewportSize
		if headPt and headPt.Z > 0 and headPt.X >= 0 and headPt.X <= vpSize.X
			and headPt.Y >= 0 and headPt.Y <= vpSize.Y then
			item.HeadDot.Visible = true
			item.HeadDot.Position = UDim2.fromOffset(headPt.X, headPt.Y)
			item.HeadDot.BackgroundColor3 = isTarget and Theme.Danger or Theme.Accent
			item.TargetRing.Visible = isTarget
			item.TargetRing.Position = UDim2.fromOffset(headPt.X, headPt.Y)
		else
			item.HeadDot.Visible = false
			item.TargetRing.Visible = false
		end

		local barW, gap = 5, 5
		item.HPBg.Position = UDim2.fromOffset(maxX + gap, minY)
		item.HPBg.Size = UDim2.fromOffset(barW, h)

		local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		item.HPFill.Size = UDim2.fromScale(1, hpRatio)
		item.HPFill.BackgroundColor3 = hpRatio > 0.5 and Theme.ActivePill
			or (hpRatio > 0.25 and Theme.AccentGold or Theme.Danger)

		local meters = math.floor(dist / METERS_TO_STUDS + 0.5)
		local tagY = math.max(0, minY - 26)
		local tagW = math.max(118, w)

		item.NameTag.Text = "HOSTILE // " .. enemy.Name:upper()
		item.NameTag.TextColor3 = accent
		item.NameTag.Position = UDim2.fromOffset(minX, tagY)
		item.NameTag.Size = UDim2.fromOffset(tagW, 12)

		item.InfoTag.Text = string.format("[%04dm] HP %3d%%%s",
			meters, math.floor(hpRatio * 100 + 0.5), isTarget and "  ◄ LOCK" or "")
		item.InfoTag.TextColor3 = isTarget and Theme.Danger or Theme.TextMuted
		item.InfoTag.Position = UDim2.fromOffset(minX, tagY + 12)
		item.InfoTag.Size = UDim2.fromOffset(tagW, 11)

		local footStart = Vector2.new((minX + maxX) * 0.5, maxY + 3)
		local delta = playerFeet2D - footStart
		if delta.Magnitude < 6 then delta = Vector2.new(0, 16) end

		local dir = delta.Unit
		local lineLen = math.clamp(delta.Magnitude, 10, 80)

		item.Pointer.Position = UDim2.fromOffset(footStart.X, footStart.Y)
		item.Pointer.Size = UDim2.fromOffset(isTarget and 2 or 1, lineLen)
		item.Pointer.Rotation = math.deg(math.atan2(dir.Y, dir.X)) - 90
		item.Pointer.BackgroundColor3 = isTarget and Theme.Danger or Theme.AccentGold
	end
end

local function resolveTargetPart(enemy)
	if not enemy or not enemy.Parent then return nil end
	local mode = State.AimPart
	if mode == "Head" then
		return enemy:FindFirstChild("Head") or enemy:FindFirstChild("UpperTorso")
			or enemy:FindFirstChild("Torso") or enemy:FindFirstChild("HumanoidRootPart")
	elseif mode == "Torso" then
		return enemy:FindFirstChild("UpperTorso") or enemy:FindFirstChild("Torso")
			or enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
	else
		return enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("UpperTorso")
			or enemy:FindFirstChild("Torso") or enemy:FindFirstChild("Head")
	end
end

local function getAimCenter()
	local vp = Cam and Cam.ViewportSize or Vector2.new(1280, 720)
	return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

local function computeBestTargetInFOV(maxRange)
	if not Cam then return nil end
	local center = getAimCenter()
	local hrp = getHRP()
	local bestPart = nil
	local bestScreenDist = State.FOVRadius

	for _, enemy in ipairs(CachedEnemies) do
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then continue end
		local part = resolveTargetPart(enemy)
		if part and part:IsA("BasePart") then
			if hrp and maxRange and (part.Position - hrp.Position).Magnitude > maxRange then
				continue
			end
			local screenPos, onScreen = Cam:WorldToViewportPoint(part.Position)
			if onScreen and screenPos.Z > 0 then
				local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
				if dist2D <= bestScreenDist then
					bestScreenDist = dist2D
					bestPart = part
				end
			end
		end
	end
	return bestPart
end

-- ----------------------------------------------------------------------------
-- SILENT AIM: instalacion protegida y una sola vez
-- ----------------------------------------------------------------------------
local silentAimInstalled = false
local hookReady = false
local hookingActive = false
local oldNamecall, oldIndex = nil, nil

local function installSilentAimHook()
	if silentAimInstalled and hookReady then return end
	silentAimInstalled = true

	local ok, err = pcall(function()
		local rawMT = getrawmetatable and getrawmetatable(game)
		if not rawMT or not hookmetamethod or not checkcaller then
			warn(CONFIG.LogTag .. " SilentAim: este executor no expone getrawmetatable/hookmetamethod/checkcaller")
			return
		end

		local wasReadOnly = isreadonly and isreadonly(rawMT) or false
		if wasReadOnly then pcall(setreadonly, rawMT, false) end

		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if hookingActive or not State.Running or not State.SilentAim or checkcaller() then
				return oldNamecall(self, ...)
			end

			local target = CachedFOVTarget
			if target and target.Parent and self == workspace then
				local method = getnamecallmethod()
				if method == "Raycast" or method == "raycast" then
					local args = { ... }
					local origin = args[1]
					if typeof(origin) == "Vector3" then
						hookingActive = true
						local dir = target.Position - origin
						args[2] = dir.Unit * math.clamp(dir.Magnitude + 15, 10, 600)
						hookingActive = false
						return oldNamecall(self, table.unpack(args))
					end
				elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
					local args = { ... }
					local ray = args[1]
					if typeof(ray) == "Ray" then
						hookingActive = true
						local dir = target.Position - ray.Origin
						args[1] = Ray.new(ray.Origin, dir.Unit * math.clamp(dir.Magnitude + 15, 10, 600))
						hookingActive = false
						return oldNamecall(self, table.unpack(args))
					end
				end
			end
			return oldNamecall(self, ...)
		end)

		oldIndex = hookmetamethod(game, "__index", function(self, key)
			if hookingActive or not State.Running or not State.SilentAim or checkcaller() then
				return oldIndex(self, key)
			end
			if self == Mouse and (key == "Hit" or key == "Target") then
				local target = CachedFOVTarget
				if target and target.Parent then
					return (key == "Hit") and target.CFrame or target
				end
			end
			return oldIndex(self, key)
		end)

		if wasReadOnly then pcall(setreadonly, rawMT, true) end
		hookReady = true
	end)

	if not ok then
		warn(CONFIG.LogTag .. " installSilentAimHook fallo: " .. tostring(err))
	end
end

local function syncHitboxes(enable)
	for _, enemy in ipairs(getEnemies()) do
		local head = enemy:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			if enable then
				if not OriginalHeads[head] then
					OriginalHeads[head] = { Size = head.Size, Transparency = head.Transparency }
				end
				head.Size = Vector3.new(6, 6, 6) * State.HitboxScale
				head.Transparency = 0.35
			elseif OriginalHeads[head] then
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
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end
end

track(LP.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	if State.Running then applyCharacterMods(char) end
	-- Cada respawn vuelve a caer en el spawn: se recalibra el origen del TP.
	local hrp = char:FindFirstChild("HumanoidRootPart")
	captureSpawnOrigin(hrp)
end))

-- Si ya habia personaje cuando se ejecuto, se toma esa posicion como spawn.
captureSpawnOrigin(getHRP())

local function bringItems(keywords)
	local hrp = getHRP()
	if not hrp then return end
	local myChar = LP.Character
	local total = 0

	for _, item in ipairs(workspace:GetDescendants()) do
		local isMine = myChar and item:IsDescendantOf(myChar)
		if isMine then continue end

		local n = item.Name:lower()
		for _, kw in ipairs(keywords) do
			if n:find(kw, 1, true) then
				if item:IsA("BasePart") and not item.Anchored then
					item.CFrame = hrp.CFrame + Vector3.new(0, 2, -3)
					total += 1
					break
				elseif item:IsA("Model") and item.PrimaryPart and not item.PrimaryPart.Anchored then
					item:PivotTo(hrp.CFrame + Vector3.new(0, 2, -3))
					total += 1
					break
				end
			end
		end
	end
	notify("Loot", "Objetos atraídos: " .. total, Theme.AccentGold)
end

-- ============================================================================
-- PESTAÑA 1: COMBATE
-- ============================================================================
makeSection("Puntería & FOV")
makeTgl("👻 Silent Aim (En FOV)", pCbt, function(s)
	State.SilentAim = s
	if s then
		refreshEnemyCache()
		installSilentAimHook()
	end
end)
makeTgl("🎯 Aimbot Suave (Lerp Camera)", pCbt, function(s)
	State.Aimbot = s
	if s then refreshEnemyCache() end
end)
makeTargetPartSubTab(pCbt)
makeSld("Suavizado Aimbot", 1, 30, State.AimSmooth, pCbt, function(v) State.AimSmooth = v end)
makeTgl("⭕ Mostrar FOV Circle", pCbt, function(s) State.ShowFOV = s end, true)
makeSld("Radio FOV (px)", 35, 340, State.FOVRadius, pCbt, function(v)
	State.FOVRadius = v
	FOVFrame.Size = UDim2.fromOffset(v * 2, v * 2)
end)

makeSection("Armas, Enemigos & Supervivencia")
makeTgl("🔫 Triggerbot (En mira)", pCbt, function(s) State.Triggerbot = s end)
makeTgl("🗡️ Kill Aura (35m)", pCbt, function(s) State.KillAura = s end)
makeTgl("💥 Hitbox Extendido", pCbt, function(s)
	State.Hitbox = s
	syncHitboxes(s)
end)
makeSld("Multiplicador Hitbox", 1, 5, State.HitboxScale, pCbt, function(v)
	State.HitboxScale = v
	if State.Hitbox then syncHitboxes(true) end
end)
makeTgl("🧱 Wallbang", pCbt, function(s) State.Wallbang = s end)
makeTgl("🎯 No Recoil", pCbt, function(s) State.NoRecoil = s end)
makeTgl("♾️ Munición Infinita", pCbt, function(s) State.InfAmmo = s end)
makeTgl("🛡️ God Mode", pCbt, function(s) State.GodMode = s end)
makeTgl("👾 ESP Enemigos (Box + HP + Línea)", pCbt, function(s)
	State.ESPEnemies = s
	if s then refreshEnemyCache() else hideAllAdvESP() end
end)

-- ============================================================================
-- DASHBOARD: STATS REALES (vehículos, armas, pickups, modelos) + TERMINAL
-- ============================================================================
local DashHead = Instance.new("TextLabel")
DashHead.Text = "── STATS (mapa real) ──"
DashHead.Font = Enum.Font.GothamBold
DashHead.TextSize = 9
DashHead.TextColor3 = Theme.AccentGold
DashHead.BackgroundTransparency = 1
DashHead.Size = UDim2.new(1, 0, 0, 16)
DashHead.Parent = pCbt

local DashBody = Instance.new("TextLabel")
DashBody.Font = Enum.Font.Gotham
DashBody.TextSize = 8
DashBody.TextColor3 = Theme.TextMuted
DashBody.TextXAlignment = Enum.TextXAlignment.Left
DashBody.Size = UDim2.new(1, -4, 0, 84)
DashBody.BackgroundColor3 = Theme.Surface
DashBody.BackgroundTransparency = 0.14
DashBody.Parent = pCbt
Instance.new("UICorner", DashBody).CornerRadius = UDim.new(0, 7)
Instance.new("UIStroke", DashBody).Color = Theme.Border

local dashPickupKeys = {
	"cap", "chapa", "coin", "scrap", "bottle", "drink", "food", "can", "sponge",
	"gun", "ammo", "rifle", "pistol", "shotgun", "bullet", "c4", "gold",
	"engine", "motor", "nut", "bolt", "wrench", "jack", "tire",
}

local function dashScan()
	local vehicles, weapons, otherModels, pickups, total = {}, {}, {}, {}, 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("MeshPart") then
			local seat = obj:FindFirstChildWhichIsA("VehicleSeat", true)
			if seat then
				table.insert(vehicles, obj.Name)
			else
				table.insert(otherModels, obj.Name)
				local n = obj.Name:lower()
				for _, kw in ipairs(dashPickupKeys) do
					if n:find(kw, 1, true) then table.insert(pickups, obj.Name); break end
				end
			end
			total += 1
		end
	end
	if #weapons == 0 and LP.Character then
		-- armas instaladas en la consola (mock realisticamente)
		local inst = 0
		for _, t in ipairs(LP.Character:GetDescendants()) do
			if t:IsA("Tool") then inst += 1 end
		end
		if inst > 0 then weapons = {"HerramientasJugador"} end
	end
	return vehicles, weapons, otherModels, pickups, total
end

local function dashBodyUpdate()
	local veh, wep, other, pickups, total = dashScan()
	local names = {}
	for _, n in ipairs(veh) do table.insert(names, n) end
	DashBody.Text = table.concat({
		"[ DUSTY TRIP — STATS ]",
		string.format(" players: %d | cars: %d %s", #Plrs:GetPlayers(), #veh, table.concat(names, ", ")),
		string.format(" modelos: %d | pickups: %d %s", #other, #pickups, table.concat(pickups, ", ")),
		string.format(" enemigos: %d | objetos scrollables: %d", #getEnemies(), total),
	}, "\n")
	DashHead.BackgroundTransparency = #getEnemies() > 0 and 0.75 or 0.9
end

local function dashVehModels()
	local out = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:FindFirstChildWhichIsA("VehicleSeat", true) then
			table.insert(out, string.format("%-18s seats=%d", obj.Name, #obj:FindChildrenWhichIsA("VehicleSeat")))
		end
	end
	return table.concat(out, "\n")
end

makeBtn("📄 Dump: listar modelos reales", Theme.SurfaceAlt, pCbt, function()
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("MeshPart") then
			count += 1
			local seat = obj:FindFirstChildWhichIsA("VehicleSeat", true)
			print(string.format("[%s] REAL_MODEL name=%q class=%s seat=%s pos=%.0f,%.0f,%.0f",
				CONFIG.LogTag, obj.Name, obj.ClassName, tostring(seat ~= nil),
				obj.Position.X, obj.Position.Y, obj.Position.Z))
		end
	end
	notify("Scan", "Dumped " .. count .. " modelos reales (consola)", Theme.AccentGold)
end)

makeBtn("📌 Dump: vehículos", Theme.SurfaceAlt, pCbt, function()
	local s = dashVehModels()
	print(string.format("[%s] REAL_VEHICLES\n%s", CONFIG.LogTag, s ~= "" and s or "(none)"))
	notify("Scan", dashVehModels() ~= "" and dashVehModels() or "(no hayvehículos)", Theme.AccentGold)
end)

-- ============================================================================
-- TERMINAL (log vivo, tipo consola)
-- ============================================================================
local Terminal = Instance.new("ScrollingFrame")
Terminal.Name = "EventTerminal"
Terminal.Size = UDim2.new(1, -4, 0, 72)
Terminal.Position = UDim2.new(2, 0, 0, 346)
Terminal.Active = true
Terminal.BackgroundColor3 = Color3.fromRGB(7, 5, 3)
Terminal.ScrollBarThickness = 3
Terminal.ScrollBarImageColor3 = Theme.Accent
Terminal.AutomaticCanvasSize = Enum.AutomaticSize.Y
Terminal.Parent = pCbt
Instance.new("UICorner", Terminal).CornerRadius = UDim.new(0, 7)

local TermBody = Instance.new("TextLabel")
TermBody.Font = Enum.Font.Code
TermBody.TextSize = 7
TermBody.TextColor3 = Theme.TextMuted
TermBody.TextXAlignment = Enum.TextXAlignment.Left
TermBody.Size = UDim2.new(1, -10, 1, -8)
TermBody.BackgroundTransparency = 1
TermBody.Text = ""
TermBody.Parent = Terminal
local termLines = {}
local termCap = 60
local function termPush(s)
	table.insert(termLines, "[DUSTY TRIP X] " .. s)
	while #termLines > termCap do table.remove(termLines, 1) end
	TermBody.Text = table.concat(termLines, "\n")
end

-- Timeline de la terminal: envejezca los eventos + spotlight en al fatally active
local function termHeartbeat()
	local l = {}
	for _, s in ipairs(termLines) do
		table.insert(l, s)
	end
	TermBody.Text = table.concat(l, "\n")
end
termHeartbeat()
task.spawn(function()
	while true do
		wait(1.6)
		if #termLines > 0 then TermBody.Text = table.concat(termLines, "\n") end
	end
end)

track(UIS.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then TermBody.Text = table.concat(termLines, "\n") end end))

-- Bucle del Dashboard: refresh del mapa real + eventos en la terminal
task.spawn(function()
	while true do
		dashBodyUpdate()
		termPush("dash: " .. tostring(#getEnemies()) .. " enemigos")
		wait(2.5)
	end
end())

-- ============================================================================
-- PESTAÑA 2: PLAYER
-- ============================================================================
makeSection("Movimiento")
makeTgl("⚡ Velocidad personalizada", pPlr, function(s)
	State.Speed = s
	local hum = getHum()
	if hum then hum.WalkSpeed = s and State.SpeedVal or 16 end
end)
makeSld("Velocidad", 16, 120, State.SpeedVal, pPlr, function(v)
	State.SpeedVal = v
	local hum = getHum()
	if State.Speed and hum then hum.WalkSpeed = v end
end)

makeTgl("🦘 Potencia de salto", pPlr, function(s)
	State.Jump = s
	local hum = getHum()
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = s and State.JumpVal or 50
	end
end)
makeSld("Salto", 50, 300, State.JumpVal, pPlr, function(v)
	State.JumpVal = v
	local hum = getHum()
	if State.Jump and hum then hum.JumpPower = v end
end)

makeTgl("✈️ Vuelo CFrame (WASD + Space/Shift)", pPlr, function(s)
	State.Fly = s
	clearMotion(getHRP())
end)
makeSld("Velocidad de vuelo", 10, 220, State.FlyVal, pPlr, function(v) State.FlyVal = v end)

makeTgl("♾️ Salto infinito", pPlr, function(s) State.InfJump = s end)
track(UIS.JumpRequest:Connect(function()
	if State.Running and State.InfJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end))

makeTgl("💨 Stamina infinita", pPlr, function(s) State.InfStamina = s end)
makeTgl("👻 Noclip", pPlr, function(s)
	State.Noclip = s
	if not s and LP.Character then
		for _, part in ipairs(LP.Character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end)

-- ============================================================================
-- PESTAÑA 3: TP POR METROS
-- ============================================================================
local function startMeterFlyTP(meters)
	local hrp = getHRP()
	if not hrp or typeof(meters) ~= "number" then return end

	local origin = getSpawnOrigin()
	if not origin then
		notify("TP Fly", "No hay posicion de spawn conocida", Theme.Danger)
		return
	end

	State.LastPos = hrp.Position
	State.TPTargetMeters = meters
	-- La distancia se mide desde el SPAWN, no desde donde estes parado.
	State.TPTargetZ = origin.Z - meters * METERS_TO_STUDS
	State.TPStartX = origin.X
	State.TPLastStreamZ = hrp.Position.Z
	State.TPActive = true
	clearMotion(hrp)

	notify("TP Fly", "Rumbo a " .. meters .. "m desde spawn (Z " .. math.floor(origin.Z) .. ")", Theme.Accent)
end

local function stepMeterFlyTP(dt)
	if not State.TPActive then return end
	local hrp = getHRP()
	local hum = getHum()
	if not hrp then
		State.TPActive = false
		return
	end

	clearMotion(hrp)

	-- FIX: antes era `local _, rotY, _ = ...` (dos locales con el mismo nombre)
	local _, rotY = hrp.CFrame:ToOrientation()
	local deltaZ = State.TPTargetZ - hrp.Position.Z
	local distStuds = math.abs(deltaZ)
	local stepStuds = State.TPSpeed * dt

	if distStuds <= math.max(stepStuds, 0.25) then
		local finalPos = Vector3.new(State.TPStartX, hrp.Position.Y, State.TPTargetZ)
		local ignore = { LP.Character }
		local veh = getSeatedVehicleModel(hum)
		if veh then table.insert(ignore, veh) end

		local groundY = findSafeGroundY(finalPos.X, finalPos.Z, math.max(finalPos.Y + 150, 450), ignore)
		if groundY then
			finalPos = Vector3.new(finalPos.X, groundY, finalPos.Z)
		end

		local finalCF = CFrame.new(finalPos) * CFrame.Angles(0, rotY, 0)
		local movedVeh = moveVehicleIfSeated(hum, finalCF)
		if not movedVeh then hrp.CFrame = finalCF end
		clearMotion(hrp)
		State.TPActive = false
		State.TPLastStreamZ = nil

		notify("TP Fly", "Frenado exacto en " .. State.TPTargetMeters .. "m desde spawn", Theme.ActiveBorder)
		return
	end

	local dirZ = (deltaZ > 0) and 1 or -1
	local moveZ = math.min(distStuds, stepStuds) * dirZ
	local nextZ = hrp.Position.Z + moveZ
	local safeY = (hrp.Position.Y < 15) and 45 or hrp.Position.Y

	if not State.TPLastStreamZ or math.abs(nextZ - State.TPLastStreamZ) >= 650 then
		State.TPLastStreamZ = nextZ
		pcall(function()
			if typeof(workspace.RequestStreamAsync) == "function" then
				workspace:RequestStreamAsync(Vector3.new(State.TPStartX, safeY, nextZ))
			end
		end)
	end

	local stepCF = CFrame.new(State.TPStartX, safeY, nextZ) * CFrame.Angles(0, rotY, 0)
	local movedVeh = moveVehicleIfSeated(hum, stepCF)
	if not movedVeh then hrp.CFrame = stepCF end
	clearMotion(hrp)
end

makeSection("TP por Metros (Lógica Fly)")
local meterBox = Instance.new("TextBox")
meterBox:SetAttribute("FilterTag", "metros distancia tp")
meterBox.Size = UDim2.new(1, 0, 0, 32)
meterBox.BackgroundColor3 = Theme.Surface
meterBox.PlaceholderText = "Ingresar metros (ej. 1500)..."
meterBox.PlaceholderColor3 = Theme.TextPlaceholder
meterBox.TextColor3 = Theme.TextMain
meterBox.Font = Enum.Font.Gotham
meterBox.TextSize = 10
meterBox.Parent = pTP
Instance.new("UICorner", meterBox).CornerRadius = UDim.new(0, 7)
Instance.new("UIStroke", meterBox).Color = Theme.Border

makeBtn("✈️ Iniciar TP a Metro Exacto", Theme.AccentRust, pTP, function()
	local m = tonumber(meterBox.Text)
	if m then startMeterFlyTP(m) else notify("TP", "Ingresa un número válido", Theme.Danger) end
end)

makeBtn("📍 Marcar spawn aqui (origen 0m)", Theme.ActiveBg, pTP, function()
	if markSpawnHere() then
		local o = getSpawnOrigin()
		notify("TP Fly", "Spawn marcado en Z " .. math.floor(o.Z) .. " (0m)", Theme.ActiveBorder)
	else
		notify("TP Fly", "No hay personaje", Theme.Danger)
	end
end)

makeBtn("🛑 Frenar TP Ahora", Color3.fromRGB(76, 30, 26), pTP, function()
	local hrp = getHRP()
	if State.TPActive then
		State.TPActive = false
		clearMotion(hrp)
		local z = hrp and hrp.Position.Z or 0
		local origin = getSpawnOrigin()
		local curMeters = origin and math.floor((origin.Z - z) / METERS_TO_STUDS + 0.5)
			or math.floor(math.abs(z / METERS_TO_STUDS) + 0.5)
		notify("TP Fly", "Detenido en " .. math.max(0, curMeters) .. "m desde spawn", Theme.AccentGold)
	end
end)

local stepRow = Instance.new("Frame")
stepRow:SetAttribute("FilterTag", "500m 1km 5km")
stepRow.Size = UDim2.new(1, 0, 0, 32)
stepRow.BackgroundTransparency = 1
stepRow.Parent = pTP
local stepGrid = Instance.new("UIGridLayout")
stepGrid.CellSize = UDim2.new(0.32, 0, 1, 0)
stepGrid.CellPadding = UDim2.new(0.02, 0, 0, 0)
stepGrid.Parent = stepRow

makeBtn("500m", Theme.SurfaceAlt, stepRow, function() startMeterFlyTP(500) end)
makeBtn("1Km", Theme.SurfaceAlt, stepRow, function() startMeterFlyTP(1000) end)
makeBtn("5Km", Theme.SurfaceAlt, stepRow, function() startMeterFlyTP(5000) end)

-- ============================================================================
-- PESTAÑA 4: LOOT & ESP
-- ============================================================================
makeSection("Atraer Objetos")
makeBtn("🪙 Traer Chapas / Dinero", Color3.fromRGB(72, 54, 18), pLoot, function() bringItems({"cap", "chapa", "coin", "scrap", "bottle"}) end)
makeBtn("🔫 Traer Armas / Munición", Color3.fromRGB(78, 28, 24), pLoot, function() bringItems({"gun", "ammo", "rifle", "pistol", "shotgun", "bullet"}) end)
makeBtn("🥫 Traer Comida / Agua", Color3.fromRGB(34, 52, 62), pLoot, function() bringItems({"food", "water", "burger", "can", "drink", "sponge"}) end)
makeBtn("💎 Traer Tuercas / Motores", Color3.fromRGB(92, 50, 22), pLoot, function() bringItems({"engine", "motor", "nut", "bolt", "wrench", "jack", "tire", "c4", "gold"}) end)

makeSection("Radar Visual")
local function refreshItemESP()
	espFolder:ClearAllChildren()
	if not State.ESPItems or not State.Running then return end
	local hrp = getHRP()
	if not hrp then return end

	local ok, err = pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("BasePart") then
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
						hl.Parent = espFolder

						local anchor = obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
						if anchor then
							local bb = Instance.new("BillboardGui")
							bb.Adornee = anchor
							bb.Size = UDim2.new(0, 135, 0, 22)
							bb.StudsOffset = Vector3.new(0, 2.2, 0)
							bb.AlwaysOnTop = true
							bb.MaxDistance = 220
							bb.Parent = espFolder

							local tx = Instance.new("TextLabel")
							tx.Size = UDim2.new(1, 0, 1, 0)
							tx.BackgroundTransparency = 1
							tx.Text = obj.Name .. " [" .. math.floor(dist) .. "m]"
							tx.TextColor3 = col
							tx.TextStrokeTransparency = 0
							tx.Font = Enum.Font.GothamBold
							tx.TextSize = 8
							tx.Parent = bb
						end
					end
				end
			end
		end
	end)

	if not ok then warn(CONFIG.LogTag .. " refreshItemESP: " .. tostring(err)) end
end

makeTgl("👁️ ESP Items con Nombres", pLoot, function(s)
	State.ESPItems = s
	refreshItemESP()
end)

-- ============================================================================
-- PESTAÑA 5: VEHÍCULO
-- ============================================================================
makeSection("Mecánica y Combustible")
makeBtn("⛽ Combustible al 100%", Theme.ActiveBg, pVeh, function()
	local nCount = 0
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("NumberValue") then
			local n = v.Name:lower()
			if n:find("fuel") or n:find("gas") or n:find("nafta") then
				v.Value = 100
				nCount += 1
			end
		end
	end
	notify("Vehículo", "Tanques llenados: " .. nCount, Theme.ActiveBorder)
end)

makeBtn("⛽ Traer Bidón / Gasolina", Theme.ActiveBg, pVeh, function() bringItems({"gas", "oil", "fuel", "canister"}) end)
makeBtn("🔧 Traer Piezas de Motor", Color3.fromRGB(66, 42, 24), pVeh, function() bringItems({"engine", "wheel", "radiator", "door", "battery"}) end)
makeBtn("🛠️ Reparar Vehículo Actual", Color3.fromRGB(84, 52, 22), pVeh, function()
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

-- ============================================================================
-- BUCLES PRINCIPALES
-- ============================================================================
track(RS.Stepped:Connect(function()
	if not State.Running then return end
	local char = LP.Character
	if not char then return end

	if State.Noclip then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end

	if State.InfStamina then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.Stamina = 100 end) end
	end
end))

local fpsTime, fpsCount = 0, 0
track(RS.RenderStepped:Connect(function(dt)
	if not State.Running then return end
	Cam = workspace.CurrentCamera

	fpsTime += dt
	fpsCount += 1
	if fpsTime >= 0.5 then
		local fps = math.clamp(math.floor(fpsCount / fpsTime + 0.5), 1, 999)
		State.ActiveMods = countActiveMods()
		TelemetryPill.Text = State.ActiveMods .. " ACTIVE | " .. fps .. " FPS"
		fpsTime, fpsCount = 0, 0
	end

	if State.SilentAim or State.Aimbot then
		CachedFOVTarget = computeBestTargetInFOV(450)
	else
		CachedFOVTarget = nil
	end

	local center = getAimCenter()
	FOVFrame.Position = UDim2.fromOffset(center.X, center.Y)
	FOVFrame.Size = UDim2.fromOffset(State.FOVRadius * 2, State.FOVRadius * 2)
	FOVFrame.Visible = State.ShowFOV and (State.Aimbot or State.SilentAim)
	if State.SilentAim then
		fovStroke.Color = Theme.CyanSignal
	elseif State.Aimbot then
		fovStroke.Color = Theme.Accent
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
		local hum = char:FindFirstChildOfClass("Humanoid")
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

			if hum and hum.MoveDirection.Magnitude > 0.05 then
				local flatLook = Vector3.new(Cam.CFrame.LookVector.X, 0, Cam.CFrame.LookVector.Z)
				if flatLook.Magnitude > 0.001 then
					flatLook = flatLook.Unit
					local flatRight = Vector3.new(Cam.CFrame.RightVector.X, 0, Cam.CFrame.RightVector.Z).Unit
					local forwardDot = hum.MoveDirection:Dot(flatLook)
					local rightDot = hum.MoveDirection:Dot(flatRight)
					local camDir = (Cam.CFrame.LookVector * forwardDot) + (Cam.CFrame.RightVector * rightDot)
					if camDir.Magnitude > 0.001 then dir += camDir end
				end
			end

			if dir.Magnitude > 0 then
				dir = dir.Unit
				local boosting = UIS.KeyboardEnabled and UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
				local spd = State.FlyVal * (boosting and State.FlyBoostMult or 1)
				hrp.CFrame = hrp.CFrame + (dir * spd * dt)
			end
		end
	end

	if State.Aimbot and CachedFOVTarget and CachedFOVTarget.Parent then
		local desiredCF = CFrame.new(Cam.CFrame.Position, CachedFOVTarget.Position)
		local alpha = 1 - math.exp(-State.AimSmooth * dt)
		Cam.CFrame = Cam.CFrame:Lerp(desiredCF, math.clamp(alpha, 0, 1))
	end
end))

track(RS.Heartbeat:Connect(function()
	if not State.Running or not State.GodMode then return end
	local hum = getHum()
	if hum then
		hum.Health = hum.MaxHealth
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	end
end))

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
					for _, enemy in ipairs(CachedEnemies) do
						local root = resolveTargetPart(enemy)
						if root and (root.Position - hrp.Position).Magnitude <= 35 then
							local hum = enemy:FindFirstChildOfClass("Humanoid")
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
			if char and Cam then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then
					if State.Wallbang then
						for _, p in ipairs(tool:GetDescendants()) do
							if p:IsA("BasePart") then
								pcall(function() p.CanCollide = false p.Massless = true end)
							end
						end
					end
					if State.NoRecoil then
						for _, v in ipairs(tool:GetDescendants()) do
							if v:IsA("NumberValue") then
								local n = v.Name:lower()
								if n:find("recoil") or n:find("kick") then v.Value = 0 end
							end
						end
					end
					if State.InfAmmo then
						for _, v in ipairs(tool:GetDescendants()) do
							if v:IsA("NumberValue") then
								local n = v.Name:lower()
								if n:find("ammo") or n:find("bullet") or n:find("balas") then v.Value = 999 end
							end
						end
					end
				end

				if State.Triggerbot then
					local center = getAimCenter()
					local ray = Cam:ViewportPointToRay(center.X, center.Y)
					local params = RaycastParams.new()
					params.FilterDescendantsInstances = { char }
					params.FilterType = Enum.RaycastFilterType.Exclude
					local hit = workspace:Raycast(ray.Origin, ray.Direction * 350, params)
					if hit and hit.Instance then
						local mdl = hit.Instance:FindFirstAncestorOfClass("Model")
						if mdl and mdl:FindFirstChildOfClass("Humanoid")
							and not Plrs:GetPlayerFromCharacter(mdl) and tool then
							tool:Activate()
						end
					end
				end
			end
		end)
	end
end)

task.spawn(function()
	while State.Running and task.wait(CONFIG.ItemEspInterval) do
		if State.ESPItems then refreshItemESP() end
	end
end)

-- ============================================================================
-- KILL SWITCH / LIMPIEZA
-- ============================================================================
track(CloseBtn.MouseButton1Click:Connect(function()
	print(string.format("[%s][%s] KILL SWITCH ejecutado", CONFIG.LogTag, SessionId))
	State.Running = false
	State.TPActive = false
	for _, key in ipairs(MOD_FLAGS) do
		if typeof(State[key]) == "boolean" then State[key] = false end
	end
	State.ActiveMods = 0
	CachedFOVTarget = nil
	CachedEnemies = {}
	FOVFrame.Visible = false
	hideAllAdvESP()
	syncHitboxes(false)

	local hum = getHum()
	if hum then
		pcall(function()
			hum.WalkSpeed = 16
			if hum.UseJumpPower then hum.JumpPower = 50 end
		end)
	end
	if LP.Character then
		for _, part in ipairs(LP.Character:GetDescendants()) do
			if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end
		end
	end

	for _, conn in ipairs(Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(Connections)
	table.clear(advEspPool)
	espFolder:ClearAllChildren()
	SG:Destroy()

	-- Nota: hookmetamethod no tiene API estandar de "unhook". Los hooks quedan
	-- instalados pero con State.Running=false pasan la llamada original sin
	-- modificar nada. Al ejecutar de nuevo el script se reinstalan limpiamente.
end))

-- ============================================================================
-- AUTODIAGNOSTICO: imprime que hay disponible y que quedo inicializado
-- ============================================================================
local function printDiagnostics()
	local capParts = {}
	for k, v in pairs(Caps) do
		table.insert(capParts, k .. "=" .. (v and "OK" or "NO"))
	end
	table.sort(capParts)

	local nPages = 0
	for _ in pairs(pages) do nPages += 1 end

	local checks = {
		{ "GUI", SG.Parent ~= nil },
		{ "Camara", Cam ~= nil },
		{ "Jugador", LP ~= nil },
		{ "5 pestañas", nPages == 5 },
		{ "Conexiones", #Connections > 0 },
		{ "Hooks silent aim", hookReady },
	}

	local passed = 0
	for _, c in ipairs(checks) do
		if c[2] then passed += 1 end
		print(string.format("[%s][%s] CHECK %-16s %s",
			CONFIG.LogTag, SessionId, c[1], c[2] and "OK" or "NO DISPONIBLE"))
	end

	print(string.format("[%s][%s] CAPS %s", CONFIG.LogTag, SessionId, table.concat(capParts, " ")))
	print(string.format("[%s][%s] GUI parent = %s | %d/%d checks OK",
		CONFIG.LogTag, SessionId,
		tostring(SG.Parent and SG.Parent:GetFullName() or "nil"), passed, #checks))

	if passed < #checks then
		warn(CONFIG.LogTag .. " Revisa la consola: los items en NO DISPONIBLE indican que tu executor/no juego no los exponen")
	end
end

task.defer(printDiagnostics)

print(string.format("[%s][%s] DUSTY TRIP HUB APEX v13.0 listo", CONFIG.LogTag, SessionId))
notify("DUSTY TRIP HUB", "v13.0 APEX listo", Theme.Accent)
