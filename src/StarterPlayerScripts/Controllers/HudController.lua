--!strict
-- HudController.lua  (CLIENTE)
-- HUD estilo "terminal de contenção": HP, stamina e os 4 poderes com cooldown.
-- Construído por código pra você não precisar montar UI no Studio no Marco 0.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local CreatureData = require(ReplicatedStorage.Shared.CreatureData)
local StateUpdate = Net.get("StateUpdate")

local player = Players.LocalPlayer

local TEAL = Color3.fromRGB(47, 212, 194)
local AMBER = Color3.fromRGB(240, 149, 74)
local INK = Color3.fromRGB(20, 26, 31)
local FADE = Color3.fromRGB(60, 72, 82)

local HudController = {}

local KEYS = { "Z", "X", "C", "V" }
local pips: { [string]: { fill: Frame, label: TextLabel, cd: TextLabel } } = {}
local hpFill: Frame, staminaFill: Frame, moneyLabel: TextLabel
local postureFill: Frame, ultFill: Frame
local coreLabel: TextLabel
local dbFrame: Frame
local dbRows: { [string]: TextLabel } = {}

local function bar(parent: Instance, y: number, color: Color3, name: string): Frame
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.new(0, 260, 0, 20)
	holder.Position = UDim2.new(0, 0, 0, y)
	holder.BackgroundColor3 = INK
	holder.BorderSizePixel = 0
	holder.Parent = parent
	Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = holder
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.Code
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.TextStrokeTransparency = 0.4
	tag.TextSize = 12
	tag.Text = name
	tag.Parent = holder

	return fill
end

function HudController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnomalyHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- barras (canto inferior esquerdo)
	local barsHolder = Instance.new("Frame")
	barsHolder.Size = UDim2.new(0, 260, 0, 100)
	barsHolder.Position = UDim2.new(0, 24, 1, -190)
	barsHolder.BackgroundTransparency = 1
	barsHolder.Parent = gui
	hpFill = bar(barsHolder, 0, Color3.fromRGB(210, 70, 70), "HP")
	staminaFill = bar(barsHolder, 26, AMBER, "STAMINA")
	postureFill = bar(barsHolder, 52, Color3.fromRGB(120, 200, 255), "GUARDA")
	ultFill = bar(barsHolder, 78, Color3.fromRGB(168, 136, 240), "ULTIMATE [G]")

	moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(0, 260, 0, 18)
	moneyLabel.Position = UDim2.new(0, 24, 1, -68)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Font = Enum.Font.Code
	moneyLabel.TextColor3 = TEAL
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.TextSize = 14
	moneyLabel.Text = "ANM-CREDITS: 0"
	moneyLabel.Parent = gui

	-- pips dos poderes (canto inferior, centro-esquerda)
	local powersHolder = Instance.new("Frame")
	powersHolder.Size = UDim2.new(0, 60 * #KEYS, 0, 60)
	powersHolder.Position = UDim2.new(0, 300, 1, -100)
	powersHolder.BackgroundTransparency = 1
	powersHolder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = powersHolder

	for _, key in KEYS do
		local box = Instance.new("Frame")
		box.Size = UDim2.new(0, 52, 0, 52)
		box.BackgroundColor3 = INK
		box.BorderSizePixel = 0
		box.Parent = powersHolder
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", box)
		stroke.Color = TEAL
		stroke.Thickness = 1.5

		local fill = Instance.new("Frame") -- overlay de cooldown (desce de cima)
		fill.Size = UDim2.fromScale(1, 0)
		fill.Position = UDim2.fromScale(0, 0)
		fill.BackgroundColor3 = FADE
		fill.BackgroundTransparency = 0.35
		fill.BorderSizePixel = 0
		fill.Parent = box

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 20
		label.Text = key
		label.Parent = box

		local cd = Instance.new("TextLabel")
		cd.Size = UDim2.fromScale(1, 1)
		cd.BackgroundTransparency = 1
		cd.Font = Enum.Font.Code
		cd.TextColor3 = AMBER
		cd.TextSize = 14
		cd.Text = ""
		cd.Parent = box

		pips[key] = { fill = fill, label = label, cd = cd }
	end

	-- Core equipada (canto inferior, acima dos poderes)
	coreLabel = Instance.new("TextLabel")
	coreLabel.Size = UDim2.new(0, 300, 0, 18)
	coreLabel.Position = UDim2.new(0, 300, 1, -122)
	coreLabel.BackgroundTransparency = 1
	coreLabel.Font = Enum.Font.Code
	coreLabel.TextColor3 = TEAL
	coreLabel.TextXAlignment = Enum.TextXAlignment.Left
	coreLabel.TextSize = 14
	coreLabel.Text = "CORE: —   [T] trocar   [B] database"
	coreLabel.Parent = gui

	-- ---------- Anomaly Database (tecla B) ----------
	dbFrame = Instance.new("Frame")
	dbFrame.Size = UDim2.new(0, 420, 0, 320)
	dbFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
	dbFrame.BackgroundColor3 = Color3.fromRGB(14, 20, 26)
	dbFrame.BackgroundTransparency = 0.05
	dbFrame.BorderSizePixel = 0
	dbFrame.Visible = false
	dbFrame.Parent = gui
	Instance.new("UICorner", dbFrame).CornerRadius = UDim.new(0, 8)
	local dbStroke = Instance.new("UIStroke", dbFrame)
	dbStroke.Color = TEAL
	dbStroke.Thickness = 1.5

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
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
		dbRows[def.id] = row
	end

	StateUpdate.OnClientEvent:Connect(function(data)
		hpFill.Size = UDim2.fromScale(math.clamp(data.hp / data.maxHp, 0, 1), 1)
		staminaFill.Size = UDim2.fromScale(math.clamp(data.stamina / data.maxStamina, 0, 1), 1)
		if data.maxPosture then
			postureFill.Size = UDim2.fromScale(math.clamp(data.posture / data.maxPosture, 0, 1), 1)
			-- guarda quebrada: barra fica vermelha
			postureFill.BackgroundColor3 = data.stunned and Color3.fromRGB(220, 60, 60)
				or Color3.fromRGB(120, 200, 255)
		end
		if data.maxUlt then
			local frac = math.clamp(data.ult / data.maxUlt, 0, 1)
			ultFill.Size = UDim2.fromScale(frac, 1)
			-- pronta pra usar: brilha
			ultFill.BackgroundColor3 = (frac >= 1) and Color3.fromRGB(255, 220, 120)
				or Color3.fromRGB(168, 136, 240)
		end
		moneyLabel.Text = string.format("ANM-CREDITS: %d   ·   BOSS KILLS: %d", data.money, data.bossKills or 0)
		if data.coreName then
			coreLabel.Text = "CORE: " .. data.coreName .. "   [T] trocar   [B] database"
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
				pip.cd.Text = info.remain > 0.05 and string.format("%.1f", info.remain) or ""
			end
		end
	end)

	-- carimbo de build no rodapé: confirma DENTRO DO JOGO qual versão do código
	-- está rodando, quantas peças o mundo tem e se os modelos externos entraram
	local stamp = Instance.new("TextLabel")
	stamp.Size = UDim2.new(0, 700, 0, 16)
	stamp.Position = UDim2.new(0, 8, 1, -18)
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.Code
	stamp.TextSize = 12
	stamp.TextColor3 = Color3.fromRGB(110, 130, 145)
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
