--!strict
-- InventoryController.lua  (CLIENTE)
-- Barra de inventário no centro inferior da tela. Quatro armas de verdade
-- (espada, adaga, machado, martelo — o CombatStance sabe desenhar/soldar
-- cada uma na mão), mais dois slots vazios reservados pra próximos itens.
-- Só uma arma fica equipada por vez: clicar numa nova guarda a anterior
-- sozinho. Clicar ou apertar a tecla numérica pega/guarda, independente do
-- lock do R.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local CombatStance = require(ReplicatedStorage.Shared.CombatStance)

local player = Players.LocalPlayer

local GLASS = Color3.fromRGB(16, 22, 28)
local FADE = Color3.fromRGB(90, 102, 112)
local WHITE = Color3.fromRGB(235, 240, 245)
local WEAPON_COLOR = Color3.fromRGB(205, 210, 220)
local WEAPON_GLOW = Color3.fromRGB(120, 220, 255)
local HILT_COLOR = Color3.fromRGB(60, 55, 50)
local LEATHER_COLOR = Color3.fromRGB(120, 82, 52) -- embrulho de couro, igual CombatStance
local POMMEL_COLOR = Color3.fromRGB(190, 160, 70) -- latão, igual CombatStance
local HAMMER_HEAD_COLOR = Color3.fromRGB(150, 156, 164)
local SHIELD_COLOR = Color3.fromRGB(140, 205, 255) -- mesmo azul da barra de Guarda
local SHIELD_GLOW = Color3.fromRGB(200, 235, 255)

local SLOT_COUNT = 6
local SLOT_SIZE = 52
local SLOT_GAP = 8

-- tecla numérica de cada slot (1..6), pra pegar item sem precisar clicar
local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
}

local InventoryController = {}

local equippedWeapon: string? = nil
local weaponRings: { [string]: UIStroke } = {}
local weaponIconParts: { [string]: { GuiObject } } = {}
local slotActions: { [number]: () -> () } = {}

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

local function iconBar(box: Instance, w: number, h: number, x: number, y: number, rot: number, color: Color3, list: { GuiObject })
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = UDim2.fromOffset(w, h)
	bar.Position = UDim2.new(0.5, x, 0.5, y)
	bar.Rotation = rot
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 0.55
	bar.BorderSizePixel = 0
	bar.ZIndex = 2
	bar.Parent = box
	corner(bar, 1)
	table.insert(list, bar)
end

local function iconDot(box: Instance, size: number, x: number, y: number, color: Color3, list: { GuiObject })
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size, size)
	dot.Position = UDim2.new(0.5, x, 0.5, y)
	dot.BackgroundColor3 = color
	dot.BackgroundTransparency = 0.55
	dot.BorderSizePixel = 0
	dot.ZIndex = 2
	dot.Parent = box
	corner(dot, size / 2)
	table.insert(list, dot)
end

-- ícones das armas: desenhados com Frame (sem imagem), com as mesmas peças
-- (pomo, embrulho de couro, colar etc.) que a arma de verdade tem na mão
-- (CombatStance.lua) — só simplificadas pro tamanho de um slot.
local WEAPON_ICON_BUILDERS: { [string]: (Instance, { GuiObject }) -> () } = {
	sword = function(box, list)
		iconBar(box, 4, 22, 0, -16, 0, WEAPON_COLOR, list)
		iconBar(box, 18, 4, 0, 0, 0, WEAPON_COLOR, list)
		iconBar(box, 6, 8, 0, 6, 0, HILT_COLOR, list)
		iconDot(box, 5, 0, 12, POMMEL_COLOR, list)
	end,
	dagger = function(box, list)
		iconBar(box, 3, 13, 0, -9, 0, WEAPON_COLOR, list)
		iconBar(box, 11, 3, 0, -1, 0, WEAPON_COLOR, list)
		iconBar(box, 4, 5, 0, 3, 0, HILT_COLOR, list)
		iconDot(box, 4, 0, 7, POMMEL_COLOR, list)
	end,
	axe = function(box, list)
		iconBar(box, 3, 20, -1, 3, 0, HILT_COLOR, list) -- cabo
		iconBar(box, 3, 6, -1, 12, 0, LEATHER_COLOR, list) -- embrulho
		iconDot(box, 4, -1, 16, POMMEL_COLOR, list) -- pomo na base
		iconBar(box, 5, 3, -1, -7, 0, POMMEL_COLOR, list) -- colar
		iconBar(box, 15, 9, 5, -10, 25, WEAPON_COLOR, list) -- lâmina
		iconBar(box, 8, 4, -6, -8, 0, WEAPON_COLOR, list) -- bico traseiro
	end,
	hammer = function(box, list)
		iconBar(box, 3, 18, 0, 5, 0, HILT_COLOR, list) -- cabo
		iconBar(box, 3, 5, 0, 13, 0, LEATHER_COLOR, list) -- embrulho
		iconDot(box, 4, 0, 17, POMMEL_COLOR, list) -- pomo na base
		iconBar(box, 14, 4, 0, -9, 0, HAMMER_HEAD_COLOR, list) -- núcleo
		iconBar(box, 8, 9, -7, -9, 0, HAMMER_HEAD_COLOR, list) -- face esquerda
		iconBar(box, 8, 9, 7, -9, 0, HAMMER_HEAD_COLOR, list) -- face direita
	end,
	bow = function(box, list)
		-- os dois braços curvando pra um lado ("(") + o punho no meio + a
		-- corda esticada do outro lado, com os "nocks" nas pontas
		iconBar(box, 3, 13, -5, -9, -20, HILT_COLOR, list)
		iconBar(box, 3, 13, -5, 9, 20, HILT_COLOR, list)
		iconBar(box, 4, 6, -6, 0, 0, LEATHER_COLOR, list)
		iconBar(box, 1, 22, 6, 0, 0, WEAPON_COLOR, list)
		iconDot(box, 3, -8, -15, POMMEL_COLOR, list)
		iconDot(box, 3, -8, 15, POMMEL_COLOR, list)
	end,
}

