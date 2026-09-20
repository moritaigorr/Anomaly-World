--!strict
-- AuraController.lua  (CLIENTE)
-- Aura ambiente ao redor do corpo, com a identidade visual da Anomaly Core
-- equipada: Thunder solta faíscas elétricas subindo rápido, Frost solta uma
-- neblina gelada subindo devagar. Tudo com ParticleEmitter + Highlight
-- nativos do Roblox (mesma técnica que plugins de "aura"/VFX usam) — sem
-- depender de nenhum asset externo, só texturas embutidas do engine
-- (rbxasset://), então funciona offline e sem precisar instalar nada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local CoreData = require(ReplicatedStorage.Shared.CoreData)
local StateUpdate = Net.get("StateUpdate")

local player = Players.LocalPlayer

local AuraController = {}

type Style = {
	color: Color3,
	texture: string,
	rate: number,
	speed: NumberRange,
	lifetime: NumberRange,
	sizeStart: number,
	sizeEnd: number,
	spread: Vector2,
	acceleration: Vector3,
}

-- estilo por id de Core (ReplicatedStorage/Shared/CoreData.lua). Core nova
-- sem estilo próprio cai no genérico (pega só a cor dela).
local AURA_STYLES: { [string]: Style } = {
	thunder = {
		color = Color3.fromRGB(160, 215, 255),
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		rate = 45,
		speed = NumberRange.new(3, 6),
		lifetime = NumberRange.new(0.35, 0.65),
		sizeStart = 0.5,
		sizeEnd = 0.05,
		spread = Vector2.new(180, 180), -- estoura pra todo lado, tipo descarga
		acceleration = Vector3.new(0, 3, 0),
	},
	frost = {
		color = Color3.fromRGB(205, 240, 255),
		texture = "rbxasset://textures/particles/smoke_main.dds",
		rate = 28,
		speed = NumberRange.new(0.8, 1.8),
		lifetime = NumberRange.new(1.6, 2.6),
		sizeStart = 0.9,
		sizeEnd = 1.9,
		spread = Vector2.new(45, 45), -- deriva devagar pra cima, tipo neblina
		acceleration = Vector3.new(0, 1, 0),
	},
}

local function genericStyle(color: Color3): Style
	return {
		color = color,
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		rate = 32,
		speed = NumberRange.new(2, 4),
		lifetime = NumberRange.new(0.6, 1.1),
		sizeStart = 0.4,
		sizeEnd = 0.05,
		spread = Vector2.new(90, 90),
		acceleration = Vector3.new(0, 2, 0),
	}
end

type Aura = {
	attachment: Attachment,
	emitter: ParticleEmitter,
	highlight: Highlight,
}

local auraByCharacter: { [Model]: Aura } = setmetatable({}, { __mode = "k" }) :: any
local currentCoreId: string? = nil

local function destroyAura(character: Model)
	local aura = auraByCharacter[character]
	if aura then
		aura.attachment:Destroy()
		aura.highlight:Destroy()
		auraByCharacter[character] = nil
	end
end

local function buildAura(character: Model, style: Style)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	destroyAura(character)

	local attachment = Instance.new("Attachment")
	attachment.Name = "AnomalyAuraPoint"
	attachment.Position = Vector3.new(0, -0.5, 0) -- perto do centro do corpo, não nos pés
	attachment.Parent = hrp

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = style.texture
	emitter.Color = ColorSequence.new(style.color)
	emitter.Size = NumberSequence.new(style.sizeStart, style.sizeEnd)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = style.lifetime
	emitter.Rate = style.rate
	emitter.Speed = style.speed
	emitter.SpreadAngle = style.spread
	emitter.Acceleration = style.acceleration
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.ZOffset = -0.2 -- evita sumir atrás do corpo do próprio jogador
	emitter.Parent = attachment

	local highlight = Instance.new("Highlight")
	highlight.Name = "AnomalyAuraGlow"
	highlight.FillColor = style.color
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = style.color
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character

	auraByCharacter[character] = { attachment = attachment, emitter = emitter, highlight = highlight }
end

-- troca a aura pro id da Core equipada (ex.: "thunder", "frost"). nil tira.
local function applyCore(coreId: string?)
	currentCoreId = coreId
	local character = player.Character
	if not character then
		return
	end
	if not coreId then
		destroyAura(character)
		return
	end
	local style = AURA_STYLES[coreId]
	if not style then
		-- Core sem estilo próprio ainda: usa a cor dela (CoreData.cor) genérica
		for _, name in CoreData.order do
			local core = CoreData[name]
			if core.id == coreId then
				style = genericStyle(core.cor)
				break
			end
		end
	end
	if style then
		buildAura(character, style)
	end
end

-- acha o id (CoreData) a partir do nome de exibição que o servidor manda
-- (ex.: "Thunder Core" -> "thunder")
local function coreIdFromName(coreName: string): string?
	for _, name in CoreData.order do
		local core = CoreData[name]
		if core.nome == coreName then
			return core.id
		end
	end
	return nil
end

function AuraController.Start()
	StateUpdate.OnClientEvent:Connect(function(data)
		if data.coreName then
			local id = coreIdFromName(data.coreName)
			if id ~= currentCoreId then
				applyCore(id)
			end
		end
	end)

	player.CharacterAdded:Connect(function(character)
		-- o corpo é novo, mas a Core equipada continua a mesma — recria a aura
		task.wait(0.1) -- deixa o HumanoidRootPart existir antes de anexar
		applyCore(currentCoreId)
	end)

	print("[AuraController] pronto")
end

return AuraController
