--!strict
-- MountService.lua  (SERVIDOR)
-- MONTARIA.
--
-- Regra de arquitetura: o servidor é dono de estar montado ou não, da montaria
-- que é, e da velocidade. O cliente só PEDE (tecla H). Se o jogador mandar
-- "montar" duas vezes por segundo, ou pedir uma montaria que não possui, ou
-- tentar montar caindo do céu, quem diz não é este arquivo.
--
-- DECISÃO DE DESIGN: montaria não luta.
-- Atacar, esquivar, bloquear ou usar poder DESMONTA. Levar dano derruba. Isso
-- mantém o combate honesto (nada de kitar montado a 60 de velocidade) e dá à
-- montaria um custo real: subir é trocar prontidão por velocidade. É a mesma
-- lógica da corrida gastando a stamina da esquiva.
--
-- COMO O CORPO FUNCIONA. O cavalo é SOLDADO ao HumanoidRootPart e todas as
-- peças dele são CanCollide = false. Quem anda continua sendo o Humanoid do
-- jogador — não há física de veículo, não há AlignPosition brigando com o
-- terreno, e a resposta ao input continua sendo a mesma do jogo a pé, que já
-- está afinada. O cavaleiro sobe via HipHeight e o corpo do cavalo é encaixado
-- por baixo, na altura exata do chão.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local MountData = require(ReplicatedStorage.Shared.MountData)
local Net = require(ReplicatedStorage.Shared.Net)
local MovementService = require(script.Parent.MovementService)
local PlayerState = require(script.Parent.PlayerState)

local MountRequest = Net.get("MountRequest")
local CombatFeedback = Net.get("CombatFeedback")

local MountService = {}

local MOUNT_COOLDOWN = 1.0 -- evita ligar/desligar em spam