local function refreshWeaponSlotVisual(weaponId: string)
	local ring = weaponRings[weaponId]
	if not ring then
		return
	end
	local isEquipped = equippedWeapon == weaponId
	TweenService:Create(ring, TweenInfo.new(0.15), {
		Color = isEquipped and WEAPON_GLOW or WEAPON_COLOR,
		Thickness = isEquipped and 2.5 or 1.5,
		Transparency = isEquipped and 0 or 0.2,
	}):Play()
	for _, part in weaponIconParts[weaponId] or {} do
		TweenService:Create(part, TweenInfo.new(0.15), {
			BackgroundTransparency = isEquipped and 0 or 0.55,
		}):Play()
	end
end

local function refreshAllWeaponSlots()
	for weaponId in weaponRings do
		refreshWeaponSlotVisual(weaponId)
	end
end

-- só uma arma equipada por vez: escolher uma nova guarda a anterior sozinha
-- (o próprio CombatStance já esconde a antiga ao equipar outra); clicar na
-- que já está equipada guarda ela.
local function selectWeapon(weaponId: string)
	local character = player.Character
	if equippedWeapon == weaponId then
		CombatStance.setWeaponActive(character, weaponId, false)
		equippedWeapon = nil
	else
		CombatStance.setWeaponActive(character, weaponId, true)
		equippedWeapon = weaponId
	end
	refreshAllWeaponSlots()
end

local function slotNumberLabel(box: Instance, slotIndex: number, dim: boolean)
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 13)
	hint.Position = UDim2.new(0, 0, 1, -14)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Code
	hint.TextColor3 = dim and FADE or WHITE
	hint.TextTransparency = dim and 0.5 or 0.35
	hint.TextSize = 11
	hint.Text = tostring(slotIndex)
	hint.ZIndex = 2
	hint.Parent = box
end

-- slot vazio: só um quadrado apagado com um "+" fraco, reservado pra item futuro
local function buildEmptySlot(parent: Instance, layoutOrder: number, slotIndex: number)
	local box = Instance.new("Frame")
	box.LayoutOrder = layoutOrder
	box.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	box.BackgroundColor3 = GLASS
	box.BackgroundTransparency = 0.45
	box.BorderSizePixel = 0
	box.Parent = parent
	corner(box, 10)
	stroke(box, FADE, 1, 0.5)

	local plus = Instance.new("TextLabel")
	plus.Size = UDim2.fromScale(1, 1)
	plus.BackgroundTransparency = 1
	plus.Font = Enum.Font.GothamBlack
	plus.TextColor3 = FADE
	plus.TextTransparency = 0.4
	plus.TextSize = 18
	plus.Text = "+"
	plus.Parent = box

	slotNumberLabel(box, slotIndex, true)
end

