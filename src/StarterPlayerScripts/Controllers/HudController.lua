--!strict
-- HudController.lua  (CLIENTE)
-- HUD "terminal de contenção" — vidro escuro, barras em pílula com gradiente,
-- poderes como ícones circulares coloridos por habilidade, e o acento geral
-- muda pra cor da Core equipada. Construído por código pra não precisar
-- montar UI no Studio no Marco 0.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Net = require(ReplicatedStorage.Shared.Net)
local CreatureData = require(ReplicatedStorage.Shared.CreatureData)
local StateUpdate = Net.get("StateUpdate")

local player = Players.LocalPlayer

local TEAL = Color3.fromRGB(47, 212, 194)
local AMBER = Color3.fromRGB(240, 149, 74)
local INK = Color3.fromRGB(12, 16, 20)
local GLASS = Color3.fromRGB(16, 22, 28)
local FADE = Color3.fromRGB(120, 138, 150)
local WHITE = Color3.fromRGB(235, 240, 245)

-- cor de cada poder (decorativo — não depende da Core equipada, só dá
-- identidade visual pra cada tecla, tipo HUD de MOBA/ARPG moderno)
local POWER_COLORS = {
	Z = Color3.fromRGB(110, 190, 255),
	X = Color3.fromRGB(255, 196, 90),
	C = Color3.fromRGB(140, 255, 210),
	V = Color3.fromRGB(200, 150, 255),
}

local HudController = {}

local KEYS = { "Z", "X", "C", "V" }
local pips: { [string]: { ring: UIStroke, fill: Frame, cd: TextLabel } } = {}
local hpFill: Frame, staminaFill: Frame, postureFill: Frame, ultFill: Frame
local ultRow: Frame, ultGlow: UIStroke
local moneyLabel: TextLabel, coreLabel: TextLabel, corePill: Frame, coreStroke: UIStroke
local dbFrame: Frame
local dbRows: { [string]: TextLabel } = {}
local accentColor = TEAL

-- ---------- primitivas de UI ----------