-- =============================================================== CORPO
-- Cavalo estilizado. A silhueta é o que importa: dorso longo, pescoço em
-- diagonal, cabeça baixa à frente. Se der pra reconhecer só pela sombra,
-- funcionou (mesma régua das criaturas).
local function piece(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false -- quem colide é o jogador; peça solta aqui vira briga de física
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.Parent = model
	return p
end

local function buildSteed(m: MountData.Mount, rootCF: CFrame): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "Montaria_" .. m.id
	local L = m.length
	local BACK = m.raise + 1.2 -- altura do dorso (onde a sela fica)

	local root = piece(model, Vector3.new(1, 1, 1), rootCF, m.corpo, Enum.Material.SmoothPlastic)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	-- FRENTE É -Z.
	-- O personagem do Roblox olha pro -Z do próprio CFrame, e o cavalo é soldado
	-- nesse CFrame: construir a cabeça em +Z deixava a montaria ANDANDO DE COSTAS.
	local function at(x: number, y: number, z: number)
		return rootCF * CFrame.new(x, y, z)
	end

	-- Peça alongada definida por ONDE COMEÇA e ONDE TERMINA, com o lookAt
	-- resolvendo a orientação. A primeira versão usava CFrame.Angles e o pescoço
	-- saía inclinado pra trás — girar +X manda o topo na direção da garupa.
	-- Assim fica impossível montar de costas por engano.
	local function limb(fromLocal: Vector3, toLocal: Vector3, w: number, h: number, color: Color3, material: Enum.Material)
		local A = (rootCF * CFrame.new(fromLocal)).Position
		local B = (rootCF * CFrame.new(toLocal)).Position
		return piece(model, Vector3.new(w, h, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), color, material)
	end

	-- BARRIL: fundo e estreito. A primeira versão era 3x3 e lia como caixa marrom.
	piece(model, Vector3.new(2.5, 2.4, L * 0.86), at(0, BACK - 1.2, 0), m.corpo, Enum.Material.SmoothPlastic)
	piece(model, Vector3.new(2.6, 2.6, L * 0.26), at(0, BACK - 1.15, -L * 0.34), m.corpo, Enum.Material.SmoothPlastic)
	piece(model, Vector3.new(2.5, 2.5, L * 0.24), at(0, BACK - 1.05, L * 0.34), m.corpo, Enum.Material.SmoothPlastic)

	-- PESCOÇO e CABEÇA
	local neckBase = Vector3.new(0, BACK - 0.15, -L * 0.31)
	local neckTop = Vector3.new(0, BACK + 2.35, -L * 0.5)
	limb(neckBase, neckTop, 1.45, 1.6, m.corpo, Enum.Material.SmoothPlastic)

	local muzzle = Vector3.new(0, BACK + 1.5, -L * 0.75)
	limb(neckTop + Vector3.new(0, -0.15, 0), muzzle, 1.15, 1.25, m.corpo, Enum.Material.SmoothPlastic)
	local muzzleW = (rootCF * CFrame.new(muzzle)).Position
	local headDir = (muzzleW - (rootCF * CFrame.new(neckTop)).Position).Unit
	piece(model, Vector3.new(0.92, 0.88, 1.0), CFrame.lookAt(muzzleW, muzzleW + headDir), m.corpo, Enum.Material.SmoothPlastic)
	piece(model, Vector3.new(1.22, 0.26, 0.7), CFrame.lookAt(muzzleW + headDir * -0.5, muzzleW + headDir), m.sela, Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		limb(neckTop + Vector3.new(sx * 0.36, 0.1, 0.25), neckTop + Vector3.new(sx * 0.44, 0.95, 0.45), 0.26, 0.26, m.corpo, Enum.Material.SmoothPlastic)
	end
	-- rédeas: do focinho até a mão do cavaleiro
	for _, sx in { -1, 1 } do
		limb(muzzle + Vector3.new(sx * 0.5, 0.1, 0), Vector3.new(sx * 0.6, BACK + 0.9, -0.6), 0.12, 0.12, m.sela, Enum.Material.Fabric)
	end

	-- CRINA ao longo da linha do pescoço
	for i = 0, 5 do
		local f = i / 5
		local base = neckBase:Lerp(neckTop, 0.25 + f * 0.72)
		limb(base + Vector3.new(0, 0.35, 0.28), base + Vector3.new(0, -0.55, 0.72), 0.24, 0.24, m.crina, Enum.Material.Fabric)
	end

	-- CAUDA em duas partes: toco grosso na garupa e rabada caindo. Uma barra reta
	-- e fina lia como TÁBUA PRETA espetada na traseira.
	limb(Vector3.new(0, BACK - 0.3, L * 0.4), Vector3.new(0, BACK - 1.1, L * 0.56), 0.85, 0.85, m.crina, Enum.Material.Fabric)
	limb(Vector3.new(0, BACK - 1.0, L * 0.55), Vector3.new(0, BACK - 3.3, L * 0.6), 0.95, 0.7, m.crina, Enum.Material.Fabric)

	-- PERNAS longas: da barriga até o chão são ~2,2 studs de vão. Perna curta
	-- fazia o cavalo ler como porco.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local legZ = sz * L * 0.3
			local back = sz > 0 and -0.18 or 0
			piece(model, Vector3.new(0.9, 1.9, 1.1), at(sx * 0.95, BACK - 2.5, legZ), m.corpo, Enum.Material.SmoothPlastic)
			piece(model, Vector3.new(0.6, 1.9, 0.6), at(sx * 0.95, BACK - 4.0, legZ + back), m.corpo, Enum.Material.SmoothPlastic)
			piece(model, Vector3.new(0.78, 0.5, 0.9), at(sx * 0.95, BACK - 4.85, legZ + back), m.casco, Enum.Material.Slate)
		end
	end

	-- SELA e manta
	piece(model, Vector3.new(2.8, 0.28, 3.0), at(0, BACK + 0.14, 0.1), m.manta, Enum.Material.Fabric)
	piece(model, Vector3.new(2.2, 0.55, 2.3), at(0, BACK + 0.42, 0.1), m.sela, Enum.Material.Fabric)
	piece(model, Vector3.new(2.3, 0.8, 0.42), at(0, BACK + 0.75, 1.25), m.sela, Enum.Material.Fabric)
	piece(model, Vector3.new(1.9, 0.6, 0.36), at(0, BACK + 0.68, -1.05), m.sela, Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		piece(model, Vector3.new(0.12, 1.3, 0.12), at(sx * 1.2, BACK - 0.5, 0.1), m.sela, Enum.Material.Fabric)
		piece(model, Vector3.new(0.6, 0.16, 0.45), at(sx * 1.2, BACK - 1.2, 0.1), m.casco, Enum.Material.Metal)
	end

	-- anomalia: Neon em PONTO, nunca em bloco
	if m.brilho then
		for _, sx in { -1, 1 } do
			local eye = piece(model, Vector3.new(0.2, 0.2, 0.2), CFrame.new(muzzleW) * CFrame.new(sx * 0.5, 0.4, 0.6), m.brilho, Enum.Material.Neon)
			eye.Shape = Enum.PartType.Ball
		end
		local aura = Instance.new("ParticleEmitter")
		aura.Rate = 9
		aura.Lifetime = NumberRange.new(0.6, 1.1)
		aura.Speed = NumberRange.new(0.5, 1.6)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.LightEmission = 0.8
		aura.LightInfluence = 0
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		aura.Color = ColorSequence.new(m.brilho)
		aura.Parent = root
	end

	-- solda tudo na raiz: um corpo rígido só
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = root
		end
	end

	return model, root
end

-- =============================================================== ESTADO
local active: { [Player]: { model: Model, id: string, baseHip: number, baseSpeed: number } } = {}

function MountService.isMounted(player: Player): boolean
	return active[player] ~= nil
end

function MountService.dismount(player: Player, reason: string?)
	local entry = active[player]
	if not entry then
		return
	end
	active[player] = nil

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.HipHeight = entry.baseHip
		hum.JumpPower = 50
	end
	entry.model:Destroy()

	local s = PlayerState.get(player)
	if s then
		s.mounted = nil
	end
	-- quem escreve WalkSpeed continua sendo o MovementService
	MovementService.applyWalkSpeed(player)
	if reason then
		CombatFeedback:FireClient(player, {
			kind = "notify",
			text = reason,
			color = Color3.fromRGB(226, 200, 140),
		})
	end
end

local function mount(player: Player, id: string)
	local s = PlayerState.get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (s and hum and hrp) then
		return
	end

	-- VALIDAÇÕES. O cliente pede; aqui é onde o pedido morre se não fizer sentido.
	if hum.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < (s.mountCdUntil or 0) then
		return
	end
	if os.clock() < s.stunUntil then
		return -- atordoado não sobe em cavalo
	end
	-- no ar não monta: senão dá pra usar a montaria como plataforma voadora
	if hum:GetState() == Enum.HumanoidStateType.Freefall or hum:GetState() == Enum.HumanoidStateType.Jumping then
		return
	end

	local m = MountData.get(id)
	if not m then
		return
	end

	s.mountCdUntil = now + MOUNT_COOLDOWN

	-- levanta o cavaleiro e encaixa o corpo por baixo, no chão exato
	local baseHip = hum.HipHeight
	local baseSpeed = hum.WalkSpeed
	hum.HipHeight = baseHip + m.raise
	task.wait() -- deixa o personagem subir antes de medir

	if not (char.Parent and hrp.Parent) then
		hum.HipHeight = baseHip
		return
	end

	-- o chão fica em HRP.Y - HipHeight - metade da altura do HRP
	local groundOffset = -(hum.HipHeight + hrp.Size.Y / 2)
	local rootCF = hrp.CFrame * CFrame.new(0, groundOffset, 0)

	local model, root = buildSteed(m, rootCF)
	model.Parent = workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.Parent = root

	hum.JumpPower = m.jump

	active[player] = { model = model, id = id, baseHip = baseHip, baseSpeed = baseSpeed }
	s.mounted = id
	MovementService.applyWalkSpeed(player)

	CombatFeedback:FireClient(player, {
		kind = "notify",
		text = "MONTOU — " .. m.nome,
		color = Color3.fromRGB(226, 200, 140),
	})
end

local function onRequest(player: Player, wanted: unknown)
	if MountService.isMounted(player) then
		MountService.dismount(player)
		return
	end
	local id = typeof(wanted) == "string" and wanted or MountData.DEFAULT
	mount(player, id)
end

-- Chamado pelo combate: qualquer ação ofensiva ou defensiva derruba.
function MountService.breakOnAction(player: Player)
	if active[player] then
		MountService.dismount(player, "VOCÊ DESMONTOU")
	end
end

function MountService.breakOnDamage(player: Player)
	if active[player] then
		MountService.dismount(player, "DERRUBADO DA MONTARIA")
	end
end

function MountService.Start()
	MountRequest.OnServerEvent:Connect(onRequest)

	-- MONTARIA NÃO LUTA. Escutamos os mesmos remotes que o combate escuta, em
	-- vez de pedir ao CombatService/MovementService que nos chamem. Assim a
	-- dependência aponta só numa direção (MountService -> MovementService) e o
	-- MovementService continua sem saber que montaria existe — o que mantém ele
	-- como dono único de WalkSpeed.
	for _, remote in { "AttackRequest", "HeavyRequest", "UltimateRequest", "PowerRequest", "DashRequest" } do
		Net.get(remote).OnServerEvent:Connect(function(player)
			MountService.breakOnAction(player)
		end)
	end
	Net.get("BlockRequest").OnServerEvent:Connect(function(player, down)
		if down == true then
			MountService.breakOnAction(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = active[player]
		if entry then
			entry.model:Destroy()
			active[player] = nil
		end
	end)

	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			local entry = active[player]
			if entry then
				entry.model:Destroy()
				active[player] = nil
				local s = PlayerState.get(player)
				if s then
					s.mounted = nil
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			hook(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	print("[MountService] pronto — H monta/desmonta")
end

return MountService