-- slot de arma: quadrado com o ícone dela e o anel que acende quando está
-- equipada. Clicável, e a tecla numérica do slot faz o mesmo.
local function buildWeaponSlot(parent: Instance, layoutOrder: number, slotIndex: number, weaponId: string)
	local box = Instance.new("TextButton")
	box.LayoutOrder = layoutOrder
	box.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	box.BackgroundColor3 = GLASS
	box.BackgroundTransparency = 0.15
	box.BorderSizePixel = 0
	box.AutoButtonColor = false
	box.Text = ""
	box.Parent = parent
	corner(box, 10)
	weaponRings[weaponId] = stroke(box, WEAPON_COLOR, 1.5, 0.2)

	local iconParts: { GuiObject } = {}
	weaponIconParts[weaponId] = iconParts
	local builder = WEAPON_ICON_BUILDERS[weaponId]
	if builder then
		builder(box, iconParts)
	end

	slotNumberLabel(box, slotIndex, false)

	local function select()
		selectWeapon(weaponId)
	end
	box.MouseButton1Click:Connect(select)
	slotActions[slotIndex] = select
end

-- slot do escudo: não é um item pra pegar, é só o lembrete visual de que o
-- botão direito do mouse (M2) bloqueia — acende enquanto você segura.
local function buildShieldSlot(parent: Instance)
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	box.BackgroundColor3 = GLASS
	box.BackgroundTransparency = 0.15
	box.BorderSizePixel = 0
	box.Parent = parent
	corner(box, 10)
	local ring = stroke(box, SHIELD_COLOR, 1.5, 0.2)

	-- corpo do escudo: retângulo com o topo arredondado
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Size = UDim2.fromOffset(20, 16)
	body.Position = UDim2.new(0.5, 0, 0.5, -6)
	body.BackgroundColor3 = SHIELD_COLOR
	body.BackgroundTransparency = 0.1
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = box
	corner(body, 8)

	-- ponta do escudo: losango embaixo do corpo, fechando a forma
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Size = UDim2.fromOffset(13, 13)
	tip.Position = UDim2.new(0.5, 0, 0.5, 6)
	tip.Rotation = 45
	tip.BackgroundColor3 = SHIELD_COLOR
	tip.BackgroundTransparency = 0.1
	tip.BorderSizePixel = 0
	tip.ZIndex = 2
	tip.Parent = box
	corner(tip, 2)

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(1, 0, 0, 13)
	tag.Position = UDim2.new(0, 0, 1, -14)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.Code
	tag.TextColor3 = WHITE
	tag.TextTransparency = 0.35
	tag.TextSize = 11
	tag.Text = "M2"
	tag.ZIndex = 2
	tag.Parent = box

	local blocking = false
	local function refresh()
		TweenService:Create(ring, TweenInfo.new(0.12), {
			Color = blocking and SHIELD_GLOW or SHIELD_COLOR,
			Thickness = blocking and 2.5 or 1.5,
			Transparency = blocking and 0 or 0.2,
		}):Play()
		TweenService:Create(body, TweenInfo.new(0.12), {
			BackgroundTransparency = blocking and 0 or 0.1,
		}):Play()
		TweenService:Create(tip, TweenInfo.new(0.12), {
			BackgroundTransparency = blocking and 0 or 0.1,
		}):Play()
	end

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		blocking = true
		refresh()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		blocking = false
		refresh()
	end)
end

function InventoryController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnomalyInventory"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local totalWidth = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_GAP
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(totalWidth, SLOT_SIZE)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -20)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local weaponOrder = CombatStance.WeaponOrder
	for i, weaponId in weaponOrder do
		buildWeaponSlot(bar, i, i, weaponId)
	end
	for i = #weaponOrder + 1, SLOT_COUNT do
		buildEmptySlot(bar, i, i)
	end

	-- escudo do M2: fora da barra numerada (não é um item), do ladinho dela
	local shieldHolder = Instance.new("Frame")
	shieldHolder.AnchorPoint = Vector2.new(0, 1)
	shieldHolder.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	shieldHolder.Position = UDim2.new(0.5, totalWidth / 2 + 16, 1, -20)
	shieldHolder.BackgroundTransparency = 1
	shieldHolder.Parent = gui
	buildShieldSlot(shieldHolder)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		for slotIndex, keyCode in SLOT_KEYS do
			if input.KeyCode == keyCode then
				local action = slotActions[slotIndex]
				if action then
					action()
				end
				return
			end
		end
	end)

	-- personagem novo (spawn/respawn): a arma some (CombatStance recomeça do
	-- zero pra esse personagem) então a barra também volta pro estado guardado
	player.CharacterAdded:Connect(function()
		equippedWeapon = nil
		refreshAllWeaponSlots()
	end)

	print("[InventoryController] pronto — clique ou tecla numérica pra trocar de arma")
end

return InventoryController