local function corner(inst: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

local function stroke(inst: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- ---------- ícones dos poderes (vetoriais, sem imagem — Frame girado/com
-- contorno, no mesmo espírito "protótipo cinza" do resto do jogo) ----------

local function iconBar(box: Instance, width: number, height: number, rotation: number, offsetX: number, offsetY: number, color: Color3)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = UDim2.fromOffset(width, height)
	bar.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
	bar.Rotation = rotation
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.ZIndex = 2
	bar.Parent = box
	corner(bar, 1)
end

-- Z: rajada de velocidade (três traços diagonais)
local function iconDash(box: Instance, color: Color3)
	iconBar(box, 3, 14, 28, -9, -2, color)
	iconBar(box, 3, 14, 28, 0, 2, color)
	iconBar(box, 3, 14, 28, 9, 6, color)
end

-- X: raio (dois traços cruzando no meio)
local function iconBolt(box: Instance, color: Color3)
	iconBar(box, 4, 17, 24, -3, -6, color)
	iconBar(box, 4, 17, 24, 3, 6, color)
end

-- C: anel (área/AoE)
local function iconRing(box: Instance, color: Color3)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(24, 24)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 2
	ring.Parent = box
	corner(ring, 12)
	stroke(ring, color, 3, 0)
end

-- V: losango (forma/buff)
local function iconDiamond(box: Instance, color: Color3)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Size = UDim2.fromOffset(18, 18)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Rotation = 45
	d.BackgroundTransparency = 1
	d.ZIndex = 2
	d.Parent = box
	corner(d, 3)
	stroke(d, color, 3, 0)
end

local POWER_ICONS = {
	Z = iconDash,
	X = iconBolt,
	C = iconRing,
	V = iconDiamond,
}

local function gradient(inst: Instance, colorA: Color3, colorB: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(colorA, colorB)
	g.Rotation = rotation or 0
	g.Parent = inst
	return g
end

-- painel de vidro: fundo escuro translúcido + borda fina
local function glassPanel(parent: Instance, size: UDim2, position: UDim2, radius: number?): Frame
	local p = Instance.new("Frame")
	p.Size = size
	p.Position = position
	p.BackgroundColor3 = GLASS
	p.BackgroundTransparency = 0.28
	p.BorderSizePixel = 0
	p.Parent = parent
	corner(p, radius or 10)
	stroke(p, Color3.fromRGB(255, 255, 255), 1, 0.9)
	return p
end

-- barra em pílula: ícone + trilho + preenchimento em gradiente
local function statBar(
	parent: Instance,
	y: number,
	icon: string,
	iconColor: Color3,
	colorA: Color3,
	colorB: Color3
): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 16)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromOffset(18, 16)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBlack
	iconLabel.TextSize = 13
	iconLabel.TextColor3 = iconColor
	iconLabel.Text = icon
	iconLabel.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 8)
	track.Position = UDim2.new(0, 24, 0.5, -4)
	track.BackgroundColor3 = INK
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = row
	corner(track, 4)
	stroke(track, Color3.fromRGB(0, 0, 0), 1, 0.4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 4)
	gradient(fill, colorA, colorB, 0)

	return fill
end

function HudController.Start()
	-- não usamos Tools/armas de verdade — a hotbar padrão do Roblox só ocupa
	-- espaço à toa no rodapé. A lista de jogadores também sai.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	-- a barrinha com logo/menu/chat/voz no canto superior esquerdo NÃO dá
	-- mais pra esconder — a Roblox tornou ela fixa (exigência da própria
	-- plataforma, não é limitação nossa). Isso aqui ainda ajuda a esconder
	-- o que sobrar dela, mas o nosso HUD é que precisa desviar dela.
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "AnomalyHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- ---------- pílula: Core + créditos (canto superior direito, embaixo
	-- do cluster de vida/stamina/guarda/ultimate) ----------
	corePill = glassPanel(gui, UDim2.new(0, 260, 0, 34), UDim2.new(1, -280, 0, 160), 17)
	coreStroke = corePill:FindFirstChildOfClass("UIStroke") :: UIStroke
	coreStroke.Color = accentColor
	coreStroke.Transparency = 0.5

	local coreDot = Instance.new("Frame")
	coreDot.Size = UDim2.fromOffset(8, 8)
	coreDot.Position = UDim2.new(0, 14, 0.5, -4)
	coreDot.BackgroundColor3 = accentColor
	coreDot.BorderSizePixel = 0
	coreDot.Parent = corePill
	corner(coreDot, 4)

	coreLabel = Instance.new("TextLabel")
	coreLabel.Size = UDim2.new(1, -34, 1, 0)
	coreLabel.Position = UDim2.new(0, 30, 0, 0)
	coreLabel.BackgroundTransparency = 1
	coreLabel.Font = Enum.Font.GothamMedium
	coreLabel.TextColor3 = WHITE
	coreLabel.TextXAlignment = Enum.TextXAlignment.Left
	coreLabel.TextSize = 13
	coreLabel.Text = "—"
	coreLabel.Parent = corePill

	moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(0, 260, 0, 16)
	moneyLabel.Position = UDim2.new(1, -280, 0, 200)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Font = Enum.Font.Code
	moneyLabel.TextColor3 = FADE
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.TextSize = 13
	moneyLabel.Text = "0 ¤   ·   0 abates   ·   [T] core   [B] database"
	moneyLabel.Parent = gui

	-- ---------- cluster de status (canto superior direito) ----------
	local statsPanel = glassPanel(gui, UDim2.new(0, 260, 0, 92), UDim2.new(1, -280, 0, 56), 12)
	local statsInner = Instance.new("Frame")
	statsInner.Size = UDim2.new(1, -28, 1, -20)
	statsInner.Position = UDim2.new(0, 14, 0, 10)
	statsInner.BackgroundTransparency = 1
	statsInner.Parent = statsPanel

	hpFill = statBar(statsInner, 0, "♥", Color3.fromRGB(255, 110, 110), Color3.fromRGB(255, 140, 140), Color3.fromRGB(200, 40, 55))
	staminaFill = statBar(statsInner, 24, "⚡", AMBER, Color3.fromRGB(255, 200, 120), AMBER)
	postureFill = statBar(statsInner, 48, "◈", Color3.fromRGB(140, 205, 255), Color3.fromRGB(180, 225, 255), Color3.fromRGB(90, 160, 230))

	local powersWidth = 60 * #KEYS + 10 * (#KEYS - 1)

	-- ultimate: fica em cima dos botões de poder, não mais no cluster de vida —
	-- lê melhor como "o botão grande que os quatro pequenos alimentam".
	ultRow = Instance.new("Frame")
	ultRow.Size = UDim2.new(0, powersWidth, 0, 20)
	ultRow.Position = UDim2.new(0, 296, 1, -114)
	ultRow.BackgroundTransparency = 1
	ultRow.Parent = gui

	local ultTrack = Instance.new("Frame")
	ultTrack.Size = UDim2.new(1, 0, 0, 16)
	ultTrack.Position = UDim2.new(0, 0, 0.5, -8)
	ultTrack.BackgroundColor3 = INK
	ultTrack.BackgroundTransparency = 0.1
	ultTrack.BorderSizePixel = 0
	ultTrack.ClipsDescendants = true
	ultTrack.Parent = ultRow
	corner(ultTrack, 8)
	ultGlow = stroke(ultTrack, Color3.fromRGB(168, 136, 240), 1, 0.4)

	ultFill = Instance.new("Frame")
	ultFill.Size = UDim2.fromScale(0, 1)
	ultFill.BorderSizePixel = 0
	ultFill.BackgroundColor3 = Color3.fromRGB(168, 136, 240)
	ultFill.Parent = ultTrack
	corner(ultFill, 8)
	gradient(ultFill, Color3.fromRGB(140, 110, 220), Color3.fromRGB(190, 160, 255), 0)

	local ultLabel = Instance.new("TextLabel")
	ultLabel.Size = UDim2.fromScale(1, 1)
	ultLabel.BackgroundTransparency = 1
	ultLabel.Font = Enum.Font.Code
	ultLabel.TextColor3 = WHITE
	ultLabel.TextSize = 11
	ultLabel.TextTransparency = 0.15
	ultLabel.Text = "ULTIMATE  [G]"
	ultLabel.TextStrokeTransparency = 0.6
	ultLabel.Parent = ultTrack

	-- ---------- poderes (canto inferior, embaixo do ultimate) ----------
	local powersHolder = Instance.new("Frame")
	powersHolder.Size = UDim2.new(0, powersWidth, 0, 60)
	powersHolder.Position = UDim2.new(0, 296, 1, -80)
	powersHolder.BackgroundTransparency = 1
	powersHolder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = powersHolder

	for i, key in KEYS do
		local powerColor = POWER_COLORS[key]

		local box = Instance.new("Frame")
		box.LayoutOrder = i
		box.Size = UDim2.fromOffset(56, 56)
		box.BackgroundColor3 = GLASS
		box.BackgroundTransparency = 0.15
		box.BorderSizePixel = 0
		box.ClipsDescendants = true
		box.Parent = powersHolder
		corner(box, 28)
		local ring = stroke(box, powerColor, 1.5, 0.15)

		local fill = Instance.new("Frame") -- overlay de cooldown (desce de cima)
		fill.Size = UDim2.fromScale(1, 0)
		fill.Position = UDim2.fromScale(0, 0)
		fill.BackgroundColor3 = INK
		fill.BackgroundTransparency = 0.25
		fill.BorderSizePixel = 0
		fill.Parent = box

		local iconBuilder = POWER_ICONS[key]
		if iconBuilder then
			iconBuilder(box, WHITE)
		end

		-- tecla pequena no cantinho — o ícone é que domina o slot agora
		local keyTag = Instance.new("TextLabel")
		keyTag.Size = UDim2.fromOffset(14, 12)
		keyTag.Position = UDim2.new(0, 4, 0, 3)
		keyTag.BackgroundTransparency = 1
		keyTag.Font = Enum.Font.Code
		keyTag.TextColor3 = WHITE
		keyTag.TextTransparency = 0.3
		keyTag.TextSize = 10
		keyTag.Text = key
		keyTag.ZIndex = 2
		keyTag.Parent = box

		local cd = Instance.new("TextLabel")
		cd.Size = UDim2.new(1, 0, 0, 14)
		cd.Position = UDim2.new(0, 0, 1, -15)
		cd.BackgroundTransparency = 1
		cd.Font = Enum.Font.Code
		cd.TextColor3 = WHITE
		cd.TextSize = 12
		cd.Text = ""
		cd.ZIndex = 2
		cd.Parent = box

		pips[key] = { ring = ring, fill = fill, cd = cd }
	end

	-- ---------- Anomaly Database (tecla B) ----------
	dbFrame = glassPanel(gui, UDim2.new(0, 420, 0, 320), UDim2.new(0.5, -210, 0.5, -160), 12)
	dbFrame.BackgroundTransparency = 0.05
	dbFrame.Visible = false
	local dbAccent = dbFrame:FindFirstChildOfClass("UIStroke") :: UIStroke
	dbAccent.Color = TEAL
	dbAccent.Transparency = 0.3

	local dbTitle = Instance.new("TextLabel")
	dbTitle.Size = UDim2.new(1, 0, 0, 40)
	dbTitle.BackgroundTransparency = 1
	dbTitle.Font = Enum.Font.Code
	dbTitle.TextColor3 = TEAL
	dbTitle.TextSize = 16
	dbTitle.Text = "◈ ANOMALY DATABASE"
	dbTitle.Parent = dbFrame

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -24, 1, -56)
	list.Position = UDim2.new(0, 12, 0, 44)
	list.BackgroundTransparency = 1
	list.Parent = dbFrame
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = list

	for _, def in CreatureData.list do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundColor3 = Color3.fromRGB(20, 28, 35)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.Code
		row.TextColor3 = FADE
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextSize = 14
		row.Text = "  " .. def.id .. "   ???"
		row.Parent = list
		corner(row, 4)
		dbRows[def.id] = row
	end

	-- ---------- estado ao vivo ----------
	local ultWasReady = false

	StateUpdate.OnClientEvent:Connect(function(data)
		hpFill.Size = UDim2.fromScale(math.clamp(data.hp / data.maxHp, 0, 1), 1)
		staminaFill.Size = UDim2.fromScale(math.clamp(data.stamina / data.maxStamina, 0, 1), 1)
		if data.maxPosture then
			local frac = math.clamp(data.posture / data.maxPosture, 0, 1)
			postureFill.Size = UDim2.fromScale(frac, 1)
			if data.stunned then
				postureFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			end
		end
		if data.maxUlt then
			local frac = math.clamp(data.ult / data.maxUlt, 0, 1)
			ultFill.Size = UDim2.fromScale(frac, 1)
			local ready = frac >= 1
			if ready and not ultWasReady then
				TweenService:Create(ultGlow, TweenInfo.new(0.25), { Thickness = 2.5, Transparency = 0 }):Play()
			elseif not ready and ultWasReady then
				TweenService:Create(ultGlow, TweenInfo.new(0.25), { Thickness = 1, Transparency = 0.4 }):Play()
			end
			ultWasReady = ready
		end
		moneyLabel.Text = string.format(
			"%d ¤   ·   %d abates   ·   [T] core   [B] database",
			data.money,
			data.bossKills or 0
		)
		if data.coreName then
			coreLabel.Text = data.coreName
		end
		if data.coreColor and data.coreColor ~= accentColor then
			accentColor = data.coreColor
			TweenService:Create(coreStroke, TweenInfo.new(0.4), { Color = accentColor }):Play()
		end
		-- Anomaly Database: revela o que já foi catalogado
		if data.database then
			for _, def in CreatureData.list do
				local row = dbRows[def.id]
				if row then
					if data.database[def.id] then
						row.Text = string.format("  %s   %s  ·  %s  ✓", def.id, def.nome, def.raridade)
						row.TextColor3 = TEAL
					else
						row.Text = "  " .. def.id .. "   ???"
						row.TextColor3 = FADE
					end
				end
			end
		end
		for _, key in KEYS do
			local info = data.cooldowns[key]
			local pip = pips[key]
			if info and pip then
				local frac = info.total > 0 and (info.remain / info.total) or 0
				pip.fill.Size = UDim2.fromScale(1, math.clamp(frac, 0, 1))
				local ready = info.remain <= 0.05
				pip.cd.Text = ready and "" or string.format("%.1f", info.remain)
				pip.ring.Transparency = ready and 0.15 or 0.55
			end
		end
	end)

	-- carimbo de build no rodapé: confirma DENTRO DO JOGO qual versão do código
	-- está rodando, quantas peças o mundo tem e se os modelos externos entraram
	local stamp = Instance.new("TextLabel")
	stamp.Size = UDim2.new(0, 700, 0, 14)
	stamp.Position = UDim2.new(0, 8, 1, -16)
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.Code
	stamp.TextSize = 10
	stamp.TextColor3 = Color3.fromRGB(70, 84, 94)
	stamp.TextXAlignment = Enum.TextXAlignment.Left
	stamp.Text = "mundo: aguardando..."
	stamp.Parent = gui

	local function refreshStamp()
		local info = ReplicatedStorage:GetAttribute("AW_WorldInfo")
		if info then
			stamp.Text = tostring(info)
		end
	end
	refreshStamp()
	ReplicatedStorage:GetAttributeChangedSignal("AW_WorldInfo"):Connect(refreshStamp)

	print("[HudController] pronto")
end

-- abre/fecha o Anomaly Database (tecla B)
function HudController.toggleDatabase()
	if dbFrame then
		dbFrame.Visible = not dbFrame.Visible
	end
end

return HudController
